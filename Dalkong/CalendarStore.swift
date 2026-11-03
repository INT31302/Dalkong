import Foundation
import EventKit
import Observation

/// 달력 화면 상단의 요일 머리글 한 칸.
struct WeekdayHeader: Identifiable {
    let weekday: Int
    let symbol: String
    var id: Int { weekday }
}

/// 일정 목록에서 하루 단위로 묶인 일정들.
struct AgendaSection: Identifiable {
    let day: Date
    let events: [EKEvent]
    var id: Date { day }
}

/// 설정 화면에서 계정(iCloud, Google 등)별로 묶어 보여주는 캘린더 목록.
struct CalendarGroup: Identifiable {
    let sourceTitle: String
    let calendars: [EKCalendar]
    var id: String { sourceTitle }
}

/// 날짜 탐색 상태와 EventKit 일정 데이터를 관리합니다.
@Observable
final class CalendarStore {
    static let defaultMenuBarFormat = "M월 d일 (E)"

    /// 앱에 한국어 현지화가 없어 시스템 로케일이 영어로 잡히므로, 날짜·요일 표기를 한국어로 고정합니다.
    static let locale = Locale(identifier: "ko_KR")

    private enum Keys {
        static let firstWeekday = "firstWeekday"
        static let agendaDayCount = "agendaDayCount"
        static let hiddenCalendarIDs = "hiddenCalendarIDs"
    }

    /// 현재 시각. 매 분 정각에 갱신되어 메뉴 막대 표시와 '오늘' 강조에 사용됩니다.
    private(set) var now = Date()

    /// 달력에 표시 중인 달 (해당 달에 속한 아무 날짜).
    var displayedMonth = Date() {
        didSet { reloadEvents() }
    }

    /// 일정 목록의 시작 날짜.
    var selectedDate = Date() {
        didSet { reloadEvents() }
    }

    /// 한 주의 시작 요일 (1 = 일요일, 2 = 월요일, ...).
    var firstWeekday: Int {
        didSet {
            UserDefaults.standard.set(firstWeekday, forKey: Keys.firstWeekday)
            reloadEvents()
        }
    }

    /// 선택한 날짜부터 일정 목록에 보여줄 일수.
    var agendaDayCount: Int {
        didSet {
            UserDefaults.standard.set(agendaDayCount, forKey: Keys.agendaDayCount)
            reloadEvents()
        }
    }

    /// 설정에서 숨긴 캘린더의 식별자. 이 캘린더의 일정은 달력과 목록에 나타나지 않습니다.
    private(set) var hiddenCalendarIDs: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(hiddenCalendarIDs), forKey: Keys.hiddenCalendarIDs)
            reloadEvents()
        }
    }

    private(set) var authorizationStatus: EKAuthorizationStatus
    private(set) var eventsByDay: [Date: [EKEvent]] = [:]
    private(set) var calendarGroups: [CalendarGroup] = []

    private let eventStore = EKEventStore()
    private let menuBarFormatter = DateFormatter()
    @ObservationIgnored private var backgroundTasks: [Task<Void, Never>] = []

    init() {
        let defaults = UserDefaults.standard
        firstWeekday = defaults.object(forKey: Keys.firstWeekday) as? Int ?? Calendar.current.firstWeekday
        agendaDayCount = defaults.object(forKey: Keys.agendaDayCount) as? Int ?? 7
        hiddenCalendarIDs = Set(defaults.stringArray(forKey: Keys.hiddenCalendarIDs) ?? [])
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        reloadCalendars()
        reloadEvents()
        startBackgroundTasks()
    }

    // MARK: - 달력 계산

    var calendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.locale = Self.locale
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    /// 표시 중인 달을 감싸는 6주(42일) 격자의 날짜들.
    var monthDays: [Date] {
        let calendar = calendar
        guard let monthStart = calendar.dateInterval(of: .month, for: displayedMonth)?.start else { return [] }
        let weekday = calendar.component(.weekday, from: monthStart)
        let leadingDays = (weekday - calendar.firstWeekday + 7) % 7
        guard let gridStart = calendar.date(byAdding: .day, value: -leadingDays, to: monthStart) else { return [] }
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }

    /// 시작 요일에 맞춰 회전한 요일 머리글.
    var weekdayHeaders: [WeekdayHeader] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        return (0..<7).map { index in
            let weekday = (firstWeekday - 1 + index) % 7 + 1
            return WeekdayHeader(weekday: weekday, symbol: symbols[weekday - 1])
        }
    }

    func isToday(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: now)
    }

    func isSelected(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }

    func isInDisplayedMonth(_ date: Date) -> Bool {
        calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
    }

    // MARK: - 탐색

    func showMonth(offset: Int) {
        displayedMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonth) ?? displayedMonth
    }

    func goToToday() {
        now = Date()
        displayedMonth = now
        selectedDate = now
    }

    func select(_ date: Date) {
        selectedDate = date
        if !isInDisplayedMonth(date) {
            displayedMonth = date
        }
    }

    // MARK: - 메뉴 막대

    func menuBarTitle(format: String) -> String {
        menuBarFormatter.locale = Self.locale
        menuBarFormatter.dateFormat = format.isEmpty ? "d" : format
        return menuBarFormatter.string(from: now)
    }

    // MARK: - 일정

    var hasAccess: Bool {
        authorizationStatus == .fullAccess
    }

    func refreshAuthorization() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        reloadCalendars()
        reloadEvents()
    }

    // MARK: - 캘린더 표시/숨김

    func isCalendarVisible(_ calendar: EKCalendar) -> Bool {
        !hiddenCalendarIDs.contains(calendar.calendarIdentifier)
    }

    func setCalendar(_ calendar: EKCalendar, visible: Bool) {
        if visible {
            hiddenCalendarIDs.remove(calendar.calendarIdentifier)
        } else {
            hiddenCalendarIDs.insert(calendar.calendarIdentifier)
        }
    }

    /// 계정별로 묶고 이름순으로 정렬한 전체 일정 캘린더 목록을 다시 읽습니다.
    func reloadCalendars() {
        guard hasAccess else {
            calendarGroups = []
            return
        }
        let grouped = Dictionary(grouping: eventStore.calendars(for: .event)) { $0.source?.title ?? "" }
        calendarGroups = grouped
            .map { sourceTitle, calendars in
                CalendarGroup(
                    sourceTitle: sourceTitle,
                    calendars: calendars.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
                )
            }
            .sorted { $0.sourceTitle.localizedStandardCompare($1.sourceTitle) == .orderedAscending }
    }

    func requestAccess() async {
        _ = try? await eventStore.requestFullAccessToEvents()
        refreshAuthorization()
    }

    /// 새 일정을 추가할 수 있는 (읽기 전용이 아닌) 캘린더들.
    var writableCalendars: [EKCalendar] {
        eventStore.calendars(for: .event)
            .filter(\.allowsContentModifications)
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    var defaultCalendarForNewEvents: EKCalendar? {
        eventStore.defaultCalendarForNewEvents
    }

    /// 새 일정의 기본 시작 시각: 선택한 날이 오늘이면 다음 정각, 아니면 그날 오전 9시.
    func defaultNewEventStart() -> Date {
        let calendar = calendar
        if calendar.isDate(selectedDate, inSameDayAs: now) {
            return calendar.nextDate(after: now, matching: DateComponents(minute: 0), matchingPolicy: .nextTime) ?? now
        }
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: selectedDate) ?? selectedDate
    }

    func addEvent(
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool,
        calendarIdentifier: String,
        location: String = "",
        notes: String = "",
        url: URL? = nil,
        repeatFrequency: EKRecurrenceFrequency? = nil,
        alertMinutesBefore: Int? = nil
    ) throws {
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.location = location.isEmpty ? nil : location
        event.notes = notes.isEmpty ? nil : notes
        event.url = url
        if let repeatFrequency {
            event.addRecurrenceRule(EKRecurrenceRule(recurrenceWith: repeatFrequency, interval: 1, end: nil))
        }
        if let alertMinutesBefore {
            event.addAlarm(EKAlarm(relativeOffset: TimeInterval(-alertMinutesBefore * 60)))
        }
        event.isAllDay = isAllDay
        event.startDate = start
        event.endDate = max(end, start)
        event.calendar = eventStore.calendar(withIdentifier: calendarIdentifier) ?? eventStore.defaultCalendarForNewEvents
        try eventStore.save(event, span: .thisEvent)
        // 추가한 일정이 바로 목록에 보이도록 그날로 이동합니다.
        select(start)
        reloadEvents()
    }

    func events(on day: Date) -> [EKEvent] {
        eventsByDay[calendar.startOfDay(for: day)] ?? []
    }

    /// 해당 날짜 일정들의 캘린더 (중복 제거, 최대 3개). 날짜 아래 점 표시에 사용합니다.
    func eventCalendars(on day: Date) -> [EKCalendar] {
        var seen = Set<String>()
        var result: [EKCalendar] = []
        for event in events(on: day) {
            guard let calendar = event.calendar, seen.insert(calendar.calendarIdentifier).inserted else { continue }
            result.append(calendar)
            if result.count == 3 { break }
        }
        return result
    }

    /// 선택한 날짜부터 `agendaDayCount`일 동안 일정이 있는 날만 모은 목록.
    var agendaSections: [AgendaSection] {
        let calendar = calendar
        let start = calendar.startOfDay(for: selectedDate)
        return (0..<agendaDayCount).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start),
                  let events = eventsByDay[day], !events.isEmpty else { return nil }
            return AgendaSection(day: day, events: events)
        }
    }

    /// 달력 격자와 일정 목록 범위를 모두 덮도록 일정을 다시 불러와 날짜별로 나눕니다.
    func reloadEvents() {
        guard hasAccess else {
            eventsByDay = [:]
            return
        }

        let calendar = calendar
        let days = monthDays
        let agendaStart = calendar.startOfDay(for: selectedDate)
        guard let gridStart = days.first,
              let lastDay = days.last,
              let gridEnd = calendar.date(byAdding: .day, value: 1, to: lastDay),
              let agendaEnd = calendar.date(byAdding: .day, value: agendaDayCount, to: agendaStart) else { return }

        let visibleCalendars = eventStore.calendars(for: .event).filter(isCalendarVisible)
        guard !visibleCalendars.isEmpty else {
            // 빈 배열을 넘기면 EventKit이 전체 캘린더로 취급할 수 있으므로 직접 비웁니다.
            eventsByDay = [:]
            return
        }

        let rangeStart = min(gridStart, agendaStart)
        let rangeEnd = max(gridEnd, agendaEnd)
        let predicate = eventStore.predicateForEvents(withStart: rangeStart, end: rangeEnd, calendars: visibleCalendars)

        var grouped: [Date: [EKEvent]] = [:]
        for event in eventStore.events(matching: predicate) {
            // 여러 날에 걸친 일정은 걸쳐 있는 모든 날에 추가합니다. 길이가 0인 일정도 최소 하루에는 들어갑니다.
            var day = calendar.startOfDay(for: max(event.startDate, rangeStart))
            let end = min(event.endDate, rangeEnd)
            repeat {
                grouped[day, default: []].append(event)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            } while day < end
        }

        for (day, events) in grouped {
            grouped[day] = events.sorted { lhs, rhs in
                if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
                return lhs.startDate < rhs.startDate
            }
        }
        eventsByDay = grouped
    }

    // MARK: - 백그라운드 갱신

    private func startBackgroundTasks() {
        // 매 분 정각에 현재 시각을 갱신하고, 날짜가 바뀌면 일정을 다시 불러옵니다.
        backgroundTasks.append(Task { [weak self] in
            while !Task.isCancelled {
                let current = Date()
                let nextMinute = Calendar.current.nextDate(
                    after: current,
                    matching: DateComponents(second: 0),
                    matchingPolicy: .nextTime
                ) ?? current.addingTimeInterval(60)
                try? await Task.sleep(for: .seconds(nextMinute.timeIntervalSince(current)))

                guard let self else { return }
                let previous = now
                now = Date()
                if !calendar.isDate(previous, inSameDayAs: now) {
                    reloadEvents()
                }
            }
        })

        // 다른 앱이나 동기화로 일정이 바뀌면 다시 불러옵니다.
        backgroundTasks.append(Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .EKEventStoreChanged) {
                self?.reloadCalendars()
                self?.reloadEvents()
            }
        })

        // 시간대 변경 등으로 날짜가 바뀐 경우.
        backgroundTasks.append(Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .NSCalendarDayChanged) {
                guard let self else { return }
                now = Date()
                reloadEvents()
            }
        })
    }
}
