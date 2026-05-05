# ImageStamp — Windows

Windows version of ImageStamp, built with C# + WinUI 3.

## Requirements to build

- Windows 11 or Windows 10 (version 1903+)
- Visual Studio 2022 with:
  - .NET Desktop Development workload
  - Windows App SDK
- [exiftool.exe](https://exiftool.org) — download the Windows executable and place it in the project root

## Building

1. Open `ImageStamp-Windows/ImageStamp.sln` in Visual Studio 2022 (or open the individual `.csproj`)
2. Download `exiftool.exe` from https://exiftool.org and place it in the `ImageStamp/` folder
3. Press F5 to run, or Build → Publish for distribution

## Running Tests

The `ImageStamp.Tests` project is a headless xUnit test project that tests pure logic without launching the WinUI window.

```powershell
# From the ImageStamp-Windows directory:
dotnet test ImageStamp.Tests\ImageStamp.Tests.csproj -p:Platform=x64

# Or build and test the whole solution:
dotnet build ImageStamp.sln -p:Platform=x64
dotnet test ImageStamp.sln -p:Platform=x64
```

> **Note:** Tests must be run on Windows (x64 or ARM64) because the project targets `net8.0-windows10.0.19041.0` and references the Windows App SDK. The test runner invokes xUnit directly — no WinUI window is launched.

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
