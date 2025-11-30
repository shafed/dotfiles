---
tags:
  - note/basic
---
```dataviewjs
/**
 * List all icons available to `obsidian.setIcon()`
 * 
 * @author Ljavuras <ljavuras.py@gmail.com>
 */

dv.container.createEl("style", { attr: { scope: "" }, text: `
.icon-table {
    display: flex;
    flex-wrap: wrap;
    margin: 0 var(--size-4-6);
}

.icon-item {
    padding: var(--size-4-2);
    line-height: 0;
    cursor: pointer;
}

.icon-item:hover {
    background-color: var(--background-modifier-active-hover);
    border-radius: var(--radius-s);
}
`});

function renderIconTable(ids) {
    const tableEl = dv.container.createDiv("icon-table");
    ids.forEach((id) => {
        let iconEl = tableEl.createDiv("icon-item");
        obsidian.setIcon(iconEl, id);
        obsidian.setTooltip(iconEl, id, { delay: 0 });
        iconEl.onclick = () => {
            navigator.clipboard.writeText(id);
            new Notice("Copied to clipboard.");
        }
    });
}

let lucide_ids = obsidian.getIconIds()
    .filter(id => id.startsWith("lucide-"))
    .map(id => id.slice(7));
dv.paragraph(`${lucide_ids.length} Lucide icons`);
renderIconTable(lucide_ids);

let other_ids = obsidian.getIconIds().filter(id => !id.startsWith("lucide-"));
dv.paragraph(`${other_ids.length} other icons`);
renderIconTable(other_ids);
```

