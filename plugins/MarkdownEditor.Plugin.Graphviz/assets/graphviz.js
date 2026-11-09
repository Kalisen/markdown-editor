// Draws ```dot / ```graphviz blocks with Viz.js after each preview update. Blocks kept by the incremental
// update are already drawn (data-graphviz-rendered) and skipped. The diagram replaces the code inside the
// <pre>, so top-level nodes are unchanged.
(() => {
  const SELECTOR = 'pre > code.language-dot, pre > code.language-graphviz';
  const RENDERED = 'graphvizRendered';
  const COLORS = { light: '#1f2328', dark: '#e6edf3' };

  const api = window.mdeditor;
  const ink = api.theme === 'dark' ? COLORS.dark : COLORS.light;
  // Default colours follow the preview theme; explicit colours in the DOT source still win.
  const options = {
    graphAttributes: { bgcolor: 'transparent', color: ink, fontcolor: ink },
    nodeAttributes: { color: ink, fontcolor: ink },
    edgeAttributes: { color: ink, fontcolor: ink },
  };
  const vizReady = window.Viz.instance();

  function showError(pre, source, message) {
    const box = document.createElement('div');
    box.className = 'graphviz-error';
    const title = document.createElement('strong');
    title.textContent = 'Graphviz error';
    const detail = document.createElement('pre');
    detail.textContent = message;
    const code = document.createElement('pre');
    code.textContent = source;
    box.append(title, detail, code);
    pre.replaceChildren(box);
  }

  api.onRender(async (root) => {
    const blocks = Array.from(root.querySelectorAll(SELECTOR));
    if (blocks.length === 0) return;
    const viz = await vizReady;
    for (const code of blocks) {
      const pre = code.parentElement;
      if (!pre || !pre.isConnected || pre.dataset[RENDERED]) continue;
      const source = code.textContent;
      pre.dataset[RENDERED] = '1';
      pre.classList.add('graphviz-diagram');
      const result = viz.render(source, { ...options, format: 'svg' });
      if (result.status === 'success') {
        pre.innerHTML = result.output;
      } else {
        showError(pre, source, result.errors.map((e) => e.message).join('\n'));
      }
    }
  });
})();
