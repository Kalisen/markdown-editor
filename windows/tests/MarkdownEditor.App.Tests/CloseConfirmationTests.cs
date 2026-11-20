using MarkdownEditor.App.Editing;

namespace MarkdownEditor.App.Tests;

public class CloseConfirmationTests
{
    private int _closeCalls;

    private CloseConfirmation Create(Func<Task<bool>> confirm) => new(confirm, () => _closeCalls++);

    [Theory]
    [InlineData(true, false)]
    [InlineData(false, true)]
    public void Synchronous_confirmation_settles_the_request_without_closing_again(bool confirmed, bool cancelled)
    {
        var guard = Create(() => Task.FromResult(confirmed));

        Assert.Equal(cancelled, guard.ShouldCancel());
        Assert.Equal(0, _closeCalls);
    }

    [Fact]
    public void Pending_confirmation_cancels_then_closes_once_confirmed()
    {
        var pending = new TaskCompletionSource<bool>();
        var guard = Create(() => pending.Task);

        Assert.True(guard.ShouldCancel());
        Assert.Equal(0, _closeCalls);

        pending.SetResult(true);

        Assert.Equal(1, _closeCalls);
        Assert.False(guard.ShouldCancel());
    }

    [Fact]
    public void Pending_confirmation_that_is_declined_does_not_close()
    {
        var pending = new TaskCompletionSource<bool>();
        var guard = Create(() => pending.Task);

        guard.ShouldCancel();
        pending.SetResult(false);

        Assert.Equal(0, _closeCalls);
    }
}
