#!/bin/bash

CONFIG_DIR="$HOME/.config/link-watcher"
CONFIG_FILE="$CONFIG_DIR/config"
DOMAINS_FILE="$CONFIG_DIR/allowed_domains.txt"
APPENDER_BIN="$CONFIG_DIR/appender"


for cmd in wl-paste zenity notify-send; do
    if ! command -v "$cmd" &> /dev/null; then
        ERROR_MSG="Link Watcher requires '$cmd'. Please run: sudo pacman -S wl-clipboard zenity libnotify"
        # If notify-send exists, show a visual error. Otherwise, print to terminal.
        if command -v notify-send &> /dev/null; then
            notify-send -u critical "Link Watcher Error" "$ERROR_MSG"
        else
            echo "$ERROR_MSG"
        fi
        exit 1
    fi
done


# --- MODE: CLIPBOARD HANDLER ---
if [ "$1" == "--handle" ]; then
    source "$CONFIG_FILE"
    
    # Read copied text piped from wl-paste
    CLIP=$(cat | tr -d '\n')
    
    # Fast exit if it doesn't look like a URL at all
    if [[ ! "$CLIP" =~ ^https?:// ]]; then exit 0; fi

    # Check against allowed domains file (-f reads patterns directly from the file)
    if echo "$CLIP" | grep -iqF -f "$DOMAINS_FILE"; then
        "$APPENDER_BIN" "$TARGET_FILE" "$CLIP"
        STATUS=$?
        
        if [ $STATUS -eq 0 ]; then
            notify-send "Link Watcher" "Link saved successfully!"
        elif [ $STATUS -eq 1 ]; then
            notify-send -u critical "Link Watcher Error" "Failed to save link to $TARGET_FILE"
        elif [ $STATUS -eq 2 ]; then
            notify-send "Link Watcher" "Link already exists!"
        fi
        # If STATUS is 2 (duplicate), it does nothing silently
    fi

    exit 0
fi

# --- MODE: STARTUP & SETUP ---

# 1. Generate plain text domains file if missing
if [ ! -f "$DOMAINS_FILE" ]; then
    cat <<EOF > "$DOMAINS_FILE"
twitter.com
x.com
t.co
facebook.com
fb.com
fb.watch
fb.gg
instagram.com
instagr.am
reddit.com
redd.it
EOF
fi

# 2. Generate default config if missing
if [ ! -f "$CONFIG_FILE" ]; then
    echo 'TARGET_FILE=""' > "$CONFIG_FILE"
fi

source "$CONFIG_FILE"

# 3. Prompt for target file if missing or invalid
if [ -z "$TARGET_FILE" ] || [ ! -f "$TARGET_FILE" ]; then
  TARGET_FILE=$(zenity --file-selection \
        --title="Select your links file to append to")
    
    if [ -z "$TARGET_FILE" ]; then
        notify-send -u critical "Link Watcher" "No file selected. Watcher shutting down."
        exit 1
    fi
    
    touch "$TARGET_FILE"
    sed -i "s|^TARGET_FILE=.*|TARGET_FILE=\"$TARGET_FILE\"|" "$CONFIG_FILE"
fi

# 4. Ensure the C++ appender exists
if [ ! -x "$APPENDER_BIN" ]; then
    notify-send -u critical "Link Watcher Error" "C++ Appender not found or not executable. Compile it first!"
    exit 1
fi

# 5. Start watching the clipboard
pkill -f "wl-paste -t text --watch $0 --handle"
wl-paste -t text --watch "$0" --handle