using Markdig;
using Markdig.Extensions.Emoji;
using MarkdownEditor.Plugins.Abstractions;
using MarkdownEditor.Plugins.Abstractions.Preview;

namespace MarkdownEditor.Plugin.Emoji;

/// <summary>
/// GitHub emoji shortcodes (<c>:smile:</c>, <c>:+1:</c>…) render as Unicode emoji. Text smileys such as
/// <c>:)</c> are left alone, as on GitHub.
/// </summary>
public sealed class EmojiPlugin : IMarkdownPlugin
{
    public const string PluginId = "emoji";

    public string Id => PluginId;

    public string Name => "Emoji shortcodes";

    public Version Version => new(1, 0, 0);

    public IReadOnlyList<PreviewAsset> PreviewAssets { get; } = [];

    public void ConfigurePipeline(MarkdownPipelineBuilder builder) =>
        builder.UseEmojiAndSmiley(new EmojiMapping(EmojiMapping.GetDefaultEmojiShortcodeToUnicode(), new Dictionary<string, string>()));
}
