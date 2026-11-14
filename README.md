# Markdown Editor

A Windows 11 desktop Markdown editor/viewer with a live split preview, compliant with
[CommonMark 0.31.2](https://spec.commonmark.org/0.31.2/), and extensible through plugins.

Download the installer from [Releases](https://github.com/Kalisen/markdown-editor/releases).
See [Code signing](#code-signing) and [Privacy](#privacy). Licensed under the [MIT License](LICENSE).

## Features

- Split view: syntax-highlighted source (AvalonEdit) and live HTML preview (WebView2), debounced at 300 ms,
  rendered on a background thread with incremental preview updates and scroll sync.
- Links in the preview: web links open in the browser, links to other Markdown files open in the editor.
- New / Open / Save / Save As (Ctrl+N / Ctrl+O / Ctrl+S / Ctrl+Shift+S), drag & drop, open from command line.
- Detects when another program changes the open file and offers to reload it; File > Reload File (F5) reloads on demand.
- Unsaved-changes guard on New, Open and Close.
- File > Export to HTML (single file, stylesheets inlined, no scripts) or PDF (light theme), including
  diagrams, math and highlighting as rendered.
- Strict CommonMark core; all 652 spec examples are run as unit tests.
- Plugins loaded from `plugins/<name>/MarkdownEditor.Plugin.*.dll` (Help > Plugins lists them and any load failures).
- The status bar lists the extensions used by the open document (hover for all loaded plugins).
- Bundled plugins:
  - **Pictures** (`images`) — relative image paths and size hints `![alt](a.png "=200x100")`.
  - GitHub Flavored Markdown (validated against the GFM 0.29 spec examples):
    **Tables** (`tables`), **Task lists** (`task-lists`), **Strikethrough** (`strikethrough`),
    **Autolinks** (`autolinks`), **Disallowed raw HTML** (`tag-filter`).
  - GitHub.com extras: **Footnotes** (`footnotes`), **Alerts** (`alerts`), **Heading anchors**
    (`heading-anchors`), **Emoji shortcodes** (`emoji`), **Syntax highlighting** (`syntax-highlighting`,
    highlight.js 11.12.0 bundled), **Math** (`math`, KaTeX 0.19.1 bundled).
  - **Table of contents** (`toc`): `[TOC]` / `[[_TOC_]]` renders a nested list of heading links.
  - **Front matter** (`front-matter`): a leading YAML block is shown as a metadata table (as on GitHub).
  - **Graphviz diagrams** (`graphviz`): ```` ```dot ```` / ```` ```graphviz ```` blocks drawn with a bundled Viz.js 3.31.0 (WebAssembly).
  - **Wikilinks** (`wikilinks`): Obsidian-style `[[Note]]`, `[[Note|alias]]`, `[[Note#Heading]]` open the note in the editor.
  - **Mermaid diagrams** (`mermaid`) — ```` ```mermaid ```` fenced blocks rendered with Mermaid 12.3.0 (bundled, offline), inline syntax errors, light/dark theme.

## Build & run

Requires the .NET 10 SDK and the WebView2 runtime (included with Windows 11).

```powershell
dotnet build MarkdownEditor.slnx
dotnet test --solution MarkdownEditor.slnx
.\src\MarkdownEditor.App\bin\Debug\net10.0-windows\MarkdownEditor.exe samples\welcome.md
```

The app icon's source is `src\MarkdownEditor.App\Assets\app-icon.svg`; after editing it, regenerate
`app-icon.ico` with `python tools\build-app-icon.py` (needs Microsoft Edge and Pillow).

## Installer

Requires [Inno Setup 6](https://jrsoftware.org/isinfo.php) (`winget install JRSoftware.InnoSetup`).

```powershell
.\installer\build.ps1
```

This publishes a self-contained win-x64 build (bundled plugins included) to `artifacts\publish\` and compiles
`installer\MarkdownEditor.iss` into `artifacts\installer\MarkdownEditor-<version>-setup.exe`. The version comes from
`<Version>` in `Directory.Build.props`.

The installer:

- installs per user by default (no admin prompt), or for all users if chosen;
- always lists Markdown Editor under "Open with" for `.md` / `.markdown`;
- offers, as a checked-by-default option, to make it the default app for `.md` / `.markdown`. The previous default
  is backed up and restored on uninstall, unless another app has taken over since. Windows still honours a
  default chosen explicitly in *Settings > Apps > Default apps*.

### Releasing

Push a version tag; the *Release* workflow builds, tests, packages the installer with that version and publishes it
as a GitHub Release (a tag with a `-suffix` becomes a pre-release):

```powershell
git tag v0.2.0
git push origin v0.2.0
```

## Code signing

Releases are signed with a **self-signed** certificate (publisher `Kalisen`): the installer, and inside it
`MarkdownEditor.exe` and the app's own `MarkdownEditor*.dll` assemblies, all timestamped. Each
[GitHub Release](https://github.com/Kalisen/markdown-editor/releases) also carries the public certificate,
`MarkdownEditor-code-signing.cer`.

Windows does not trust a self-signed certificate by default, so on a machine that has not imported it the
installer still shows "Unknown publisher" and the SmartScreen warning. To trust it (this trusts everything signed
with that certificate, so only do it if you trust the publisher), run in PowerShell:

```powershell
Import-Certificate .\MarkdownEditor-code-signing.cer -CertStoreLocation Cert:\CurrentUser\Root
Import-Certificate .\MarkdownEditor-code-signing.cer -CertStoreLocation Cert:\CurrentUser\TrustedPublisher
```

Windows then shows `Kalisen` as the publisher. SmartScreen decides from reputation, so it may still warn about
a newly downloaded installer.

### Setting up signing

1. Create the certificate, outside the repository (asks for a password; keep the `.pfx` private and backed up):

   ```powershell
   .\tools\new-code-signing-certificate.ps1 -OutputDirectory $HOME\secrets\markdown-editor
   ```

2. Store it in the repository secrets (*Settings > Secrets and variables > Actions*):

   | Secret | Value |
   |---|---|
   | `CODE_SIGNING_PFX_BASE64` | the `.pfx`, base64-encoded |
   | `CODE_SIGNING_PFX_PASSWORD` | its password |

   The script prints the `gh secret set` commands. Until `CODE_SIGNING_PFX_BASE64` is set, the *Release* workflow
   publishes an unsigned installer (with a warning).

To sign a local build, set `CODE_SIGNING_PFX_PASSWORD` and run
`.\installer\build.ps1 -CertificatePath <path to .pfx>`.

## Privacy

This program will not transfer any information to other networked systems unless specifically requested by
the user or the person installing or operating it. The only network access is the user's own: opening a web
link from the preview in the browser, and loading remote (`https:`) images referenced by the document being
viewed.

## Architecture

```mermaid
flowchart LR
    classDef app fill:#dbeafe,stroke:#1e40af,color:#0b1b3f
    classDef core fill:#dcfce7,stroke:#166534,color:#052e16
    classDef contract fill:#fef3c7,stroke:#92400e,color:#3b1d02
    classDef plugin fill:#f3e8ff,stroke:#6b21a8,color:#2e1065

    App["MarkdownEditor.App<br/>WPF, AvalonEdit, WebView2"]:::app
    Core["MarkdownEditor.Core<br/>Documents, Editing, Rendering, Plugins"]:::core
    Abs["MarkdownEditor.Plugins.Abstractions<br/>IMarkdownPlugin, PreviewAsset, PreviewHosts"]:::contract
    Img["Plugin.Images"]:::plugin
    Mmd["Plugin.Mermaid"]:::plugin

    App --> Core --> Abs
    Img --> Abs
    Mmd --> Abs
    Core -. "loads at runtime<br/>(AssemblyLoadContext)" .-> Img
    Core -. "loads at runtime" .-> Mmd
```

| Project | Responsibility |
|---|---|
| `MarkdownEditor.Plugins.Abstractions` | Plugin contract shared by host and plugins (plus Markdig). |
| `MarkdownEditor.Core` | `Documents` (model, file store), `Editing` (`EditorSession` workflow), `Rendering` (Markdig pipeline, preview shell page, messages), `Plugins` (discovery, isolation). UI-agnostic and unit tested. |
| `MarkdownEditor.App` | WPF shell: editor, `PreviewHost` (WebView2 virtual hosts + web messages), dialogs. |
| `plugins/*` | Bundled plugins, staged into the app's `plugins/` folder on build. |

### Preview pipeline

```mermaid
sequenceDiagram
    participant E as Editor (UI thread)
    participant R as BackgroundRenderer
    participant H as PreviewHost
    participant P as Preview page (WebView2)
    E->>E: keystroke (no text copy), restart 300 ms timer
    E->>R: timer: sync text, RenderAsync(markdown)
    R-->>E: HTML (null if a newer render started)
    E->>H: Render(html)
    H->>P: PostWebMessageAsString(html)
    P->>P: patch changed top-level blocks only
    P->>P: plugin onRender callbacks (e.g. Mermaid)
    P-->>H: {type: open-link, href} on click
    H->>H: PreviewLinkPolicy: browser / open in editor / ignore
```

1. Markdown → HTML by Markdig (strict CommonMark + plugin extensions), off the UI thread; only the
   latest request's result is shown.
2. The preview shell (`index.html`, `preview.js`, `preview.css`) is loaded once from
   `https://app.mdeditor.local/`. Rendered HTML is posted as a plain string message; the page diffs it
   against the previous render by top-level block and replaces only the changed range, so unchanged
   content, scroll position and plugin output (rendered diagrams) are kept.
3. Plugin assets are served from `https://<plugin-id>.plugin.mdeditor.local/`, the open document's
   folder from `https://doc.mdeditor.local/`.

## Writing a plugin

1. Create a `net10.0` class library named `MarkdownEditor.Plugin.<Name>` under `plugins/` and import
   `..\Plugin.targets` (references the contract without copying shared assemblies).
2. Implement `IMarkdownPlugin` (public, parameterless constructor):
   - `Id`: lowercase letters, digits, hyphens (used as a host name).
   - `ConfigurePipeline(MarkdownPipelineBuilder)`: add Markdig extensions.
   - `PreviewAssets`: scripts/stylesheets relative to the plugin folder.
   - Optionally implement `IDocumentFeatureProbe.IsUsedBy(MarkdownDocument)` so the status bar can report
     when the plugin applies to the open document.
3. Preview scripts may register a post-render callback:

```js
window.mdeditor.onRender(async (root) => { /* transform rendered content */ });
// window.mdeditor.theme is "light" or "dark"
```

   Callbacks run after every update. Because unchanged blocks are kept between updates, a callback must
   be idempotent (skip content it already transformed) and may change the inside of top-level blocks but
   must not add or remove top-level nodes of `root`.
4. Scripts must be files (the preview CSP forbids inline script and `eval`).

Plugins are trusted code; a plugin that fails to load or configure is skipped and reported, never fatal.

## Security model

- **Documents are untrusted.** CommonMark allows raw HTML, so the preview shell enforces a strict
  Content-Security-Policy: scripts only from the app and plugin hosts (no inline script, no eval; WebAssembly
  compilation is allowed for bundled plugins such as Graphviz),
  no network requests, frames, objects or forms. Images may load from the document folder or `https:`
  (remote images can reveal that a document was opened).
- The preview cannot navigate away from its shell page; clicked links are classified by
  `PreviewLinkPolicy` (http/https/mailto open in the browser, Markdown files open in the editor,
  everything else is ignored). Messages from the page are validated and only accepted from the shell origin.
- Release builds disable WebView2 DevTools, browser shortcuts, autofill and password saving.
- **Plugins are trusted code** running with your privileges. Install the editor where only administrators
  can write (e.g. `Program Files`) and only add plugins you trust to its `plugins` folder.

## Performance and memory

Measured with a 650 KB / 4,000-section document (Release build, 40 edits with a render after each):

| | Before tuning | After tuning |
|---|---|---|
| WebView2 private memory after load | 1,006 MB | 714 MB |
| WebView2 private memory after 40 edits | 1,449 MB | 871 MB |
| App private memory after 40 edits | 591 MB | 566 MB |

What keeps memory down:
- Incremental DOM patching, plus `content-visibility: auto` so off-screen blocks are not laid out or painted.
- Editor text is copied only when rendering or saving, not on every keystroke.
- The saved state is kept as a SHA-256 hash, not a second copy of the text.
- HTML is posted as a plain string, with no JSON envelope copy.
- The undo stack is limited to 2,000 entries.
- The Mermaid SVG cache is bounded by size.
- The WebView2 memory target is set to Low while the window is minimized or inactive.
- `System.GC.ConserveMemory=5` makes the GC compact the Large Object Heap more eagerly.

Note: on machines with GPU overlay/driver DLLs injected into every process, a large share of the app's
private memory is independent of the editor (about 490 MB with an empty document on the test machine).

## Project tracking

Stories, issues, and assumptions are tracked in [GitHub Issues](https://github.com/Kalisen/markdown-editor/issues)
(label `Assumption` for decisions made without review, also listed in [docs/ASSUMPTIONS.md](docs/ASSUMPTIONS.md)). Review pass findings are summarized in
[docs/REVIEW-PASSES.md](docs/REVIEW-PASSES.md).
