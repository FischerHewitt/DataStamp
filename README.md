# ImageStamp

A native macOS app for updating EXIF and metadata dates on scanned photos and videos.

## What it does

When you scan old photos, the file date gets set to today — not when the photo was actually taken. ImageStamp lets you fix that by stamping the correct date onto the EXIF metadata of one file, many files, or an entire folder at once.

## Features

- Drag and drop photos, videos, or folders
- Select individual files with checkboxes, or select all
- Supports JPEG, HEIC, PNG, TIFF, RAW (CR2, NEF, ARW, DNG), MP4, MOV, and more
- Optional recursive subfolder scanning
- Confirm before any changes are made
- Calendar or type-to-enter date input with live validation
- Custom time stamping (default or per-session)
- GPS location stamping with interactive map picker
- Batch rename files to date format with custom prepend/append
- EXIF metadata preview panel with image thumbnail
- Duplicate date detection
- Undo support with backup files
- Recent dates history
- Light / Dark / System appearance
- Adjustable text and icon size
- Fully self-contained — no dependencies required

## Requirements

- macOS 13.0 or later

## Built with

- Swift + SwiftUI
- [ExifTool](https://exiftool.org) by Phil Harvey (bundled)
- MapKit for location picking

## License

MIT
