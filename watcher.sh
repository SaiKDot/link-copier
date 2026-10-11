#!/bin/bash

CONFIG_DIR="$HOME/.config/link-watcher"
CONFIG_FILE="$CONFIG_DIR/config"
APPENDER_BIN="$CONFIG_DIR/appender"

# --- MODE: CLIPBOARD HANDLER ---
# This block is executed every time wl-paste detects a new text clipboard entry
if [ "$1" == "--handle" ]; then
    source "$CONFIG_FILE"
    
    # Read copied text piped from wl-paste
    CLIP=$(cat | tr -d '\n')
    
    # Fast exit if it doesn't look like a URL at all
    if [[ ! "$CLIP" =~ ^https?:// ]]; then exit 0; fi

    # Check against allowed domains
    DOMAIN_MATCH=0
    for domain in $ALLOWED_DOMAINS; do
        if echo "$CLIP" | grep -iqF "$domain"; then
            DOMAIN_MATCH=1
            break
        fi
    done

    # If it's a valid domain, pass it to the C++ appender
    if [ $DOMAIN_MATCH -eq 1 ]; then
        if ! "$APPENDER_BIN" "$TARGET_FILE" "$CLIP"; then
            notify-send -u critical "Link Watcher Error" "Failed to save link to $TARGET_FILE"
        fi
    fi
    
    exit 0
fi

# --- MODE: STARTUP & SETUP ---

# 1. Generate default config if missing
if [ ! -f "$CONFIG_FILE" ]; then
    echo 'TARGET_FILE=""' > "$CONFIG_FILE"
    echo 'ALLOWED_DOMAINS="youtube.com github.com archlinux.org"' >> "$CONFIG_FILE"
fi

source "$CONFIG_FILE"

# 2. Prompt for target file if missing or invalid
if [ -z "$TARGET_FILE" ] || [ ! -f "$TARGET_FILE" ]; then
    TARGET_FILE=$(zenity --file-selection --save --confirm-overwrite \
        --title="Select or create a file to save your copied links")
    
    if [ -z "$TARGET_FILE" ]; then
        notify-send -u critical "Link Watcher" "No file selected. Watcher shutting down."
        exit 1
    fi
    
    touch "$TARGET_FILE"
    # Safely update the config file
    sed -i "s|^TARGET_FILE=.*|TARGET_FILE=\"$TARGET_FILE\"|" "$CONFIG_FILE"
fi

# 3. Ensure the C++ appender exists
if [ ! -x "$APPENDER_BIN" ]; then
    notify-send -u critical "Link Watcher Error" "C++ Appender not found or not executable. Compile it first!"
    exit 1
fi

# 4. Start watching the clipboard for plain text changes
# We use pkill to ensure we don't accidentally stack multiple watcher processes on reload
pkill -f "wl-paste -t text --watch $0 --handle"
wl-paste -t text --watch "$0" --handle