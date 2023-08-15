import SwiftUI

struct SettingsTabView: View {
  private(set) var isAuthorized: Bool
  private(set) var calendarsDict: CalendarsDictType
  private(set) var toggleCalendar: (String, String) async throws -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      if isAuthorized {
        ForEach(calendarsDict.keys.sorted(), id: \.self) { key in
          VStack(alignment: .leading) {
            Text(key).font(.headline)
            ForEach(calendarsDict[key] ?? []) { calendar in
              Toggle(calendar.title, isOn: Binding(get: {
                calendar.enabled
              }, set: { _ in
                Task {
                  try await toggleCalendar(key, calendar.title)
                }
              })).font(.subheadline)
            }
          }
        }
      } else {
        Text("Not Authorized")
      }
    }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading).padding(.horizontal, 10)
  }
}
