import SwiftUI
import EventKit

/// 6주 단위의 월간 달력 격자.
struct MonthGridView: View {
    let store: CalendarStore
    @AppStorage("showWeekNumbers") private var showWeekNumbers = false

    var body: some View {
        let days = store.monthDays
        let calendar = store.calendar

        Grid(horizontalSpacing: 0, verticalSpacing: 2) {
            GridRow {
                if showWeekNumbers {
                    Color.clear.frame(width: 24, height: 1)
                }
                ForEach(store.weekdayHeaders) { header in
                    Text(verbatim: header.symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(weekdayColor(header.weekday).opacity(0.8))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 2)

            ForEach(0..<(days.count / 7), id: \.self) { row in
                let week = days[(row * 7)..<(row * 7 + 7)]
                GridRow {
                    if showWeekNumbers, let firstDay = week.first {
                        Text(verbatim: String(calendar.component(.weekOfYear, from: firstDay)))
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(.tertiary)
                            .frame(width: 24)
                    }
                    ForEach(week, id: \.self) { day in
                        DayCell(
                            dayNumber: calendar.component(.day, from: day),
                            textColor: weekdayColor(calendar.component(.weekday, from: day)),
                            isInDisplayedMonth: store.isInDisplayedMonth(day),
                            isToday: store.isToday(day),
                            isSelected: store.isSelected(day),
                            eventCalendars: store.eventCalendars(on: day)
                        ) {
                            store.select(day)
                        }
                    }
                }
            }
        }
    }

    /// 일요일은 빨간색, 토요일은 파란색으로 표시합니다.
    private func weekdayColor(_ weekday: Int) -> Color {
        switch weekday {
        case 1: .red
        case 7: .blue
        default: .primary
        }
    }
}

private struct DayCell: View {
    let dayNumber: Int
    let textColor: Color
    let isInDisplayedMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let eventCalendars: [EKCalendar]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(verbatim: String(dayNumber))
                    .font(.system(size: 15, weight: isToday ? .bold : .regular).monospacedDigit())
                    .foregroundStyle(isToday ? Color.white : textColor.opacity(isInDisplayedMonth ? 1 : 0.35))
                    .frame(width: 30, height: 30)
                    .background {
                        if isToday {
                            Circle().fill(.tint)
                        } else if isSelected {
                            Circle().strokeBorder(.tint, lineWidth: 1.5)
                        }
                    }

                HStack(spacing: 2) {
                    ForEach(eventCalendars, id: \.calendarIdentifier) { calendar in
                        Circle()
                            .fill(Color(cgColor: calendar.cgColor))
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 4)
                .opacity(isInDisplayedMonth ? 1 : 0.4)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
