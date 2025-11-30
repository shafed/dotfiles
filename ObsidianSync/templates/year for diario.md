---
related: "[[diario]]"
tags:
  - periodic/year
---

```dataview
table
where related = [[<% tp.date.now("YYYY") %>]] and contains(file.tags, "#periodic/month")
sort file.name asc
```
<%*
const newName = tp.date.now("YYYY");
await tp.file.rename(newName);
%>
