return {
  "kamegoro/tobira.nvim",
  event = "VeryLazy",

  config = function()
    local float = require("tobira.ui.float")

    -- Обычная подсказка Tobira -> Noice
    float.show = function(suggestion, _, pattern)
      local str = require("tobira.i18n").load()
      local sug = str.suggestions and str.suggestions[suggestion.cmd]

      if not sug then
        return
      end

      local lines = {}

      local reason
      if pattern and str.float.reasons and str.float.reasons[pattern] then
        reason = str.float.reasons[pattern]
      elseif suggestion.trigger then
        reason = str.float.ambient_reason:format(suggestion.trigger)
      end

      if reason then
        table.insert(lines, reason)
        table.insert(lines, "")
      end

      table.insert(lines, sug.body)

      if sug.example and sug.example ~= "" then
        table.insert(lines, "")
        table.insert(lines, str.float.example_prefix .. sug.example)
      end

      require("noice").notify(table.concat(lines, "\n"), vim.log.levels.INFO, {
        title = "🚪 " .. sug.title,
      })
    end

    -- Сообщение, когда команда освоена -> Noice
    float.celebrate = function(cmd)
      local str = require("tobira.i18n").load()

      require("noice").notify("✓ " .. str.float.celebrate:format(cmd), vim.log.levels.INFO, {
        title = "🚪 tobira",
      })
    end

    require("tobira").setup({})
  end,
}
