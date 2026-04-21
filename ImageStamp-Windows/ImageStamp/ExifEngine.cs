using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;

namespace ImageStamp;

/// Wraps exiftool.exe for EXIF date writing on Windows.
/// exiftool.exe must be placed next to the app executable.
public static class ExifEngine
{
    private static readonly HashSet<string> VideoExtensions = new(StringComparer.OrdinalIgnoreCase)
        { ".mp4", ".mov", ".m4v", ".avi", ".mkv", ".mts", ".m2ts", ".3gp" };

    // ── Update date ────────────────────────────────────────────────────────────

    public static StampResult UpdateDate(string filePath, DateTime date)
    {
        if (!File.Exists(filePath))
            return new StampResult(filePath, false, "File not found");

        var dateStr = date.ToString("yyyy:MM:dd HH:mm:ss");
        var ext = Path.GetExtension(filePath).ToLowerInvariant();
        var isVideo = VideoExtensions.Contains(ext);

        var args = new List<string> { "-overwrite_original" };

        if (isVideo)
        {
            args.AddRange(new[]
            {
                $"-QuickTime:CreateDate={dateStr}",
                $"-QuickTime:ModifyDate={dateStr}",
                $"-QuickTime:TrackCreateDate={dateStr}",
                $"-QuickTime:TrackModifyDate={dateStr}",
                $"-QuickTime:MediaCreateDate={dateStr}",
                $"-QuickTime:MediaModifyDate={dateStr}",
            });
        }
        else
        {
            args.AddRange(new[]
            {
                $"-DateTimeOriginal={dateStr}",
                $"-CreateDate={dateStr}",
                $"-DateTimeDigitized={dateStr}",
            });
        }

        args.Add($"\"{filePath}\"");

        var (output, error, code) = RunExiftool(args);

        if (code == 0)
            return new StampResult(filePath, true, $"Updated to {dateStr}");

        var msg = string.IsNullOrWhiteSpace(error) ? output : error;
        return new StampResult(filePath, false, msg.Trim());
    }

    // ── Read current date ──────────────────────────────────────────────────────

    public static string? ReadCurrentDate(string filePath)
    {
        if (!File.Exists(filePath)) return null;

        var ext = Path.GetExtension(filePath).ToLowerInvariant();
        var tag = VideoExtensions.Contains(ext) ? "-QuickTime:CreateDate" : "-DateTimeOriginal";

        var (output, _, _) = RunExiftool(new List<string> { tag, "-s3", $"\"{filePath}\"" });
        var trimmed = output.Trim();
        if (string.IsNullOrEmpty(trimmed)) return null;

        // Convert "yyyy:MM:dd HH:mm:ss" to readable format
        if (DateTime.TryParseExact(trimmed, "yyyy:MM:dd HH:mm:ss",
            System.Globalization.CultureInfo.InvariantCulture,
            System.Globalization.DateTimeStyles.None, out var dt))
        {
            return dt.ToString("MMM d, yyyy");
        }
        return trimmed;
    }

    // ── Run exiftool ───────────────────────────────────────────────────────────

    private static (string output, string error, int code) RunExiftool(List<string> args)
    {
        var exiftoolPath = FindExiftool();
        if (exiftoolPath == null)
            return ("", "exiftool.exe not found", -1);

        var psi = new ProcessStartInfo
        {
            FileName = exiftoolPath,
            Arguments = string.Join(" ", args),
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        using var process = new Process { StartInfo = psi };
        process.Start();

        var output = process.StandardOutput.ReadToEnd();
        var error = process.StandardError.ReadToEnd();

        if (!process.WaitForExit(30000))
        {
            process.Kill();
            return ("", "exiftool timed out", -1);
        }

        return (output, error, process.ExitCode);
    }

    private static string? FindExiftool()
    {
        // Look next to the executable first
        var appDir = AppContext.BaseDirectory;
        var local = Path.Combine(appDir, "exiftool.exe");
        if (File.Exists(local)) return local;

        // Fall back to PATH
        foreach (var dir in (Environment.GetEnvironmentVariable("PATH") ?? "").Split(';'))
        {
            var candidate = Path.Combine(dir.Trim(), "exiftool.exe");
            if (File.Exists(candidate)) return candidate;
        }

        return null;
    }
}
