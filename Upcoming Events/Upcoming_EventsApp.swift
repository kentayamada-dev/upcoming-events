import EventKit
import MenuBarExtraAccess
import SwiftUI

struct UpcomingEventModel: Identifiable {
  var id: String { time + title }
  private(set) var time: String
  private(set) var title: String
}

struct CalendarModel: Codable, Identifiable {
  var id: String { title }
  private(set) var title: String
  var enabled: Bool
}

typealias UpcomingEventsDictType = [String: [UpcomingEventModel]]
typealias CalendarsType = [CalendarModel]
typealias CalendarsDictType = [String: CalendarsType]

func DateFormatterToString(dateFormat: String, date: Date) -> String {
  let df = DateFormatter()
  df.dateFormat = dateFormat
  return df.string(from: date)
}

final class BaseViewModel: ObservableObject {
  private let calendarsKey = "calendars"
  private let userDefaults = UserDefaults.standard
  private let eventStore: EKEventStore = .init()
  private var allCalendars: [EKCalendar] = []
  @Published private(set) var nextEvent: EKEvent? {
    didSet {
      print("nextEvent")
    }
  }
  
  @Published private(set) var isAuthorized = false {
    didSet {
      print("isAuthorized")
    }
  }
  
  @Published private(set) var calendarsDict: CalendarsDictType = [:] {
    didSet {
      print("calendarsDict")
    }
  }
  
  @Published private(set) var upcomingEventsDict: UpcomingEventsDictType = [:] {
    didSet {
      print("upcomingEventsDict")
    }
  }
  
  init() {
    Task {
      guard try await Task(operation: { @MainActor in
        isAuthorized = try await eventStore.requestAccess(to: .event)
        return isAuthorized
      }).value == true else {
        return
      }
      allCalendars = eventStore.calendars(for: .event)
      try await Task { @MainActor in
        calendarsDict = try await getCalendarsDict(allCalendars: allCalendars)
      }.value
      setUpcomingEventsAndTimeRemainingLabel()
      NotificationCenter.default.addObserver(self, selector: #selector(setUpcomingEventsAndTimeRemainingLabel), name: .EKEventStoreChanged, object: nil)
    }
  }
  
  @objc
  func setUpcomingEventsAndTimeRemainingLabel() {
    Task {
      await MainActor.run {
        if !upcomingEventsDict.isEmpty {
          upcomingEventsDict = [:]
        }
        if nextEvent != nil {
          nextEvent = nil
        }
        let upcomingEvents = getUpcomingEvents(calendarsDict: calendarsDict)
        if !upcomingEvents.isEmpty {
          nextEvent = upcomingEvents[0]
          upcomingEventsDict = getUpcomingEventsDict(upcomingEvents: upcomingEvents, upcomingEventsDict: upcomingEventsDict)
        }
      }
    }
  }
  
  private func getUpcomingEvents(calendarsDict: CalendarsDictType) -> Array<EKEvent>.SubSequence {
    let filteredCalendars = allCalendars.filter { calendar in
      calendarsDict[calendar.source.title]?.first(where: { $0.title == calendar.title })?.enabled ?? false
    }
    if filteredCalendars.isEmpty {
      return []
    }
    let startDate = Date()
    guard let endDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: startDate) else { return [] }
    let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: filteredCalendars)
    return eventStore.events(matching: predicate).filter { $0.startDate.compare(startDate) == .orderedDescending }.prefix(5)
  }
  
  private func getUpcomingEventsDict(upcomingEvents: Array<EKEvent>.SubSequence, upcomingEventsDict: UpcomingEventsDictType) -> UpcomingEventsDictType {
    var tempUpcomingEventsDict = upcomingEventsDict
    for upcomingEvent in upcomingEvents {
      let date = DateFormatterToString(dateFormat: "M/dd", date: upcomingEvent.startDate)
      let time = DateFormatterToString(dateFormat: "HH:mm", date: upcomingEvent.startDate)
      if !tempUpcomingEventsDict.keys.contains(date) {
        tempUpcomingEventsDict.updateValue([], forKey: date)
      }
      tempUpcomingEventsDict[date]?.append(UpcomingEventModel(time: time, title: upcomingEvent.title))
    }
    return tempUpcomingEventsDict
  }
  
  private func getCalendarsDict(allCalendars: [EKCalendar]) async throws -> CalendarsDictType {
    var calendarsDict: CalendarsDictType = [:]
    if let savedcalendars = userDefaults.data(forKey: calendarsKey) {
      calendarsDict = try JSONDecoder().decode(CalendarsDictType.self, from: savedcalendars)
      return calendarsDict
    }
    allCalendars.forEach {
      let title = $0.source.title
      if !calendarsDict.keys.contains(title) {
        calendarsDict.updateValue([], forKey: title)
      }
      calendarsDict[title]?.append(CalendarModel(title: $0.title, enabled: false))
    }
    return calendarsDict
  }
  
  func toggleCalendar(key: String, title: String) async throws {
    await MainActor.run {
      if var titles = calendarsDict[key] {
        if let index = titles.firstIndex(where: { $0.title == title }) {
          titles[index].enabled.toggle()
          calendarsDict[key] = titles
        }
      }
    }
    let data = try JSONEncoder().encode(calendarsDict)
    userDefaults.set(data, forKey: calendarsKey)
    
    setUpcomingEventsAndTimeRemainingLabel()
  }
}

struct LabelView: View {
  private let timer = DispatchSource.makeTimerSource(flags: .strict)
  private(set) var isAuthorized: Bool
  private(set) var nextEvent: EKEvent?
  private(set) var setUpcomingEventsAndTimeRemainingLabel: () -> Void
  @State private var timeRemainingLabel = ""
  @State private var tempNextEvent: EKEvent?
  
  var body: some View {
    let _ = Self._printChanges()
    let showTimeRemainingLabel = isAuthorized && !timeRemainingLabel.isEmpty
    return VStack {
      if showTimeRemainingLabel {
        Text(timeRemainingLabel)
      } else {
        Image(systemName: "message.fill")
      }
    }.onChange(of: nextEvent) { nextEvent in
      tempNextEvent = nextEvent
    }.onAppear {
      startTimer()
    }
  }
  
  private func startTimer() {
    let now = Date()
    let calendar = Calendar.current
    let nextNanosecond = calendar.date(byAdding: .nanosecond, value: 1 - calendar.component(.nanosecond, from: now), to: now)!
    let intervalToWait = nextNanosecond.timeIntervalSince(now)
    
    timer.schedule(wallDeadline: .now() + intervalToWait, repeating: 1)
    timer.setEventHandler {
      eventHandler(nextEvent: tempNextEvent)
    }
    timer.resume()
  }
  
  private func eventHandler(nextEvent: EKEvent?) {
    if let nextEventDate = nextEvent?.startDate {
      let timeDiff = Int(ceil(getTimeDiff(date: nextEventDate)))
      if timeDiff == 0 {
        setUpcomingEventsAndTimeRemainingLabel()
      }
      timeRemainingLabel = getTimeRemainingLabel(title: nextEvent!.title, timeDiff: Int(ceil(getTimeDiff(date: nextEvent!.startDate))), date: nextEvent!.startDate)
    } else {
      timeRemainingLabel = ""
    }
  }
  
  private func getTimeDiff(date: Date) -> TimeInterval {
    return date.timeIntervalSince(Date())
  }
  
  private func getTimeRemainingLabel(title: String, timeDiff: Int, date: Date) -> String {
    let seconds = timeDiff % 60
    let minutes = (timeDiff / 60) % 60
    let hours = (timeDiff / 3600)
    
    if timeDiff < 1 {
      return ""
    } else if timeDiff < 60 {
      return "\(title) \(seconds)秒"
    } else if timeDiff <= 3600 {
      return "\(title) \(minutes + 1)分"
    } else if timeDiff <= 86400 {
      return "\(title) \(hours)時間 \(minutes + 1)分"
    }
    return "\(title) \(DateFormatterToString(dateFormat: "M/dd", date: date))"
  }
}

struct ListView: View {
  @ObservedObject private(set) var baseViewModel: BaseViewModel
  
  var body: some View {
    let _ = Self._printChanges()
    let upcomingEventsDict = baseViewModel.upcomingEventsDict
    let isAuthorized = baseViewModel.isAuthorized
    return VStack {
      if isAuthorized {
        if upcomingEventsDict.isEmpty {
          Text("No upcoming events within a week.")
        } else {
          ForEach(upcomingEventsDict.keys.sorted(), id: \.self) { key in
            VStack(alignment: .leading) {
              Text(key).font(.headline).padding(.bottom, 5)
              Grid(alignment: .leading, horizontalSpacing: 30, verticalSpacing: 10) {
                ForEach(upcomingEventsDict[key] ?? []) { upcomingEvent in
                  GridRow {
                    Text(upcomingEvent.time).font(.subheadline)
                    Text(upcomingEvent.title).font(.subheadline)
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

struct SettingsTabView: View {
  private(set) var isAuthorized: Bool
  private(set) var calendarsDict: CalendarsDictType
  private(set) var toggleCalendar: (String, String) async throws -> Void
  
  var body: some View {
    let _ = Self._printChanges()
    return VStack(alignment: .leading, spacing: 20) {
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

@main
struct Upcoming_EventsApp: App {
  @State private var isMenuPresented = true
  @StateObject private var baseViewModel = BaseViewModel()
  
  var body: some Scene {
    MenuBarExtra {
      VStack(spacing: 5) {
        ListView(baseViewModel: baseViewModel)
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
      LabelView(isAuthorized: baseViewModel.isAuthorized, nextEvent: baseViewModel.nextEvent, setUpcomingEventsAndTimeRemainingLabel: baseViewModel.setUpcomingEventsAndTimeRemainingLabel)
    }.menuBarExtraStyle(.window).menuBarExtraAccess(isPresented: $isMenuPresented)
    Settings {
      TabView {
        SettingsTabView(isAuthorized: baseViewModel.isAuthorized, calendarsDict: baseViewModel.calendarsDict, toggleCalendar: baseViewModel.toggleCalendar)
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
