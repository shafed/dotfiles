return {
  "keaising/im-select.nvim",
  config = function()
    require("im_select").setup({
      default_im_select = "1033",
      default_command = "im-select.exe",
      set_default_events = {"InsertLeave", "CmdLineLeave"},
    })
  end,
}

