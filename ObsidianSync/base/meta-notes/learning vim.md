---
tags:
  - system/meta
aliases:
category:
  - "[[programming]]"
---
[[Excel vim.xlam]]

# Hotkeys

- Movements
	- `h` ←
	- `j` ↓
	- `k` ↑
	- `l` →
	- `gg` move to the start of the file
		- `G` move to the end of the file
			- `<n> + G` jump to the `n` line
	- `w` start of the next word
		- `W` start of the next word (ignores punctuation and special characters)
	- `b` start of the previous word
		- `B` start of the previous word (ignores punctuation and special characters)
	- `e` move to the end of the word
	- `0` move to the star of the line
		- `^` move to the first non-space characters
		- `$` move to the end of the line
	- `%` move to a paired brackets/quote
	- `t + <symbol>` move to the one position before `<symbol>` (at the same line)
		- `T + <symbol>` move to the one position after `<symbol>`
	- `f + <symbol>` move to the position of `symbol` (forward at the same line)
		- `F + <symbol>` move to the position of `symbol` (backward at the same line)

- Turn insert mode
	- `i` *before* character
		- `I` at the *start* of the line
	- `a`  *after* character
		- `A` at the *end* of the line
	- `o` on a new line *below*
		- O` on a new line *above*
- Editing
	- `u` undo
		- `ctrl+r` redo
	- `y` copy selected
		- `yy` copy line
		- 'Y' copy rest of the line
	- `p` paste after
	- `P` paste before
	- `d` delete
		- `dd` delete line
		- `D` delete rest of the line
	- `c` change
		- `cc` delete line + turn insert mode
		- `C` change rest of the line
		

> [!info] Combined commands
> - We can combine command, for example
> 	- `dw` delete to the start of the next word
> 	- `c2w` delete to the start of the 2-nd next word and change
> 	- `diw` delete inner word (full word)
> 	- `ci"` delete quotation marks
> 		- by analogy for others '()[]{}
> - `<number>+<hotkey>` for repeated command
