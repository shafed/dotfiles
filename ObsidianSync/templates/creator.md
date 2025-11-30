<%*
// naming
let title = tp.file.title
if (title.startsWith("Untitled")) {
title = await tp.system.prompt("Title");
}
await tp.file.rename(title)
-%>
<% "---" %>
tags:
  - people/creator
aliases:
<% "---" %>

# Sources
```dataview
LIST
FROM #source
WHERE contains(creator, [[]])
```
# Quotes
```dataview
LIST
FROM #mark/quote
WHERE contains(file.outlinks, [[]])
```
# Mentions
```dataview
LIST
FROM -#source AND -#mark/quote
WHERE contains(file.outlinks, [[]])
```