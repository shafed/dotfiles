---
related: "[[<% tp.date.now("YYYY") %>]]"
tags: periodic/month
---

```dataview
table
where related = this.file.link and contains(file.tags, "#periodic/day")
sort asc
```
<%*
// Получаем название месяца на русском и делаем первую букву заглавной
const monthRaw = tp.date.now("MMMM", "ru");  
const month = monthRaw.charAt(0).toUpperCase() + monthRaw.slice(1);

// Формируем имя: номер месяца, точка, месяц с заглавной, год
const newName = `${tp.date.now("MM", "ru")}. ${month} ${tp.date.now("YYYY")}`;

// Переименовываем файл
await tp.file.rename(newName);
%>