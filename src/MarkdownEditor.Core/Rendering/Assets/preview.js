(() => {
  const root = document.getElementById('content');
  const callbacks = [];
  const host = window.chrome && window.chrome.webview;
  const post = (msg) => host && host.postMessage(msg);

  // Serialized form of each top-level node currently in `root`, as last rendered by the host.
  // Plugins may mutate the inside of these nodes but must not add/remove top-level nodes.
  let blocks = [];

  // Source line attributes written by the host (SourceLineAnnotator). They are left out of the block keys:
  // inserting a line shifts the numbers of every following block, which must not force them to re-render.
  const LINE = 'data-line';
  const LINE_END = 'data-line-end';
  const LINE_ATTRIBUTES = / data-line(?:-end)?="\d+"/g;

  const keyOf = (node) => node.nodeType === Node.ELEMENT_NODE
    ? node.outerHTML.replace(LINE_ATTRIBUTES, '')
    : '#' + node.nodeType + ':' + node.textContent;

  // A kept block may have moved in the source: shift its line numbers (and its descendants') to the new ones.
  function moveLines(kept, fresh) {
    if (kept.nodeType !== Node.ELEMENT_NODE || !fresh.hasAttribute(LINE) || !kept.hasAttribute(LINE)) return;
    const delta = Number(fresh.getAttribute(LINE)) - Number(kept.getAttribute(LINE));
    if (delta === 0) return;
    for (const el of [kept, ...kept.querySelectorAll('[' + LINE + ']')]) {
      el.setAttribute(LINE, Number(el.getAttribute(LINE)) + delta);
      if (el.hasAttribute(LINE_END)) el.setAttribute(LINE_END, Number(el.getAttribute(LINE_END)) + delta);
    }
  }

  // Replaces only the range of top-level blocks that changed since the previous render, so unchanged
  // content (and plugin output such as rendered diagrams) is kept and the DOM is not rebuilt.
  function patch(html) {
    const template = document.createElement('template');
    template.innerHTML = html;
    const next = Array.from(template.content.childNodes);
    const keys = next.map(keyOf);

    let start = 0;
    while (start < blocks.length && start < keys.length && blocks[start] === keys[start]) start++;
    let endOld = blocks.length;
    let endNew = keys.length;
    while (endOld > start && endNew > start && blocks[endOld - 1] === keys[endNew - 1]) { endOld--; endNew--; }

    const current = Array.from(root.childNodes);
    for (let i = 0; i < start; i++) moveLines(current[i], next[i]);
    for (let i = endOld; i < current.length; i++) moveLines(current[i], next[i - endOld + endNew]);
    const anchor = current[endOld] || null;
    for (let i = start; i < endOld; i++) current[i].remove();
    const fragment = document.createDocumentFragment();
    for (let i = start; i < endNew; i++) fragment.appendChild(next[i]);
    root.insertBefore(fragment, anchor);
    blocks = keys;
  }

  async function update(html) {
    patch(html);
    layoutChanged();
    for (const cb of callbacks) {
      try { await cb(root); } catch (e) { console.error('mdeditor plugin callback failed', e); }
    }
  }

  // ---- Scroll synchronization ----
  // The panel receiving user input drives; the other follows so that both show the same source line at the
  // top. Positions are mapped through points (source line, page y): each annotated block contributes its
  // top (at its first line) and its bottom (after its last line), and positions in between are interpolated.
  // A one-line image thus spans its whole height in the preview, and blank lines span the gap between blocks.

  let driving = false;      // true while user input targets the preview
  let anchorLine = 0;       // fractional 0-based source line currently shown at the top
  let map = null;           // { lines: number[], ys: number[] }, rebuilt lazily after layout changes
  let scrollQueued = false;

  function buildMap() {
    const scrollY = window.scrollY;
    const points = [[0, 0]];
    for (const el of root.querySelectorAll('[' + LINE + ']')) {
      const box = el.getBoundingClientRect();
      if (box.width === 0 && box.height === 0) continue; // not displayed
      const first = Number(el.getAttribute(LINE));
      const last = Number(el.getAttribute(LINE_END) || first);
      points.push([first, box.top + scrollY], [last + 1, box.bottom + scrollY]);
    }
    points.sort((a, b) => a[0] - b[0] || a[1] - b[1]);
    return monotonic(points);
  }

  // Keeps the longest run of points whose y never decreases, dropping out-of-order content (e.g. footnotes
  // rendered at the end of the page but defined earlier in the source).
  function monotonic(points) {
    const tails = [];   // index of the smallest last point of a run of each length
    const previous = new Array(points.length);
    for (let i = 0; i < points.length; i++) {
      let lo = 0, hi = tails.length;
      while (lo < hi) {
        const mid = (lo + hi) >> 1;
        if (points[tails[mid]][1] <= points[i][1]) lo = mid + 1; else hi = mid;
      }
      previous[i] = lo > 0 ? tails[lo - 1] : -1;
      tails[lo] = i;
    }
    const lines = [], ys = [];
    for (let i = tails.length ? tails[tails.length - 1] : -1; i >= 0; i = previous[i]) {
      lines.push(points[i][0]);
      ys.push(points[i][1]);
    }
    return { lines: lines.reverse(), ys: ys.reverse() };
  }

  // Index of the last value <= target in an ascending array, or -1.
  function lastAtMost(values, target) {
    let lo = 0, hi = values.length;
    while (lo < hi) {
      const mid = (lo + hi) >> 1;
      if (values[mid] <= target) lo = mid + 1; else hi = mid;
    }
    return lo - 1;
  }

  // Maps along `from` to `to`: from the last point at or before `value`, toward the next one.
  function interpolate(from, to, value) {
    const i = Math.max(0, lastAtMost(from, value));
    if (i >= from.length - 1 || from[i + 1] === from[i]) return to[i];
    return to[i] + (to[i + 1] - to[i]) * (value - from[i]) / (from[i + 1] - from[i]);
  }

  const currentMap = () => map || (map = buildMap());
  const lineToY = (line) => interpolate(currentMap().lines, currentMap().ys, line);
  const yToLine = (y) => interpolate(currentMap().ys, currentMap().lines, y);

  function showLine(line) {
    anchorLine = line;
    window.scrollTo(0, lineToY(line));
  }

  // Content was re-rendered or resized (images loaded, diagrams drawn, window resized): keep the anchor line on top.
  function layoutChanged() {
    map = null;
    showLine(anchorLine);
  }

  function startDriving() { driving = true; }
  for (const type of ['wheel', 'keydown', 'pointerdown', 'touchstart']) {
    window.addEventListener(type, startDriving, { capture: true, passive: true });
  }

  window.addEventListener('scroll', () => {
    if (!driving || scrollQueued) return;
    scrollQueued = true;
    requestAnimationFrame(() => {
      scrollQueued = false;
      if (!driving) return;
      anchorLine = yToLine(window.scrollY);
      post({ type: 'scrolled', line: anchorLine });
    });
  }, { passive: true });

  new ResizeObserver(layoutChanged).observe(root);

  document.addEventListener('click', (e) => {
    const a = e.target.closest && e.target.closest('a[href]');
    if (!a) return;
    const href = a.getAttribute('href');
    e.preventDefault();
    if (href.startsWith('#')) {
      // In-page anchors (headings, footnotes) scroll within the preview; no navigation happens.
      const target = document.getElementById(decodeURIComponent(href.slice(1)));
      if (target) {
        startDriving();
        target.scrollIntoView({ block: 'start' });
      }
      return;
    }
    post({ type: 'open-link', href });
  });

  window.mdeditor = {
    theme: document.documentElement.dataset.theme,
    onRender(cb) { callbacks.push(cb); },
  };

  // Plugin scripts are loaded synchronously after this file; DOMContentLoaded fires once they have all
  // registered their callbacks. (No inline script: the page CSP forbids it.)
  document.addEventListener('DOMContentLoaded', () => {
    if (host) {
      host.addEventListener('message', (e) => {
        const m = e.data;
        // Rendered HTML arrives as a plain string (no JSON envelope copy); control messages as objects.
        if (typeof m === 'string') update(m);
        else if (m && m.type === 'scroll-to-line') {
          driving = false;
          showLine(m.line);
        }
      });
    }
    post({ type: 'ready' });
  });
})();
