return {
  "CRAG666/code_runner.nvim",
  cmd = { "RunCode", "RunFile", "RunProject", "RunClose", "CRFiletype", "CRProjects" },
  keys = {
    { "<leader>rr", "<cmd>RunCode<cr>", desc = "[P]Run Code" },
    { "<leader>rf", "<cmd>RunFile<cr>", desc = "[P]Run File" },
    { "<leader>rft", "<cmd>RunFile tab<cr>", desc = "[P]Run File (tab)" },
    { "<leader>rp", "<cmd>RunProject<cr>", desc = "[P]Run Project" },
    { "<leader>rc", "<cmd>RunClose<cr>", desc = "[P]Run Close" },
    { "<leader>crf", "<cmd>CRFiletype<cr>", desc = "[P]Code Runner: edit filetypes json" },
    { "<leader>crp", "<cmd>CRProjects<cr>", desc = "[P]Code Runner: edit projects json" },
  },
  opts = {
    -- your config (mode, filetype, ...) goes here
  },
}
