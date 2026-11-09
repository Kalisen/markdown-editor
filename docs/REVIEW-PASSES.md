# Review passes

Each pass filed its findings as GitHub issues and fixed them in one pull request.

## Bug hunt (PR [#28](https://github.com/Kalisen/markdown-editor/pull/28))

| Issue | Finding | Fix |
|---|---|---|
| [#23](https://github.com/Kalisen/markdown-editor/issues/23) | Huge image size hint (`"=99999999999x"`) overflowed `int.Parse` and crashed rendering | Size hints bounded to 5 digits |
| [#24](https://github.com/Kalisen/markdown-editor/issues/24) | Relative links opened the browser on internal virtual hosts | `PreviewLinkPolicy`: Markdown links open in the editor, internal hosts ignored |
| [#25](https://github.com/Kalisen/markdown-editor/issues/25) | Unreadable plugin folder aborted startup | Listing errors reported as plugin failures |
| [#26](https://github.com/Kalisen/markdown-editor/issues/26) | Missing WebView2 runtime crashed the app | Failure reported in the status bar; editor stays usable |
| [#27](https://github.com/Kalisen/markdown-editor/issues/27) | Malformed preview message crashed the host | `PreviewMessages.TryParse` ignores anything malformed |

## Security assessment (PR [#35](https://github.com/Kalisen/markdown-editor/pull/35))

| Issue | Finding | Fix |
|---|---|---|
| [#29](https://github.com/Kalisen/markdown-editor/issues/29) | Script in Markdown raw HTML (`onerror`, `onload`) executed in the preview | Strict CSP, no inline script |
| [#30](https://github.com/Kalisen/markdown-editor/issues/30) | Preview could navigate away from its shell | Non-shell navigations cancelled |
| [#31](https://github.com/Kalisen/markdown-editor/issues/31) | DevTools/autofill/password saving enabled in Release | Disabled in Release |
| [#32](https://github.com/Kalisen/markdown-editor/issues/32) | Web messages accepted from any origin | Only the shell URL is accepted |
| [#33](https://github.com/Kalisen/markdown-editor/issues/33) | Plugin trust model undocumented | README security model |

Accepted risk: remote https images (assumption [#34](https://github.com/Kalisen/markdown-editor/issues/34)).

## Scalability and memory (PR [#41](https://github.com/Kalisen/markdown-editor/pull/41))

| Issue | Finding | Fix |
|---|---|---|
| [#36](https://github.com/Kalisen/markdown-editor/issues/36) | Whole preview DOM rebuilt on each update | Block-level incremental patching |
| [#37](https://github.com/Kalisen/markdown-editor/issues/37) | Off-screen content laid out and painted | `content-visibility: auto` |
| [#38](https://github.com/Kalisen/markdown-editor/issues/38) | Full text copied per keystroke; saved copy kept | Lazy text sync; saved state as hash |
| [#39](https://github.com/Kalisen/markdown-editor/issues/39) | Rendering on UI thread; JSON copy of HTML | `BackgroundRenderer`; string messages |
| [#40](https://github.com/Kalisen/markdown-editor/issues/40) | Background memory, unbounded caches, scroll spam | Low memory target when inactive, bounded caches, undo limit, scroll de-dupe, GC conserve |

Results are in the README "Performance and memory" section.
