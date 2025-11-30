---
aliases:
  - книги
  - книжные заметки
---

```dataview
table creator as "Автор"
where contains(file.tags, "#source/book")
sort file.mtime desc
```

