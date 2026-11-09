namespace MarkdownEditor.Plugins.Abstractions.Preview;

/// <summary>
/// The JavaScript API exposed by the preview page to plugin scripts:
/// <code>window.mdeditor.onRender(async (root) =&gt; { ... })</code>
/// Callbacks run after each content update with the content root element.
/// <code>window.mdeditor.theme</code> is "light" or "dark".
/// </summary>
public static class PreviewScriptApi
{
    public const string GlobalObject = "mdeditor";
    public const string OnRenderFunction = "onRender";
    public const string ThemeProperty = "theme";
}
