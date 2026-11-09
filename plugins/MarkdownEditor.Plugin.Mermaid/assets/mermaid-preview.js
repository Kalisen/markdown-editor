// Renders .mermaid-diagram blocks after each preview update.
// SVGs are cached by (theme, source) so unchanged diagrams are not re-rendered while typing.
(() => {
  const DIAGRAM_SELECTOR = '.mermaid-diagram';
  const SOURCE_SELECTOR = '.mermaid-source';
  const ERROR_CLASS = 'mermaid-error';
  const MAX_CACHE_ENTRIES = 100;

  const api = window.mdeditor;
  const theme = api.theme === 'dark' ? 'dark' : 'default';
  const cache = new Map();
  let counter = 0;

  window.mermaid.initialize({ startOnLoad: false, securityLevel: 'strict', theme });

  function remember(key, svg) {
    cache.set(key, svg);
    if (cache.size > MAX_CACHE_ENTRIES) cache.delete(cache.keys().next().value);
  }

  function showError(container, source, error) {
    const box = document.createElement('div');
    box.className = ERROR_CLASS;
    const title = document.createElement('strong');
    title.textContent = 'Mermaid syntax error';
    const message = document.createElement('pre');
    message.textContent = (error && error.message) || String(error);
    const code = document.createElement('pre');
    code.textContent = source;
    box.append(title, message, code);
    container.replaceChildren(box);
  }

  async function renderDiagram(container) {
    const sourceElement = container.querySelector(SOURCE_SELECTOR);
    if (!sourceElement) return;
    const source = sourceElement.textContent;
    const key = theme + '\u0000' + source;
    let svg = cache.get(key);
    if (svg === undefined) {
      try {
        const result = await window.mermaid.render('mermaid-svg-' + (++counter), source);
        svg = result.svg;
        remember(key, svg);
      } catch (error) {
        // mermaid leaves its temporary error element behind; remove it.
        document.getElementById('dmermaid-svg-' + counter)?.remove();
        showError(container, source, error);
        return;
      }
    }
    container.innerHTML = svg;
  }

  api.onRender(async (root) => {
    for (const container of root.querySelectorAll(DIAGRAM_SELECTOR)) {
      await renderDiagram(container);
    }
  });
})();
