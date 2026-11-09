using Markdig.Renderers;
using Markdig.Renderers.Html;

namespace MarkdownEditor.Plugin.Tables;

/// <summary>Renders tables as GFM does: <c>align</c> attributes, <c>tbody</c> only when there are body rows.</summary>
internal sealed class GfmTableRenderer : HtmlObjectRenderer<GfmTable>
{
    protected override void Write(HtmlRenderer renderer, GfmTable table)
    {
        renderer.EnsureLine();
        renderer.WriteLine("<table>");
        var inBody = false;
        foreach (GfmTableRow row in table)
        {
            if (row.IsHeader)
            {
                renderer.WriteLine("<thead>");
            }
            else if (!inBody)
            {
                renderer.WriteLine("<tbody>");
                inBody = true;
            }

            renderer.WriteLine("<tr>");
            var tag = row.IsHeader ? "th" : "td";
            for (var i = 0; i < row.Count; i++)
            {
                renderer.Write('<').Write(tag);
                if (AlignValue(table.Alignments[i]) is { } align) renderer.Write(" align=\"").Write(align).Write('"');
                renderer.Write('>');
                renderer.WriteLeafInline((GfmTableCell)row[i]);
                renderer.Write("</").Write(tag).WriteLine(">");
            }
            renderer.WriteLine("</tr>");
            if (row.IsHeader) renderer.WriteLine("</thead>");
        }
        if (inBody) renderer.WriteLine("</tbody>");
        renderer.WriteLine("</table>");
    }

    private static string? AlignValue(ColumnAlignment alignment) => alignment switch
    {
        ColumnAlignment.Left => "left",
        ColumnAlignment.Center => "center",
        ColumnAlignment.Right => "right",
        _ => null,
    };
}
