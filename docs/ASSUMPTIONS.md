# Assumptions

Decisions made without explicit review during implementation. Each one is also tracked as a GitHub issue labelled `Assumption`; add new entries here and as an issue.

## [#8](https://github.com/Kalisen/markdown-editor/issues/8) Target .NET 10 (LTS), net10.0-windows

SDK 10.0.403 is installed and .NET 10 is the current LTS. App targets net10.0-windows, x64, Windows 11.


## [#9](https://github.com/Kalisen/markdown-editor/issues/9) Rendering pipeline is Markdig -> HTML -> WebView2

Markdig (CommonMark mode, no extra extensions in core) produces HTML displayed in WebView2. The WebView2 Evergreen runtime ships with Windows 11 and is assumed present.


## [#10](https://github.com/Kalisen/markdown-editor/issues/10) Editor control is AvalonEdit

AvalonEdit (MIT) provides the source editor with Markdown highlighting via a custom .xshd definition.


## [#11](https://github.com/Kalisen/markdown-editor/issues/11) Plugin contract and isolation model

Plugins implement IMarkdownPlugin (Id, Name, Version, Configure(MarkdownPipelineBuilder), head assets/scripts). Loaded with a collectible-free AssemblyLoadContext per plugin folder that shares the Abstractions + Markdig assemblies with the host. No sandboxing: plugins are trusted code. Plugins are loaded only at startup (no hot reload).


## [#12](https://github.com/Kalisen/markdown-editor/issues/12) Core renderer is strict CommonMark; GFM extras are out of scope

Tables, task lists, strikethrough, etc. are not enabled in core; they can be added later as plugins. The spec test suite runs against the core pipeline with no plugins.


## [#13](https://github.com/Kalisen/markdown-editor/issues/13) Preview assets served via WebView2 virtual host mapping

The document folder is mapped to https://doc.local/ and each plugin folder to https://plugin-<id>.local/ so relative images and bundled plugin JS load without file:// restrictions.


## [#14](https://github.com/Kalisen/markdown-editor/issues/14) Mermaid bundled offline as mermaid.min.js 12.3.0

The Mermaid plugin ships the UMD build mermaid@12.3.0/dist/mermaid.min.js inside the plugin folder (copied at build time from npm tarball, checked in). No CDN access at runtime.


## [#15](https://github.com/Kalisen/markdown-editor/issues/15) Light theme default; theme follows Windows app mode

Preview CSS has light/dark variants chosen from the Windows AppsUseLightTheme registry value at startup.


## [#16](https://github.com/Kalisen/markdown-editor/issues/16) Testing stack: xUnit + FluentAssertions-free assertions

Unit tests use xUnit with built-in Assert. UI (WPF) is kept thin (MVVM-ish ViewModel) so logic is unit-testable without UI automation.


## [#17](https://github.com/Kalisen/markdown-editor/issues/17) Encoding: UTF-8, line endings preserved

Files are read with BOM detection (default UTF-8) and saved as UTF-8 without BOM. Existing line endings are not normalized.


## [#19](https://github.com/Kalisen/markdown-editor/issues/19) Mermaid PR is stacked on the Phase 1 PR

Phase 2 (Mermaid, #7) is developed on branch feature/issue-7-mermaid-extension created from the Phase 1 branch, and its PR targets the Phase 1 branch (stacked PR) so Phase 1 can be reviewed/merged independently. Merge #18 first, then retarget the Mermaid PR to main.


## [#20](https://github.com/Kalisen/markdown-editor/issues/20) Mermaid security level strict, render caching, info string matching

Mermaid diagrams render with securityLevel "strict" (no click handlers/HTML labels script execution). Rendered SVGs are cached per (source, theme) in the preview so typing elsewhere does not re-render unchanged diagrams. Only fenced blocks whose info string first word is exactly `mermaid` are treated as diagrams.

## [#34](https://github.com/Kalisen/markdown-editor/issues/34) Remote https images are allowed in the preview

Remote images (https) are allowed by the preview Content-Security-Policy so documents referencing online pictures render. This lets a document author learn when/where it is opened (tracking pixels). Accepted for a local editor; can become a setting later.

## [#68](https://github.com/Kalisen/markdown-editor/issues/68) TOC marker syntax and heading ids

No GitHub syntax exists for an in-document TOC; `[TOC]` (Typora/Python-Markdown) and `[[_TOC_]]` (GitLab) are supported. The TOC plugin assigns GitHub-style heading ids itself (same algorithm as heading-anchors), so it works with or without that plugin.
