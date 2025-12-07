-- Функция для установки цветов в стиле Gruvbox Material
local function set_markdown_highlights()
    -- ЗАГОЛОВКИ (H1 - H6)
    -- В Material Gruvbox используются более мягкие оттенки
    vim.api.nvim_set_hl(0, "@markup.heading.1.markdown", { fg = "#c14a4a", bold = true }) -- Red
    vim.api.nvim_set_hl(0, "@markup.heading.2.markdown", { fg = "#d8a657", bold = true }) -- Yellow
    vim.api.nvim_set_hl(0, "@markup.heading.3.markdown", { fg = "#a9b665", bold = true }) -- Green
    vim.api.nvim_set_hl(0, "@markup.heading.4.markdown", { fg = "#7daea3", bold = true }) -- Aqua
    vim.api.nvim_set_hl(0, "@markup.heading.5.markdown", { fg = "#d3869b", bold = true }) -- Purple
    vim.api.nvim_set_hl(0, "@markup.heading.6.markdown", { fg = "#89b482", bold = true }) -- Green (alt)

    
    -- ЖИРНЫЙ И КУРСИВ
    vim.api.nvim_set_hl(0, "@markup.strong", { bold = true, fg = "#e78a4e" }) -- Orange для жирного
    vim.api.nvim_set_hl(0, "@markup.italic", { italic = true, fg = "#a9b665" }) -- Green для курсива

    -- ССЫЛКИ (URL)
    vim.api.nvim_set_hl(0, "@markup.link.label", { fg = "#7daea3" }) -- Aqua для текста ссылки
    vim.api.nvim_set_hl(0, "@markup.link.url", { fg = "#d3869b", italic = true }) -- Purple для URL
    
    -- INLINE CODE
    vim.api.nvim_set_hl(0, "@markup.raw.markdown_inline", { fg = "#d8a657" }) -- Yellow для инлайн кода
end

-- Применяем настройки при загрузке и при смене цветовой схемы
set_markdown_highlights()
vim.api.nvim_create_autocmd("ColorScheme", {
    pattern = "*",
    callback = set_markdown_highlights,
})
