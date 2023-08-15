import EventKit
import SwiftUI

struct LabelView: View {
  private let timer = DispatchSource.makeTimerSource(flags: .strict)
  private(set) var isAuthorized: Bool
  private(set) var nextEvent: EKEvent?
  private(set) var setUpcomingEventsAndTimeRemainingLabel: () -> Void
  @State private var timeRemainingLabel = ""
  @State private var tempNextEvent: EKEvent?

  var body: some View {
    let showTimeRemainingLabel = isAuthorized && !timeRemainingLabel.isEmpty
    VStack {
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
      return "\(title) in \(seconds)s"
    } else if timeDiff <= 3600 {
      return "\(title) in \(minutes + 1)m"
    } else if timeDiff <= 86400 {
      return "\(title) in \(hours)h \(minutes + 1)m"
    }
    return "\(title) in \(date.ex.dateString)d"
  }
}
