using MarkdownEditor.Core.Documents;

namespace MarkdownEditor.Core.Tests.Documents;

public class MarkdownDocumentTests
{
    [Fact]
    public void New_document_is_untitled_and_clean()
    {
        var doc = new MarkdownDocument();
        Assert.Equal((MarkdownDocument.UntitledName, false, null), (doc.DisplayName, doc.IsDirty, doc.Directory));
    }

    [Fact]
    public void Editing_marks_dirty_and_reverting_or_saving_cleans()
    {
        var doc = new MarkdownDocument(@"C:\d\a.md", "x");
        doc.Text = "y";
        Assert.True(doc.IsDirty);
        doc.Text = "x";
        Assert.False(doc.IsDirty);

        doc.Text = "z";
        doc.MarkSaved(@"C:\e\b.md");
        Assert.Equal(("b.md", @"C:\e", false), (doc.DisplayName, doc.Directory, doc.IsDirty));
    }
}
