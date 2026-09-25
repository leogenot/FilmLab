import SwiftUI

enum NumericControlValue {
  static func parse(_ text: String, range: ClosedRange<Double>) -> Double? {
    let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: ",", with: ".")
    guard let number = Double(normalized), number.isFinite else { return nil }
    return min(max(number, range.lowerBound), range.upperBound)
  }

  static func display(_ value: Double, fractionDigits: Int) -> String {
    value.formatted(
      .number.grouping(.never).precision(.fractionLength(fractionDigits)))
  }
}

struct NumericControlField: View {
  let title: String
  @Binding var value: Double
  let range: ClosedRange<Double>
  let fractionDigits: Int

  @State private var draft = ""
  @FocusState private var isFocused: Bool

  var body: some View {
    TextField(title, text: $draft)
      .textFieldStyle(.plain)
      .multilineTextAlignment(.trailing)
      .monospacedDigit()
      .frame(width: fractionDigits == 0 ? 72 : 62)
      .padding(.horizontal, 5)
      .padding(.vertical, 3)
      .background(Color.white.opacity(0.055))
      .clipShape(RoundedRectangle(cornerRadius: 4))
      .accessibilityLabel("\(title) value")
      .focused($isFocused)
      .onAppear { draft = NumericControlValue.display(value, fractionDigits: fractionDigits) }
      .onChange(of: value) {
        draft = NumericControlValue.display(value, fractionDigits: fractionDigits)
      }
      .onChange(of: isFocused) {
        if !isFocused { commit() }
      }
      .onSubmit {
        isFocused = false
      }
  }

  private func commit() {
    let displayed = NumericControlValue.display(value, fractionDigits: fractionDigits)
    if draft != displayed,
      let committed = NumericControlValue.parse(draft, range: range)
    {
      value = committed
    }
    draft = NumericControlValue.display(value, fractionDigits: fractionDigits)
  }
}
