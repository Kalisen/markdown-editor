namespace MarkdownEditor.Core.Export;

public enum ExportFormat
{
    Html,
    Pdf,
}

public static class ExportFormats
{
    public static string Extension(ExportFormat format) => format switch
    {
        ExportFormat.Html => ".html",
        ExportFormat.Pdf => ".pdf",
        _ => throw new ArgumentOutOfRangeException(nameof(format)),
    };

    public static string DialogFilter(ExportFormat format) => format switch
    {
        ExportFormat.Html => "HTML file (*.html)|*.html",
        ExportFormat.Pdf => "PDF document (*.pdf)|*.pdf",
        _ => throw new ArgumentOutOfRangeException(nameof(format)),
    };
}
