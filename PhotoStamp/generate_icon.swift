#!/usr/bin/swift
// Run with: swift DataStamp/generate_icon.swift
import AppKit
import Foundation

let sizes: [(Int, Int, String)] = [
    (16,  1, "icon_16x16.png"),
    (16,  2, "icon_16x16@2x.png"),
    (32,  1, "icon_32x32.png"),
    (32,  2, "icon_32x32@2x.png"),
    (128, 1, "icon_128x128.png"),
    (128, 2, "icon_128x128@2x.png"),
    (256, 1, "icon_256x256.png"),
    (256, 2, "icon_256x256@2x.png"),
    (512, 1, "icon_512x512.png"),
    (512, 2, "icon_512x512@2x.png"),
]

func makeIcon(pixelSize: Int) -> NSImage {
    let s = CGFloat(pixelSize)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext
    let rect = CGRect(origin: .zero, size: CGSize(width: s, height: s))

    // --- Rounded rect clip ---
    let radius = s * 0.22
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.addPath(path)
    ctx.clip()

    // --- Deep navy-to-steel-blue gradient background ---
    let bgColors = [
        NSColor(red: 0.06, green: 0.14, blue: 0.35, alpha: 1).cgColor, // deep navy
        NSColor(red: 0.12, green: 0.32, blue: 0.62, alpha: 1).cgColor, // mid blue
        NSColor(red: 0.20, green: 0.52, blue: 0.82, alpha: 1).cgColor, // sky blue
    ]
    let bgGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: bgColors as CFArray,
        locations: [0.0, 0.5, 1.0]
    )!
    ctx.drawLinearGradient(bgGradient,
                           start: CGPoint(x: 0, y: s),
                           end: CGPoint(x: s, y: 0),
                           options: [])

    // --- Subtle light orb top-right ---
    let orbColors = [
        NSColor(red: 0.55, green: 0.80, blue: 1.0, alpha: 0.18).cgColor,
        NSColor(red: 0.55, green: 0.80, blue: 1.0, alpha: 0.0).cgColor,
    ]
    let orbGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: orbColors as CFArray,
                                  locations: [0, 1])!
    ctx.drawRadialGradient(orbGradient,
                           startCenter: CGPoint(x: s * 0.72, y: s * 0.78),
                           startRadius: 0,
                           endCenter: CGPoint(x: s * 0.72, y: s * 0.78),
                           endRadius: s * 0.55,
                           options: [])

    // --- Photo frame (rounded rect) ---
    let frameInset = s * 0.14
    let frameW = s * 0.62
    let frameH = s * 0.50
    let frameX = (s - frameW) / 2 - s * 0.04
    let frameY = s * 0.30
    let frameRect = CGRect(x: frameX, y: frameY, width: frameW, height: frameH)
    let frameRadius = s * 0.06

    // Frame fill — light blue-white
    ctx.setFillColor(NSColor(red: 0.75, green: 0.88, blue: 1.0, alpha: 0.22).cgColor)
    let framePath = CGPath(roundedRect: frameRect, cornerWidth: frameRadius, cornerHeight: frameRadius, transform: nil)
    ctx.addPath(framePath)
    ctx.fillPath()

    // Frame border
    ctx.setStrokeColor(NSColor(red: 0.85, green: 0.93, blue: 1.0, alpha: 0.55).cgColor)
    ctx.setLineWidth(s * 0.025)
    ctx.addPath(framePath)
    ctx.strokePath()

    // Mountain/landscape inside frame
    let mtnColor = NSColor(red: 0.55, green: 0.78, blue: 1.0, alpha: 0.45).cgColor
    ctx.setFillColor(mtnColor)
    let mtn = CGMutablePath()
    mtn.move(to: CGPoint(x: frameX + frameW * 0.05, y: frameY + frameH * 0.15))
    mtn.addLine(to: CGPoint(x: frameX + frameW * 0.30, y: frameY + frameH * 0.65))
    mtn.addLine(to: CGPoint(x: frameX + frameW * 0.50, y: frameY + frameH * 0.35))
    mtn.addLine(to: CGPoint(x: frameX + frameW * 0.72, y: frameY + frameH * 0.70))
    mtn.addLine(to: CGPoint(x: frameX + frameW * 0.95, y: frameY + frameH * 0.15))
    mtn.closeSubpath()
    ctx.addPath(mtn)
    ctx.fillPath()

    // Sun circle inside frame
    ctx.setFillColor(NSColor(red: 0.90, green: 0.96, blue: 1.0, alpha: 0.60).cgColor)
    let sunR = frameH * 0.14
    let sunCX = frameX + frameW * 0.78
    let sunCY = frameY + frameH * 0.72
    ctx.fillEllipse(in: CGRect(x: sunCX - sunR, y: sunCY - sunR, width: sunR * 2, height: sunR * 2))

    // --- Stamp circle (bottom-right overlap) ---
    let stampCX = frameX + frameW * 0.88
    let stampCY = frameY - s * 0.04
    let stampR = s * 0.22

    // Stamp outer ring shadow
    ctx.setFillColor(NSColor(red: 0.04, green: 0.10, blue: 0.28, alpha: 0.45).cgColor)
    ctx.fillEllipse(in: CGRect(x: stampCX - stampR + s*0.01, y: stampCY - stampR - s*0.01,
                                width: stampR * 2, height: stampR * 2))

    // Stamp fill — vivid cyan-blue
    let stampColors = [
        NSColor(red: 0.10, green: 0.55, blue: 0.95, alpha: 1).cgColor,
        NSColor(red: 0.04, green: 0.35, blue: 0.78, alpha: 1).cgColor,
    ]
    let stampGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                colors: stampColors as CFArray,
                                locations: [0, 1])!
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: stampCX - stampR, y: stampCY - stampR,
                               width: stampR * 2, height: stampR * 2))
    ctx.clip()
    ctx.drawLinearGradient(stampGrad,
                           start: CGPoint(x: stampCX, y: stampCY + stampR),
                           end: CGPoint(x: stampCX, y: stampCY - stampR),
                           options: [])
    ctx.restoreGState()

    // Stamp outer ring
    ctx.setStrokeColor(NSColor(red: 0.70, green: 0.88, blue: 1.0, alpha: 0.80).cgColor)
    ctx.setLineWidth(s * 0.018)
    ctx.strokeEllipse(in: CGRect(x: stampCX - stampR, y: stampCY - stampR,
                                  width: stampR * 2, height: stampR * 2))

    // Stamp inner ring (dashed)
    ctx.setStrokeColor(NSColor(red: 0.80, green: 0.93, blue: 1.0, alpha: 0.55).cgColor)
    ctx.setLineWidth(s * 0.010)
    ctx.setLineDash(phase: 0, lengths: [s * 0.025, s * 0.018])
    let innerR = stampR * 0.80
    ctx.strokeEllipse(in: CGRect(x: stampCX - innerR, y: stampCY - innerR,
                                  width: innerR * 2, height: innerR * 2))
    ctx.setLineDash(phase: 0, lengths: [])

    // Calendar icon inside stamp
    let calFont = NSFont.systemFont(ofSize: stampR * 0.95, weight: .bold)
    let calAttrs: [NSAttributedString.Key: Any] = [
        .font: calFont,
        .foregroundColor: NSColor.white
    ]
    let calStr = NSAttributedString(string: "🕐", attributes: calAttrs)
    let calSize = calStr.size()
    calStr.draw(at: CGPoint(x: stampCX - calSize.width / 2,
                             y: stampCY - calSize.height / 2))

    image.unlockFocus()
    return image
}

let outputDir = "DataStamp/DataStamp/Assets.xcassets/AppIcon.appiconset"

for (points, scale, filename) in sizes {
    let pixelSize = points * scale
    let img = makeIcon(pixelSize: pixelSize)
    guard let tiff = img.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        print("✗ Failed: \(filename)"); continue
    }
    let url = URL(fileURLWithPath: "\(outputDir)/\(filename)")
    try! png.write(to: url)
    print("✓ \(filename) (\(pixelSize)x\(pixelSize)px)")
}
print("\nIcon generation complete.")
