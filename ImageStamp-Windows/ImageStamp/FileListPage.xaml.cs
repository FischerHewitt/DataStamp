using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Windows.ApplicationModel.DataTransfer;
using Windows.Storage;
using Windows.Storage.Pickers;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Threading.Tasks;
using WinRT.Interop;

namespace ImageStamp;

public sealed partial class FileListPage : Page
{
    private ObservableCollection<FileItemViewModel> _items = new();

    public FileListPage()
    {
        InitializeComponent();
        FileListView.ItemsSource = _items;
        _items.CollectionChanged += (_, _) => UpdateUI();
    }

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        if (e.Parameter is List<FileItem> files)
        {
            foreach (var f in files)
                _items.Add(new FileItemViewModel(f));

            UpdateUI();
            LoadExifDatesAsync();
        }
    }

    // ── EXIF date loading ──────────────────────────────────────────────────────

    private async void LoadExifDatesAsync()
    {
        int total = _items.Count;
        int done = 0;

        ProgressPanel.Visibility = Visibility.Visible;
        ExifProgressBar.Maximum = total;

        // Adaptive concurrency
        int concurrency = total switch
        {
            <= 20   => total,
            <= 100  => 12,
            <= 500  => 8,
            <= 2000 => 4,
            _       => 2
        };

        var semaphore = new System.Threading.SemaphoreSlim(concurrency);

        var tasks = _items.Select(async item =>
        {
            await semaphore.WaitAsync();
            try
            {
                var date = await Task.Run(() => ExifEngine.ReadCurrentDate(item.FilePath));
                DispatcherQueue.TryEnqueue(() =>
                {
                    item.CurrentExifDate = date ?? "No date set";
                    done++;
                    ExifProgressBar.Value = done;
                    ProgressText.Text = $"{done} / {total}";
                    if (done >= total)
                        ProgressPanel.Visibility = Visibility.Collapsed;
                });
            }
            finally { semaphore.Release(); }
        });

        await Task.WhenAll(tasks);
    }

    // ── UI helpers ─────────────────────────────────────────────────────────────

    private void UpdateUI()
    {
        int selected = _items.Count(i => i.IsSelected);
        int total = _items.Count;
        SelectionCount.Text = $"{selected} of {total} selected";
        StampButtonText.Text = $"Stamp {selected} File{(selected == 1 ? "" : "s")}";
        StampButton.IsEnabled = selected > 0;
        SelectAllButton.Content = _items.All(i => i.IsSelected) ? "Deselect All" : "Select All";
    }

    private void SelectAllButton_Click(object sender, RoutedEventArgs e)
    {
        bool allSelected = _items.All(i => i.IsSelected);
        foreach (var item in _items)
            item.IsSelected = !allSelected;
        UpdateUI();
    }

    // ── Add more files ─────────────────────────────────────────────────────────

    private async void AddMore_Click(object sender, RoutedEventArgs e)
    {
        var picker = new FileOpenPicker();
        picker.FileTypeFilter.Add("*");
        var hwnd = WindowNative.GetWindowHandle(MainWindow.Instance);
        InitializeWithWindow.Initialize(picker, hwnd);

        var files = await picker.PickMultipleFilesAsync();
        if (files?.Count > 0)
        {
            var newItems = FileCollector.Collect(files.Select(f => f.Path).ToList());
            var existing = new HashSet<string>(_items.Select(i => i.FilePath));
            foreach (var f in newItems.Where(f => !existing.Contains(f.Path)))
                _items.Add(new FileItemViewModel(f));
            UpdateUI();
        }
    }

    // ── Drag and drop ──────────────────────────────────────────────────────────

    private void FileList_DragOver(object sender, DragEventArgs e)
        => e.AcceptedOperation = DataPackageOperation.Copy;

    private async void FileList_Drop(object sender, DragEventArgs e)
    {
        if (e.DataView.Contains(StandardDataFormats.StorageItems))
        {
            var items = await e.DataView.GetStorageItemsAsync();
            var paths = items.Select(i => i.Path).ToList();
            var newItems = FileCollector.Collect(paths);
            var existing = new HashSet<string>(_items.Select(i => i.FilePath));
            foreach (var f in newItems.Where(f => !existing.Contains(f.Path)))
                _items.Add(new FileItemViewModel(f));
            UpdateUI();
        }
    }

    // ── Stamp ──────────────────────────────────────────────────────────────────

    private void StampButton_Click(object sender, RoutedEventArgs e)
    {
        var selected = _items.Where(i => i.IsSelected).ToList();
        if (selected.Count == 0) return;

        var date = MainWindow.Instance?.SelectedDate.DateTime ?? System.DateTime.Now;
        MainWindow.Instance?.ContentFrame.Navigate(
            typeof(ResultsPage),
            new StampJob(selected.Select(i => i.FilePath).ToList(), date)
        );
    }
}
