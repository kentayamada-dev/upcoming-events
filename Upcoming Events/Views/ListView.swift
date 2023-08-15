import SwiftUI

struct ListView: View {
  private(set) var isAuthorized: Bool
  @Binding private(set) var upcomingEventsDict: UpcomingEventsDictType

  var body: some View {
    VStack(alignment: .leading) {
      if isAuthorized {
        if upcomingEventsDict.isEmpty {
          Text("No upcoming events within a week.")
        } else {
          ForEach(upcomingEventsDict.keys.sorted(), id: \.self) { key in
            VStack(alignment: .leading) {
              Text(key).font(.system(size: 15, weight: .bold, design: .monospaced)).padding(.bottom, 5)
              Grid(alignment: .leading, horizontalSpacing: 30, verticalSpacing: 10) {
                ForEach(upcomingEventsDict[key] ?? []) { upcomingEvent in
                  GridRow {
                    Text(upcomingEvent.time).font(.system(size: 12, design: .monospaced))
                    Text(upcomingEvent.title).font(.system(size: 13))
                  }
                }
              }
            }.padding(.bottom, 15)
          }
        }
      } else {
        Text("Not Authorized")
      }
      Spacer()
    }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }
}
