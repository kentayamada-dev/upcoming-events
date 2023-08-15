struct CalendarModel: Codable, Identifiable {
  var id: String { title }
  private(set) var title: String
  var enabled: Bool
}
