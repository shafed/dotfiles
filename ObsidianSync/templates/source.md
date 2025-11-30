<%*
// naming
let title = tp.file.title
if (title.startsWith("Untitled")) {
	title = await tp.system.prompt("Title");
}
await tp.file.rename(title)

// select source type
const source_types = ["🧾 article", "📖 book", "🎓 course", "🎬 movie", "📻 podcast", "📺 video"]
let input_source_type = await tp.system.suggester(source_types, source_types.map(function (value) {return value.slice(2).trim()}), false, "Source TYPE")
if (input_source_type != null) {
	input_source_type = "\n  - source/" + input_source_type
} else {
	input_source_type = "\n  - source/article"
	input_source_type += "\n  - mark/fleeting"
}

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
tags:<% input_source_type %>
aliases:
status: todo
category:<% category %>
creator:
url:
<% "---" %>

<% tp.file.cursor(1) %>