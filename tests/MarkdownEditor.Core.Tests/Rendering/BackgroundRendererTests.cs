using MarkdownEditor.Core.Rendering;

namespace MarkdownEditor.Core.Tests.Rendering;

public class BackgroundRendererTests
{
    [Fact]
    public async Task Renders_off_the_calling_thread()
    {
        var caller = Environment.CurrentManagedThreadId;
        var renderThread = 0;
        var renderer = new BackgroundRenderer(md =>
        {
            renderThread = Environment.CurrentManagedThreadId;
            return md.ToUpperInvariant();
        });

        Assert.Equal("A", await renderer.RenderAsync("a"));
        Assert.NotEqual(caller, renderThread);
    }

    [Fact]
    public async Task Superseded_render_yields_null()
    {
        using var gate = new ManualResetEventSlim();
        var renderer = new BackgroundRenderer(md =>
        {
            if (md == "old") gate.Wait(TestContext.Current.CancellationToken);
            return md;
        });

        var older = renderer.RenderAsync("old");
        Assert.Equal("new", await renderer.RenderAsync("new"));
        gate.Set();

        Assert.Null(await older);
    }
}
