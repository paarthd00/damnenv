# ═══════════════════════════════════════════════════════════════════
#  ZSH Configuration
# ═══════════════════════════════════════════════════════════════════

# Instant prompt (must be first - before any console output)
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Locale
export LC_ALL=en_CA.utf8
export LANG=en_CA.utf8

# Editor
export EDITOR='zed --wait'
export VISUAL='zed --wait'

# ───────────────────────────────────────────────────────────────────
#  History
# ───────────────────────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt SHARE_HISTORY

# ───────────────────────────────────────────────────────────────────
#  Nix-Managed Shell Plugins
# ───────────────────────────────────────────────────────────────────
fpath+=${ZDOTDIR:-~}/.zsh_functions
typeset -U fpath

setopt correct

# zsh-autocomplete expects to manage compinit itself and is only useful in real terminals.
if [[ "$TERM" != "dumb" ]] && [[ -r "$RANG_ZSH_AUTOCOMPLETE" ]]; then
  source "$RANG_ZSH_AUTOCOMPLETE"
fi
[[ -r "$RANG_ZSH_POWERLEVEL10K" ]] && source "$RANG_ZSH_POWERLEVEL10K"
[[ -r "$RANG_ZSH_AUTOSUGGESTIONS" ]] && source "$RANG_ZSH_AUTOSUGGESTIONS"

# ───────────────────────────────────────────────────────────────────
#  PATH
# ───────────────────────────────────────────────────────────────────
path=(
  $HOME/.local/bin
  $HOME/.rbenv/bin
  $HOME/.rbenv/plugins/ruby-build/bin
  $HOME/.turso
  $HOME/.fly/bin
  $HOME/.sst/bin
  $HOME/.dotnet/tools
  $HOME/.config/emacs/bin
  $HOME/.config/composer/vendor/bin
  $HOME/.composer/vendor/bin
  $HOME/.opencode/bin
  $HOME/go/bin
  $HOME/tools/zig
  /opt/nvim-linux64/bin
  /opt/zig
  /usr/local/go/bin
  /lib/postgresql/15/bin
  $path
)

# Deduplicate and remove non-existent directories
typeset -U path
path=($^path(N-/))

# ───────────────────────────────────────────────────────────────────
#  Aliases
# ───────────────────────────────────────────────────────────────────
command -v nvim        &>/dev/null && alias v='nvim' && alias vim='nvim' && alias zshconfig='nvim ~/.zshrc'
command -v npm         &>/dev/null && alias h2='$(npm prefix -s)/node_modules/.bin/shopify hydrogen'
command -v python3     &>/dev/null && alias settings='python3 ~/.settings.py'

# ls — use best available
if command -v eza &>/dev/null; then
  alias ls='eza'
  alias la='eza --long --all --group'
elif command -v exa &>/dev/null; then
  alias ls='exa'
  alias la='exa --long --all --group'
elif command -v colorls &>/dev/null; then
  alias ls='colorls'
  alias la='colorls -al'
fi

# Flatpak apps
command -v flatpak &>/dev/null && {
  alias code='flatpak run com.visualstudio.code'
}

# Docker / devcontainer
command -v docker &>/dev/null && {
  alias dce='docker exec -it $(docker ps --filter "label=devcontainer.local_folder=$(pwd)" -q) bash'
  alias dcr='docker rm -f $(docker ps -aq)'
  alias dcvr='docker volume rm $(docker volume ls -q)'
}
command -v devcontainer &>/dev/null && {
  alias dcup='devcontainer up --workspace-folder . --remove-existing-container --log-level info'
  alias dcupnc='devcontainer up --workspace-folder . --remove-existing-container --build-no-cache --log-level info'
}

# ───────────────────────────────────────────────────────────────────
#  FZF
# ───────────────────────────────────────────────────────────────────
[[ -r "$RANG_FZF_COMPLETION" ]] && source "$RANG_FZF_COMPLETION"
[[ -r "$RANG_FZF_KEY_BINDINGS" ]] && source "$RANG_FZF_KEY_BINDINGS"

# Use fd if available, fallback to find
if command -v fd &>/dev/null; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
elif command -v fdfind &>/dev/null; then
  export FZF_DEFAULT_COMMAND='fdfind --type f --hidden --follow --exclude .git'
  export FZF_ALT_C_COMMAND='fdfind --type d --hidden --follow --exclude .git'
else
  export FZF_DEFAULT_COMMAND='find . -type f -not -path "*/\.git/*" -not -path "*/node_modules/*"'
  export FZF_ALT_C_COMMAND='find . -type d -not -path "*/\.git/*" -not -path "*/node_modules/*"'
fi
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

export FZF_DEFAULT_OPTS='
  --height 60%
  --layout=reverse
  --border=rounded
  --info=inline
  --ansi
'

# Preview options (use bat if available)
if command -v bat &>/dev/null; then
  export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range :500 {}'"
else
  export FZF_CTRL_T_OPTS="--preview 'head -500 {}'"
fi

if command -v tree &>/dev/null; then
  export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -200'"
fi

# FZF + Neovim helpers
vf()  { local f=$(fzf --preview 'head -50 {}') && [[ -f "$f" ]] && nvim "$f"; }
vfp() { local f=$(fzf --preview 'bat --style=numbers --color=always --line-range :500 {} 2>/dev/null || head -50 {}') && [[ -f "$f" ]] && nvim "$f"; }
nv()  { local f=$(find . -type f -name "*$1*" 2>/dev/null | fzf) && [[ -f "$f" ]] && nvim "$f"; }

fzfc() {
  local file
  file=$(fzf --preview 'bat --style=numbers --color=always {} 2>/dev/null || head -100 {}' \
             --height=80% --preview-window=right:60%:wrap \
             --bind 'ctrl-o:execute(code {})+abort' \
             --bind 'ctrl-y:execute-silent(echo {} | xclip -selection clipboard)+abort' \
             --header 'C-o: VSCode | C-y: Copy path')
  [[ -n "$file" ]] && code "$file"
}

# ───────────────────────────────────────────────────────────────────
#  Tool Initialization
# ───────────────────────────────────────────────────────────────────
# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# PNPM
export PNPM_HOME="$HOME/.local/share/pnpm"
[[ ":$PATH:" != *":$PNPM_HOME:"* ]] && export PATH="$PNPM_HOME:$PATH"

# Ruby
command -v rbenv &>/dev/null && eval "$(rbenv init -)"

# Bun
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# Turso
[ -f "$HOME/.turso" ] && source "$HOME/.turso"

# GHCup (Haskell)
[ -f "$HOME/.ghcup/env" ] && source "$HOME/.ghcup/env"

# SDKMAN (must be near end)
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

# ───────────────────────────────────────────────────────────────────
#  Powerlevel10k
# ───────────────────────────────────────────────────────────────────
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# Syntax highlighting should load after other shell widgets and completions.
[[ -r "$RANG_ZSH_SYNTAX_HIGHLIGHTING" ]] && source "$RANG_ZSH_SYNTAX_HIGHLIGHTING"

# ───────────────────────────────────────────────────────────────────
#  Startup Banner (causes prompt jump - remove if unwanted)
# ───────────────────────────────────────────────────────────────────
[[ -t 1 ]] && command -v neofetch &>/dev/null && neofetch

# bun
export BUN_INSTALL="$HOME/.bun"
[[ ":$PATH:" != *":$BUN_INSTALL/bin:"* ]] && export PATH="$BUN_INSTALL/bin:$PATH"
