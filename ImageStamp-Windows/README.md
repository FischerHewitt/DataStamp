# ImageStamp — Windows

Windows version of ImageStamp, built with C# + WinUI 3.

## Requirements to build

- Windows 11 or Windows 10 (version 1903+)
- Visual Studio 2022 with:
  - .NET Desktop Development workload
  - Windows App SDK
- [exiftool.exe](https://exiftool.org) — download the Windows executable and place it in the project root

## Building

1. Open `ImageStamp-Windows/ImageStamp/ImageStamp.csproj` in Visual Studio 2022
2. Download `exiftool.exe` from https://exiftool.org and place it in the `ImageStamp/` folder
3. Press F5 to run, or Build → Publish for distribution

## Distribution

### Standalone .exe
- Build → Publish → Self-contained, single file
- Produces a `.exe` users can run directly

### Microsoft Store (.msix)
- Requires a Microsoft Partner Center account ($19 one-time fee)
- Build → Publish → MSIX Package
- Upload to https://partner.microsoft.com

## Features (v1.0)
- Drop photos, videos, or folders
- Set EXIF date with a date picker
- Batch process entire folders
- Progress tracking
- Show in Explorer after stamping
- Dark/Light mode
- Include subfolders setting

## Supported formats
Images: JPEG, HEIC, PNG, TIFF, AVIF, RAW (CR2, NEF, ARW, DNG, etc.)
Videos: MP4, MOV, AVI, MKV, MTS, 3GP
