// Highlights <pre><code class="language-x"> blocks after each preview update. Blocks kept by the
// incremental update are already highlighted (data-highlighted) and skipped.
(() => {
  const VENDOR = 'vendor/highlightjs-11.12.0/';
  const THEMES = { light: 'github.min.css', dark: 'github-dark.min.css' };
  // Rendered by other plugins (e.g. math) or not code.
  const SKIPPED_LANGUAGES = new Set(['math', 'mermaid', 'dot', 'graphviz']);

  const api = window.mdeditor;
  const hljs = window.hljs;
  hljs.configure({ ignoreUnescapedHTML: true });

  const assetsBase = document.currentScript.src.replace(/[^/]*$/, '');
  const theme = document.createElement('link');
  theme.rel = 'stylesheet';
  theme.href = assetsBase + VENDOR + (api.theme === 'dark' ? THEMES.dark : THEMES.light);
  document.head.appendChild(theme);

  function languageOf(code) {
    for (const cls of code.classList) if (cls.startsWith('language-')) return cls.slice('language-'.length);
    return null;
  }

  api.onRender((root) => {
    for (const code of root.querySelectorAll('pre > code[class*="language-"]:not([data-highlighted])')) {
      const language = languageOf(code);
      if (!language || SKIPPED_LANGUAGES.has(language) || !hljs.getLanguage(language)) continue;
      hljs.highlightElement(code);
    }
  });
})();
