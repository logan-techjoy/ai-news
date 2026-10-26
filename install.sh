#!/bin/bash
# Installs the AI News Desk for the current user (Linux/Hyprland or macOS).
#   desk.qml, desk.js -> ~/.local/share/ai-news-desk/   (zapped.ini there is kept)
#   launcher          -> ~/.local/bin/ai-news-desk
# Linux also gets a .desktop entry; the Hyprland binding and autostart are printed, not edited.
set -euo pipefail
cd "$(dirname "$0")"

share=~/.local/share/ai-news-desk
bin=~/.local/bin
mkdir -p "$share" "$bin"
cp desk/desk.qml desk/desk.js "$share/"

case $(uname -s) in
  Linux)
    install -m 755 linux/ai-news-desk "$bin/ai-news-desk"
    mkdir -p ~/.local/share/applications
    sed "s#@HOME@#$HOME#" linux/ai-news-desk.desktop > ~/.local/share/applications/ai-news-desk.desktop
    cat <<'EOF'
Installed. On Hyprland (Omarchy Lua config), add if missing:
  ~/.config/hypr/bindings.lua:  o.bind("SUPER + ALT + N", "AI news desk", "ai-news-desk")
  ~/.config/hypr/autostart.lua: o.exec_on_start(os.getenv("HOME") .. "/.local/bin/ai-news-desk --login")
EOF
    ;;
  Darwin)
    install -m 755 macos/ai-news-desk "$bin/ai-news-desk"
    command -v qml >/dev/null || [[ -x "$(brew --prefix qt 2>/dev/null)/bin/qml" ]] ||
      echo "Qt 6 not found: brew install qt"
    cat <<'EOF'
Installed. Run `ai-news-desk` from your terminal (make sure ~/.local/bin is on PATH).
Give that terminal app Accessibility permission so the desk can place windows:
  System Settings > Privacy & Security > Accessibility
EOF
    ;;
  *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac
