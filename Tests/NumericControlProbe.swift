import Foundation

@main
enum NumericControlProbe {
  static func main() {
    precondition(NumericControlValue.parse("1,25", range: -3...3) == 1.25)
    precondition(NumericControlValue.parse("1.25", range: -3...3) == 1.25)
    precondition(NumericControlValue.parse("9", range: -3...3) == 3)
    precondition(NumericControlValue.parse("-9", range: -3...3) == -3)
    precondition(NumericControlValue.parse("nan", range: -3...3) == nil)
    precondition(NumericControlValue.parse("garbage", range: -3...3) == nil)
    precondition(NumericControlValue.display(5634, fractionDigits: 0) == "5634")
    print("Precise numeric parsing and bounds checks passed")
  }
}
