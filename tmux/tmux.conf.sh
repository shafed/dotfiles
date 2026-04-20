unbind r
bind r source-file ~/.tmux.conf

tmux_zoxide="~/dotfiles/tmux/tools/scripts/tmux-zoxide-session.sh"
tmux_list="~/dotfiles/tmux/tools/scripts/tmux-list-sessions.sh"
daily_note="~/dotfiles/scripts/daily-notes.sh"

bind -n M-Tab switch-client -l # переключение между двумя последними сессиями

bind-key f run-shell "tmux neww $tmux_zoxide"
bind-key s run-shell "tmux neww $tmux_list"

unbind C-t
bind-key -r C-t run-shell "$tmux_zoxide --session obsidian"
unbind C-c
bind-key -r C-c run-shell "$tmux_zoxide --session projects"
unbind C-a
bind-key -r C-a run-shell "$tmux_zoxide --session home"
unbind C-d
bind-key -r C-d run-shell "$tmux_zoxide --session dotfiles"
bind-key -r C-y new-session -A -s yazi yazi
bind-key -r 1 run-shell "$daily_note"

bind-key x kill-pane
unbind Space
bind-key Space switch-client -l

set -g prefix C-s

set -g mouse on
set -g focus-events on # for xkb-switch.nvim

set -g allow-passthrough on
set -ga update-environment TERM
set -ga update-environment TERM_PROGRAM

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
