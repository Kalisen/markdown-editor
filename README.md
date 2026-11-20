# Markdown Editor

A desktop Markdown editor/viewer with a live split preview, compliant with
[CommonMark 0.31.2](https://spec.commonmark.org/0.31.2/), and extensible through plugins.
Licensed under the [MIT License](LICENSE).

| Platform | App | Stack | Details |
|---|---|---|---|
| Windows 11 | [Releases](https://github.com/Kalisen/markdown-editor/releases) | C# / .NET 10, WPF, AvalonEdit, WebView2, Markdig | [windows/README.md](windows/README.md) |
| macOS | Built locally | Swift, AppKit, WKWebView, own CommonMark engine | [macos/README.md](macos/README.md) |

## Repository layout

| Folder | Content |
|---|---|
| `windows/` | The Windows app: solution, sources, plugins, tests, installer, tools. |
| `macos/` | The macOS app: Swift package, tests, app bundle scripts. |
| `shared/preview/` | Preview page script and stylesheet (`preview.js`, `preview.css`) loaded by both apps. |
| `shared/plugins/<plugin-id>/assets/` | Plugin preview assets: stylesheets, scripts and the vendored Mermaid, KaTeX, highlight.js and Viz.js bundles. |
| `shared/spec/` | CommonMark 0.31.2 and GFM 0.29 spec examples run as tests by both apps. |
| `shared/icon/` | App icon source (`app-icon.svg`). |
| `samples/` | Sample documents. |
| `docs/` | [Assumptions](docs/ASSUMPTIONS.md) and [review passes](docs/REVIEW-PASSES.md). |

A change under `shared/` affects both apps: both CI workflows run for it.

## Project tracking

Stories, issues and assumptions are tracked in [GitHub Issues](https://github.com/Kalisen/markdown-editor/issues)
(label `Assumption` for decisions made without review, also listed in [docs/ASSUMPTIONS.md](docs/ASSUMPTIONS.md)).
