import SwiftUI

// MARK: - DateStampPicker

struct DateStampPicker: View {

    @Binding var date: Date
    /// True whenever the field is focused OR contains an invalid date.
    /// Callers should disable the Stamp button when this is true.
    @Binding var hasError: Bool

    @ObservedObject private var settings = SettingsStore.shared

    @State private var textValue: String = ""
    @FocusState private var fieldFocused: Bool

    // Three mutually exclusive states
    private enum FieldState { case valid, editing, invalid }

    @State private var fieldState: FieldState = .valid

    private let acceptedFormats = [
        "MM/dd/yyyy", "M/d/yyyy", "yyyy-MM-dd",
        "MMMM d, yyyy", "MMM d, yyyy", "MM-dd-yyyy",
    ]

    var body: some View {
        Group {
            switch settings.datePickerStyle {
            case .compact:
                DatePicker("", selection: $date, displayedComponents: [.date])
                    .labelsHidden()
                    .datePickerStyle(.field)
            case .textField:
                typeableField
            }
        }
    }

    // MARK: - Typeable field

    private var typeableField: some View {
        HStack(spacing: 6) {
            ZStack(alignment: .leading) {
                // Placeholder
                if textValue.isEmpty {
                    Text("e.g. 07/07/1977")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 8)
                }

                TextField("", text: $textValue)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .focused($fieldFocused)
                    .onAppear {
                        textValue = formatDate(date)
                        fieldState = .valid
                        hasError = false
                    }
                    // External date change — sync text only when not editing
                    .onChange(of: date) { newDate in
                        if !fieldFocused {
                            textValue = formatDate(newDate)
                            fieldState = .valid
                            hasError = false
                        }
                    }
                    // Live feedback as user types
                    .onChange(of: textValue) { newValue in
                        liveValidate(newValue)
                    }
                    // Focus gained — switch to editing state
                    .onChange(of: fieldFocused) { focused in
                        if focused {
                            // Only move to editing if currently valid
                            if fieldState == .valid {
                                fieldState = .editing
                                hasError = true
                            }
                        } else {
                            // Focus lost — commit
                            commitText()
                        }
                    }
                    // Enter key — commit
                    .onSubmit { commitText() }
                    .accessibilityIdentifier("dateTextField")
            }
            .frame(width: 130)
            .background(fieldBackground)

            // Status icon — always visible, reflects current state
            statusIcon
        }
        .animation(.easeInOut(duration: 0.15), value: fieldState == .valid)
        .animation(.easeInOut(duration: 0.15), value: fieldState == .invalid)
    }

    // MARK: - Styling helpers

    private var borderColor: Color {
        switch fieldState {
        case .valid:   return .green
        case .editing: return .dsAccent
        case .invalid: return .red
        }
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(
                fieldState == .invalid
                    ? Color.red.opacity(0.07)
                    : fieldState == .valid
                        ? Color.green.opacity(0.06)
                        : Color(NSColor.controlBackgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1.5)
            )
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch fieldState {
        case .valid:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 14))
                .transition(.scale.combined(with: .opacity))
                .accessibilityIdentifier("dateValidIcon")

        case .editing:
            // No icon while editing — border colour is enough feedback
            EmptyView()

        case .invalid:
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.system(size: 14))
                Text("Invalid")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            .transition(.opacity)
            .accessibilityIdentifier("dateInvalidLabel")
        }
    }

    // MARK: - Validation logic

    /// Live check while typing — sets editing vs invalid, never commits the date yet.
    private func liveValidate(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)

        guard !trimmed.isEmpty else {
            fieldState = fieldFocused ? .editing : .invalid
            hasError = true
            return
        }

        if tryParse(trimmed) != nil {
            // Parseable — show green immediately
            fieldState = .valid
            hasError = false
        } else {
            // Not parseable yet — blue while short, red once long enough to be wrong
            fieldState = (trimmed.count >= 6 && fieldFocused) ? .invalid : .editing
            hasError = true
        }
    }

    /// Commit on Enter or focus loss — finalises the date or locks in the error.
    private func commitText() {
        let trimmed = textValue.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            fieldState = .invalid
            hasError = true
            return
        }
        if let parsed = tryParse(trimmed) {
            date = parsed
            textValue = formatDate(parsed)
            fieldState = .valid
            hasError = false
        } else {
            fieldState = .invalid
            hasError = true
        }
    }

    private func tryParse(_ text: String) -> Date? {
        parseDateString(text)
    }

    private func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM/dd/yyyy"
        return f.string(from: d)
    }
}

// MARK: - Testable free function

/// Parses `text` against the six accepted date formats used by `DateStampPicker`.
/// Returns the parsed `Date` when exactly one format matches and the year is in
/// `[1000, 9999]`; returns `nil` otherwise.
///
/// Declared `internal` so it is accessible from the `DataStampTests` test target
/// without needing to instantiate the SwiftUI view.
///
/// **Separator enforcement**: `DateFormatter` (backed by ICU) treats separator
/// characters as interchangeable even with `isLenient = false`, so `"07.07.1977"`
/// would otherwise match `MM/dd/yyyy`. For numeric-separator formats we explicitly
/// require the input to contain the expected separator and to contain no other
/// common date-separator characters (`/`, `-`, `.`, space).
func parseDateString(_ text: String) -> Date? {
    // Formats whose fields are separated by a single punctuation character.
    // We enforce that the input uses exactly that separator.
    let numericSepFormats: [(format: String, sep: Character)] = [
        ("MM/dd/yyyy", "/"),
        ("M/d/yyyy",   "/"),
        ("yyyy-MM-dd", "-"),
        ("MM-dd-yyyy", "-"),
    ]
    // Formats that use month names — no separator restriction needed.
    let wordFormats = ["MMMM d, yyyy", "MMM d, yyyy"]

    let allNumericSeps: Set<Character> = ["/", "-", ".", " "]

    for (fmt, expectedSep) in numericSepFormats {
        // Input must contain the expected separator …
        guard text.contains(expectedSep) else { continue }
        // … and must NOT contain any other common date-separator character.
        let forbidden = allNumericSeps.subtracting([expectedSep])
        guard !forbidden.contains(where: { text.contains($0) }) else { continue }

        let f = DateFormatter()
        f.dateFormat = fmt
        f.locale = Locale(identifier: "en_US_POSIX")
        f.isLenient = false
        if let d = f.date(from: text) {
            let year = Calendar.current.component(.year, from: d)
            guard year >= 1000 && year <= 9999 else { continue }
            return d
        }
    }

    for fmt in wordFormats {
        let f = DateFormatter()
        f.dateFormat = fmt
        f.locale = Locale(identifier: "en_US_POSIX")
        f.isLenient = false
        if let d = f.date(from: text) {
            let year = Calendar.current.component(.year, from: d)
            guard year >= 1000 && year <= 9999 else { continue }
            return d
        }
    }

    return nil
}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        Text("Calendar").font(.caption).foregroundStyle(.secondary)
        DatePicker("", selection: .constant(Date()), displayedComponents: [.date])
            .labelsHidden().datePickerStyle(.compact)

        Text("Type Date").font(.caption).foregroundStyle(.secondary)
        DateStampPicker(date: .constant(Date()), hasError: .constant(false))
    }
    .padding(24)
    .frame(width: 340)
    .background(Color(NSColor.windowBackgroundColor))
}
