using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Windows.ApplicationModel.DataTransfer;
using Windows.Storage;
using Windows.Storage.Pickers;
using System.Collections.Generic;
using System.Linq;
using WinRT.Interop;

namespace ImageStamp;

public sealed partial class DropPage : Page
{
    private static readonly HashSet<string> SupportedExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".jpg", ".jpeg", ".tiff", ".tif", ".heic", ".heif", ".png", ".avif",
        ".cr2", ".cr3", ".nef", ".arw", ".dng", ".orf", ".rw2", ".pef", ".raw",
        ".mp4", ".mov", ".m4v", ".avi", ".mkv", ".mts", ".m2ts", ".3gp"
    };

    public DropPage()
    {
        InitializeComponent();
    }

    // ── Browse button ──────────────────────────────────────────────────────────

    private async void BrowseButton_Click(object sender, RoutedEventArgs e)
    {
        var picker = new FileOpenPicker();
        picker.ViewMode = PickerViewMode.Thumbnail;
        picker.SuggestedStartLocation = PickerLocationId.PicturesLibrary;
        picker.FileTypeFilter.Add("*");

        // Required for WinUI 3 desktop
        var hwnd = WindowNative.GetWindowHandle(MainWindow.Instance);
        InitializeWithWindow.Initialize(picker, hwnd);

        var files = await picker.PickMultipleFilesAsync();
        if (files?.Count > 0)
            LoadFiles(files.Select(f => f.Path).ToList());
    }

    // ── Drag and drop ──────────────────────────────────────────────────────────

    private void DropZone_DragOver(object sender, DragEventArgs e)
    {
        e.AcceptedOperation = DataPackageOperation.Copy;
        e.DragUIOverride.Caption = "Add to ImageStamp";
        e.DragUIOverride.IsGlyphVisible = true;

        // Highlight the drop zone
        DropZone.BorderBrush = new SolidColorBrush(Microsoft.UI.Colors.DodgerBlue);
    }

    private async void DropZone_Drop(object sender, DragEventArgs e)
    {
        DropZone.BorderBrush = new SolidColorBrush(Microsoft.UI.ColorHelper.FromArgb(102, 26, 140, 242));

        if (e.DataView.Contains(StandardDataFormats.StorageItems))
        {
            var items = await e.DataView.GetStorageItemsAsync();
            var paths = new List<string>();

            foreach (var item in items)
            {
                if (item is StorageFile file)
                    paths.Add(file.Path);
                else if (item is StorageFolder folder)
                    paths.Add(folder.Path);
            }

            if (paths.Count > 0)
                LoadFiles(paths);
        }
    }

    // ── Load files and navigate ────────────────────────────────────────────────

    private void LoadFiles(List<string> paths)
    {
        var files = FileCollector.Collect(paths);
        if (files.Count == 0) return;

        MainWindow.Instance?.ContentFrame.Navigate(
            typeof(FileListPage),
            files
        );
    }
}
