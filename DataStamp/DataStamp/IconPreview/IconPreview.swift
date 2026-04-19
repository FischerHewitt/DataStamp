import SwiftUI

/// Standalone SwiftUI preview of the DataStamp app icon.
/// Open this file in Xcode and use the canvas (⌥⌘↩) to preview live.
/// Tweak colours, sizes, and shapes here, then copy changes back to generate_icon.swift.

struct DataStampIcon: View {
    var size: CGFloat = 512

    private var s: CGFloat { size }

    var body: some View {
        ZStack {
            // ── Background gradient ──────────────────────────────────────
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.06, green: 0.14, blue: 0.35), location: 0.0),
                    .init(color: Color(red: 0.12, green: 0.32, blue: 0.62), location: 0.5),
                    .init(color: Color(red: 0.20, green: 0.52, blue: 0.82), location: 1.0),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // ── Soft light orb ───────────────────────────────────────────
            RadialGradient(
                colors: [
                    Color(red: 0.55, green: 0.80, blue: 1.0).opacity(0.18),
                    Color.clear
                ],
                center: UnitPoint(x: 0.72, y: 0.28),
                startRadius: 0,
                endRadius: s * 0.55
            )

            // ── Photo frame ──────────────────────────────────────────────
            let frameW = s * 0.62
            let frameH = s * 0.50
            let frameX = (s - frameW) / 2 - s * 0.04
            let frameY = s * 0.30

            PhotoFrame(
                x: frameX, y: frameY,
                w: frameW, h: frameH,
                cornerRadius: s * 0.06,
                size: s
            )

            // ── Stamp circle ─────────────────────────────────────────────
            let stampCX = frameX + frameW * 0.88
            let stampCY = frameY - s * 0.04
            let stampR  = s * 0.22

            StampCircle(cx: stampCX, cy: stampCY, r: stampR, size: s)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

// MARK: - Photo Frame

private struct PhotoFrame: View {
    let x, y, w, h, cornerRadius, size: CGFloat

    var body: some View {
        ZStack {
            // Frame fill
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(red: 0.75, green: 0.88, blue: 1.0).opacity(0.22))
                .frame(width: w, height: h)

            // Frame border
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    Color(red: 0.85, green: 0.93, blue: 1.0).opacity(0.55),
                    lineWidth: size * 0.025
                )
                .frame(width: w, height: h)

            // Mountains
            MountainShape(frameW: w, frameH: h)
                .fill(Color(red: 0.55, green: 0.78, blue: 1.0).opacity(0.45))
                .frame(width: w, height: h)

            // Sun
            Circle()
                .fill(Color(red: 0.90, green: 0.96, blue: 1.0).opacity(0.60))
                .frame(width: h * 0.28, height: h * 0.28)
                .offset(x: w * 0.28, y: -h * 0.22)
        }
        .offset(x: x - (size / 2 - w / 2), y: -(y - (size / 2 - h / 2)))
    }
}

private struct MountainShape: Shape {
    let frameW, frameH: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to:    CGPoint(x: frameW * 0.05,  y: frameH * 0.85))
        p.addLine(to: CGPoint(x: frameW * 0.30,  y: frameH * 0.35))
        p.addLine(to: CGPoint(x: frameW * 0.50,  y: frameH * 0.65))
        p.addLine(to: CGPoint(x: frameW * 0.72,  y: frameH * 0.30))
        p.addLine(to: CGPoint(x: frameW * 0.95,  y: frameH * 0.85))
        p.closeSubpath()
        return p
    }
}

// MARK: - Stamp Circle

private struct StampCircle: View {
    let cx, cy, r, size: CGFloat

    var body: some View {
        ZStack {
            // Drop shadow
            Circle()
                .fill(Color(red: 0.04, green: 0.10, blue: 0.28).opacity(0.45))
                .frame(width: r * 2, height: r * 2)
                .offset(x: 2, y: -2)

            // Fill gradient
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.55, blue: 0.95),
                            Color(red: 0.04, green: 0.35, blue: 0.78),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: r * 2, height: r * 2)

            // Outer ring
            Circle()
                .strokeBorder(
                    Color(red: 0.70, green: 0.88, blue: 1.0).opacity(0.80),
                    lineWidth: size * 0.018
                )
                .frame(width: r * 2, height: r * 2)

            // Inner dashed ring
            Circle()
                .strokeBorder(style: StrokeStyle(
                    lineWidth: size * 0.010,
                    dash: [size * 0.025, size * 0.018]
                ))
                .foregroundColor(Color(red: 0.80, green: 0.93, blue: 1.0).opacity(0.55))
                .frame(width: r * 1.60, height: r * 1.60)

            // Clock icon
            Image(systemName: "clock.fill")
                .font(.system(size: r * 0.85, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
        }
        .offset(
            x: cx - size / 2,
            y: -(cy - size / 2)
        )
    }
}

// MARK: - Previews

#Preview("512 — Full size") {
    DataStampIcon(size: 512)
        .padding(40)
        .background(Color(NSColor.windowBackgroundColor))
}

#Preview("128 — Medium") {
    DataStampIcon(size: 128)
        .padding(20)
        .background(Color(NSColor.windowBackgroundColor))
}

#Preview("32 — Small (dock/finder)") {
    DataStampIcon(size: 32)
        .padding(10)
        .background(Color(NSColor.windowBackgroundColor))
}

#Preview("All sizes") {
    HStack(spacing: 24) {
        VStack(spacing: 8) {
            DataStampIcon(size: 512)
            Text("512").font(.caption).foregroundStyle(.secondary)
        }
        VStack(spacing: 8) {
            DataStampIcon(size: 128)
            Text("128").font(.caption).foregroundStyle(.secondary)
        }
        VStack(spacing: 8) {
            DataStampIcon(size: 64)
            Text("64").font(.caption).foregroundStyle(.secondary)
        }
        VStack(spacing: 8) {
            DataStampIcon(size: 32)
            Text("32").font(.caption).foregroundStyle(.secondary)
        }
        VStack(spacing: 8) {
            DataStampIcon(size: 16)
            Text("16").font(.caption).foregroundStyle(.secondary)
        }
    }
    .padding(32)
    .background(Color(NSColor.windowBackgroundColor))
}
