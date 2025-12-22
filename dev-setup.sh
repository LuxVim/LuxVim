#!/bin/bash

# LuxVim Development Setup Script
# Makes it easy to set up local development for LuxVim plugins

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the LuxVim directory
LUXVIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEBUG_DIR="$LUXVIM_DIR/debug"

echo -e "${BLUE}🔧 LuxVim Development Setup${NC}"
echo -e "${YELLOW}LuxVim directory: ${LUXVIM_DIR}${NC}"

# Create debug directory if it doesn't exist
mkdir -p "$DEBUG_DIR"

# Available plugins for development
declare -A PLUGINS=(
    ["nvim-luxdash"]="https://github.com/LuxVim/nvim-luxdash.git"
    ["nvim-luxterm"]="https://github.com/LuxVim/nvim-luxterm.git"
    ["nvim-luxmotion"]="https://github.com/LuxVim/nvim-luxmotion.git"
    ["nvim-luxline"]="https://github.com/LuxVim/nvim-luxline.git"
    ["vim-luxpane"]="https://github.com/LuxVim/vim-luxpane.git"
    ["vim-easycomment"]="https://github.com/josstei/vim-easycomment.git"
    ["vim-easyops"]="https://github.com/josstei/vim-easyops.git"
    ["vim-easyenv"]="https://github.com/josstei/vim-easyenv.git"
)

# Function to clone a plugin for development
clone_plugin() {
    local plugin_name="$1"
    local plugin_url="${PLUGINS[$plugin_name]}"
    local plugin_dir="$DEBUG_DIR/$plugin_name"
    
    if [ -z "$plugin_url" ]; then
        echo -e "${RED}❌ Unknown plugin: $plugin_name${NC}"
        return 1
    fi
    
    if [ -d "$plugin_dir" ]; then
        echo -e "${YELLOW}⚠️  Plugin $plugin_name already exists in debug directory${NC}"
        read -p "Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Skipping $plugin_name${NC}"
            return 0
        fi
        rm -rf "$plugin_dir"
    fi
    
    echo -e "${BLUE}📦 Cloning $plugin_name...${NC}"
    git clone "$plugin_url" "$plugin_dir"
    echo -e "${GREEN}✅ Successfully cloned $plugin_name to debug directory${NC}"
}

# Function to remove a plugin from development
remove_plugin() {
    local plugin_name="$1"
    local plugin_dir="$DEBUG_DIR/$plugin_name"
    
    if [ ! -d "$plugin_dir" ]; then
        echo -e "${RED}❌ Plugin $plugin_name not found in debug directory${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}⚠️  This will remove $plugin_name from debug directory${NC}"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$plugin_dir"
        echo -e "${GREEN}✅ Removed $plugin_name from debug directory${NC}"
    else
        echo -e "${YELLOW}Cancelled${NC}"
    fi
}

# Function to list available plugins
list_plugins() {
    echo -e "${BLUE}Available plugins for development:${NC}"
    for plugin in "${!PLUGINS[@]}"; do
        if [ -d "$DEBUG_DIR/$plugin" ]; then
            echo -e "  • $plugin ${GREEN}[DEBUG ACTIVE]${NC}"
        else
            echo -e "  • $plugin"
        fi
    done
}

# Function to show status
show_status() {
    echo -e "${BLUE}🔧 Development Status${NC}"
    echo -e "Debug directory: $DEBUG_DIR"
    echo
    
    local active_count=0
    for plugin in "${!PLUGINS[@]}"; do
        if [ -d "$DEBUG_DIR/$plugin" ]; then
            echo -e "${GREEN}✅ $plugin${NC} (debug active)"
            ((active_count++))
        fi
    done
    
    if [ $active_count -eq 0 ]; then
        echo -e "${YELLOW}No debug plugins currently active${NC}"
    else
        echo -e "\n${GREEN}$active_count debug plugin(s) active${NC}"
    fi
    
    echo -e "\nUse ${BLUE}:LuxDevStatus${NC} inside LuxVim for runtime status"
}

# Main menu
case "${1:-}" in
    "clone")
        if [ -z "${2:-}" ]; then
            echo -e "${RED}Usage: $0 clone <plugin-name>${NC}"
            list_plugins
            exit 1
        fi
        clone_plugin "$2"
        ;;
    "remove")
        if [ -z "${2:-}" ]; then
            echo -e "${RED}Usage: $0 remove <plugin-name>${NC}"
            list_plugins
            exit 1
        fi
        remove_plugin "$2"
        ;;
    "list")
        list_plugins
        ;;
    "status")
        show_status
        ;;
    "help"|"-h"|"--help")
        echo -e "${BLUE}LuxVim Development Setup${NC}"
        echo
        echo "Usage: $0 <command> [options]"
        echo
        echo "Commands:"
        echo "  clone <plugin>   Clone a plugin for local development"
        echo "  remove <plugin>  Remove a plugin from debug directory"
        echo "  list            List available plugins"
        echo "  status          Show development status"
        echo "  help            Show this help"
        echo
        echo "Example:"
        echo "  $0 clone nvim-luxdash"
        echo "  $0 remove nvim-luxdash"
        ;;
    "")
        show_status
        echo
        echo -e "${YELLOW}Use '$0 help' for available commands${NC}"
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo -e "${YELLOW}Use '$0 help' for available commands${NC}"
        exit 1
        ;;
esac