---
aliases:
  - все видео
---

```dataview
table status as "status", category as "category", creator as "creator", link as "link"
where contains(file.tags, "#source/video")
sort file.mtime desc
```
