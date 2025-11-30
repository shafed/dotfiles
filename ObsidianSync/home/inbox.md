---
aliases:
  - Заметки
  - Просто
  - Входящие
---

# Inbox
```dataview
LIST
FROM #mark/fleeting
SORT file.ctime DESC
```
# Evergreen
```dataview
LIST
FROM #note/evergreen
SORT file.name ASC
```
# Orphans
```dataview
LIST
FROM 
	!"home" 
	AND 
	!"templates" 
	AND 
	!"periodic"
	AND
	!"projects"
	AND
	!"sources"
	AND
	!"types"
WHERE
	length(file.inlinks) = 0 
	AND 
	length(file.outlinks) = 0
	AND
	!regexmatch("^\\d{4}-\\d{2}-\\d{2} sleep$", file.name)
```
