# vim:ft=zsh ts=2 sw=2 sts=2
#
# agnoster's Theme - https://gist.github.com/3712874
# A Powerline-inspired theme for ZSH
#
# # README
#
# In order for this theme to render correctly, you will need a
# [Powerline-patched font](https://gist.github.com/1595572).
#
# In addition, I recommend the
# [Solarized theme](https://github.com/altercation/solarized/) and, if you're
# using it on Mac OS X, [iTerm 2](http://www.iterm2.com/) over Terminal.app -
# it has significantly better color fidelity.
#
# # Goals
#
# The aim of this theme is to only show you *relevant* information. Like most
# prompts, it will only show git information when in a git working directory.
# However, it goes a step further: everything from the current user and
# hostname to whether the last call exited with an error to whether background
# jobs are running in this shell will all be displayed automatically when
# appropriate.

### Segments of the prompt, default order declaration

typeset -aHg AGNOSTER_PROMPT_SEGMENTS=(
    prompt_down_arrow
    prompt_status
    prompt_context
    prompt_virtualenv
    prompt_dir
    prompt_git
    prompt_end
    prompt_right_arrow
)

### Segment drawing
# A few utility functions to make it easy and re-usable to draw segmented prompts

CURRENT_BG='NONE'
if [[ -z "$PRIMARY_FG" ]]; then
	PRIMARY_FG=black
fi

# Characters
REVERSE_SEGMENT_SEPARATOR="\ue0b2"
SEGMENT_SEPARATOR="\ue0b0"
PLUSMINUS="\u00b1"
BRANCH="\ue0a0"
DETACHED="\u27a6"
CROSS="\u2718"
LIGHTNING="\u26a1"
GEAR="\u2699"
LINUX_UBUNTU="\uF31B"

# Begin a segment
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.
prompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
    print -n "%{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%}"
  else
    print -n "%{$bg%}%{$fg%}"
  fi
  CURRENT_BG=$1
  [[ -n $3 ]] && print -n $3
}

# Begin a segment
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.
prompt_reverse_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  print -n "%{$bg%F{$CURRENT_BG}%}%{$fg%}$REVERSE_SEGMENT_SEPARATOR"
  CURRENT_BG=$1
  [[ -n $3 ]] && print -n $3
}

prompt_down_arrow(){
  print -n "╭─"
}

prompt_right_arrow(){
  print -n "╰─➤ "
}

# End the prompt, closing any open segments
prompt_end() {
  if [[ -n $CURRENT_BG ]]; then
    print -n "%{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
  else
    print -n "%{%k%}"
  fi
  print -n "%{%f%}"
  CURRENT_BG=''
  print -n "\n"
}

### Prompt components
# Each component will draw itself, and hide itself if no information needs to be shown

# Context: user@hostname (who am I and where am I)
prompt_context() {
  local user=`whoami`

  if [[ "$user" != "$DEFAULT_USER" || -n "$SSH_CONNECTION" ]]; then
    prompt_segment $PRIMARY_FG default "%(!.%{%F{yellow}%}.)$LINUX_UBUNTU $user "
  fi
}

# Git: branch/detached head, dirty status
prompt_git() {
   (( $+commands[git] )) || return
   if [[ "$(git config --get oh-my-zsh.hide-status 2>/dev/null)" = 1 ]]; then
     return
   fi
   local PL_BRANCH_CHAR
   () {
     local LC_ALL="" LC_CTYPE="en_US.UTF-8"
     PL_BRANCH_CHAR=$' \ue0a0'         # 
   }
   local ref dirty mode repo_path

    if [[ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" = "true" ]]; then
     repo_path=$(git rev-parse --git-dir 2>/dev/null)
     dirty=$(parse_git_dirty)
     ref=$(git symbolic-ref HEAD 2> /dev/null) || ref="➦ $(git rev-parse --short HEAD 2> /dev/null)"
     if [[ -n $dirty ]]; then
       prompt_segment yellow black
     else
       prompt_segment green $CURRENT_FG
     fi

     if [[ -e "${repo_path}/BISECT_LOG" ]]; then
       mode=" <B>"
     elif [[ -e "${repo_path}/MERGE_HEAD" ]]; then
       mode=" >M<"
     elif [[ -e "${repo_path}/rebase" || -e "${repo_path}/rebase-apply" || -e "${repo_path}/rebase-merge" || -e "${repo_path}/../.dotest" ]]; then
       mode=" >R>"
     fi

     setopt promptsubst
     autoload -Uz vcs_info

     zstyle ':vcs_info:*' enable git
     zstyle ':vcs_info:*' get-revision true
     zstyle ':vcs_info:*' check-for-changes true
     zstyle ':vcs_info:*' stagedstr '✚'
     zstyle ':vcs_info:*' unstagedstr '±'
     zstyle ':vcs_info:*' formats ' %u%c'
     zstyle ':vcs_info:*' actionformats ' %u%c'
     vcs_info
     echo -n "${${ref:gs/%/%%}/refs\/heads\//$PL_BRANCH_CHAR }${vcs_info_msg_0_%% }${mode}"
   fi
 }

# prompt_git() {
#   local color ref
#   is_dirty() {
#     test -n "$(git status --porcelain --ignore-submodules)"
#   }
#   ref="$vcs_info_msg_0_"
#   if [[ -n "$ref" ]]; then
#     if is_dirty; then
#       color=yellow
#       ref="${ref} $PLUSMINUS"
#     else
#       color=green
#       ref="${ref} "
#     fi
#     if [[ "${ref/.../}" == "$ref" ]]; then
#       ref="$BRANCH $ref"
#     else
#       ref="$DETACHED ${ref/.../}"
#     fi
#     prompt_segment $color $PRIMARY_FG
#     print -n " $ref"
#   fi
# }

# Dir: current working directory
prompt_dir() {
  prompt_segment blue $PRIMARY_FG ' %~ '
}

# Status:
# - was there an error
# - am I root
# - are there background jobs?
prompt_status() {
  local symbols
  symbols=()
  prompt_reverse_segment '' $PRIMARY_FG
  [[ $RETVAL -ne 0 ]] && symbols+="%{%F{red}%}$CROSS"
  [[ $UID -eq 0 ]] && symbols+="%{%F{yellow}%}$LIGHTNING"
  [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{cyan}%}$GEAR"

  [[ -n "$symbols" ]] && prompt_segment $PRIMARY_FG default " $symbols "
}

# Display current virtual environment
prompt_virtualenv() {
  if [[ -n $VIRTUAL_ENV ]]; then
    color=cyan
    prompt_segment $color $PRIMARY_FG
    print -Pn " $(basename $VIRTUAL_ENV) "
  fi
}

## Main prompt
prompt_agnoster_main() {
  RETVAL=$?
  CURRENT_BG='NONE'
  echo ${(r:$COLUMNS::-:)}
  for prompt_segment in "${AGNOSTER_PROMPT_SEGMENTS[@]}"; do
    [[ -n $prompt_segment ]] && $prompt_segment
  done
}

prompt_agnoster_precmd() {
  vcs_info
  PROMPT='%{%f%b%k%}$(prompt_agnoster_main) '
}

prompt_agnoster_setup() {
  autoload -Uz add-zsh-hook
  autoload -Uz vcs_info

  prompt_opts=(cr subst percent)

  add-zsh-hook precmd prompt_agnoster_precmd

  zstyle ':vcs_info:*' enable git
  zstyle ':vcs_info:*' check-for-changes false
  zstyle ':vcs_info:git:*' formats ' #%8.8i'
  zstyle ':vcs_info:git*' actionformats '%b (%a)'
}

prompt_agnoster_setup "$@"
