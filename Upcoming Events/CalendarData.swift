import EventKit
import Foundation

final class CalendarData: ObservableObject {
  private let calendarsKey = "calendars"
  private let userDefaults = UserDefaults.standard
  private let eventStore: EKEventStore = .init()
  private var allCalendars: [EKCalendar] = []
  @Published private(set) var nextEvent: EKEvent?
  @Published private(set) var isAuthorized = false
  @Published private(set) var calendarsDict: CalendarsDictType = [:]
  @Published private(set) var upcomingEventsDict: UpcomingEventsDictType = [:]

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
        let upcomingEvents = getUpcomingEvents(calendarsDict: calendarsDict)
        if !upcomingEvents.isEmpty {
          if nextEvent != upcomingEvents[0] {
            nextEvent = upcomingEvents[0]
          }
          let newUpcomingEventsDict = getUpcomingEventsDict(upcomingEvents: upcomingEvents)
          if upcomingEventsDict != newUpcomingEventsDict {
            upcomingEventsDict = newUpcomingEventsDict
          }
        } else {
          if nextEvent != nil {
            nextEvent = nil
          }
          if !upcomingEventsDict.isEmpty {
            upcomingEventsDict = [:]
          }
        }
      }
    }
  }

  private func getUpcomingEvents(calendarsDict: CalendarsDictType) -> UpcomingEventsType {
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

  private func getUpcomingEventsDict(upcomingEvents: UpcomingEventsType) -> UpcomingEventsDictType {
    var upcomingEventsDict: UpcomingEventsDictType = [:]
    for upcomingEvent in upcomingEvents {
      let date = upcomingEvent.startDate.ex.dateString
      let time = upcomingEvent.startDate.ex.timeString
      if !upcomingEventsDict.keys.contains(date) {
        upcomingEventsDict.updateValue([], forKey: date)
      }
      upcomingEventsDict[date]?.append(UpcomingEventModel(sourceTitle: upcomingEvent.calendar.source.title, calendarTitle: upcomingEvent.calendar.title, time: time, title: upcomingEvent.title))
    }
    return upcomingEventsDict
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
