---
aliases:
  - journal
  - diary
  - дневник
---

```dataview
TABLE
WHERE contains(file.tags, "#periodic/year") and !contains(file.path, "templates")
SORT file.name ASC
```
