unbind r
bind r source-file ~/.tmux.conf

tmux_sessionizer="~/dotfiles/tmux/tools/scripts/tmux-sessionizer.sh"
tmux_nvim="~/dotfiles/tmux/tools/scripts/tmux-sessionizer-nvim.sh"
tmux_switch="~/dotfiles/tmux/tools/scripts/tmux-sessionizer-switch.sh"
tmux_zoxide="~/dotfiles/tmux/tools/scripts/tmux-zoxide-session.sh"
tmux_list="~/dotfiles/tmux/tools/scripts/tmux-list-sessions.sh"
daily_note="~/dotfiles/scripts/daily-notes.sh"

bind -n M-Tab switch-client -l # переключение между двумя последними сессиями
bind-key w run-shell "tmux neww $tmux_switch"
bind-key C-k run-shell "tmux neww $tmux_switch -k" # kill session
bind-key f run-shell "tmux neww $tmux_sessionizer"

bind-key R run-shell "tmux neww $tmux_zoxide"
bind-key J run-shell "tmux neww $tmux_list"

bind-key "T" run-shell "sesh connect \"$(
  sesh list --icons | fzf-tmux -p 100%,100% \
    --layout=reverse \
    --no-sort --ansi --border-label ' sesh ' --prompt '⚡  ' \
    --header '  ^a all ^t tmux ^g configs ^x zoxide ^d tmux kill ^f find' \
    --bind 'tab:down,btab:up' \
    --bind 'ctrl-a:change-prompt(⚡  )+reload(sesh list --icons)' \
    --bind 'ctrl-t:change-prompt(🪟  )+reload(sesh list -t --icons)' \
    --bind 'ctrl-g:change-prompt(⚙️  )+reload(sesh list -c --icons)' \
    --bind 'ctrl-x:change-prompt(📁  )+reload(sesh list -z --icons)' \
    --bind 'ctrl-f:change-prompt(🔎  )+reload(fd -H -d 2 -t d -E .Trash . ~)' \
    --bind 'ctrl-d:execute(tmux kill-session -t {2..})+change-prompt(⚡  )+reload(sesh list --icons)' \
    --preview-window 'right:55%' \
    --preview 'sesh preview {}'
)\""

unbind C-t
bind-key -r C-t run-shell "$tmux_nvim ~/obsidian"
unbind C-d
bind-key -r C-c run-shell "$tmux_nvim ~/projects"
bind-key -r C-a run-shell "$tmux_nvim ~"
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
