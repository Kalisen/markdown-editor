(() => {
  const root = document.getElementById('content');
  const callbacks = [];
  const host = window.chrome && window.chrome.webview;
  const post = (msg) => host && host.postMessage(msg);

  // Serialized form of each top-level node currently in `root`, as last rendered by the host.
  // Plugins may mutate the inside of these nodes but must not add/remove top-level nodes.
  let blocks = [];

  const keyOf = (node) => node.nodeType === Node.ELEMENT_NODE
    ? node.outerHTML
    : '#' + node.nodeType + ':' + node.textContent;

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
    const anchor = current[endOld] || null;
    for (let i = start; i < endOld; i++) current[i].remove();
    const fragment = document.createDocumentFragment();
    for (let i = start; i < endNew; i++) fragment.appendChild(next[i]);
    root.insertBefore(fragment, anchor);
    blocks = keys;
  }

  async function update(html) {
    patch(html);
    for (const cb of callbacks) {
      try { await cb(root); } catch (e) { console.error('mdeditor plugin callback failed', e); }
    }
  }

  function scrollToRatio(ratio) {
    const max = document.documentElement.scrollHeight - window.innerHeight;
    window.scrollTo(0, Math.max(0, max) * ratio);
  }

  document.addEventListener('click', (e) => {
    const a = e.target.closest && e.target.closest('a[href]');
    if (!a) return;
    const href = a.getAttribute('href');
    e.preventDefault();
    if (href.startsWith('#')) {
      // In-page anchors (headings, footnotes) scroll within the preview; no navigation happens.
      const target = document.getElementById(decodeURIComponent(href.slice(1)));
      if (target) target.scrollIntoView({ block: 'start' });
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
        else if (m && m.type === 'scroll') scrollToRatio(m.ratio);
      });
    }
    post({ type: 'ready' });
  });
})();
