-------------------------------------------------------------------------------
--                            Remote operations
-------------------------------------------------------------------------------

-- The following are used in all the remote motions
-- r - remote flash
-- {text} - stuff to search with flash
-- {flash_char} - character used to jump in flash

-- Surround in "", 4 words in a remote location
-- gsar{text}{flash_char}4e"
-- gsa - surround add (leaves you in pending mode)
-- 4e - select 4 words
-- " - surround in quotes

-- Paste text in '' in another line where my cursor is at
-- Mind blowing trick shared by Maria Solano
-- https://youtu.be/0DNC3uRPBwc?si=kHMTyvpEP6j8q9eD&t=3214
-- yr{text}{flash_char}a'p
-- y - copy mode (leaves you in pending)
-- a' - around ' (select the text around '')
-- p - paste

-- Bold a remote location
-- gsar{text}{flash_char}4e?**<CR>**<CR>
-- gsa - surround add (leaves you in pending mode)
-- 4e - select 4 words
-- ? - mini.surround interactive. Prompts user to enter left and right parts.

-------------------------------------------------------------------------------
--                         End of Remote operations
-------------------------------------------------------------------------------

return {
  "folke/flash.nvim",
  opts = {
    labels = "fghjklqwetyupzcvbnm",
    search = {
      mode = "search",
    },
    modes = {
      char = {
        enabled = false,
      },
    },
  },
  keys = {
    {
      "s",
      mode = { "n", "x", "o" },
      function()
        require("flash").jump({
          labels = "fghjklqwetyupzcvbnm",
        })
      end,
      desc = "Flash (EN)",
    },
    {
      "ы",
      mode = { "n", "x", "o" },
      function()
        require("flash").jump({
          labels = "аоенгшщзхъфывапролджэячсмитьбю",
          search = {
            mode = "search",
          },
        })
      end,
      desc = "Flash (RU)",
    },
    {
      "S",
      mode = { "n", "x", "o" },
      function()
        require("flash").treesitter()
      end,
      desc = "Flash Treesitter (EN)",
    },
    {
      "Ы",
      mode = { "n", "x", "o" },
      function()
        require("flash").treesitter({
          labels = "аоенгшщзхъфывапролджэячсмитьбю",
        })
      end,
      desc = "Flash Treesitter (RU)",
    },
  },
}
