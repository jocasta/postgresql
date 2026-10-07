/* ── Mermaid diagram viewer ──
 * Click any Mermaid diagram to open it full screen, with an "Open in new tab" button.
 *
 * Zensical renders each diagram into a *closed* shadow root on a div.mermaid host, so the
 * SVG can't normally be reached from page scripts. We wrap attachShadow to keep a reference
 * to those roots; rendering itself is unchanged. Zensical renders asynchronously (after
 * loading Mermaid from the CDN), so this script runs before any diagram is attached.
 */
(function () {
  const roots = new WeakMap();
  const attachShadow = Element.prototype.attachShadow;
  Element.prototype.attachShadow = function (init) {
    const root = attachShadow.call(this, init);
    if (this.classList && this.classList.contains("mermaid")) roots.set(this, root);
    return root;
  };

  let overlay, stage;

  function buildOverlay() {
    overlay = document.createElement("div");
    overlay.className = "mermaid-viewer";
    overlay.setAttribute("role", "dialog");
    overlay.setAttribute("aria-modal", "true");
    overlay.innerHTML =
      '<div class="mermaid-viewer__bar">' +
      '<button type="button" data-action="tab" title="Open the diagram on its own in a new tab">Open in new tab</button>' +
      '<button type="button" data-action="close" title="Close (Esc)" aria-label="Close">✕</button>' +
      "</div>" +
      '<div class="mermaid-viewer__stage"></div>';
    stage = overlay.querySelector(".mermaid-viewer__stage");
    overlay.addEventListener("click", (e) => {
      const action = e.target.closest("[data-action]")?.dataset.action;
      if (action === "close" || e.target === overlay || e.target === stage) close();
      if (action === "tab") openInTab();
    });
    document.body.appendChild(overlay);
  }

  function open(host) {
    const svg = roots.get(host)?.querySelector("svg");
    if (!svg) return;
    if (!overlay) buildOverlay();
    const clone = svg.cloneNode(true);
    clone.removeAttribute("style");          // drop Mermaid's max-width so it can grow
    clone.setAttribute("width", "100%");
    clone.setAttribute("height", "100%");
    stage.replaceChildren(clone);
    overlay._host = host;
    overlay.classList.add("is-open");
    document.documentElement.classList.add("mermaid-viewer-open");
    overlay.querySelector('[data-action="close"]').focus();
  }

  function close() {
    if (!overlay) return;
    overlay.classList.remove("is-open");
    document.documentElement.classList.remove("mermaid-viewer-open");
    stage.replaceChildren();
  }

  // Standalone SVG for a new tab: resolve the theme's CSS variables (they only exist on the
  // wiki page) into concrete values, and size the SVG to its natural dimensions.
  function openInTab() {
    const host = overlay._host;
    const svg = roots.get(host)?.querySelector("svg");
    if (!svg) return;
    const clone = svg.cloneNode(true);
    const css = getComputedStyle(host);
    const names = new Set();
    clone.querySelectorAll("style").forEach((s) =>
      s.textContent.replace(/var\((--[\w-]+)/g, (_, n) => names.add(n))
    );
    const vars = [...names]
      .map((n) => `${n}: ${css.getPropertyValue(n).trim()};`)
      .join(" ");
    const bg = getComputedStyle(document.body).backgroundColor;
    const style = document.createElementNS("http://www.w3.org/2000/svg", "style");
    style.textContent = `svg { ${vars} background: ${bg}; font-family: ${css.fontFamily}; }`;
    clone.insertBefore(style, clone.firstChild);

    const vb = clone.viewBox && clone.viewBox.baseVal;
    clone.removeAttribute("style");
    if (vb && vb.width) {
      clone.setAttribute("width", vb.width);
      clone.setAttribute("height", vb.height);
    }
    clone.setAttribute("xmlns", "http://www.w3.org/2000/svg");
    const blob = new Blob([new XMLSerializer().serializeToString(clone)], { type: "image/svg+xml" });
    window.open(URL.createObjectURL(blob), "_blank");
  }

  // Event delegation survives Zensical's instant navigation (pages are swapped without reload).
  document.addEventListener("click", (e) => {
    if (overlay && overlay.contains(e.target)) return;
    const host = e.target.closest && e.target.closest("div.mermaid");
    if (host && roots.has(host)) open(host);
  });
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && overlay?.classList.contains("is-open")) close();
  });
})();
