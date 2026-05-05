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
    // Exposed as internal so the test project can reference it via InternalsVisibleTo
    // if needed; public so BuildArgs (also public) can use it directly.
    public static readonly HashSet<string> VideoExtensions = new(StringComparer.OrdinalIgnoreCase)
        { ".mp4", ".mov", ".m4v", ".avi", ".mkv", ".mts", ".m2ts", ".3gp" };

    // ── Pure helper methods (public static, no I/O) ────────────────────────────

    /// Formats a DateTime to the EXIF date/time string "yyyy:MM:dd HH:mm:ss".
    // Feature: imagestamp-windows-tests, Property 1: FormatExifDate round-trip
    public static string FormatExifDate(DateTime dt)
        => dt.ToString("yyyy:MM:dd HH:mm:ss");

    /// Applies the selected TimeMode to a date, returning a new DateTime
    /// with the correct time component.  The date component is always preserved.
    // Feature: imagestamp-windows-tests, Property 2: ApplyTimeMode correctness across all modes
    public static DateTime ApplyTimeMode(DateTime date, TimeMode mode, TimeSpan? customTime)
        => mode switch
        {
            TimeMode.None     => date.Date,                    // 00:00:00
            TimeMode.Midnight => date.Date,                    // 00:00:00
            TimeMode.Noon     => date.Date.AddHours(12),       // 12:00:00
            TimeMode.Custom   => date.Date.Add(
                                     customTime.HasValue
                                         ? new TimeSpan(customTime.Value.Hours,
                                                        customTime.Value.Minutes, 0)
                                         : TimeSpan.Zero),
            _                 => date.Date
        };

    /// Builds the list of exiftool arguments for a given file, date, and optional GPS.
    /// Does NOT include the file path itself — the caller appends it.
    // Feature: imagestamp-windows-tests, Property 3: BuildArgs always contains -overwrite_original
    // Feature: imagestamp-windows-tests, Property 4: GPS hemisphere references are sign-correct
    public static List<string> BuildArgs(string filePath, DateTime date,
                                         GpsCoordinate? location)
    {
        var ext = Path.GetExtension(filePath).ToLowerInvariant();
        var isVideo = VideoExtensions.Contains(ext);
        var dateStr = FormatExifDate(date);

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

            if (location != null)
            {
                // ISO 6709 format: +lat+lon/ (sign is explicit for both hemispheres)
                var latSign = location.Latitude  >= 0 ? "+" : "";
                var lonSign = location.Longitude >= 0 ? "+" : "";
                args.Add($"-Keys:GPSCoordinates={latSign}{location.Latitude}{lonSign}{location.Longitude}/");
            }
        }
        else
        {
            args.AddRange(new[]
            {
                $"-DateTimeOriginal={dateStr}",
                $"-CreateDate={dateStr}",
                $"-DateTimeDigitized={dateStr}",
            });

            if (location != null)
            {
                var absLat = Math.Abs(location.Latitude);
                var absLon = Math.Abs(location.Longitude);
                var latRef = location.Latitude  >= 0 ? "N" : "S";
                var lonRef = location.Longitude >= 0 ? "E" : "W";
                args.AddRange(new[]
                {
                    $"-GPSLatitude={absLat}",
                    $"-GPSLatitudeRef={latRef}",
                    $"-GPSLongitude={absLon}",
                    $"-GPSLongitudeRef={lonRef}",
                });
            }
        }

        return args;
    }

    // ── Update date ────────────────────────────────────────────────────────────

    /// Stamps EXIF date (and optional GPS) onto a single file.
    /// Internally applies the current TimeMode, builds args, then invokes exiftool.
    public static StampResult UpdateDate(string filePath, DateTime date,
                                         GpsCoordinate? location = null)
    {
        if (!File.Exists(filePath))
            return new StampResult(filePath, false, "File not found");

        // Resolve the time component according to the persisted TimeMode
        var stampDate = ApplyTimeMode(date, AppSettings.TimeMode, AppSettings.CustomTime);

        var args = BuildArgs(filePath, stampDate, location);
        args.Add($"\"{filePath}\"");

        var (output, error, code) = RunExiftool(args);

        if (code == 0)
            return new StampResult(filePath, true, $"Updated to {FormatExifDate(stampDate)}");

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
