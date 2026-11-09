// Adds a GitHub-style link icon before each heading that has an id (idempotent: headings kept between
// incremental updates already have one).
(() => {
  const ANCHOR_CLASS = 'heading-anchor';
  const SVG_NS = 'http://www.w3.org/2000/svg';
  // Octicon "link" (MIT, GitHub).
  const LINK_PATH = 'm7.775 3.275 1.25-1.25a3.5 3.5 0 1 1 4.95 4.95l-2.5 2.5a3.5 3.5 0 0 1-4.95 0 .751.751 0 0 1 .018-1.042.751.751 0 0 1 1.042-.018 1.998 1.998 0 0 0 2.83 0l2.5-2.5a2.002 2.002 0 0 0-2.83-2.83l-1.25 1.25a.751.751 0 0 1-1.042-.018.751.751 0 0 1-.018-1.042Zm-4.69 9.64a1.998 1.998 0 0 0 2.83 0l1.25-1.25a.751.751 0 0 1 1.042.018.751.751 0 0 1 .018 1.042l-1.25 1.25a3.5 3.5 0 1 1-4.95-4.95l2.5-2.5a3.5 3.5 0 0 1 4.95 0 .751.751 0 0 1-.018 1.042.751.751 0 0 1-1.042.018 1.998 1.998 0 0 0-2.83 0l-2.5 2.5a1.998 1.998 0 0 0 0 2.83Z';

  function icon() {
    const svg = document.createElementNS(SVG_NS, 'svg');
    svg.setAttribute('viewBox', '0 0 16 16');
    svg.setAttribute('width', '16');
    svg.setAttribute('height', '16');
    svg.setAttribute('aria-hidden', 'true');
    const path = document.createElementNS(SVG_NS, 'path');
    path.setAttribute('d', LINK_PATH);
    svg.appendChild(path);
    return svg;
  }

  window.mdeditor.onRender((root) => {
    for (const heading of root.querySelectorAll('h1[id], h2[id], h3[id], h4[id], h5[id], h6[id]')) {
      if (heading.querySelector(':scope > .' + ANCHOR_CLASS)) continue;
      const anchor = document.createElement('a');
      anchor.className = ANCHOR_CLASS;
      anchor.href = '#' + encodeURIComponent(heading.id);
      anchor.setAttribute('aria-label', 'Link to this section');
      anchor.appendChild(icon());
      heading.prepend(anchor);
    }
  });
})();
