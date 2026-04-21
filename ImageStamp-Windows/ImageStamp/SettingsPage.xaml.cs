using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace ImageStamp;

public sealed partial class SettingsPage : Page
{
    public SettingsPage()
    {
        InitializeComponent();
        // Load saved settings
        DarkModeToggle.IsOn = AppSettings.DarkMode;
        SubfoldersToggle.IsOn = AppSettings.IncludeSubfolders;
    }

    private void DarkModeToggle_Toggled(object sender, RoutedEventArgs e)
    {
        AppSettings.DarkMode = DarkModeToggle.IsOn;
        if (MainWindow.Instance?.Content is FrameworkElement root)
            root.RequestedTheme = DarkModeToggle.IsOn
                ? ElementTheme.Dark
                : ElementTheme.Light;
    }
}
