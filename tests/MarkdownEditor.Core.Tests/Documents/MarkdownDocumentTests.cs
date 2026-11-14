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

    [Fact]
    public void File_changed_on_disk_makes_document_dirty_until_it_matches_the_file()
    {
        var doc = new MarkdownDocument(@"C:\d\a.md", "x");
        Assert.True(doc.MatchesSaved("x"));

        doc.MarkChangedOnDisk("y");
        Assert.Equal((true, true, false), (doc.IsDirty, doc.MatchesSaved("y"), doc.MatchesSaved("x")));

        doc.Text = "y";
        Assert.False(doc.IsDirty);
    }

    [Fact]
    public void Same_length_edit_is_dirty()
    {
        var doc = new MarkdownDocument(text: "abc") { Text = "abd" };
        Assert.True(doc.IsDirty);
    }
}
