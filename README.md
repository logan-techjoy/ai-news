# AI News Desk

A frameless viewer that rotates AI news sites across the top 65% of the screen,
with the terminal underneath. Built with Qt Quick + QtWebEngine; runs on Linux
(Hyprland/Omarchy) and macOS.

## Install

```
git clone <this repo> && cd ai-news-desk && ./install.sh
```

`install.sh` copies `desk/desk.qml` and `desk/desk.js` to `~/.local/share/ai-news-desk/`
(an existing `zapped.ini` there is kept) and the launcher for your OS to `~/.local/bin/ai-news-desk`.

**Linux (Hyprland / Omarchy).** Needs `qt6-webengine`, `qt6-declarative`, `jq`, `uwsm`.
The launcher uses `hyprctl` to lift the desk to the top of the tiling layout with a
65/35 split. Add the binding and autostart lines the installer prints
(`SUPER + ALT + N`, and `ai-news-desk --login` at session start).

**macOS.** Needs Qt 6 with WebEngine: `brew install qtwebengine qtdeclarative` (or the
full `brew install qt`). The installer builds `~/Applications/AI News Desk.app`
(`macos/make-app`): the desk alone, as a normal app with no terminal attached. Open it from
Spotlight or the Dock; it reopens at the size and place you left it (`window.ini` next to
`desk.qml`) and logs to `~/Library/Logs/ai-news-desk.log`. Like on Linux, the desk browses
in its own profile (`storageName: "ai-news-desk"`), apart from every other browser.

For the tiled layout instead, run `ai-news-desk` from your terminal: it opens the desk across the top 65% of the main screen and moves the
terminal's window into the bottom 35%. Window placement goes through System Events, so
the terminal app needs Accessibility permission (System Settings > Privacy & Security >
Accessibility). There's no window manager to keep the split, so re-run the command after
moving things around. The DM Sans / DM Mono fonts used by the status pill fall back to the
system font if they aren't installed.

| File | What it does |
|---|---|
| `desk/desk.qml` | The viewer: site list, timing, zoom, slide animation, progress bar, status pill, load checks |
| `desk/desk.js` | Injected into every page: accepts cookie banners, removes full-screen popups, glide-and-pause auto-scroll |
| `linux/ai-news-desk` | Hyprland launcher: opens the desk (or focuses it), lifts it to the top of the layout, sets the 65/35 split |
| `linux/ai-news-desk.desktop` | App-launcher entry (runs `ai-news-desk --login`) |
| `macos/ai-news-desk` | macOS launcher: opens the desk and tiles it above the frontmost window |
| `macos/make-app` | Builds `~/Applications/AI News Desk.app`: the desk on its own, no terminal |
| `install.sh` | Installs the above for the current OS |

Paths below are the installed locations under `~/.local/share/ai-news-desk/`.

## Using it

Keys (the desk window must have focus): Right/Left next/previous, Space pause, R reload,
**X three times** removes the current site, **U** undoes the last removal.

Removing a site: the first X shows a red warning at the top with one lit ✕, the second
lights two. The warning fades over about 5.5 s, and if it fades out the count starts again,
so a single stray X does nothing. The third X removes the site and slides to the next one.
Removed sites are stored as urls in `zapped.ini` next to `desk.qml`, which survives restarts
and edits to the list. To bring a site back later, delete its url from that file (or the
whole file) and restart the desk.

Settings live at the top of `desk.qml`: `allSites`, `rotateMs` (40 s), `preloadMs`,
`scrollDelayMs` (2.5 s), `zoom`, `holdMs` (5 s). The scroll rhythm (glide size, glide time, pause; no scrolling at all while the countdown is held)
is `GLIDE_SCREENS`, `GLIDE_EXTRA_PX`, `GLIDE_MS` and `PAUSE_MS` at the top of the auto-scroll section of `desk.js`.

The countdown holds while you read: any mouse move, wheel, click or key on the page
(frames included) freezes it, and it resumes `holdMs` after you stop. desk.js tracks
this and exposes `__deskIdleMs()`, which desk.qml polls every 250 ms. Page scrolling
alone doesn't count, and neither do the same-spot mousemoves Chromium sends while the
page auto-scrolls under a still cursor, so auto-scroll can't hold the clock by itself.

How the site list was picked (2026-10-21): each candidate was loaded in an offscreen
WebEngine at the desk's zoom and measured for page text and for how much of the first two
screens is covered by images. Kept: loads, at least 2k characters of text, and images under
about 30%. Substack sites use their `/archive` page, since the home page opens on a large
hero. Left out: Reddit (redirects to a login wall), LMArena (refuses the embedded browser),
TLDR (almost no text), and image-heavy pages: Mistral, Meta AI, Ai2, Stanford HAI, The Decoder,
MarkTechPost, Engadget, CNBC, The Register, IEEE Spectrum, Ben's Bites.

Removed from the rotation and why: MIT Technology Review (full-screen exit popup),
The Verge (huge images and ads above the fold), Reuters (blocks automated browsers).

## Why qml crashed, and how not to do it again

Every `qml` crash on 2026-10-19 (5 core dumps, `coredumpctl list | grep qml`) was
from building and testing the desk, not from the desk running. All have the same
backtrace:

```
#0 QQuickWebEngineView::setProfile(QQuickWebEngineProfile*)   libQt6WebEngineQuick.so.6
#3 QQmlBinding::doUpdate ...
#5 QQmlObjectCreator::finalize ...
```

**Cause:** a `WebEngineView`'s grouped properties (`settings.*`, `userScripts.*`)
were declared as QML bindings. Qt creates them against the default profile
while the view is built, then applying the real profile (from
`WebEngineProfilePrototype.instance()`) dereferences state that isn't there and
segfaults instead of reporting an error. A related mistake: reading the profile
through a window-level property or the window's `onCompleted`, where
`instance()` can still be `null`. That one doesn't crash, but it threw and
skipped loading the first site, which was the blank Hacker News page.

Likely aggravating factor: since the 2026-10-19 14:35 update, `qt6-webengine`
(6.11.2) is a release behind `qt6-base` / `qt6-declarative` (6.12.0). Don't
downgrade for this. The rules below avoid the crash either way, and Arch will
ship WebEngine 6.12.

**Rules (also at the top of `desk.qml`):**

1. Never declare `settings.*` or `userScripts.*` on a `WebEngineView` as
   bindings. Set them in the view's own `Component.onCompleted`.
2. Bind `profile: profileMaker.instance()` directly on each view. Don't route it
   through a window property or touch it in the window's `onCompleted`.
3. Start the first page with `Qt.callLater`, so every view has finished its own
   `onCompleted` first.
4. Test edits before relaunching the real desk. Qt sends `console.*` output to
   the journal unless forced to stderr:

   ```
   QT_FORCE_STDERR_LOGGING=1 /usr/lib/qt6/bin/qml ~/.local/share/ai-news-desk/desk.qml
   ```

Each crash also raises Omarchy's "Process crashed: qml" notification, which
offers to start an AI agent to diagnose it. For crashes from the desk, check
this file first.

QtWebEngineProcess (Chromium renderer) crashes are muted in Omarchy's crash watcher
via `~/.config/systemd/user/omarchy-crash-watch.service.d/ignore.conf`
(`OMARCHY_CRASH_IGNORE`). A renderer crash only kills one page, and the desk retries it.
`qml` crashes still notify. Delete that file and run
`systemctl --user daemon-reload && systemctl --user restart omarchy-crash-watch` to unmute.
