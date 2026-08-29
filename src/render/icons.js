// UTS :: render/icons — CUSTOM SVG ICON SET (zero emoji, zero deps).
// Every icon is hand-authored geometry on a 24×24 grid, stroked with
// currentColor so it inherits the text color. One source of truth: the
// demo injects this sprite and references it with <use href="#i-name">;
// tests guarantee the HTML never ships an emoji again.

export const ICONS = Object.freeze({
  eye: '<path d="M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6-10-6-10-6z"/><circle cx="12" cy="12" r="2.6"/>',
  scales: '<path d="M12 3v18M4 21h16"/><path d="M4 7h16M6 7l-3 6h6L6 7zm12 0l-3 6h6l-3-6z"/>',
  folder: '<path d="M3 6a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6z"/>',
  terminal: '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M7 9l3 3-3 3M12 15h5"/>',
  box: '<path d="M12 2l9 5v10l-9 5-9-5V7l9-5z"/><path d="M3 7l9 5 9-5M12 12v10"/>',
  gamepad: '<path d="M6 9h12a4 4 0 0 1 4 4l-1 5a2 2 0 0 1-3.6.8L15 16H9l-2.4 2.8A2 2 0 0 1 3 18l-1-5a4 4 0 0 1 4-4z"/><path d="M8 12v3M6.5 13.5h3"/><circle cx="16" cy="12.4" r="0.6"/><circle cx="18" cy="14.4" r="0.6"/>',
  palette: '<path d="M12 3a9 9 0 1 0 0 18h1.5a2.5 2.5 0 0 0 0-5H12a2 2 0 0 1 0-4h6a3 3 0 0 0 3-3c0-3.5-4-6-9-6z"/><circle cx="7.5" cy="10.5" r="0.7"/><circle cx="12" cy="7.5" r="0.7"/><circle cx="16.5" cy="10.5" r="0.7"/>',
  link: '<path d="M10 14a5 5 0 0 0 7.1 0l2.4-2.4a5 5 0 0 0-7.1-7.1L11 5.9"/><path d="M14 10a5 5 0 0 0-7.1 0l-2.4 2.4a5 5 0 0 0 7.1 7.1L13 18.1"/>',
  check: '<path d="M4 12.5l5.5 5.5L20 6.5"/>',
  cross: '<path d="M6 6l12 12M18 6L6 18"/>',
  forbid: '<circle cx="12" cy="12" r="9"/><path d="M5.8 5.8l12.4 12.4"/>',
  warn: '<path d="M12 3L2 21h20L12 3z"/><path d="M12 10v5M12 18.2v.1"/>',
  speaker: '<path d="M4 9v6h4l5 4V5L8 9H4z"/><path d="M16.5 8.5a5 5 0 0 1 0 7M19 6a8.5 8.5 0 0 1 0 12"/>',
  mute: '<path d="M4 9v6h4l5 4V5L8 9H4z"/><path d="M17 9l5 6M22 9l-5 6"/>',
  earth: '<circle cx="12" cy="12" r="9"/><path d="M3.5 9h5M15.5 3.5L13 8h5l-2.5 4.5M4 15.5h6l-2 5M13 20.5l2.5-4"/>',
  dawn: '<path d="M4 18h16M12 14a4 4 0 0 1 4 4H8a4 4 0 0 1 4-4zM12 3v4M5.6 7.6l2 2M18.4 7.6l-2 2"/>',
  island: '<path d="M3 18c2-1.6 4-1.6 6 0s4 1.6 6 0 4-1.6 6 0M12 14V8"/><path d="M12 8c-3 0-4.5-1.5-4.5-1.5S9 4 12 4s4.5 2.5 4.5 2.5S15 8 12 8z"/>',
  fire: '<path d="M12 3s5.5 4.6 5.5 10a5.5 5.5 0 0 1-11 0C6.5 8.5 9 7 9 7c0 2 1 3 2 3 0-3 .5-5.5 1-7z"/><path d="M12 21a3 3 0 0 1-3-3c0-1.8 3-4 3-4s3 2.2 3 4a3 3 0 0 1-3 3z"/>',
  temple: '<path d="M4 21h16M5 18h14M6 10v8M10 10v8M14 10v8M18 10v8M3 10h18L12 3 3 10z"/>',
  play: '<path d="M7 4.5v15l12-7.5-12-7.5z"/>',
  wand: '<path d="M4 20L15 9M13 4l1-2 1 2 2 1-2 1-1 2-1-2-2-1 2-1zM19 9l.7-1.4L21 7l-1.3-.6L19 5l-.7 1.4L17 7l1.3.6L19 9zM7 6l.6-1.2L9 4.2l-1.4-.6L7 2.4l-.6 1.2L5 4.2l1.4.6L7 6z"/>',
  radar: '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="4.5"/><path d="M12 12l6-6M12 3v2M21 12h-2"/>',
  drop: '<path d="M12 3s6 6.6 6 11a6 6 0 0 1-12 0c0-4.4 6-11 6-11z"/>',
  brush: '<path d="M20 4s-7 3-10 8c-1.4 2.4-1 5 1.5 6.5C14 20 17 19 18 16c1-2.6 2-12 2-12z"/><path d="M9 13c-2.5.5-4 2-4.5 4.5-.3 1.4.3 2.5 1.5 2.5s3-1 3.5-3"/>',
  gear: '<circle cx="12" cy="12" r="3.2"/><path d="M12 2.5v3M12 18.5v3M2.5 12h3M18.5 12h3M5.3 5.3l2.1 2.1M16.6 16.6l2.1 2.1M18.7 5.3l-2.1 2.1M7.4 16.6l-2.1 2.1"/>',
});

/** the complete sprite as an injectable <svg> block (symbols per icon) */
export function spriteSheet() {
  const symbols = Object.entries(ICONS)
    .map(([name, body]) => `<symbol id="i-${name}" viewBox="0 0 24 24">${body}</symbol>`)
    .join('');
  return `<svg xmlns="http://www.w3.org/2000/svg" style="display:none" aria-hidden="true">${symbols}</svg>`;
}

/** one icon as inline svg (for places that cannot <use>) */
export function svgIcon(name, { cls = 'ic' } = {}) {
  if (!ICONS[name]) throw new Error(`ícone desconhecido: "${name}" (tenho: ${Object.keys(ICONS).join(', ')})`);
  return `<svg class="${cls}" viewBox="0 0 24 24" aria-hidden="true">${ICONS[name]}</svg>`;
}
