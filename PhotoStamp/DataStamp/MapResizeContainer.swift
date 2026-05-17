import SwiftUI
import AppKit

// MARK: - MapEdgeAxis

/// Identifies which edge of the map widget a drag handle is attached to.
enum MapEdgeAxis {
    case top
    case left
}

// MARK: - MapEdgeHandle

/// A drag handle view placed on the top or left edge of the `MapWidget` overlay.
///
/// Mirrors the visual style of `ImageResizeHandle` (horizontal separator + grip dots),
/// rotated 90° for the left-edge variant. Active state thickens the separator line
/// and tints both the line and dots with `Color.dsAccent`.
///
/// - Parameters:
///   - axis: Whether this handle sits on the `.top` (resizes height) or `.left` (resizes width) edge.
///   - isDragging: Binding that the parent sets `true` while a drag gesture is active.
struct MapEdgeHandle: View {
    let axis: MapEdgeAxis
    @Binding var isDragging: Bool

    var body: some View {
        ZStack {
            separatorLine
            hitArea
            gripDots
        }
        .frame(for: axis)
        .onHover { hovering in
            if hovering {
                cursor(for: axis).push()
            } else {
                NSCursor.pop()
            }
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var separatorLine: some View {
        if axis == .top {
            Rectangle()
                .fill(isDragging ? Color.dsAccent.opacity(0.3) : Color(NSColor.separatorColor))
                .frame(height: isDragging ? 3 : 1.0 / 3.0)
        } else {
            Rectangle()
                .fill(isDragging ? Color.dsAccent.opacity(0.3) : Color(NSColor.separatorColor))
                .frame(width: isDragging ? 3 : 1.0 / 3.0)
        }
    }

    /// Invisible 10 pt hit area so the handle is easy to grab.
    @ViewBuilder
    private var hitArea: some View {
        if axis == .top {
            Rectangle()
                .fill(Color.white.opacity(0.001))
                .frame(height: 10)
                .contentShape(Rectangle())
        } else {
            Rectangle()
                .fill(Color.white.opacity(0.001))
                .frame(width: 10)
                .contentShape(Rectangle())
        }
    }

    @ViewBuilder
    private var gripDots: some View {
        let dot = Circle()
            .fill(isDragging ? Color.dsAccent : Color(NSColor.separatorColor))
            .frame(width: 3, height: 3)

        if axis == .top {
            HStack(spacing: 3) {
                dot
                dot
                dot
            }
        } else {
            VStack(spacing: 3) {
                dot
                dot
                dot
            }
        }
    }

    // MARK: - Helpers

    private func cursor(for axis: MapEdgeAxis) -> NSCursor {
        axis == .top ? .resizeUpDown : .resizeLeftRight
    }
}

// MARK: - View frame helper

private extension View {
    /// Applies the correct frame constraints for a top or left edge handle.
    @ViewBuilder
    func frame(for axis: MapEdgeAxis) -> some View {
        if axis == .top {
            self.frame(maxWidth: .infinity, minHeight: 10, maxHeight: 10)
        } else {
            self.frame(minWidth: 10, maxWidth: 10, maxHeight: .infinity)
        }
    }
}

// MARK: - MapToggleButton

/// A plain icon button that shows or hides the `MapWidget` overlay.
///
/// Renders `map.fill` (accent color) when the map is visible and `map` (secondary color)
/// when hidden. Intended for placement in the bottom bar of `ContentView`, gated on
/// `detailGPSCoordinate != nil`.
///
/// - Parameters:
///   - isVisible: Binding to the current map visibility state.
///   - onToggle: Closure called when the button is tapped.
struct MapToggleButton: View {
    @Binding var isVisible: Bool
    let onToggle: () -> Void

    var body: some View {
        Button {
            onToggle()
        } label: {
            Image(systemName: isVisible ? "map.fill" : "map")
                .font(.system(size: 16))
                .foregroundColor(isVisible ? .dsAccent : .secondary)
        }
        .buttonStyle(.plain)
        .help(isVisible ? "Hide map" : "Show map")
        .accessibilityIdentifier("mapToggleButton")
    }
}

// MARK: - clampedMapDimension

/// Returns a map dimension (width or height) clamped to the valid range.
///
/// The minimum is always 100 pt. The maximum is 75 % of `windowDimension`.
/// If `windowDimension` is zero or negative, a safe fallback of 600 pt is used
/// as the effective window size, giving a maximum of 450 pt.
///
/// - Parameters:
///   - value: The proposed dimension in points.
///   - minVal: The minimum allowed value (default 100 pt).
///   - windowDimension: The relevant window dimension (width or height) in points.
/// - Returns: `value` clamped to `[minVal, windowDimension * 0.75]`.
func clampedMapDimension(
    _ value: CGFloat,
    min minVal: CGFloat = 100,
    windowDimension: CGFloat
) -> CGFloat {
    let effectiveMax = windowDimension > 0 ? windowDimension * 0.75 : 600 * 0.75
    return max(minVal, min(effectiveMax, value))
}
