// Typesets math after each preview update: span.math (inline), div.math ($$ blocks) and ```math fences.
// Elements kept by the incremental update are already typeset and skipped.
(() => {
  const RENDERED = 'mathRendered';
  const INLINE = /^\\\(([\s\S]*)\\\)$/;
  const DISPLAY = /^\\\[([\s\S]*)\\\]$/;

  const katex = window.katex;

  function typeset(element, tex, displayMode) {
    // throwOnError: false renders invalid input in red with the error as a tooltip, like GitHub.
    katex.render(tex, element, { displayMode, throwOnError: false, output: 'htmlAndMathml' });
    element.dataset[RENDERED] = '1';
  }

  window.mdeditor.onRender((root) => {
    for (const el of root.querySelectorAll('span.math, div.math')) {
      if (el.dataset[RENDERED]) continue;
      const text = el.textContent.trim();
      const display = el.tagName === 'DIV';
      const match = (display ? DISPLAY : INLINE).exec(text);
      typeset(el, match ? match[1].trim() : text, display);
    }
    for (const code of root.querySelectorAll('pre > code.language-math')) {
      const pre = code.parentElement;
      if (pre.dataset[RENDERED]) continue;
      pre.classList.add('math-fence');
      typeset(pre, code.textContent, true);
    }
  });
})();
