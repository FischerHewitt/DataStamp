using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Windows.Foundation;

namespace ImageStamp;

public sealed partial class MainWindow : Window
{
    public static MainWindow? Instance { get; private set; }
    public DateTimeOffset SelectedDate { get; private set; } = DateTimeOffset.Now;

    public MainWindow()
    {
        Instance = this;
        InitializeComponent();
        AppWindow.SetIcon("Assets\\AppIcon.ico");
        AppWindow.Resize(new Windows.Graphics.SizeInt32(860, 600));

        // Start on the drop page
        ContentFrame.Navigate(typeof(DropPage));
    }

    private void DatePicker_DateChanged(CalendarDatePicker sender,
                                        CalendarDatePickerDateChangedEventArgs args)
    {
        if (args.NewDate.HasValue)
            SelectedDate = args.NewDate.Value;
    }

    private void SettingsButton_Click(object sender, RoutedEventArgs e)
    {
        if (ContentFrame.CurrentSourcePageType == typeof(SettingsPage))
            ContentFrame.GoBack();
        else
            ContentFrame.Navigate(typeof(SettingsPage));
    }

    public void NavigateTo(Type pageType)
    {
        ContentFrame.Navigate(pageType);
    }
}
