using Markdig.Helpers;
using Markdig.Parsers;
using Markdig.Syntax;

namespace MarkdownEditor.Plugin.Tables;

/// <summary>A GFM table: a header row followed by zero or more body rows.</summary>
internal sealed class GfmTable(BlockParser parser, IReadOnlyList<ColumnAlignment> alignments) : ContainerBlock(parser)
{
    public IReadOnlyList<ColumnAlignment> Alignments { get; } = alignments;

    public int ColumnCount => Alignments.Count;

    /// <summary>
    /// Adds a row from a raw source line. GFM: cells beyond the header width are ignored and missing
    /// cells are rendered empty.
    /// </summary>
    public void AddRow(string line, int lineIndex, bool isHeader)
    {
        var row = new GfmTableRow(isHeader) { Line = lineIndex };
        var cells = GfmTableSyntax.SplitCells(line);
        for (var i = 0; i < ColumnCount; i++)
        {
            var text = i < cells.Count ? GfmTableSyntax.UnescapePipes(cells[i]) : string.Empty;
            var cell = new GfmTableCell { Line = lineIndex, ProcessInlines = true, IsOpen = false };
            cell.Lines = new StringLineGroup(text);
            row.Add(cell);
        }
        row.IsOpen = false;
        Add(row);
    }
}

internal sealed class GfmTableRow(bool isHeader) : ContainerBlock(null)
{
    public bool IsHeader { get; } = isHeader;
}

internal sealed class GfmTableCell() : LeafBlock(null);
