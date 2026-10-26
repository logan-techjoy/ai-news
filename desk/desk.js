// Injected into every page the AI News Desk shows.
// 1. Accepts cookie banners and removes full-screen popups for the first ~20s.
// 2. Exposes __deskStart(delayMs) / __deskStop() so the desk can start scrolling
//    when the page comes on screen: half-screen glides with reading pauses between.
//    It doesn't scroll at all while the desk holds the countdown (__deskHold).
// 3. Exposes __deskIdleMs() (time since you last moved, scrolled, clicked or typed on the
//    page) so the desk can hold its countdown while you're reading.
(() => {
  if (window.__deskInstalled) return;
  window.__deskInstalled = true;

  const ACCEPT = /^(accept( all)?( cookies)?|allow( all)?( cookies)?|i agree|agree( (&|and) close)?|i accept|got it|ok(ay)?|continue|consent|yes,? i agree|accept & close|accept and continue)$/i;
  const CLOSE = /^(close|dismiss|no,? thanks|not now|maybe later|skip|×|✕|x)$/i;

  const label = (el) => (el.innerText || el.value || el.getAttribute("aria-label") || el.title || "").trim().replace(/\s+/g, " ");

  function clickConsent(root) {
    for (const el of root.querySelectorAll('button, [role="button"], a, input[type="button"], input[type="submit"]')) {
      const text = label(el);
      if (text && text.length < 40 && ACCEPT.test(text) && el.offsetParent !== null) {
        el.click();
        return true;
      }
    }
    return false;
  }

  function coversViewport(el) {
    const s = getComputedStyle(el);
    if (s.position !== "fixed" && s.position !== "sticky") return false;
    if (s.display === "none" || s.visibility === "hidden") return false;
    const r = el.getBoundingClientRect();
    return r.width * r.height > innerWidth * innerHeight * 0.35;
  }

  function removeOverlays() {
    // Close buttons inside dialogs first, then strip anything fixed that blankets the page
    for (const dialog of document.querySelectorAll('[role="dialog"], [aria-modal="true"], dialog[open]')) {
      const close = [...dialog.querySelectorAll('button, [role="button"], a')].find((b) => CLOSE.test(label(b)) || /close|dismiss/i.test(b.getAttribute("aria-label") || ""));
      if (close) close.click();
    }
    for (const el of document.querySelectorAll("body *")) {
      if (el.childElementCount > 400) continue; // never the page wrapper itself
      if (coversViewport(el) && !el.querySelector("article, main")) el.remove();
    }
    // Undo the scroll lock popups leave behind, without touching pages that never had one
    for (const node of [document.documentElement, document.body]) {
      if (!node) continue;
      const s = getComputedStyle(node);
      if (s.overflowY === "hidden") node.style.setProperty("overflow", "visible", "important");
      if (s.position === "fixed") node.style.setProperty("position", "static", "important");
    }
  }

  // The desk's navy window shows through pages that rely on the browser's default
  // white canvas (TechCrunch, HN), leaving dark text on navy. Restore the white.
  function paintCanvas() {
    if (window.top !== window || !document.body) return;
    const clear = (el) => /rgba\(0, 0, 0, 0\)|transparent/.test(getComputedStyle(el).backgroundColor);
    if (clear(document.documentElement) && clear(document.body)) {
      document.documentElement.style.setProperty("background-color", "#fff");
    }
  }

  function tidy() {
    paintCanvas();
    clickConsent(document);
    if (window.top === window) removeOverlays();
  }

  // Banners often arrive late; keep tidying for a while, and whenever the DOM changes
  let tidyUntil = Date.now() + 20000;
  const interval = setInterval(() => {
    if (Date.now() > tidyUntil) return clearInterval(interval);
    tidy();
  }, 1000);
  new MutationObserver(() => { if (Date.now() < tidyUntil) tidy(); })
    .observe(document.documentElement, { childList: true, subtree: true });
  tidy();

  // ---------- activity: the desk holds its countdown while you read or move the page ----------
  // Not "scroll": auto-scroll fires it too. Chromium also sends fake mousemoves while the page
  // scrolls under a still cursor, so a mousemove only counts if the pointer actually moved.
  const ACTIVITY = ["mousemove", "mousedown", "wheel", "keydown", "touchstart", "touchmove"];
  let pointerX = null, pointerY = null;
  const isActivity = (e) => {
    if (e.type !== "mousemove") return true;
    const moved = e.screenX !== pointerX || e.screenY !== pointerY;
    pointerX = e.screenX;
    pointerY = e.screenY;
    return moved;
  };

  if (window.top !== window) {
    // Frames forward their activity to the top page, which the desk asks
    let sent = 0;
    const forward = (e) => {
      if (!isActivity(e) || Date.now() - sent < 250) return;
      sent = Date.now();
      try { window.top.postMessage("__deskActive", "*"); } catch (err) {}
    };
    for (const type of ACTIVITY) addEventListener(type, forward, { passive: true, capture: true });
    return;
  }

  let lastActive = -1e9;
  const touched = () => { lastActive = performance.now(); };
  for (const type of ACTIVITY) addEventListener(type, (e) => { if (isActivity(e)) touched(); }, { passive: true, capture: true });
  addEventListener("message", (e) => { if (e.data === "__deskActive") touched(); });
  window.__deskIdleMs = () => Math.round(performance.now() - lastActive);

  // ---------- auto-scroll: medium-speed glides with reading pauses ----------
  const GLIDE_SCREENS = 0.5;  // each glide moves this fraction of the visible height...
  const GLIDE_EXTRA_PX = 100; // ...plus this many pixels
  const GLIDE_MS = 1400;      // duration of one glide (eased in and out)
  const PAUSE_MS = 2800;      // rest between glides
  let timer = null, frame = null, last = 0, pausedUntil = 0, carry = 0, held = false;
  let glide = null;           // { start, distance, done } while moving

  // null means the window itself scrolls (works in quirks mode too)
  function scroller() {
    const page = document.documentElement.scrollHeight - innerHeight;
    if (page > 50) return null;
    // Some sites scroll an inner container instead of the page
    let best = null, extra = 0;
    for (const el of document.querySelectorAll("main, div, section")) {
      const s = getComputedStyle(el);
      if (!/(auto|scroll)/.test(s.overflowY)) continue;
      const room = el.scrollHeight - el.clientHeight;
      if (room > extra) { best = el; extra = room; }
    }
    return best;
  }

  function scrollBy(px) {
    const el = scroller();
    if (el) el.scrollTop += px;
    else window.scrollBy(0, px);
  }

  const ease = (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2);

  function step(now) {
    frame = requestAnimationFrame(step);
    last = now;
    // Brake on our own activity at once; the desk's hold arrives by a 250 ms poll
    if (held || now < pausedUntil || now - lastActive < 1000) {
      glide = null;
      return;
    }
    if (!glide) {
      const el = scroller();
      const view = el ? el.clientHeight : innerHeight;
      glide = { start: now, distance: view * GLIDE_SCREENS + GLIDE_EXTRA_PX, done: 0 };
    }
    const t = Math.min(1, (now - glide.start) / GLIDE_MS);
    carry += ease(t) * glide.distance - glide.done;
    glide.done = ease(t) * glide.distance;
    const whole = Math.trunc(carry);
    if (whole) {
      scrollBy(whole);
      carry -= whole;
    }
    if (t >= 1) {
      glide = null;
      pausedUntil = now + PAUSE_MS;
    }
  }

  window.__deskStop = () => {
    clearTimeout(timer);
    cancelAnimationFrame(frame);
    timer = frame = null;
  };

  window.__deskStart = (delay = 2500) => {
    window.__deskStop();
    tidyUntil = Math.max(tidyUntil, Date.now() + 15000);
    const el = scroller();
    if (el) el.scrollTop = 0;
    else window.scrollTo(0, 0);
    glide = null;
    pausedUntil = 0;
    timer = setTimeout(() => {
      last = performance.now();
      frame = requestAnimationFrame(step);
    }, delay);
  };

  // The desk holds while you read; on release, rest one pause before the next glide
  window.__deskHold = (on) => {
    if (held && !on) pausedUntil = performance.now() + PAUSE_MS;
    held = on;
  };
})();
