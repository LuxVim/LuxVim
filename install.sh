#!/bin/bash
set -e

LUXVIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
START_TIME=$SECONDS

# ── Colors ───────────────────────────────────────────────
NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'

# ── Truecolor detection ─────────────────────────────────
HAS_TRUECOLOR=false
if [[ "$COLORTERM" == "truecolor" || "$COLORTERM" == "24bit" ]]; then
    HAS_TRUECOLOR=true
fi

# ── Cleanup trap (always restore cursor) ─────────────────
cleanup() { tput cnorm 2>/dev/null; }
trap cleanup EXIT

# ── Helpers ──────────────────────────────────────────────

step_ok() {
    printf "\r  ${GREEN}✓${NC} %b\n" "$1"
}

step_fail() {
    printf "\r  ${RED}✗${NC} %b\n" "$1"
}

# Returns a truecolor escape for position $1 out of $2 total steps
# in the orange (#ff7801) to purple (#db2dee) gradient.
gradient_color() {
    local i=$1 total=$2
    local r g b
    if (( total <= 1 )); then
        r=255 g=120 b=1
    else
        r=$(( 255 - 36 * i / (total - 1) ))
        g=$(( 120 - 75 * i / (total - 1) ))
        b=$(( 1 + 237 * i / (total - 1) ))
    fi
    printf '\033[38;2;%d;%d;%dm' "$r" "$g" "$b"
}

spinner() {
    local pid=$1 msg=$2
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0

    tput civis 2>/dev/null
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${CYAN}%s${NC} %s" "${frames[$i]}" "$msg"
        i=$(( (i + 1) % ${#frames[@]} ))
        sleep 0.08
    done
    tput cnorm 2>/dev/null
}

# ── Logo ─────────────────────────────────────────────────

LOGO=(
"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣿⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣿⣿⣿⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣾⣿⣿⣿⣿⣿⣷⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣾⣿⣿⣿⣿⣿⣿⣿⣧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
"⠀⠀⠀⠀⠀⠀⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⠀⠀⠀⠀⠀⠀⠀"
"⠀⠀⠀⠀⠀⠀⠀⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠀⠀⠀⠀⠀⠀⠀⠀"
"⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠀⠀⠀⠀⠀⠀⠀⠀⠀"
"⠀⠀⠀⠀⠀⠀⠀⠀⠈⣿⣿⣿⣿⣿⣧⠀⠀⠀⠈⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⣾⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⣿⣿⣿⣿⣿⣧⠀⠀⠀⠘⣿⣿⣿⣿⣿⠁⠀⠀⠀⣾⣿⣿⣿⣿⣿⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⣿⣿⣿⣿⣿⣆⠀⠀⠀⠹⣿⣿⣿⠃⠀⠀⠀⣼⣿⣿⣿⣿⣿⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
"⠀⠀⠀⠀⠀⠀⠀⠀⠀⣤⣿⣿⣿⣿⣿⣿⣿⣆⠀⠀⠀⠹⣿⠃⠀⠀⠀⣰⣿⣿⣿⣿⣿⣿⣿⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
"⠀⠀⠀⠀⠀⠀⢀⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡄⠀⠀⠀⠉⠀⠀⠀⣠⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⡀⠀⠀⠀⠀⠀⠀⠀"
"⠀⠀⠀⠀⠀⠀⠉⠉⠛⠻⠿⣿⣿⣿⣿⣿⣿⣿⣿⡀⠀⠀⠀⠀⠀⢠⣿⣿⣿⣿⣿⣿⣿⣿⠿⠟⠛⠉⡉⠀⠀⠀⠀⠀⠀⠀"
"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⡀⠀⠀⠀⢠⣿⣿⣿⣿⣿⡿⠀⠀⠀⢀⣴⠾⠋⠀⠀⠀⠀⠀⠀⠀⠀"
"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⠀⠀⢀⣿⣿⣿⣿⣿⣿⣿⢀⣴⡾⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣾⣿⣿⣿⣿⣿⣿⣿⣷⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣼⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣿⡿⠛⠉⠀⠘⣿⣿⣿⣿⣿⣿⣿⣿⣿⠃⠀⠉⠛⢿⣿⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠀⠀⠀⠀⠀⠀⣸⣿⣿⣿⣿⣿⣿⣿⠁⠀⠀⠀⠀⠀⠀⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⣾⠛⠁⠈⣿⣿⣿⣿⡿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣤⣾⠟⠁⠀⠀⠀⠀⠀⢿⣿⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
"⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⡾⠟⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
"⣤⣤⠀⠀⠀⢀⣠⣼⡟⠁⠀⠀⣤⣤⠀⣤⣤⡄⠀⠀⣤⣤⡄⣤⣤⡄⠀⠀⠀⣤⣤⡄⢠⣤⡄⠀⢠⣤⣤⡀⠀⠀⢀⣤⣤⡄"
"⣿⣿⠀⣠⠾⠋⢹⣿⡇⠀⠀⠀⣿⣿⠀⠈⣿⣿⡄⣼⣿⠟⠀⠘⣿⣿⠀⠀⢀⣿⣿⠀⢸⣿⡇⠀⢸⣿⣿⣷⠀⠀⣾⣿⣿⡇"
"⣿⣿⠈⠀⠀⠀⢸⣿⡇⠀⠀⠀⣿⣿⠀⠀⠈⣿⣿⣿⠟⠀⠀⠀⢻⣿⡆⠀⣾⣿⠃⠀⢸⣿⡇⠀⢸⣿⡿⣿⣆⣰⣿⢿⣿⡇"
"⣿⣿⠀⠀⠀⠀⢸⣿⡇⠀⠀⠀⣿⣿⠀⠀⢀⣿⣿⣿⣧⠀⠀⠀⠀⣿⣿⢠⣿⡿⠀⠀⢸⣿⡇⠀⢸⣿⡇⢿⣿⣿⡿⢸⣿⡇"
"⣿⣿⣶⣶⣶⡆⠈⣿⣿⣤⣤⣾⣿⠏⠀⢠⣿⣿⠁⢻⣿⣷⠀⠀⠀⢹⣿⣿⣿⠁⠀⠀⢸⣿⡇⠀⢸⣿⡇⠈⣿⣿⠀⢸⣿⡇"
"⠛⠛⠛⠛⠛⠃⠀⠀⠙⠻⠿⠛⠉⠀⠀⠛⠛⠁⠀⠀⠛⠛⠓⠀⠀⠀⠛⠛⠛⠀⠀⠀⠘⠛⠓⠀⠘⠛⠃⠀⠀⠀⠀⠘⠛⠃"
)

print_logo() {
    local total=${#LOGO[@]}
    local term_width
    term_width=$(tput cols 2>/dev/null || echo 80)

    # Compute display width of first line (character count, not bytes)
    local logo_width=${#LOGO[0]}
    local pad=$(( (term_width - logo_width) / 2 ))
    (( pad < 0 )) && pad=0
    local padding=""
    for (( p=0; p<pad; p++ )); do padding+=" "; done

    echo ""
    tput civis 2>/dev/null

    for (( i=0; i<total; i++ )); do
        if $HAS_TRUECOLOR; then
            printf '%s%s%s%b\n' "$padding" "$(gradient_color "$i" "$total")" "${LOGO[$i]}" "${NC}"
            sleep 0.03
        else
            printf '%s%s\n' "$padding" "${LOGO[$i]}"
        fi
    done

    tput cnorm 2>/dev/null
    echo ""
}

# Draws a box with a title and key-value pairs.
# Usage: draw_box "Title" "Label1" "Value1" "Label2" "Value2" ...
draw_box() {
    local title=$1
    shift
    local box_width=36
    local inner=$(( box_width - 4 ))

    # Top border
    local title_len=${#title}
    local border_rest=$(( box_width - title_len - 5 ))
    printf "  ${DIM}┌─ %s " "$title"
    printf '%0.s─' $(seq 1 "$border_rest")
    printf "┐${NC}\n"

    # Rows
    while (( $# >= 2 )); do
        local label=$1 value=$2
        shift 2
        # Truncate value if it exceeds available space
        local max_val_len=$(( inner - 12 ))
        if (( ${#value} > max_val_len )); then
            value="...${value: -$((max_val_len - 3))}"
        fi
        printf "  ${DIM}│${NC}  %-10s %-${max_val_len}s  ${DIM}│${NC}\n" "$label" "$value"
    done

    # Bottom border
    printf "  ${DIM}└"
    printf '%0.s─' $(seq 1 $(( box_width - 2 )))
    printf "┘${NC}\n"
}

# Draws a progress bar with optional gradient fill.
# Usage: draw_progress_bar <filled> <width> <message>
draw_progress_bar() {
    local filled=$1 width=$2 msg=$3
    local empty=$(( width - filled ))
    local bar=""

    if $HAS_TRUECOLOR; then
        for (( j=0; j<filled; j++ )); do
            local r=$(( 255 - 36 * j / (width - 1) ))
            local g=$(( 120 - 75 * j / (width - 1) ))
            local b=$(( 1 + 237 * j / (width - 1) ))
            bar+="\033[38;2;${r};${g};${b}m█"
        done
        bar+="${NC}"
    else
        bar+="${GREEN}"
        for (( j=0; j<filled; j++ )); do
            bar+="█"
        done
        bar+="${NC}"
    fi

    bar+="${DIM}"
    for (( j=0; j<empty; j++ )); do
        bar+="░"
    done
    bar+="${NC}"

    printf "\r  %b  %s" "$bar" "$msg"
}

# ── Logo ─────────────────────────────────────────────────
print_logo

# ── System info ──────────────────────────────────────────
NVIM_VERSION=$(nvim --version 2>/dev/null | head -1 | sed 's/NVIM /v/')
OS_INFO=$(uname -sr)
SHELL_NAME=$(basename "${SHELL:-unknown}")
DISPLAY_PATH="${LUXVIM_DIR/#$HOME/\~}"

draw_box "System" \
    "Neovim" "$NVIM_VERSION" \
    "OS" "$OS_INFO" \
    "Shell" "$SHELL_NAME" \
    "Path" "$DISPLAY_PATH"
echo ""

# ── Check prerequisites ─────────────────────────────────

if ! command -v nvim &> /dev/null; then
    step_fail "Neovim not found — install it from https://neovim.io"
    exit 1
fi
step_ok "Neovim found"

if ! command -v git &> /dev/null; then
    step_fail "Git not found — install git first"
    exit 1
fi
step_ok "Git found"

# ── Create launcher ──────────────────────────────────────

ALIAS_SCRIPT_DIR="$HOME/.local/bin"
ALIAS_SCRIPT="$ALIAS_SCRIPT_DIR/lux"

mkdir -p "$ALIAS_SCRIPT_DIR"

cat > "$ALIAS_SCRIPT" << EOF
#!/bin/bash
# LuxVim launcher script
NVIM_APPNAME="LuxVim" XDG_DATA_HOME="${LUXVIM_DIR}" nvim --cmd "set rtp+=${LUXVIM_DIR}" -u "${LUXVIM_DIR}/init.lua" "\$@"
EOF

chmod +x "$ALIAS_SCRIPT"
step_ok "Created ${DIM}lux${NC} command"

if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo ""
    echo -e "  ${YELLOW}!${NC} ~/.local/bin is not in your PATH"
    echo -e "    Add to your shell profile:  ${CYAN}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
    echo ""
fi

# ── Bootstrap lazy.nvim ──────────────────────────────────

LUXVIM_DATA_DIR="$LUXVIM_DIR/data"
mkdir -p "$LUXVIM_DATA_DIR/lazy" "$LUXVIM_DATA_DIR/luxlsp" "$LUXVIM_DATA_DIR/site"

LAZY_PATH="$LUXVIM_DATA_DIR/lazy/lazy.nvim"
if [ ! -d "$LAZY_PATH" ]; then
    git clone -q --filter=blob:none --branch=stable \
        https://github.com/folke/lazy.nvim.git "$LAZY_PATH" 2>/dev/null &
    spinner $! "Cloning lazy.nvim..."
    wait $!
    step_ok "Installed lazy.nvim"
else
    step_ok "lazy.nvim already present"
fi

# ── Install plugins ──────────────────────────────────────

LOG_FILE=$(mktemp)

"$ALIAS_SCRIPT" --headless "+Lazy! sync" +qa > "$LOG_FILE" 2>&1 &
SYNC_PID=$!

BAR_WIDTH=32
EST_TICKS=100  # ~15 seconds at 0.15s/tick
tick=0

tput civis 2>/dev/null
while kill -0 "$SYNC_PID" 2>/dev/null; do
    count=$(grep -c "Finished task clone" "$LOG_FILE" 2>/dev/null || true)
    filled=$(( tick * BAR_WIDTH / EST_TICKS ))
    (( filled > BAR_WIDTH )) && filled=$BAR_WIDTH
    draw_progress_bar "$filled" "$BAR_WIDTH" "Installing plugins (${count:-0} installed)..."
    sleep 0.15
    (( tick++ )) || true
done
tput cnorm 2>/dev/null

wait "$SYNC_PID"
SYNC_EXIT=$?

if [ "$SYNC_EXIT" -eq 0 ]; then
    PLUGIN_COUNT=$(grep -c "Finished task clone" "$LOG_FILE" 2>/dev/null || echo "0")
    step_ok "Installed ${PLUGIN_COUNT} plugins"
else
    step_fail "Plugin sync failed"
    echo ""
    cat "$LOG_FILE"
    rm -f "$LOG_FILE"
    exit 1
fi

rm -f "$LOG_FILE"

# ── Done ─────────────────────────────────────────────────

echo ""
echo -e "  ${GREEN}${BOLD}LuxVim is ready!${NC}"
echo -e "  Run ${CYAN}lux${NC} to start."
echo ""
