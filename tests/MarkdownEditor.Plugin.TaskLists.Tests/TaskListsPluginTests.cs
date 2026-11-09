using Markdig;

namespace MarkdownEditor.Plugin.TaskLists.Tests;

public class TaskListsPluginTests
{
    private static string Render(string markdown)
    {
        var builder = new MarkdownPipelineBuilder();
        new TaskListsPlugin().ConfigurePipeline(builder);
        return Markdown.ToHtml(markdown, builder.Build());
    }

    // GFM spec 0.29 examples 279 and 280 (task list items extension; disabled in cmark-gfm's suite,
    // so the expected checkbox markup is Markdig's equivalent of GitHub's).
    [Fact]
    public void Unchecked_and_checked_items_render_as_disabled_checkboxes()
    {
        var html = Render("- [ ] foo\n- [x] bar\n- [X] baz\n");

        Assert.Contains("<ul class=\"contains-task-list\">", html);
        Assert.Contains("<li class=\"task-list-item\"><input disabled=\"disabled\" type=\"checkbox\" /> foo</li>", html);
        Assert.Contains("<li class=\"task-list-item\"><input disabled=\"disabled\" type=\"checkbox\" checked=\"checked\" /> bar</li>", html);
        Assert.Contains("checked=\"checked\" /> baz", html);
    }

    [Fact]
    public void Nested_task_lists_render()
    {
        var html = Render("- [x] foo\n  - [ ] bar\n  - [x] baz\n- [ ] bim\n");
        Assert.Equal(4, html.Split("type=\"checkbox\"").Length - 1);
    }

    [Theory]
    [InlineData("[ ] not a list item\n")]
    [InlineData("- [] missing space\n")]
    [InlineData("- [y] other letter\n")]
    public void Brackets_outside_task_list_syntax_stay_text(string markdown) =>
        Assert.DoesNotContain("checkbox", Render(markdown));

    [Fact]
    public void Declared_stylesheet_exists() =>
        Assert.True(File.Exists(Path.Combine(AppContext.BaseDirectory, TaskListsPlugin.StylesheetPath)));
}
