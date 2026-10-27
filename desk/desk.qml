// AI News Desk: frameless rotating viewer for AI news sites.
// Keys: Right/Left = next/previous site, Space = pause/resume, R = reload,
//       X three times = remove the current site for good (zapped.ini), U = undo the last removal.
// desk.js (injected into every page) accepts cookie banners, removes popups and slowly scrolls.
//
// CRASH RULES (see README.md). Breaking these segfaults qml in QQuickWebEngineView::setProfile:
//   1. Never declare WebEngineView grouped properties (settings.*, userScripts.*) as bindings.
//      Set them in the view's Component.onCompleted, after `profile` is attached.
//   2. Never reach the profile through a window property or the window's onCompleted;
//      profileMaker.instance() can still be null there. Bind it directly on each view.
//   3. Test edits with: QT_FORCE_STDERR_LOGGING=1 /usr/lib/qt6/bin/qml desk.qml
import QtQuick
import QtQuick.Window
import QtCore
import QtWebEngine

Window {
    id: win
    title: "AI News Desk"
    width: 1280
    height: 460
    visible: true
    color: "#0B1A4A"

    // ---------- configuration ----------
    readonly property int rotateMs: 40 * 1000
    readonly property int preloadMs: 35 * 1000   // load the next site this long before switching
    readonly property int scrollDelayMs: 2500    // pause on the top of each page before scrolling
    readonly property real zoom: 0.85
    readonly property int holdMs: 5000           // countdown waits until the mouse/keys are idle this long
    // Every site the desk knows. X X X on a site adds its url to zapped.ini, which takes it out of `sites`.
    // Picked 2026-10-21 for loading in WebEngine with mostly text above the fold (README has the method).
    readonly property var allSites: [
        { name: "Hacker News",                 url: "https://news.ycombinator.com/" },
        { name: "Simon Willison",              url: "https://simonwillison.net/" },
        { name: "Hugging Face Papers",         url: "https://huggingface.co/papers" },
        { name: "Techmeme",                    url: "https://www.techmeme.com/" },
        { name: "GitHub Trending",             url: "https://github.com/trending?since=daily" },
        { name: "Anthropic News",              url: "https://www.anthropic.com/news" },
        { name: "AINews (smol.ai)",            url: "https://news.smol.ai/" },
        { name: "Interconnects",               url: "https://www.interconnects.ai/archive" },
        { name: "Lobsters AI",                 url: "https://lobste.rs/t/ai" },
        { name: "HF Trending Models",          url: "https://huggingface.co/models?sort=trending" },
        { name: "TechCrunch AI",               url: "https://techcrunch.com/category/artificial-intelligence/" },
        { name: "Import AI",                   url: "https://importai.substack.com/archive" },
        { name: "Ollama Blog",                 url: "https://ollama.com/blog" },
        { name: "OpenAI News",                 url: "https://openai.com/news/" },
        { name: "Epoch AI",                    url: "https://epoch.ai/latest" },
        { name: "Latent Space",                url: "https://www.latent.space/archive" },
        { name: "Artificial Analysis",         url: "https://artificialanalysis.ai/" },
        { name: "HF Papers Trending",          url: "https://huggingface.co/papers/trending" },
        { name: "Ars Technica AI",             url: "https://arstechnica.com/ai/" },
        { name: "Ahead of AI",                 url: "https://magazine.sebastianraschka.com/archive" },
        { name: "vLLM Blog",                   url: "https://vllm.ai/blog" },
        { name: "Google DeepMind",             url: "https://deepmind.google/discover/blog/" },
        { name: "OpenRouter Rankings",         url: "https://openrouter.ai/rankings" },
        { name: "Last Week in AI",             url: "https://lastweekin.ai/archive" },
        { name: "The New Stack AI",            url: "https://thenewstack.io/ai/" },
        { name: "Hugging Face Blog",           url: "https://huggingface.co/blog" },
        { name: "One Useful Thing",            url: "https://www.oneusefulthing.org/archive" },
        { name: "Anthropic Research",          url: "https://www.anthropic.com/research" },
        { name: "llama.cpp Releases",          url: "https://github.com/ggml-org/llama.cpp/releases" },
        { name: "InfoQ AI",                    url: "https://www.infoq.com/ai-ml-data-eng/" },
        { name: "Understanding AI",            url: "https://www.understandingai.org/archive" },
        { name: "Google AI Blog",              url: "https://blog.google/technology/ai/" },
        { name: "LMSYS Blog",                  url: "https://lmsys.org/blog/" },
        { name: "AlphaSignal",                 url: "https://alphasignal.ai/" },
        { name: "arXiv cs.CL (new papers)",    url: "https://arxiv.org/list/cs.CL/recent" },
        { name: "OpenAI Research",             url: "https://openai.com/research/index/" },
        { name: "Don't Worry About the Vase",  url: "https://thezvi.substack.com/archive" },
        { name: "Lobsters Vibecoding",         url: "https://lobste.rs/t/vibecoding" },
        { name: "MIT News AI",                 url: "https://news.mit.edu/topic/artificial-intelligence2" },
        { name: "Qwen Research",               url: "https://qwen.ai/research" },
        { name: "The Rundown",                 url: "https://www.therundown.ai/" },
        { name: "EleutherAI Blog",             url: "https://blog.eleuther.ai/" },
        { name: "VentureBeat AI",              url: "https://venturebeat.com/category/ai/" },
        { name: "AI as Normal Technology",     url: "https://www.normaltech.ai/archive" },
        { name: "PyTorch Blog",                url: "https://pytorch.org/blog/" },
        { name: "Google Research Blog",        url: "https://research.google/blog/" },
        { name: "Nature: Machine Learning",    url: "https://www.nature.com/subjects/machine-learning" },
        { name: "xAI News",                    url: "https://x.ai/news" },
        { name: "Lilian Weng",                 url: "https://lilianweng.github.io/" },
        { name: "KDnuggets",                   url: "https://www.kdnuggets.com/" },
        { name: "AI Alignment Forum",          url: "https://www.alignmentforum.org/" },
        { name: "Quanta: AI",                  url: "https://www.quantamagazine.org/tag/artificial-intelligence/" },
        { name: "Microsoft Research Blog",     url: "https://www.microsoft.com/en-us/research/blog/" },
        { name: "Apple ML Research",           url: "https://machinelearning.apple.com/" },
        { name: "Tom's Hardware AI",           url: "https://www.tomshardware.com/tech-industry/artificial-intelligence" },
        { name: "BAIR Blog",                   url: "https://bair.berkeley.edu/blog/" },
        { name: "Gary Marcus",                 url: "https://garymarcus.substack.com/archive" },
        { name: "Sakana AI",                   url: "https://sakana.ai/blog/" },
        { name: "Wired AI",                    url: "https://www.wired.com/tag/artificial-intelligence/" }
    ]

    // ---------- removed sites (persist across restarts) ----------
    Settings {
        id: store
        location: Qt.resolvedUrl("zapped.ini")
        property string zapped: "[]"     // JSON list of urls; a one-item list doesn't survive QSettings as a var
    }
    // ---------- window size and position (persist across restarts) ----------
    // macOS has no tiler to place the desk, so it reopens where it was last left.
    Settings {
        id: place
        location: Qt.resolvedUrl("window.ini")
        property int x: 0
        property int y: 0
        property int w: 0                // 0 = never saved; keep the default size
        property int h: 0
    }
    property bool placed: false          // don't save geometry until the saved one has been applied
    function restorePlace() {
        // Skip a saved spot that no connected screen covers (a monitor was unplugged)
        const onScreen = Qt.application.screens.some((s) =>
            place.x >= s.virtualX && place.x < s.virtualX + s.width &&
            place.y >= s.virtualY && place.y < s.virtualY + s.height)
        if (place.w >= 400 && place.h >= 200 && onScreen) {
            win.x = place.x; win.y = place.y; win.width = place.w; win.height = place.h
        }
        placed = true
    }
    onXChanged: if (placed) place.x = x
    onYChanged: if (placed) place.y = y
    onWidthChanged: if (placed) place.w = width
    onHeightChanged: if (placed) place.h = height

    function zappedUrls() { try { return JSON.parse(store.zapped) } catch (e) { return [] } }
    function liveSites() { const gone = zappedUrls(); return allSites.filter((s) => gone.indexOf(s.url) < 0) }

    // ---------- state ----------
    property var sites: liveSites()      // the rotation; reassigned only by zap() and unzap()
    property int index: 0
    property real elapsed: 0
    property bool paused: false
    property bool holding: false          // you're reading or moving the page; countdown waits
    property real touchedAt: 0            // last wheel/mouse move the window itself saw (covers ads and frames)

    function touched() { touchedAt = Date.now(); holding = true }
    // No auto-scroll while held
    onHoldingChanged: viewAt(front).runJavaScript("window.__deskHold && window.__deskHold(" + holding + ")")
    property int front: 0                 // which of the two views is showing
    property int queued: -1               // site index loaded into the back view
    property var failedAt: ({})           // site index -> time it last failed every retry

    function viewAt(i) { return i === 0 ? viewA : viewB }
    function wrap(i) { return (i + sites.length) % sites.length }

    function startScroll(view) {
        view.runJavaScript("window.__deskStart && window.__deskStart(" + scrollDelayMs + "); window.__deskHold && window.__deskHold(" + holding + ")")
    }
    function stopScroll(view) { view.runJavaScript("window.__deskStop && window.__deskStop()") }

    // Next site after i that hasn't failed in the last 10 minutes
    function nextHealthy(i, step) {
        for (let n = 1; n <= sites.length; n++) {
            const candidate = wrap(i + n * step)
            if (!failedAt[candidate] || Date.now() - failedAt[candidate] > 10 * 60 * 1000) return candidate
        }
        return wrap(i + step)
    }

    function load(view, siteIndex) {
        view.site = siteIndex
        view.attempts = 0
        view.health = "loading"
        view.url = sites[siteIndex].url
    }

    function preload(i) {
        queued = wrap(i)
        load(viewAt(1 - front), queued)
    }

    function go(i, direction) {
        const target = wrap(i)
        if (queued !== target) preload(target)
        const incoming = viewAt(1 - front)
        const outgoing = viewAt(front)
        swap.direction = direction
        swap.incoming = incoming
        swap.outgoing = outgoing
        swap.restart()
        front = 1 - front
        index = target
        elapsed = 0
        queued = -1
        stopScroll(outgoing)
        if (incoming.health === "ok") startScroll(incoming)
        hud.changed()
    }

    // ---------- zap: X once warns, twice warns harder, three times removes the site ----------
    property int strikes: 0               // X presses on the current site since the warning last faded
    property string strikeUrl: ""
    property var lastZapped: null         // for U

    function strike() {
        const site = sites[index]
        if (strikeUrl !== site.url) strikes = 0
        strikeUrl = site.url
        if (++strikes < 3) {
            zapToast.show(strikes, strikes === 1
                ? "Remove " + site.name + "?  Press X twice more"
                : "Press X once more to remove " + site.name)
        } else if (sites.length < 2) {
            zapToast.show(0, "Can't remove the last site")
        } else {
            zap()
        }
    }

    function zap() {
        const gone = sites[index]
        // Site indexes shift, so forget everything keyed by them and slide to whatever moved into this slot.
        // Swap the list before writing the store, so `sites` never changes under a stale index.
        const remaining = sites.filter((s) => s.url !== gone.url)
        const target = index % remaining.length
        index = target
        sites = remaining
        failedAt = {}
        queued = -1
        viewAt(front).forget()
        store.zapped = JSON.stringify(zappedUrls().concat([gone.url]))
        store.sync()
        lastZapped = gone
        strikes = 0
        go(target, 1)
        zapToast.show(3, "Removed " + gone.name + "  ·  U to undo")
    }

    function unzap() {
        if (!lastZapped) return
        const back = lastZapped
        lastZapped = null
        const currentUrl = sites[index].url
        const restored = allSites.filter((s) => s.url === back.url || sites.some((t) => t.url === s.url))
        const at = (url) => restored.findIndex((s) => s.url === url)
        sites = restored
        index = at(currentUrl)
        viewAt(front).site = index
        failedAt = {}
        queued = -1
        store.zapped = JSON.stringify(zappedUrls().filter((u) => u !== back.url))
        store.sync()
        go(at(back.url), -1)
        zapToast.show(0, "Restored " + back.name)
    }

    // Called when a view gives up on its site after every retry
    function siteFailed(view) {
        failedAt[view.site] = Date.now()
        if (view === viewAt(front)) {
            go(nextHealthy(index, 1), 1)             // on screen: move on right away
        } else if (view.site === queued) {
            preload(nextHealthy(view.site, 1))       // in the wings: line up the one after
        }
    }

    WebEngineProfilePrototype {
        id: profileMaker
        storageName: "ai-news-desk"   // keeps cookies, so consent banners stay dismissed
    }

    // Views set up their scripts in their own onCompleted, so start on the next tick
    Component.onCompleted: {
        restorePlace()
        Qt.callLater(() => load(viewA, 0))
    }

    component DeskView: WebEngineView {
        id: view
        property int site: -1
        property int attempts: 0
        property string health: "idle"   // idle | loading | ok | failed

        anchors.fill: parent
        profile: profileMaker.instance()
        zoomFactor: win.zoom
        backgroundColor: "#0B1A4A"
        // Grouped properties crash when bound before the profile is attached; apply once ready
        Component.onCompleted: {
            settings.showScrollBars = false
            settings.playbackRequiresUserGesture = true
            userScripts.collection = [{
                name: "desk",
                sourceUrl: Qt.resolvedUrl("desk.js"),
                injectionPoint: WebEngineScript.DocumentReady,
                worldId: WebEngineScript.MainWorld,
                runsOnSubFrames: true
            }]
        }
        onNewWindowRequested: (request) => Qt.openUrlExternally(request.requestedUrl)

        // Its site was just removed: drop it without reporting a failure or touching the new indexes
        function forget() {
            site = -1
            retryTimer.stop()
            contentCheck.stop()
        }

        function retry() {
            if (site < 0) return
            if (++attempts > 3) {
                health = "failed"
                console.warn("AI News Desk: giving up on", win.sites[site].name)
                win.siteFailed(view)
                return
            }
            console.warn("AI News Desk: retrying", win.sites[site].name, "attempt", attempts)
            retryTimer.interval = 2000 * attempts
            retryTimer.restart()
        }

        Timer { id: retryTimer; onTriggered: view.reload() }

        // After a "successful" load, make sure the page actually rendered something
        Timer {
            id: contentCheck
            interval: 3000
            onTriggered: view.runJavaScript(
                "(document.body ? document.body.innerText.trim().length : 0)",
                (chars) => {
                    if (view.site < 0) return
                    if (chars >= 150) {
                        view.health = "ok"
                        if (win.viewAt(win.front) === view) win.startScroll(view)
                    } else {
                        view.retry()
                    }
                })
        }

        onLoadingChanged: (info) => {
            if (info.status === WebEngineView.LoadSucceededStatus) {
                zoomFactor = win.zoom
                contentCheck.restart()
            } else if (info.status === WebEngineView.LoadFailedStatus) {
                contentCheck.stop()
                retry()
            }
        }
    }

    Item {
        id: stage
        anchors.fill: parent
        clip: true
        DeskView { id: viewA; z: front === 0 ? 1 : 0 }
        DeskView { id: viewB; z: front === 1 ? 1 : 0; opacity: 0 }

        // Pages miss input over ad frames, so the window watches too. Neither of these takes the
        // event: hover isn't blocked, and wheel ticks are passed on to the page underneath.
        HoverHandler {
            property real lastX: -1
            property real lastY: -1
            // Qt re-sends hover at the same spot while the scene redraws; only real movement counts
            onPointChanged: {
                if (point.position.x === lastX && point.position.y === lastY) return
                lastX = point.position.x
                lastY = point.position.y
                win.touched()
            }
        }
        MouseArea {
            anchors.fill: parent
            z: 2
            acceptedButtons: Qt.NoButton
            onWheel: (wheel) => { win.touched(); wheel.accepted = false }
        }
    }

    // Slide + fade between sites; the old page drifts away as the new one arrives
    ParallelAnimation {
        id: swap
        property Item incoming
        property Item outgoing
        property int direction: 1
        NumberAnimation { target: swap.incoming; property: "x"; from: swap.direction * stage.width * 0.06; to: 0; duration: 700; easing.type: Easing.OutCubic }
        NumberAnimation { target: swap.incoming; property: "opacity"; from: 0; to: 1; duration: 600; easing.type: Easing.OutCubic }
        NumberAnimation { target: swap.outgoing; property: "x"; to: -swap.direction * stage.width * 0.06; duration: 600; easing.type: Easing.OutCubic }
        NumberAnimation { target: swap.outgoing; property: "opacity"; to: 0; duration: 500; easing.type: Easing.OutCubic }
        onFinished: swap.outgoing.x = 0
    }

    // ---------- vertical progress bar on the right edge, filling downward ----------
    Rectangle {
        z: 10
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
        width: 5
        color: "#11225C"
        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: parent.height * Math.min(1, win.elapsed / win.rotateMs)
            color: win.paused || win.holding ? "#F4B255" : "#5C80F3"
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    // ---------- status pill: current site, position, and countdown to the next ----------
    Rectangle {
        id: hud
        z: 10
        anchors { left: parent.left; bottom: parent.bottom; margins: 12 }
        radius: height / 2
        height: 30
        width: row.implicitWidth + 26
        color: "#EB0B1A4A"
        border.color: "#1A2D6B"
        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

        function changed() { pulse.restart() }

        readonly property int secondsLeft: Math.max(0, Math.ceil((win.rotateMs - win.elapsed) / 1000))

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 10
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 7; height: 7; radius: 4
                color: win.paused || win.holding ? "#F4B255" : "#5C80F3"
            }
            Text {
                id: current
                anchors.verticalCenter: parent.verticalCenter
                color: "#FFFFFF"
                font { family: "DM Sans"; pixelSize: 12; weight: Font.DemiBold; letterSpacing: 1.2 }
                text: win.sites[win.index].name.toUpperCase()
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: "#64748B"
                font { family: "DM Mono"; pixelSize: 11 }
                text: (win.index + 1) + "/" + win.sites.length
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: "#94A3B8"
                font { family: "DM Sans"; pixelSize: 12 }
                textFormat: Text.RichText
                text: win.paused
                      ? "<font color='#F4B255'>paused</font> · space to resume"
                      : "next: " + win.sites[win.nextHealthy(win.index, 1)].name + "  <font color='" + (win.holding ? "#F4B255" : "#E2E8F0") + "' face='DM Mono'>"
                        + Math.floor(hud.secondsLeft / 60) + ":" + String(hud.secondsLeft % 60).padStart(2, "0") + "</font>"
                        + (win.holding ? "  <font color='#F4B255'>held</font>" : "")
            }
        }

        SequentialAnimation {
            id: pulse
            NumberAnimation { target: current; property: "opacity"; to: 0; duration: 120 }
            NumberAnimation { target: current; property: "opacity"; to: 1; duration: 380; easing.type: Easing.OutCubic }
        }
    }

    // ---------- zap warning: red, top centre, fades over ~5.5 s; fading out resets the strikes ----------
    Rectangle {
        id: zapToast
        z: 20
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 18 }
        radius: 10
        height: 44
        width: zapRow.implicitWidth + 32
        color: "#F2B42318"
        border.color: "#F04438"
        opacity: 0
        visible: opacity > 0
        property int marks: 0      // red X's lit, out of 3
        property string message: ""

        function show(count, text) {
            marks = count
            message = text
            fade.restart()
        }

        Row {
            id: zapRow
            anchors.centerIn: parent
            spacing: 14
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                visible: zapToast.marks > 0
                Repeater {
                    model: 3
                    Text {
                        text: "✕"
                        color: "#FFFFFF"
                        opacity: index < zapToast.marks ? 1 : 0.25
                        font { family: "DM Sans"; pixelSize: 20; weight: Font.Black }
                    }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: zapToast.message
                color: "#FFFFFF"
                font { family: "DM Sans"; pixelSize: 15; weight: Font.DemiBold }
            }
        }

        SequentialAnimation {
            id: fade
            NumberAnimation { target: zapToast; property: "opacity"; to: 1; duration: 120 }
            NumberAnimation { target: zapToast; property: "opacity"; to: 0; duration: 5500; easing.type: Easing.InQuad }
            onFinished: win.strikes = 0
        }
    }

    // ---------- hold: stop the countdown while you read, resume after holdMs of no mouse/keys ----------
    Timer {
        interval: 250
        running: true
        repeat: true
        onTriggered: win.viewAt(win.front).runJavaScript(
            "window.__deskIdleMs ? window.__deskIdleMs() : -1",
            (idle) => {
                win.holding = Date.now() - win.touchedAt < win.holdMs
                              || (typeof idle === "number" && idle >= 0 && idle < win.holdMs)
            })
    }

    // ---------- clock ----------
    Timer {
        interval: 100
        running: !win.paused && !win.holding
        repeat: true
        onTriggered: {
            win.elapsed += interval
            if (win.queued < 0 && win.elapsed >= win.rotateMs - win.preloadMs) win.preload(win.nextHealthy(win.index, 1))
            if (win.elapsed >= win.rotateMs) win.go(win.queued >= 0 ? win.queued : win.nextHealthy(win.index, 1), 1)
        }
    }

    Shortcut { sequence: "Right"; onActivated: win.go(win.nextHealthy(win.index, 1), 1) }
    Shortcut { sequence: "Left";  onActivated: win.go(win.nextHealthy(win.index, -1), -1) }
    Shortcut { sequence: "Space"; onActivated: { win.paused = !win.paused; hud.changed() } }
    Shortcut { sequence: "R";     onActivated: win.load(win.viewAt(win.front), win.index) }
    Shortcut { sequence: "X";     onActivated: win.strike() }
    Shortcut { sequence: "U";     onActivated: win.unzap() }
}
