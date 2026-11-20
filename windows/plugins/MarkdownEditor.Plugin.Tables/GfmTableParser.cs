using Markdig.Parsers;
using Markdig.Syntax;

namespace MarkdownEditor.Plugin.Tables;

/// <summary>
/// Opens a table when a delimiter row follows a paragraph whose last line has the same number of cells
/// (that line becomes the header; earlier lines stay a paragraph). Rows continue until a blank line or
/// the start of another block.
/// </summary>
internal sealed class GfmTableParser : BlockParser
{
    public GfmTableParser() => OpeningCharacters = ['|', '-', ':'];

    public override bool CanInterrupt(BlockProcessor processor, Block block) => block is ParagraphBlock;

    public override BlockState TryOpen(BlockProcessor processor)
    {
        if (processor.IsCodeIndent || processor.CurrentBlock is not ParagraphBlock { Lines.Count: > 0 } paragraph)
            return BlockState.None;

        var alignments = GfmTableSyntax.ParseDelimiterRow(processor.Line.ToString());
        if (alignments is null) return BlockState.None;

        var headerIndex = paragraph.Lines.Count - 1;
        var header = paragraph.Lines.Lines[headerIndex].Slice.ToString();
        if (GfmTableSyntax.SplitCells(header).Count != alignments.Count) return BlockState.None;

        var table = new GfmTable(this, alignments) { Line = processor.LineIndex - 1, Column = processor.Column };
        table.AddRow(header, table.Line, isHeader: true);

        paragraph.Lines.RemoveAt(headerIndex);
        if (paragraph.Lines.Count == 0) processor.Discard(paragraph);
        else processor.Close(paragraph);

        processor.NewBlocks.Push(table);
        return BlockState.ContinueDiscard;
    }

    public override BlockState TryContinue(BlockProcessor processor, Block block)
    {
        var line = processor.Line.ToString();
        if (processor.IsBlankLine || GfmTableSyntax.StartsOtherBlock(line)) return BlockState.None;
        ((GfmTable)block).AddRow(line, processor.LineIndex, isHeader: false);
        return BlockState.ContinueDiscard;
    }
}
