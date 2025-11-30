<%*
// naming
let title = tp.file.title
if (title.startsWith("Untitled")) {
	title = await tp.system.prompt("Title");
}
await tp.file.rename(title)

// select category
const dv = this.app.plugins.plugins["dataview"].api
const categories = dv.pages("#system/category").sort(p => p.file.name).file.name
let category = await tp.system.suggester(categories.map(function (value) {return "🗺️ "+value}), categories, false, "Select the category")
if (category != null) {
	category = "\n  - \"[[" + category + "]]\""
} else {
	category = ""
}
-%>
<% "---" %>
tags:
  - system/hierarchy
aliases:
category:<% category %>
<% "---" %>

<% tp.file.cursor(0) %>