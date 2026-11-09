using MarkdownEditor.Core.Rendering;
using Microsoft.Win32;

namespace MarkdownEditor.App.Infrastructure;

/// <summary>Reads the Windows "app mode" (light/dark) setting.</summary>
internal static class SystemTheme
{
    private const string PersonalizeKey = @"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize";
    private const string AppsUseLightThemeValue = "AppsUseLightTheme";
    private const int DarkModeFlag = 0;

    public static PreviewTheme Detect()
    {
        using var key = Registry.CurrentUser.OpenSubKey(PersonalizeKey);
        return key?.GetValue(AppsUseLightThemeValue) is int value && value == DarkModeFlag
            ? PreviewTheme.Dark
            : PreviewTheme.Light;
    }
}
