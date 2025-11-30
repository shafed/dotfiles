---
related: '[[<%* moment.locale("ru"); const monthNumber = moment().format("MM"); const monthName = moment().format("MMMM").charAt(0).toUpperCase() + moment().format("MMMM").slice(1); const year = moment().format("YYYY"); tR += `${monthNumber}. ${monthName} ${year}`; %>]]'
tags:
  - periodic/day
---

```meta-bind-button
label: Next Note
icon: ""
style: default
class: obsidian
cssStyle: ""
backgroundImage: ""
tooltip: ""
id: ""
hidden: false
actions:
  - type: command
    command: daily-notes:goto-next

```
```meta-bind-button
label: Previous Note
icon: ""
style: default
class: obsidian
cssStyle: ""
backgroundImage: ""
tooltip: ""
id: ""
hidden: false
actions:
  - type: command
    command: daily-notes:goto-prev

```

<% tp.file.cursor(1) %>