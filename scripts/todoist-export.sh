#!/usr/bin/env bash

# ── Config ────────────────────────────────────────────────
TODOIST_TOKEN="f3736efb85c6f5c726090bb92df83fa9b07a6b19"

# Mirror the directory structure from daily-notes.sh
main_note_dir=~/obsidian/periodic

current_year=$(date +"%Y")
current_month_num=$(date +"%m")
current_month_abbr=$(date +"%b")
current_day=$(date +"%d")
current_weekday=$(date +"%A")

note_dir=${main_note_dir}/${current_year}/${current_month_num}-${current_month_abbr}
note_name=${current_year}-${current_month_num}-${current_day}-${current_weekday}
OUT=${note_dir}/${note_name}.md
TODAY=$(date +%Y-%m-%d)
# ──────────────────────────────────────────────────────────

# Fetch data from the Todoist API v1
api_get() {
  curl -sf "https://api.todoist.com/api/v1/$1" \
    -H "Authorization: Bearer $TODOIST_TOKEN"
}

# Load all tasks and projects upfront to avoid redundant API calls
TASKS=$(api_get tasks | jq '.results // .')
PROJECTS=$(api_get projects | jq '.results // .')

# Format a single task as a markdown checkbox line with optional due date and priority icon
build_task_line() {
  local content="$1" due="$2" priority="$3" id="$4"
  local icon=""
  case $priority in
  4) icon=" 🔴" ;;
  3) icon=" 🟠" ;;
  2) icon=" 🔵" ;;
  esac
  local due_str=""
  [[ -n "$due" && "$due" != "null" ]] && due_str=" \`$due\`"
  echo "- [ ] ${content}${due_str}${icon} <!-- todoist:$id -->"
}

# Build a task list for a single project, grouped by sections
build_md_filtered() {
  local project_id="$1"

  # Fetch sections for this project
  local sections
  sections=$(api_get "sections?project_id=$project_id" | jq '.results // .')

  local lines=""

  # Tasks not assigned to any section
  local no_section_tasks
  no_section_tasks=$(echo "$TASKS" | jq -c --arg pid "$project_id" \
    '[.[] | select(.project_id == $pid and .section_id == null)]')

  if [[ $(echo "$no_section_tasks" | jq 'length') -gt 0 ]]; then
    while IFS= read -r task; do
      local content due priority
      content=$(echo "$task" | jq -r '.content')
      due=$(echo "$task" | jq -r '.due.date // empty')
      priority=$(echo "$task" | jq -r '.priority')
      id=$(echo "$task" | jq -r '.id')
      lines+="$(build_task_line "$content" "$due" "$priority" "$id")\n"
    done < <(echo "$no_section_tasks" | jq -c '.[]')
  fi

  # Tasks grouped under their section as a nested bullet
  while IFS= read -r section; do
    local sid sname section_tasks
    sid=$(echo "$section" | jq -r '.id')
    sname=$(echo "$section" | jq -r '.name')
    section_tasks=$(echo "$TASKS" | jq -c --arg sid "$sid" \
      '[.[] | select(.section_id == $sid)]')

    # Skip sections with no tasks
    [[ $(echo "$section_tasks" | jq 'length') -eq 0 ]] && continue

    lines+="- **$sname**\n"
    while IFS= read -r task; do
      local content due priority
      content=$(echo "$task" | jq -r '.content')
      due=$(echo "$task" | jq -r '.due.date // empty')
      priority=$(echo "$task" | jq -r '.priority')
      id=$(echo "$task" | jq -r '.id')
      lines+="$(build_task_line "$content" "$due" "$priority" "$id")\n"
    done < <(echo "$section_tasks" | jq -c '.[]')
  done < <(echo "$sections" | jq -c '.[]')

  echo -e "$lines"
}

# Build a task list for all projects, each as a nested bullet group
build_md_grouped() {
  local lines=""
  while IFS= read -r project; do
    local pid pname
    pid=$(echo "$project" | jq -r '.id')
    pname=$(echo "$project" | jq -r '.name')
    local project_tasks
    project_tasks=$(echo "$TASKS" | jq -c --arg pid "$pid" '[.[] | select(.project_id == $pid)]')

    # Skip projects with no tasks
    [[ $(echo "$project_tasks" | jq 'length') -eq 0 ]] && continue

    lines+="- **$pname**\n"
    while IFS= read -r task; do
      local content due priority
      content=$(echo "$task" | jq -r '.content')
      due=$(echo "$task" | jq -r '.due.date // empty')
      priority=$(echo "$task" | jq -r '.priority')
      id=$(echo "$task" | jq -r '.id')
      lines+="$(build_task_line "$content" "$due" "$priority" "$id")\n"
    done < <(echo "$project_tasks" | jq -c '.[]')
    lines+="\n"
  done < <(echo "$PROJECTS" | jq -c '.[]')
  echo -e "$lines"
}

# Return the project ID for a given project name (case-insensitive)
find_project_id() {
  local name="$1"
  local id
  id=$(echo "$PROJECTS" | jq -r --arg name "$name" '.[] | select(.name | ascii_downcase == ($name | ascii_downcase)) | .id')
  if [[ -z "$id" ]]; then
    echo "Project '$name' not found. Available projects:" >&2
    echo "$PROJECTS" | jq -r '.[].name' >&2
    exit 1
  fi
  echo "$id"
}

# Return the section ID for a given section name within a project (case-insensitive)
find_section_id() {
  local project_id="$1" section_name="$2"
  local sections id
  sections=$(api_get "sections?project_id=$project_id" | jq '.results // .')
  id=$(echo "$sections" | jq -r --arg name "$section_name" \
    '.[] | select(.name | ascii_downcase == ($name | ascii_downcase)) | .id')
  if [[ -z "$id" ]]; then
    echo "Section '$section_name' not found. Available sections:" >&2
    echo "$sections" | jq -r '.[].name' >&2
    exit 1
  fi
  echo "$id"
}

# Build a flat task list for a single section
build_md_section() {
  local section_id="$1"
  local lines=""
  while IFS= read -r task; do
    local content due priority
    content=$(echo "$task" | jq -r '.content')
    due=$(echo "$task" | jq -r '.due.date // empty')
    priority=$(echo "$task" | jq -r '.priority')
    id=$(echo "$task" | jq -r '.id')
    lines+="$(build_task_line "$content" "$due" "$priority" "$id")\n"
  done < <(echo "$TASKS" | jq -c --arg sid "$section_id" '.[] | select(.section_id == $sid)')
  echo -e "$lines"
}

# Write the markdown content to today's note file.
# If the file exists, insert after the ## Tasks heading.
# If the file doesn't exist, create it with the content.
write_md() {
  mkdir -p "$note_dir"
  if [[ -f "$OUT" ]]; then
    if grep -q "^## Tasks" "$OUT"; then
      awk -v content="$1" '
        /^## Tasks/ { print; print ""; print content; next }
        { print }
      ' "$OUT" >"$OUT.tmp" && mv "$OUT.tmp" "$OUT"
      echo "Inserted after ## Tasks: $OUT"
    else
      echo "Heading ## Tasks not found in $OUT" >&2
      exit 1
    fi
  else
    echo "$1" >"$OUT"
    echo "Created file: $OUT"
  fi
}

# ── Entry point ───────────────────────────────────────────
case "$1" in
--list-projects)
  echo "$PROJECTS" | jq -r '.[].name'
  ;;
# List sections of a project that have at least one task
--list-sections)
  [[ -z "$2" ]] && {
    echo "Specify a project name" >&2
    exit 1
  }
  PID=$(find_project_id "$2")
  sections=$(api_get "sections?project_id=$PID" | jq '.results // .')
  tasks_in_project=$(echo "$TASKS" | jq --arg pid "$PID" '[.[] | select(.project_id == $pid)]')
  echo "$sections" | jq -r --argjson tasks "$tasks_in_project" \
    '.[] | select(.id as $sid | $tasks | any(.section_id == $sid)) | .name'
  ;;

# List tasks in a specific section (used for picker preview)
--list-section-tasks)
  [[ -z "$2" || -z "$3" ]] && {
    echo "Specify a project and section name" >&2
    exit 1
  }
  PID=$(find_project_id "$2")
  SID=$(find_section_id "$PID" "$3")
  echo "$TASKS" | jq -r --arg sid "$SID" \
    '.[] | select(.section_id == $sid) | "- [ ] " + .content'
  ;;
--complete)
  [[ -z "$2" ]] && {
    echo "Specify a task ID" >&2
    exit 1
  }
  curl -sf -X POST "https://api.todoist.com/api/v1/tasks/$2/close" \
    -H "Authorization: Bearer $TODOIST_TOKEN"
  echo "Task $2 completed"
  ;;
--reopen)
  [[ -z "$2" ]] && {
    echo "Specify a task ID" >&2
    exit 1
  }
  curl -sf -X POST "https://api.todoist.com/api/v1/tasks/$2/reopen" \
    -H "Authorization: Bearer $TODOIST_TOKEN"
  echo "Task $2 reopened"
  ;;
--add)
  [[ -z "$2" ]] && {
    echo "Specify task content" >&2
    exit 1
  }
  content="$2"
  project_id=""
  section_id=""

  # Resolve project ID if provided
  if [[ -n "$3" ]]; then
    project_id=$(find_project_id "$3")
  fi

  # Resolve section ID if provided
  if [[ -n "$4" && -n "$project_id" ]]; then
    section_id=$(find_section_id "$project_id" "$4")
  fi

  # Build JSON payload
  payload=$(jq -n \
    --arg content "$content" \
    --arg pid "$project_id" \
    --arg sid "$section_id" \
    '{content: $content} +
     (if $pid != "" then {project_id: $pid} else {} end) +
     (if $sid != "" then {section_id: $sid} else {} end)')

  result=$(curl -sf -X POST "https://api.todoist.com/api/v1/tasks" \
    -H "Authorization: Bearer $TODOIST_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$payload")
  echo "$result" | jq -r '.id'
  ;;
# Export a project, optionally filtered to a single section
--project)
  [[ -z "$2" ]] && {
    echo "Specify a project name: --project NAME [SECTION]" >&2
    exit 1
  }
  PID=$(find_project_id "$2")
  if [[ -n "$3" ]]; then
    SID=$(find_section_id "$PID" "$3")
    write_md "$(build_md_section "$SID")"
  else
    write_md "$(build_md_filtered "$PID")"
  fi
  ;;

# Export all projects grouped by name
"")
  write_md "$(build_md_grouped)"
  ;;

*)
  echo "Usage: $0 [--project NAME [SECTION] | --list-sections NAME | --list-section-tasks PROJECT SECTION]" >&2
  exit 1
  ;;
esac
