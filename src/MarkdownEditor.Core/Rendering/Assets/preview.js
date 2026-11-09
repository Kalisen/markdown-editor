(() => {
  const root = document.getElementById('content');
  const callbacks = [];
  const host = window.chrome && window.chrome.webview;
  const post = (msg) => host && host.postMessage(msg);

  async function update(html) {
    root.innerHTML = html;
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
    if (href.startsWith('#')) return;
    e.preventDefault();
    post({ type: 'open-link', href });
  });

  window.mdeditor = {
    theme: document.documentElement.dataset.theme,
    onRender(cb) { callbacks.push(cb); },
    _ready() {
      if (host) {
        host.addEventListener('message', (e) => {
          const m = e.data;
          if (m.type === 'render') update(m.html);
          else if (m.type === 'scroll') scrollToRatio(m.ratio);
        });
      }
      post({ type: 'ready' });
    },
  };
})();
