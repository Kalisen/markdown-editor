namespace MarkdownEditor.Plugins.Abstractions.Preview;

/// <param name="Kind">Asset type.</param>
/// <param name="RelativePath">Path relative to the plugin folder, using '/' separators.</param>
public sealed record PreviewAsset(PreviewAssetKind Kind, string RelativePath)
{
    public static PreviewAsset Script(string relativePath) => new(PreviewAssetKind.Script, relativePath);

    public static PreviewAsset Stylesheet(string relativePath) => new(PreviewAssetKind.Stylesheet, relativePath);
}
