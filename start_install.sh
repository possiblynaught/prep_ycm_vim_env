#!/usr/bin/env bash
# This script preps a fresh, debian-based system with vim + YouCompleteMe
# For more info on YCM, see: https://github.com/ycm-core/YouCompleteMe

# Env vars
set -Eeuo pipefail
# Debug
[[ "${DEBUG:-0}" == "1" ]] && set -x

# Source the sh functions
SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1; pwd -P)"
common_functions="$SCRIPT_DIR/common_shell_functions/common_sh_functions.sh"
if [ ! -d "$(dirname "$common_functions")" ]; then
  echo "You may need to add the submodule with:
  git submodule add https://github.com/possiblynaught/common_shell_functions.git
  git submodule update --init --recursive"
  exit 1
elif [ ! -x "$common_functions" ]; then
  git submodule update --init --recursive
fi
# shellcheck source=/dev/null
source "$common_functions"

# Main
main () {
  # Set up repo dir
  repo_dir="$HOME/Documents/repos"
  mkdir -p "$(dirname "$repo_dir")"
  mkdir -p "$repo_dir"
  if [ ! -d "$repo_dir" ]; then
    err "Error, failed to create repo directory:
    $repo_dir"
  fi

  # Install necessary packages
  check_installed "apt-get" "sudo"
  sudo apt-get install -y \
    apt-transport-https \
    bash-completion \
    build-essential \
    cmake \
    curl \
    firejail \
    git \
    git-lfs \
    gitk \
    htop \
    moreutils \
    python3-dev \
    shellcheck \
    ssh \
    unzip \
    vim-nox \
    wget \
    golang \
    mono-complete \
    nodejs \
    npm \
    openjdk-17-jdk \
    openjdk-17-jre \
    xclip

  # Disable ssh server
  sudo systemctl stop ssh
  sudo systemctl disable ssh
  sudo systemctl mask ssh

  # Set up git and enable git-lfs
  if [ -z "$(git config --global user.name)" ]; then
    read -r -p "Please enter the git username for commits: " name
    git config --global user.name "$name"
  fi
  if [ -z "$(git config --global user.email)" ]; then
    read -r -p "Please enter the git email for commits: " email
    git config --global user.email "$email"
  fi
  git config --global core.editor "vim"
  git config --global pull.ff only
  git lfs install
  echo "git configured for: $(git config user.name) ($(git config user.email))"

  # Generate ed25519 ssh key and copy to clipboard
  priv_key="$HOME/.ssh/id_ed25519"
  pub_key="$priv_key.pub"
  mkdir -p "$(dirname "$priv_key")"
  chmod 700 "$(dirname "$priv_key")"
  if [ ! -s "$priv_key" ]; then
    ssh-keygen -a "$(random_number "250" "750")" -o -t ed25519
    chmod 400 "$priv_key"
    chmod 600 "$pub_key"
  else
    echo "Skipping keygen, key already exists!"
  fi
  if [ -s "$priv_key" ] && [ -s "$pub_key" ]; then
    ssh-add "$priv_key"
    xclip -sel c < "$pub_key"
    echo -e "\n-------------------------------------------------------------------------------
  Public key has been copied to the clipboard!\n"
  fi

  # Set aliases
  rc="$HOME/.bashrc"
  if ! grep -qF "### Begin custom aliases" < "$rc"; then
    echo -e "\n### Begin custom aliases added by: $(basename "$SCRIPT_DIR")" >> "$rc"
    echo "alias unlock='ssh-add -l >/dev/null || ssh-add $priv_key'" >> "$rc"
    echo "alias clean='git clean -fx'" >> "$rc"
    echo "alias pull='unlock; find . -mindepth 1 -maxdepth 1 -type d -print -execdir git --git-dir={}/.git --work-tree=\$PWD/{} pull origin \;'" >> "$rc"
    echo "alias push='git add . && git commit && git push'" >> "$rc"
    echo "alias repo='cd $repo_dir'" >> "$rc"
    echo "alias summ='git diff --compact-summary HEAD^1 HEAD'" >> "$rc"
    echo "alias add='unlock;'" >> "$rc"
  fi

  # Add vundle to vim
  vim_pkgs="$HOME/.vim/bundle"
  mkdir -p "$(dirname "$vim_pkgs")"
  mkdir -p "$vim_pkgs"
  vundle="$vim_pkgs/Vundle.vim"
  if [ ! -d "$vundle" ]; then
    git clone https://github.com/VundleVim/Vundle.vim.git "$vundle"
  fi
  # TODO: Finish and add vundle to vimrc
  
  # Start installing YouCompleteMe
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_current.x nodistro main" | \
    sudo tee /etc/apt/sources.list.d/nodesource.list
  ycp_dir="$vim_pkgs/YouCompleteMe"
  git clone https://github.com/ycm-core/YouCompleteMe.git "$ycp_dir"
  cd "$ycp_dir" || err "Error, directory is missing: $ycp_dir"
  git submodule update --init --recursive
  python3 install.py --all
  # TODO: Finish YouCompleteMe install
  # TODO: Finish and add to vimrc
  
  # Enable firejail
  firecfg --fix-sound
  sudo firecfg

  # Notify of completion
  echo -e "\n-------------------------------------------------------------------------------
  Finished! Make sure to reload your .bashrc with:
    source $rc"
}

# Run main
main "$@"
