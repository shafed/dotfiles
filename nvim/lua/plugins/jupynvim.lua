-- .ipynb opened as a real notebook: :w writes nbformat with outputs, plots
-- render inline through kitty graphics. Kernel comes from the project's .venv
-- (needs ipykernel there) or any installed kernelspec.
return {
  "sheng-tse/jupynvim",
  build = function(plugin)
    local install = loadfile(plugin.dir .. "/lua/jupynvim/install.lua")()
    install.run(plugin)
  end,
  opts = {
    keymaps = {
      -- <C-j>/<C-k> belong to vim-kitty-navigator
      enter_output_dn = "<leader>nv",
      enter_output_up = "<leader>nV",
    },
  },
}
