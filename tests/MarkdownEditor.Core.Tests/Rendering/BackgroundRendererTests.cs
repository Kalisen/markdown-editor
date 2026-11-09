using MarkdownEditor.Core.Rendering;

namespace MarkdownEditor.Core.Tests.Rendering;

public class BackgroundRendererTests
{
    [Fact]
    public async Task Does_not_block_the_caller_while_rendering()
    {
        using var gate = new ManualResetEventSlim();
        var renderer = new BackgroundRenderer<string>(md =>
        {
            gate.Wait(TestContext.Current.CancellationToken);
            return md.ToUpperInvariant();
        });

        var pending = renderer.RenderAsync("a"); // would deadlock if rendering ran on the caller

        Assert.False(pending.IsCompleted);
        gate.Set();
        Assert.Equal("A", await pending);
    }

    [Fact]
    public async Task Superseded_render_yields_null()
    {
        using var gate = new ManualResetEventSlim();
        var renderer = new BackgroundRenderer<string>(md =>
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
