using Microsoft.UI;
using Microsoft.UI.Xaml.Media;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Runtime.CompilerServices;

namespace ImageStamp;

// ── File item ──────────────────────────────────────────────────────────────────

public class FileItem
{
    public string Path { get; set; } = "";
    public string FileName => System.IO.Path.GetFileName(Path);
    public bool IsVideo => VideoExtensions.Contains(
        System.IO.Path.GetExtension(Path).ToLowerInvariant());

    private static readonly HashSet<string> VideoExtensions = new(StringComparer.OrdinalIgnoreCase)
        { ".mp4", ".mov", ".m4v", ".avi", ".mkv", ".mts", ".m2ts", ".3gp" };
}

// ── File item view model ───────────────────────────────────────────────────────

public class FileItemViewModel : INotifyPropertyChanged
{
    private bool _isSelected = true;
    private string _currentExifDate = "Reading…";

    public FileItemViewModel(FileItem item)
    {
        FilePath = item.Path;
        FileName = item.FileName;
        FolderName = Path.GetFileName(Path.GetDirectoryName(item.Path) ?? "");
        Icon = item.IsVideo ? "\uE8B2" : "\uEB9F";
    }

    public string FilePath { get; }
    public string FileName { get; }
    public string FolderName { get; }
    public string Icon { get; }

    public bool IsSelected
    {
        get => _isSelected;
        set { _isSelected = value; OnPropertyChanged(); }
    }

    public string CurrentExifDate
    {
        get => _currentExifDate;
        set { _currentExifDate = value; OnPropertyChanged(); }
    }

    public event PropertyChangedEventHandler? PropertyChanged;
    private void OnPropertyChanged([CallerMemberName] string? name = null)
        => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
}

// ── Stamp result ───────────────────────────────────────────────────────────────

public class StampResult
{
    public StampResult(string filePath, bool success, string message)
    {
        FilePath = filePath;
        Success = success;
        Message = message;
    }

    public string FilePath { get; }
    public bool Success { get; }
    public string Message { get; }
    public string FileName => Path.GetFileName(FilePath);
}

// ── Result view model ──────────────────────────────────────────────────────────

public class ResultViewModel
{
    public ResultViewModel(StampResult result)
    {
        FileName = result.FileName;
        Message = result.Message;
        StatusIcon = result.Success ? "\uE73E" : "\uE711";
        StatusColor = new SolidColorBrush(result.Success ? Colors.Green : Colors.Red);
    }

    public string FileName { get; }
    public string Message { get; }
    public string StatusIcon { get; }
    public SolidColorBrush StatusColor { get; }
}

// ── Stamp job ──────────────────────────────────────────────────────────────────

public class StampJob
{
    public StampJob(List<string> filePaths, DateTime date)
    {
        FilePaths = filePaths;
        Date = date;
    }

    public List<string> FilePaths { get; }
    public DateTime Date { get; }
}

// ── File collector ─────────────────────────────────────────────────────────────

public static class FileCollector
{
    private static readonly HashSet<string> Supported = new(StringComparer.OrdinalIgnoreCase)
    {
        ".jpg", ".jpeg", ".tiff", ".tif", ".heic", ".heif", ".png", ".avif",
        ".cr2", ".cr3", ".nef", ".arw", ".dng", ".orf", ".rw2", ".pef", ".raw",
        ".bmp", ".gif", ".webp",
        ".mp4", ".mov", ".m4v", ".avi", ".mkv", ".mts", ".m2ts", ".3gp"
    };

    public static List<FileItem> Collect(List<string> paths, bool recursive = false)
    {
        var items = new List<FileItem>();
        foreach (var path in paths)
        {
            if (Directory.Exists(path))
                items.AddRange(CollectFromFolder(path, recursive));
            else if (File.Exists(path) && Supported.Contains(Path.GetExtension(path)))
                items.Add(new FileItem { Path = path });
        }
        return items;
    }

    private static List<FileItem> CollectFromFolder(string folder, bool recursive)
    {
        var items = new List<FileItem>();
        try
        {
            var option = recursive
                ? SearchOption.AllDirectories
                : SearchOption.TopDirectoryOnly;

            foreach (var file in Directory.GetFiles(folder, "*", option))
            {
                if (Supported.Contains(Path.GetExtension(file)))
                    items.Add(new FileItem { Path = file });
            }
        }
        catch { }
        return items;
    }
}

// ── App settings ───────────────────────────────────────────────────────────────

public static class AppSettings
{
    public static bool DarkMode
    {
        get => Windows.Storage.ApplicationData.Current.LocalSettings
                   .Values["DarkMode"] as bool? ?? false;
        set => Windows.Storage.ApplicationData.Current.LocalSettings
                   .Values["DarkMode"] = value;
    }

    public static bool IncludeSubfolders
    {
        get => Windows.Storage.ApplicationData.Current.LocalSettings
                   .Values["IncludeSubfolders"] as bool? ?? false;
        set => Windows.Storage.ApplicationData.Current.LocalSettings
                   .Values["IncludeSubfolders"] = value;
    }
}
