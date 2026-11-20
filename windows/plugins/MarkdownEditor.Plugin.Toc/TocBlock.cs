using Markdig.Parsers;
using Markdig.Syntax;

namespace MarkdownEditor.Plugin.Toc;

/// <summary>Placeholder for the table of contents; headings are collected at render time.</summary>
internal sealed class TocBlock(BlockParser parser) : LeafBlock(parser);

/// <summary>Opens a <see cref="TocBlock"/> for a line that is exactly a TOC marker (not inside a paragraph).</summary>
internal sealed class TocBlockParser : BlockParser
{
    public static readonly IReadOnlyList<string> Markers = ["[TOC]", "[[_TOC_]]"];

    public TocBlockParser() => OpeningCharacters = ['['];

    // A marker line inside a paragraph is paragraph text (GitLab/Typora behaviour).
    public override bool CanInterrupt(BlockProcessor processor, Block block) => block is not ParagraphBlock;

    public override BlockState TryOpen(BlockProcessor processor)
    {
        if (processor.IsCodeIndent) return BlockState.None;
        var line = processor.Line.ToString().Trim();
        if (!Markers.Any(m => string.Equals(m, line, StringComparison.OrdinalIgnoreCase))) return BlockState.None;

        processor.NewBlocks.Push(new TocBlock(this) { Line = processor.LineIndex, Column = processor.Column });
        return BlockState.BreakDiscard;
    }
}
