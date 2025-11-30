---
tags: 
  - system/category
aliases:
---

# Hierarchy

```dataview
LIST
FROM #system/hierarchy
WHERE contains(category, [[]])
SORT file.name ASC
```

# Meta-notes

```dataview
LIST
FROM #system/meta
WHERE contains(category, [[]])
SORT file.name ASC
```

# Projects

```dataviewjs
const {fieldModifier: f} = MetadataMenu.api

dv.table(["Project", "Status", "Category", "Start", "End"], 
    dv.pages("#project")
    .where(p => dv.func.contains(p.category, dv.current().file.link))
    .sort(p => {
        switch (p.status) {
            case "wip": return 0;
            case "todo": return 1;
            case "done": return 2;
            case "drop": return 3;
        }
    })
    .map(p => [
        p.file.link, 
        f(dv, p, "status"),
        f(dv, p, "category"),
        f(dv, p, "start"),
        f(dv, p, "end")
        ])
)
```

# Sources

```dataviewjs
const {fieldModifier: f} = MetadataMenu.api

dv.table(["Source", "Status", "Category", "Creator", "URL"], 
    dv.pages("#source")
    .where(p => dv.func.contains(p.category, dv.current().file.link))
    .sort(p => {
        switch (p.status) {
            case "wip": return 0;
            case "todo": return 1;
            case "done": return 2;
            case "drop": return 3;
        }
    })
    .map(p => [
        p.file.link, 
        f(dv, p, "status"),
        f(dv, p, "category"),
        f(dv, p, "creator"),
        f(dv, p, "url")
        ])
)
```