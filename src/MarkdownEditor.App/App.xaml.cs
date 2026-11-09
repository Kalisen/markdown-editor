using System.IO;
using System.Windows;
using MarkdownEditor.App.Infrastructure;
using MarkdownEditor.Core.Documents;
using MarkdownEditor.Core.Editing;
using MarkdownEditor.Core.Plugins;
using MarkdownEditor.Core.Rendering;

namespace MarkdownEditor.App;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        var pluginsRoot = Path.Combine(AppContext.BaseDirectory, PluginLoader.PluginsFolderName);
        var catalog = new PluginLoader().LoadFrom(pluginsRoot);
        var renderer = new MarkdownRenderer(catalog.Plugins.Select(p => p.Plugin));
        var active = catalog.Plugins.Where(p => renderer.ActivePlugins.Contains(p.Plugin)).ToList();
        var failures = catalog.Failures.Concat(renderer.Failures).ToList();

        var session = new EditorSession(new FileDocumentStore(), new WpfUserPrompts());
        var window = new MainWindow(session, renderer, active, failures, SystemTheme.Detect());
        MainWindow = window;
        window.Show();

        if (e.Args.Length > 0) _ = session.OpenAsync(e.Args[0]);
    }
}
