import EventKit
import MenuBarExtraAccess
import SwiftUI

@main
struct Upcoming_EventsApp: App {
  @State private var isMenuPresented = true
  @StateObject private var calendarData = CalendarData()
  @State private var tempUpcomingEventsDict: UpcomingEventsDictType = [:]

  var body: some Scene {
    MenuBarExtra {
      VStack(spacing: 5) {
        ListView(isAuthorized: calendarData.isAuthorized, upcomingEventsDict: $tempUpcomingEventsDict)
        Divider()
        Button {
          isMenuPresented = false
          NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
          NSApp.activate(ignoringOtherApps: true)
        } label: {
          Text("Settings")
            .frame(maxWidth: .infinity)
        }
        Button {
          NSApplication.shared.terminate(self)
        } label: {
          Text("Quit")
            .frame(maxWidth: .infinity)
        }
      }.frame(width: 200).padding(5)
    } label: {
      LabelView(isAuthorized: calendarData.isAuthorized, nextEvent: calendarData.nextEvent, setUpcomingEventsAndTimeRemainingLabel: calendarData.setUpcomingEventsAndTimeRemainingLabel)
    }.menuBarExtraStyle(.window).menuBarExtraAccess(isPresented: $isMenuPresented).onChange(of: calendarData.upcomingEventsDict) { upcomingEventsDict in
      tempUpcomingEventsDict = upcomingEventsDict
    }
    Settings {
      TabView {
        SettingsTabView(isAuthorized: calendarData.isAuthorized, calendarsDict: calendarData.calendarsDict, toggleCalendar: calendarData.toggleCalendar)
          .tabItem {
            Label("Settings", systemImage: "gear")
          }
        Text("About")
          .tabItem {
            Label("About", systemImage: "info.circle")
          }
      }.frame(width: 500, height: 200)
    }
  }
}
