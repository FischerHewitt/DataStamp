using Microsoft.UI.Xaml;

namespace ImageStamp;

public partial class App : Application
{
    private MainWindow? _window;

    public App()
    {
        InitializeComponent();
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        _window = new MainWindow();
        _window.Activate();

        // Apply saved theme
        if (_window.Content is FrameworkElement root)
        {
            root.RequestedTheme = AppSettings.DarkMode
                ? ElementTheme.Dark
                : ElementTheme.Default;
        }
    }
}
