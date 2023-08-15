struct UpcomingEventModel: Equatable, Identifiable {
  var id: String { "\(sourceTitle)_\(calendarTitle)_\(time)_\(title)" }
  private(set) var sourceTitle: String
  private(set) var calendarTitle: String
  private(set) var time: String
  private(set) var title: String
}
