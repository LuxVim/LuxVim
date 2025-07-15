# LuxVIM Unix/Linux Installer
#!/usr/bin/env bash

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGGED_DIR="$REPO_DIR/plugged"
VIMRC="$REPO_DIR/.vimrc"
PLUG_VIM="$REPO_DIR/autoload/plug.vim"

# 1. Download vim-plug locally if missing
if [ ! -f "$PLUG_VIM" ]; then
  mkdir -p "$REPO_DIR/autoload"
  curl -fLo "$PLUG_VIM" --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

mkdir -p "$PLUGGED_DIR"

# 2. Install plugins for Vim/Neovim
for editor in vim nvim; do
  if command -v $editor >/dev/null 2>&1; then
    $editor \
      --cmd "set runtimepath^=$REPO_DIR,$REPO_DIR/plugged" \
      -u "$VIMRC" +PlugInstall +qall
  fi
done

# 3. Write aliases to shell profile
ALIAS_STR="
# LuxVim aliases
alias luxvim='vim -u \"$REPO_DIR/.vimrc\" --cmd \"set runtimepath^=$REPO_DIR,$REPO_DIR/plugged\"'
alias lux='nvim -u \"$REPO_DIR/.vimrc\" --cmd \"set runtimepath^=$REPO_DIR,$REPO_DIR/plugged\"'
"

PROFILE=""
if [ -n "$ZSH_VERSION" ]; then
  PROFILE="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ]; then
  PROFILE="$HOME/.bashrc"
else
  PROFILE="$HOME/.profile"
fi

if ! grep -q "LuxVim aliases" "$PROFILE"; then
  echo "$ALIAS_STR" >> "$PROFILE"
  echo "Aliases added to $PROFILE. Restart your shell or run: source $PROFILE"
else
  echo "Aliases already exist in $PROFILE."
fi

echo "LuxVim setup complete! Use 'lux', 'luxvim' to launch with project settings."
