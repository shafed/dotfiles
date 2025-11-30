<%*
setTimeout(() => {
app.fileManager.processFrontMatter(tp.config.target_file, frontmatter => {
delete frontmatter["tags"]
frontmatter["tags"] = ["note/basic", "mark/quote"]
frontmatter["aliases"] = []
})
}, 400)
-%>

> [!quote]
> <% tp.file.cursor(0) %>
> - source
> - author