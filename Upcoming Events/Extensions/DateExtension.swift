import Foundation

extension Date: ExtensionCompatible {}

public extension Extension where Base == Date {
  var dateString: String {
    let df = DateFormatter()
    df.dateFormat = "M/dd"
    return df.string(from: base)
  }

  var timeString: String {
    let df = DateFormatter()
    df.dateFormat = "HH:mm"
    return df.string(from: base)
  }
}
