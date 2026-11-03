import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> MonthEntry {
        MonthEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (MonthEntry) -> Void) {
        completion(MonthEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MonthEntry>) -> Void) {
        let currentDate = Date()
        let calendar = Calendar.current
        // 자정 1초 뒤에 갱신하여 날짜가 바뀌자마자 오늘 하이라이트를 최신화합니다.
        let nextMidnight = calendar.nextDate(
            after: currentDate,
            matching: DateComponents(hour: 0, minute: 0, second: 1),
            matchingPolicy: .nextTime
        ) ?? currentDate.addingTimeInterval(3600)

        let entry = MonthEntry(date: currentDate)
        let timeline = Timeline(entries: [entry], policy: .after(nextMidnight))
        completion(timeline)
    }
}

// MARK: - Timeline Entry

struct MonthEntry: TimelineEntry {
    let date: Date
}

// MARK: - Calendar Calculation Model

struct CalendarDay: Identifiable {
    let id: Int
    let date: Date?
    let dayNumber: Int?
    let weekday: Int
    let isToday: Bool
}

struct MonthCalendarData {
    let referenceDate: Date
    let calendar: Calendar

    init(date: Date) {
        self.referenceDate = date
        var cal = Calendar.autoupdatingCurrent
        cal.locale = Locale(identifier: "ko_KR")
        self.calendar = cal
    }

    var yearString: String {
        let formatter = DateFormatter()
        formatter.locale = calendar.locale
        formatter.dateFormat = "yyyy년"
        return formatter.string(from: referenceDate)
    }

    var monthString: String {
        let formatter = DateFormatter()
        formatter.locale = calendar.locale
        formatter.dateFormat = "M월"
        return formatter.string(from: referenceDate)
    }

    var fullMonthString: String {
        let formatter = DateFormatter()
        formatter.locale = calendar.locale
        formatter.dateFormat = "yyyy년 M월"
        return formatter.string(from: referenceDate)
    }

    var todayFullDateString: String {
        let formatter = DateFormatter()
        formatter.locale = calendar.locale
        formatter.dateFormat = "M월 d일 (E)"
        return formatter.string(from: referenceDate)
    }

    var weekdaySymbolToday: String {
        let formatter = DateFormatter()
        formatter.locale = calendar.locale
        formatter.dateFormat = "EEEE"
        return formatter.string(from: referenceDate)
    }

    var dayNumberToday: Int {
        calendar.component(.day, from: referenceDate)
    }

    var weekdayHeaders: [(symbol: String, weekday: Int)] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let firstWeekday = calendar.firstWeekday
        return (0..<7).map { index in
            let weekday = (firstWeekday - 1 + index) % 7 + 1
            return (symbols[weekday - 1], weekday)
        }
    }

    /// 현재 표시되는 달의 날짜 그리드를 생성합니다. 이전/다음 달의 여백 날짜는 nil(빈칸) 처리합니다.
    var calendarDays: [CalendarDay] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: referenceDate) else { return [] }
        let monthStart = monthInterval.start
        let weekdayOfFirst = calendar.component(.weekday, from: monthStart)
        let leadingBlanks = (weekdayOfFirst - calendar.firstWeekday + 7) % 7

        guard let range = calendar.range(of: .day, in: .month, for: referenceDate) else { return [] }
        let numberOfDays = range.count

        var items: [CalendarDay] = []
        var idCounter = 0

        // 1일 이전 앞쪽 빈칸
        for i in 0..<leadingBlanks {
            let weekday = (calendar.firstWeekday - 1 + i) % 7 + 1
            items.append(CalendarDay(id: idCounter, date: nil, dayNumber: nil, weekday: weekday, isToday: false))
            idCounter += 1
        }

        // 해당 월의 날짜들 (1 ~ 말일)
        for day in 1...numberOfDays {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                let weekday = calendar.component(.weekday, from: date)
                let isToday = calendar.isDate(date, inSameDayAs: referenceDate)
                items.append(CalendarDay(id: idCounter, date: date, dayNumber: day, weekday: weekday, isToday: isToday))
                idCounter += 1
            }
        }

        // 7열 맞춤을 위한 뒤쪽 빈칸
        let remainder = items.count % 7
        if remainder != 0 {
            let trailingBlanks = 7 - remainder
            for i in 0..<trailingBlanks {
                let weekday = (calendar.firstWeekday - 1 + (remainder + i)) % 7 + 1
                items.append(CalendarDay(id: idCounter, date: nil, dayNumber: nil, weekday: weekday, isToday: false))
                idCounter += 1
            }
        }

        return items
    }

    var rowCount: Int {
        max(1, calendarDays.count / 7)
    }
}

// MARK: - Day Cell Component

private struct DayCellView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let item: CalendarDay
    let fontSize: CGFloat
    let circleSize: CGFloat

    private var isTintedMode: Bool {
        renderingMode == .accented || renderingMode == .vibrant
    }

    var body: some View {
        if let dayNum = item.dayNumber {
            if item.isToday {
                ZStack {
                    if isTintedMode {
                        // [데스크탑 어두운/틴트/글래스 모드]: 단색 원이 글자를 삼키지 않도록 링 + 반투명 베이스로 텍스트 100% 보존
                        Circle()
                            .fill(Color.primary.opacity(0.18))
                        Circle()
                            .strokeBorder(Color.primary, lineWidth: 2)
                        Text("\(dayNum)")
                            .font(.system(size: fontSize, weight: .bold).monospacedDigit())
                            .foregroundStyle(Color.primary)
                    } else {
                        // [일반/풀컬러 모드]: 사용자가 가장 선호했던 선명하고 산뜻한 파란색 솔리드 원 + 흰색 숫자
                        Circle()
                            .fill(Color.blue)
                        Text("\(dayNum)")
                            .font(.system(size: fontSize, weight: .bold).monospacedDigit())
                            .foregroundStyle(Color.white)
                    }
                }
                .frame(width: circleSize, height: circleSize)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("\(dayNum)")
                    .font(.system(size: fontSize, weight: .medium).monospacedDigit())
                    .foregroundStyle(dateColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var dateColor: Color {
        let isWeekend = (item.weekday == 1 || item.weekday == 7)
        if isTintedMode {
            // 틴트 모드: 주말은 요청대로 은은하게 톤다운
            return isWeekend ? Color.primary.opacity(0.38) : Color.primary.opacity(0.95)
        } else {
            // 풀컬러 모드: 일요일 빨강, 토요일 파랑, 평일 프라이머리
            switch item.weekday {
            case 1: return Color.red
            case 7: return Color.blue
            default: return Color.primary
            }
        }
    }
}

// MARK: - Weekday Header Component

private struct WeekdayHeaderRow: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let headers: [(symbol: String, weekday: Int)]
    let fontSize: CGFloat

    private var isTintedMode: Bool {
        renderingMode == .accented || renderingMode == .vibrant
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                Text(header.symbol)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundStyle(headerColor(for: header.weekday))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func headerColor(for weekday: Int) -> Color {
        if isTintedMode {
            let isWeekend = (weekday == 1 || weekday == 7)
            return isWeekend ? Color.primary.opacity(0.42) : Color.primary.opacity(0.9)
        } else {
            switch weekday {
            case 1: return Color.red
            case 7: return Color.blue
            default: return Color.secondary
            }
        }
    }
}

// MARK: - Widget Views

struct MonthWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: MonthEntry

    var body: some View {
        let data = MonthCalendarData(date: entry.date)
        Group {
            switch family {
            case .systemSmall:
                SmallMonthView(data: data)
            case .systemMedium:
                MediumMonthView(data: data)
            case .systemLarge, .systemExtraLarge:
                LargeMonthView(data: data)
            default:
                SmallMonthView(data: data)
            }
        }
        // 위젯 클릭 시 macOS 기본 캘린더 앱(Calendar.app) 열기
        .widgetURL(URL(string: "dalkong://calendar"))
    }
}

// MARK: - Small Widget View

struct SmallMonthView: View {
    let data: MonthCalendarData

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                Text(data.monthString)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer()

                Text(data.yearString)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 4)

            // Weekday Headers
            WeekdayHeaderRow(headers: data.weekdayHeaders, fontSize: 10)
                .padding(.bottom, 2)

            // Calendar Grid: 불필요한 바깥 여백 없이 높이를 균등하게 채움
            let days = data.calendarDays
            let rows = data.rowCount
            VStack(spacing: 0) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { col in
                            let index = row * 7 + col
                            if index < days.count {
                                DayCellView(
                                    item: days[index],
                                    fontSize: 10,
                                    circleSize: 18
                                )
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(12)
    }
}

// MARK: - Medium Widget View

struct MediumMonthView: View {
    let data: MonthCalendarData

    var body: some View {
        HStack(spacing: 12) {
            // Left Column: Liquid Glass Today Card
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(data.monthString)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                }

                Spacer()

                Text("\(data.dayNumberToday)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.blue)

                Text(data.weekdaySymbolToday)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(12)
            .frame(width: 98)
            .frame(maxHeight: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))

            // Right Column: Month Calendar Grid
            VStack(spacing: 0) {
                HStack {
                    Text(data.fullMonthString)
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                }
                .padding(.bottom, 4)

                // Weekdays
                WeekdayHeaderRow(headers: data.weekdayHeaders, fontSize: 10)
                    .padding(.bottom, 2)

                Divider()
                    .opacity(0.4)
                    .padding(.bottom, 2)

                // Grid
                let days = data.calendarDays
                let rows = data.rowCount
                VStack(spacing: 0) {
                    ForEach(0..<rows, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<7, id: \.self) { col in
                                let index = row * 7 + col
                                if index < days.count {
                                    DayCellView(
                                        item: days[index],
                                        fontSize: 11,
                                        circleSize: 18
                                    )
                                }
                            }
                        }
                        .frame(maxHeight: .infinity)
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(12)
    }
}

// MARK: - Large Widget View

struct LargeMonthView: View {
    let data: MonthCalendarData

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(data.monthString)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(data.yearString)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.bottom, 12)

            // Weekday Header Row
            WeekdayHeaderRow(headers: data.weekdayHeaders, fontSize: 15)
                .padding(.bottom, 8)

            Divider()
                .opacity(0.3)
                .padding(.bottom, 8)

            // Calendar Grid: 온전히 달력 본연에 집중하여 전체 위젯 영역을 균등하게 채움
            let days = data.calendarDays
            let rows = data.rowCount
            VStack(spacing: 0) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { col in
                            let index = row * 7 + col
                            if index < days.count {
                                DayCellView(
                                    item: days[index],
                                    fontSize: 18,
                                    circleSize: 36
                                )
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(18)
    }
}

// MARK: - Widget Definition

struct MonthWidget: Widget {
    let kind: String = "MonthWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MonthWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    // 리퀴드 글래스 효과를 돋보이게 하는 은은한 배경
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.06),
                            Color.indigo.opacity(0.03),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("월간 달력")
        .description("한 달 전체 날짜를 리퀴드 글래스(Liquid Glass) 디자인으로 확인할 수 있는 위젯입니다.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    MonthWidget()
} timeline: {
    MonthEntry(date: .now)
}

#Preview("Medium", as: .systemMedium) {
    MonthWidget()
} timeline: {
    MonthEntry(date: .now)
}

#Preview("Large", as: .systemLarge) {
    MonthWidget()
} timeline: {
    MonthEntry(date: .now)
}
