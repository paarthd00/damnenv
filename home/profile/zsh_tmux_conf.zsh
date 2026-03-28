# tmux config for damnenv.

set -g default-terminal "tmux-256color"
set -as terminal-features ",xterm-256color:RGB,alacritty:RGB"
set -g allow-passthrough on

# Use Ctrl+a as prefix
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# Split panes (like oh-my-tmux)
bind - split-window -v -c "#{pane_current_path}"
bind _ split-window -h -c "#{pane_current_path}"

# Source theme managed by damnenv
source-file -q ~/.tmux-theme.conf
