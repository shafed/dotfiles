return {
  "CRAG666/code_runner.nvim",
  cmd = { "RunCode", "RunFile", "RunProject", "RunClose", "CRFiletype", "CRProjects" },
  keys = {
    {
      "<leader>rr",
      function()
        -- In Java coursework every file has its own main(), so the open file is
        -- what to run. RunCode would find pom.xml and run the project's fixed
        -- exec.mainClass instead, whichever file is open.
        vim.cmd(vim.bo.filetype == "java" and "RunFile" or "RunCode")
      end,
      desc = "[P]Run Code",
    },
    { "<leader>rf", "<cmd>RunFile<cr>", desc = "[P]Run File" },
    { "<leader>rft", "<cmd>RunFile tab<cr>", desc = "[P]Run File (tab)" },
    { "<leader>rp", "<cmd>RunProject<cr>", desc = "[P]Run Project" },
    { "<leader>rc", "<cmd>RunClose<cr>", desc = "[P]Run Close" },
    { "<leader>crf", "<cmd>CRFiletype<cr>", desc = "[P]Code Runner: edit filetypes json" },
    { "<leader>crp", "<cmd>CRProjects<cr>", desc = "[P]Code Runner: edit projects json" },
  },
  opts = {
    filetype = {
      -- Keeps the Scilab window open after the script runs (needed to see
      -- plots and inspect variables), unlike the headless -nw flag.
      scilab = "scilab -f $file",
      -- JDK 22+ launches a source file directly and resolves the classes it
      -- uses from the same source tree, so packages work and nothing is
      -- written to target/. The plugin default (javac + java $fileNameWithoutExt)
      -- breaks on a file that declares a package.
      java = "java $file",
    },
  },
}
