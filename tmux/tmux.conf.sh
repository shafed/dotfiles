unbind r
bind r source-file ~/.tmux.conf

tmux_zoxide="~/dotfiles/tmux/tools/scripts/tmux-zoxide-session.sh"
tmux_list="~/dotfiles/tmux/tools/scripts/tmux-list-sessions.sh"
daily_note="~/dotfiles/scripts/daily-notes.sh"

bind -n M-Tab switch-client -l # переключение между двумя последними сессиями

bind-key f run-shell "tmux neww $tmux_zoxide"
bind-key s run-shell "tmux neww $tmux_list"

bind-key -r C-t run-shell "$tmux_zoxide --session todos"
bind-key -r C-w run-shell "$tmux_zoxide --session downloads"
bind-key -r C-o run-shell "$tmux_zoxide --session obsidian"
bind-key -r C-c run-shell "$tmux_zoxide --session projects"
bind-key -r C-a run-shell "$tmux_zoxide --session home"
bind-key -r C-d run-shell "$tmux_zoxide --session dotfiles"
bind-key -r C-y new-session -A -s yazi yazi
bind-key -r 1 run-shell "$daily_note"

bind-key x kill-pane
unbind Space
bind-key Space switch-client -l

set -g prefix C-s

set -g history-limit 50000

# Вся история панели в neovim-буфере (аналог kitty_mod+i, но для tmux).
# capture-pane -S - берёт ВСЮ историю прокрутки, не только видимый экран.
bind-key i run-shell 'tmux capture-pane -p -e -S - -t "#{pane_id}" > /tmp/tmux-scrollback-#{pane_id}.txt; tmux new-window "nvim --cmd \"set eventignore=FileType\" \"+nnoremap q ZQ\" \"+call nvim_open_term(0, {})\" \"+set nomodified nolist noswapfile\" \"+\\$\" /tmp/tmux-scrollback-#{pane_id}.txt"'

set -g mouse on
set -g focus-events on # for xkb-switch.nvim

set -g allow-passthrough on
set -ga update-environment TERM
set -ga update-environment TERM_PROGRAM

# Атомарная перерисовка кадров (synchronized output, DECSET 2026).
# Без этого TUI вроде Claude Code рвут вывод при быстром потоке:
# диффы налезают, появляется второй "-- INSERT --", курсор уходит вверх.
set -as terminal-features ',*:sync'
# truecolor для внешнего терминала (kitty), иначе тоже бывают артефакты цвета
set -as terminal-features ',xterm-kitty:RGB'

bind-key h select-pane -L
bind-key j select-pane -D
bind-key k select-pane -U
bind-key l select-pane -R

set-window-option -g mode-keys vi # vim mode
set-option -g status-position top
set -gq allow-passthrough on
set -g visual-activity off
set-option -g focus-events on

# List of plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'egel/tmux-gruvbox'
set -g @plugin 'christoomey/vim-tmux-navigator'
# set date in US notation

# Initialize TMUX plugin manager (keep this line at the very bottom of tmux.conf)
run '~/.tmux/plugins/tpm/tpm'

set -g status-right ""
