using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Navigation;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading.Tasks;

namespace ImageStamp;

public sealed partial class ResultsPage : Page
{
    private ObservableCollection<ResultViewModel> _results = new();
    private StampJob? _job;

    public ResultsPage()
    {
        InitializeComponent();
        ResultsListView.ItemsSource = _results;
    }

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        if (e.Parameter is StampJob job)
        {
            _job = job;
            RunStampAsync(job);
        }
    }

    private async void RunStampAsync(StampJob job)
    {
        int total = job.FilePaths.Count;
        int done = 0;
        int succeeded = 0;

        SummaryText.Text = $"Updating 0 of {total}…";

        foreach (var path in job.FilePaths)
        {
            var result = await Task.Run(() => ExifEngine.UpdateDate(path, job.Date));
            done++;

            if (result.Success) succeeded++;

            _results.Add(new ResultViewModel(result));
            SummaryText.Text = $"Updating {done} of {total}…";
        }

        // Done
        ProcessingRing.IsActive = false;
        SummaryText.Text = $"✓ {succeeded} stamped" +
                           (succeeded < total ? $"  ✗ {total - succeeded} failed" : "") +
                           $"  ({total} total)";

        ShowFolderButton.Visibility = Visibility.Visible;
    }

    private void ShowFolder_Click(object sender, RoutedEventArgs e)
    {
        if (_job == null) return;
        var folders = _job.FilePaths
            .Select(p => Path.GetDirectoryName(p))
            .Where(d => d != null)
            .Distinct();
        foreach (var folder in folders)
            Process.Start("explorer.exe", folder!);
    }

    private void StartOver_Click(object sender, RoutedEventArgs e)
    {
        MainWindow.Instance?.ContentFrame.Navigate(typeof(DropPage));
    }
}
