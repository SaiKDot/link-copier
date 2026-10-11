#!/bin/bash

# Check dependencies before starting initialization
for cmd in g++ wl-paste zenity notify-send; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: Required command '$cmd' is not installed."
        echo "Please install missing packages by running:"
        echo "sudo pacman -S gcc wl-clipboard zenity libnotify"
        exit 1
    fi
done

CONFIG_DIR="$HOME/.config/link-watcher"
APPENDER_SRC="./appender.cpp"
APPENDER_BIN="$CONFIG_DIR/appender"
WATCHER_SCRIPT="$CONFIG_DIR/watcher.sh"
HYPR_CONF="$HOME/.config/hypr/hyprland.conf"

echo "Starting initialization..."


# 1. Setup and give permissions to the watcher script
mkdir -p "$CONFIG_DIR"

if [ -f "$WATCHER_SCRIPT" ]; then
    chmod +x "$WATCHER_SCRIPT"
    echo "Permissions granted to existing watcher.sh."
else
    echo "watcher.sh not found in config folder. Attempting to copy from current directory..."
    # Attempt to copy watcher.sh from the current directory to the config directory
    if cp "watcher.sh" "$WATCHER_SCRIPT" 2>/dev/null; then
        chmod +x "$WATCHER_SCRIPT"
        echo "Successfully copied watcher.sh to $CONFIG_DIR and granted permissions."
    else
        echo "Error: Could not find or copy watcher.sh. Make sure it is in the same folder as this init script."
        exit 1
    fi
fi
# 2. Compile the C++ program IF the executable doesn't exist
if [ ! -f "$APPENDER_BIN" ]; then
    if [ -f "$APPENDER_SRC" ]; then
        echo "Executable not found. Compiling appender.cpp..."
        if g++ "$APPENDER_SRC" -o "$APPENDER_BIN" -O2; then
            chmod +x "$APPENDER_BIN"
            echo "Compilation successful."
        else
            echo "Error: Compilation failed. Make sure gcc is installed."
            exit 1
        fi
    else
        echo "Error: $APPENDER_SRC not found. Cannot compile."
        exit 1
    fi
else
    echo "Executable already exists. Skipping compilation."
    chmod +x "$APPENDER_BIN" # Ensure execution rights just in case
fi

# 3. Add to Hyprland startup
if [ -f "$HYPR_CONF" ]; then
    # Check if it's already in the config
    if grep -q "$WATCHER_SCRIPT" "$HYPR_CONF"; then
        echo "Startup entry already exists in hyprland.conf."
    else
        echo -e "\n# Link Watcher Autostart\nexec-once = $WATCHER_SCRIPT" >> "$HYPR_CONF"
        echo "Added to hyprland.conf for startup!"
    fi
else
    echo "Warning: $HYPR_CONF not found. You will need to add it to your specific compositor's startup file manually."
fi

# 4. Start the process
echo "Starting the Link Watcher service..."
# Kill any existing instances to avoid duplicates if this script is run multiple times
pkill -f "wl-paste.*watcher.sh.*--handle"

# Run in background and disown so it survives terminal closure
"$WATCHER_SCRIPT" & 
disown

echo "Initialization Complete! The watcher is now running in the background."