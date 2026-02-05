#!/bin/bash

# **********************************************************
# ********************* LUXVIM INSTALLER ******************
# **********************************************************

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the absolute path of LuxVim directory
LUXVIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}🚀 Installing LuxVim...${NC}"
echo -e "${YELLOW}LuxVim directory: ${LUXVIM_DIR}${NC}"

# Check if nvim is installed
if ! command -v nvim &> /dev/null; then
    echo -e "${RED}❌ Neovim is not installed. Please install Neovim first.${NC}"
    echo -e "${YELLOW}Visit: https://neovim.io/${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Neovim found${NC}"

# Create the lux alias script
ALIAS_SCRIPT_DIR="$HOME/.local/bin"
ALIAS_SCRIPT="$ALIAS_SCRIPT_DIR/lux"

# Create .local/bin directory if it doesn't exist
mkdir -p "$ALIAS_SCRIPT_DIR"

# Create the lux script
cat > "$ALIAS_SCRIPT" << EOF
#!/bin/bash
# LuxVim launcher script
NVIM_APPNAME="LuxVim" XDG_DATA_HOME="${LUXVIM_DIR}" XDG_CONFIG_HOME="${LUXVIM_DIR}" nvim --cmd "set rtp+=${LUXVIM_DIR}" -u "${LUXVIM_DIR}/init.lua" "\$@"
EOF

# Make the script executable
chmod +x "$ALIAS_SCRIPT"

echo -e "${GREEN}✅ Created lux command at ${ALIAS_SCRIPT}${NC}"

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo -e "${YELLOW}⚠️  ~/.local/bin is not in your PATH${NC}"
    echo -e "${YELLOW}Add the following line to your shell profile (~/.bashrc, ~/.zshrc, etc.):${NC}"
    echo -e "${BLUE}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
    echo -e "${YELLOW}Then restart your terminal or run: source ~/.bashrc (or ~/.zshrc)${NC}"
fi

# Create data directories within LuxVim
LUXVIM_DATA_DIR="$LUXVIM_DIR/data"
mkdir -p "$LUXVIM_DATA_DIR/lazy"
mkdir -p "$LUXVIM_DATA_DIR/mason"
mkdir -p "$LUXVIM_DATA_DIR/nvim"

echo -e "${GREEN}✅ Created data directories in LuxVim${NC}"

# Bootstrap lazy.nvim within LuxVim
LAZY_PATH="$LUXVIM_DATA_DIR/lazy/lazy.nvim"
if [ ! -d "$LAZY_PATH" ]; then
    echo -e "${BLUE}📦 Bootstrapping lazy.nvim...${NC}"
    git clone --filter=blob:none --branch=stable https://github.com/folke/lazy.nvim.git "$LAZY_PATH"
    echo -e "${GREEN}✅ lazy.nvim installed${NC}"
else
    echo -e "${GREEN}✅ lazy.nvim already exists${NC}"
fi

echo -e "${GREEN}🎉 LuxVim installation complete!${NC}"
echo -e "${BLUE}Usage: lux [file]${NC}"
echo -e "${YELLOW}Note: Plugins will auto-download on first run${NC}"

# Test if lux command is available
if command -v lux &> /dev/null; then
    echo -e "${GREEN}✅ 'lux' command is ready to use${NC}"
else
    echo -e "${YELLOW}⚠️  'lux' command not found in PATH. You may need to restart your terminal or update your PATH.${NC}"
fi

echo -e "${BLUE}Starting LuxVim for initial plugin installation...${NC}"
"$ALIAS_SCRIPT" --headless "+Lazy! sync" +qa

echo -e "${GREEN}🎉 All plugins installed! LuxVim is ready to use.${NC}"
