# Installer Spectacle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite `install.sh` into a branded experience with truecolor gradient logo, system info panel, gradient progress bars, and summary box.

**Architecture:** Single-file rewrite of `install.sh`. All visual helpers (gradient math, box drawing, progress bars) are bash functions at the top. The script flows linearly: logo → system info → prerequisite checks → launcher creation → lazy.nvim clone → plugin sync → summary. Truecolor is detected once and gates gradient rendering vs plain fallback throughout.

**Tech Stack:** Bash, truecolor ANSI escapes (`\033[38;2;R;G;Bm`), box-drawing Unicode characters, Braille Unicode art.

**Note:** This project has no test suite. Verification is manual — run `./install.sh` after a clean `rm -rf data/ ~/.local/bin/lux` and confirm visual output.

---

## File Structure

- **Modify:** `install.sh` — complete rewrite

---

### Task 1: Foundation — Colors, Truecolor Detection, Cleanup Trap, Step Helpers

**Files:**
- Modify: `install.sh` (replace lines 1–44)

- [ ] **Step 1: Write the script header, color constants, truecolor detection, and cleanup trap**

Replace the top of `install.sh` with:

```bash
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
```

- [ ] **Step 2: Write the step_ok, step_fail, and gradient_color helpers**

Append below the trap:

```bash
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
```

- [ ] **Step 3: Verify the foundation compiles**

Append a temporary test at the bottom of the file:

```bash
echo "HAS_TRUECOLOR=$HAS_TRUECOLOR"
gradient_color 0 10
echo "orange"
gradient_color 9 10
echo "purple"
printf "${NC}\n"
step_ok "test passed"
```

Run: `bash install.sh`

Expected: prints `HAS_TRUECOLOR=true` (or false), "orange" in orange, "purple" in purple, and a green checkmark line. Remove the temporary test after confirming.

- [ ] **Step 4: Commit**

```bash
git add install.sh
git commit -m "feat(installer): add truecolor detection, gradient math, and step helpers"
```

---

### Task 2: Logo Reveal with Gradient Animation

**Files:**
- Modify: `install.sh` (add logo array and print_logo function, replace header section)

- [ ] **Step 1: Add the logo array**

Add after the `gradient_color` function. The logo data comes from `lua/plugins/ui/config/luxdash.lua:85-113` — embed it as a bash array:

```bash
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
```

- [ ] **Step 2: Write the print_logo function**

Add after the LOGO array:

```bash
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
```

- [ ] **Step 3: Replace the old header with logo call**

Remove the old header section (the `echo` lines that printed "LuxVim Installer" and the dash separator). Replace with:

```bash
# ── Logo ─────────────────────────────────────────────────
print_logo
```

This goes right after all the function/data definitions, before the prerequisite checks.

- [ ] **Step 4: Verify the logo renders**

Run: `rm -rf data/ ~/.local/bin/lux && bash install.sh`

Expected: the Braille logo appears with an orange-to-purple gradient, animated line-by-line. The rest of the installer continues to work as before. If `$COLORTERM` is not set, the logo appears in plain white with no animation.

- [ ] **Step 5: Commit**

```bash
git add install.sh
git commit -m "feat(installer): add gradient logo reveal with truecolor animation"
```

---

### Task 3: System Info Panel

**Files:**
- Modify: `install.sh` (add draw_box function and system info section)

- [ ] **Step 1: Write the draw_box function**

Add after `print_logo`, before the logo call:

```bash
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
```

- [ ] **Step 2: Add the system info section after the logo call**

```bash
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
```

- [ ] **Step 3: Verify the system info panel renders**

Run: `rm -rf data/ ~/.local/bin/lux && bash install.sh`

Expected: after the logo, a box appears with correct Neovim version, OS, shell, and path. Long paths are truncated with `...` prefix. The box border is dimmed.

- [ ] **Step 4: Commit**

```bash
git add install.sh
git commit -m "feat(installer): add system info panel with box drawing"
```

---

### Task 4: Gradient Progress Bar for Plugin Sync

**Files:**
- Modify: `install.sh` (add draw_progress_bar, rewrite plugin sync section)

- [ ] **Step 1: Write the draw_progress_bar function**

Add after `draw_box`:

```bash
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
```

- [ ] **Step 2: Rewrite the lazy.nvim clone section**

The lazy.nvim clone is fast (~1-2s), so keep the existing spinner approach. No changes needed to this section — it already works well with the spinner from the current install.sh. However, the `spinner` function was removed in the foundation task. Re-add it:

```bash
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
```

- [ ] **Step 3: Rewrite the plugin sync section with progress bar**

Replace the plugin sync section with:

```bash
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
```

- [ ] **Step 4: Verify the progress bar works**

Run: `rm -rf data/ ~/.local/bin/lux && bash install.sh`

Expected: during plugin sync, a gradient-filled progress bar appears that fills over ~15 seconds. The count of installed plugins ticks up. On completion, the bar is replaced with a green checkmark line showing the total.

- [ ] **Step 5: Commit**

```bash
git add install.sh
git commit -m "feat(installer): add gradient progress bar for plugin sync"
```

---

### Task 5: Completion Summary Box and Timer

**Files:**
- Modify: `install.sh` (replace the closing section)

- [ ] **Step 1: Replace the closing section with summary box**

Replace everything after the `rm -f "$LOG_FILE"` line with:

```bash
# ── Done ─────────────────────────────────────────────────

ELAPSED=$(( SECONDS - START_TIME ))

echo ""
draw_box "Install Complete" \
    "Plugins" "${PLUGIN_COUNT} installed" \
    "Time" "${ELAPSED}s"
echo ""
echo -e "  ${GREEN}${BOLD}LuxVim is ready!${NC} Run ${CYAN}lux${NC} to start."
echo ""
```

- [ ] **Step 2: Verify the summary renders**

Run: `rm -rf data/ ~/.local/bin/lux && bash install.sh`

Expected: after all installation steps, a box appears showing plugin count and elapsed time. Below it, the "LuxVim is ready!" message in bold green with "lux" in cyan. The timer reflects actual wall-clock time.

- [ ] **Step 3: Commit**

```bash
git add install.sh
git commit -m "feat(installer): add completion summary box with timing"
```

---

### Task 6: Integration Test — Full Clean Install

**Files:**
- No new files. This task verifies the complete script.

- [ ] **Step 1: Clean all state**

```bash
rm -rf data/ ~/.local/bin/lux
```

- [ ] **Step 2: Run the installer and verify all sections**

```bash
./install.sh
```

Check each section visually:

1. **Logo**: 29-line Braille art with orange→purple gradient, animated line-by-line
2. **System info**: box with Neovim version, OS, shell, path — all values correct
3. **Checkmarks**: Neovim found, Git found, Created lux command, Created data directories
4. **PATH warning**: appears only if `~/.local/bin` is not in PATH
5. **Lazy.nvim**: spinner while cloning, checkmark on completion
6. **Plugin sync**: gradient progress bar with incrementing count, replaced by checkmark
7. **Summary box**: correct plugin count and timing
8. **Closing message**: "LuxVim is ready! Run lux to start."

- [ ] **Step 3: Verify lux command works**

```bash
lux --headless +qa
```

Expected: exits cleanly with no errors.

- [ ] **Step 4: Test truecolor fallback**

```bash
rm -rf data/ ~/.local/bin/lux
COLORTERM="" bash install.sh
```

Expected: logo appears in plain white, no animation. Progress bar uses plain green fill. Everything else identical.

- [ ] **Step 5: Fix any issues found, then commit**

If any fixes were needed:

```bash
git add install.sh
git commit -m "fix(installer): address issues from integration test"
```
