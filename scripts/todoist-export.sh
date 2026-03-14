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

# Fetch all data in a single request using the Sync API
SYNC=$(curl -sf "https://api.todoist.com/api/v1/sync" \
  -H "Authorization: Bearer $TODOIST_TOKEN" \
  -d "sync_token=*" \
  -d "resource_types=[\"all\"]")

TASKS=$(echo "$SYNC" | jq '[.items[] | select(.checked == false and .is_deleted == false)]')
PROJECTS=$(echo "$SYNC" | jq '[.projects[] | select(.is_deleted == false)]')
SECTIONS=$(echo "$SYNC" | jq '[.sections[] | select(.is_deleted == false)]')

# Format a single task as a markdown checkbox with optional due date and priority icon
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
  local lines=""

  # Tasks not assigned to any section
  local no_section_tasks
  no_section_tasks=$(echo "$TASKS" | jq -c --arg pid "$project_id" \
    '[.[] | select(.project_id == $pid and .section_id == null)]')

  if [[ $(echo "$no_section_tasks" | jq 'length') -gt 0 ]]; then
    while IFS= read -r task; do
      local content due priority id
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
      local content due priority id
      content=$(echo "$task" | jq -r '.content')
      due=$(echo "$task" | jq -r '.due.date // empty')
      priority=$(echo "$task" | jq -r '.priority')
      id=$(echo "$task" | jq -r '.id')
      lines+="  $(build_task_line "$content" "$due" "$priority" "$id")\n"
    done < <(echo "$section_tasks" | jq -c '.[]')
  done < <(echo "$SECTIONS" | jq -c --arg pid "$project_id" '[.[] | select(.project_id == $pid)] | .[]')

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
      local content due priority id
      content=$(echo "$task" | jq -r '.content')
      due=$(echo "$task" | jq -r '.due.date // empty')
      priority=$(echo "$task" | jq -r '.priority')
      id=$(echo "$task" | jq -r '.id')
      lines+="  $(build_task_line "$content" "$due" "$priority" "$id")\n"
    done < <(echo "$project_tasks" | jq -c '.[]')
    lines+="\n"
  done < <(echo "$PROJECTS" | jq -c '.[]')
  echo -e "$lines"
}

# Return the project ID for a given project name (case-insensitive)
find_project_id() {
  local name="$1"
  local id
  id=$(echo "$PROJECTS" | jq -r --arg name "$name" \
    '.[] | select(.name | ascii_downcase == ($name | ascii_downcase)) | .id')
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
  local id
  id=$(echo "$SECTIONS" | jq -r --arg pid "$project_id" --arg name "$section_name" \
    '.[] | select(.project_id == $pid and (.name | ascii_downcase == ($name | ascii_downcase))) | .id')
  if [[ -z "$id" ]]; then
    echo "Section '$section_name' not found. Available sections:" >&2
    echo "$SECTIONS" | jq -r --arg pid "$project_id" \
      '.[] | select(.project_id == $pid) | .name' >&2
    exit 1
  fi
  echo "$id"
}

# Build a flat task list for a single section
build_md_section() {
  local section_id="$1"
  local lines=""
  while IFS= read -r task; do
    local content due priority id
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

# List all sections of a project
--list-sections)
  [[ -z "$2" ]] && {
    echo "Specify a project name" >&2
    exit 1
  }
  PID=$(find_project_id "$2")

  # Sections with tasks first, empty ones last
  echo "$SECTIONS" | jq -r --arg pid "$PID" --argjson tasks "$TASKS" \
    '[.[] | select(.project_id == $pid)] |
     sort_by(
       .id as $sid |
       if ($tasks | any(.section_id == $sid)) then 0 else 1 end
     ) | .[].name'
  ;;

# List all sections across all projects (used for autocomplete preload)
--list-all-sections)
  echo "$SECTIONS" | jq -r --argjson projects "$PROJECTS" \
    '.[] | . as $sec | ($projects[] | select(.id == $sec.project_id) | .name) + "/" + $sec.name'
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

# List all project names
--list-projects)
  echo "$PROJECTS" | jq -r '.[].name'
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

# Complete a task in Todoist
--complete)
  [[ -z "$2" ]] && {
    echo "Specify a task ID" >&2
    exit 1
  }
  curl -sf -X POST "https://api.todoist.com/api/v1/tasks/$2/close" \
    -H "Authorization: Bearer $TODOIST_TOKEN"
  echo "Task $2 completed"
  ;;

# Reopen a completed task in Todoist
--reopen)
  [[ -z "$2" ]] && {
    echo "Specify a task ID" >&2
    exit 1
  }
  curl -sf -X POST "https://api.todoist.com/api/v1/tasks/$2/reopen" \
    -H "Authorization: Bearer $TODOIST_TOKEN"
  echo "Task $2 reopened"
  ;;

# Add a new task with optional project and section
--add)
  [[ -z "$2" ]] && {
    echo "Specify task content" >&2
    exit 1
  }
  content="$2"
  project_id=""
  section_id=""

  if [[ -n "$3" ]]; then
    project_id=$(find_project_id "$3")
  fi

  if [[ -n "$4" && -n "$project_id" ]]; then
    section_id=$(find_section_id "$project_id" "$4")
  fi

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

# Export all projects grouped by name
"")
  write_md "$(build_md_grouped)"
  ;;

*)
  echo "Usage: $0 [--project NAME [SECTION] | --list-projects | --list-sections NAME | --list-all-sections | --list-section-tasks PROJECT SECTION | --complete ID | --reopen ID | --add CONTENT [PROJECT] [SECTION]]" >&2
  exit 1
  ;;
esac
