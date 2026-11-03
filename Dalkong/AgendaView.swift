import SwiftUI
import EventKit

/// 선택한 날짜부터 며칠 동안의 일정 목록.
struct AgendaView: View {
    let store: CalendarStore

    var body: some View {
        let sections = store.agendaSections

        if sections.isEmpty {
            Text("예정된 일정이 없습니다")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
        } else {
            // 스크롤 없이 전체 기간이 한 번에 보이도록 내용 높이만큼 패널이 늘어납니다.
            // 글자 크기는 달력 날짜(15pt)보다 조금 작게 맞춥니다.
            VStack(alignment: .leading, spacing: 14) {
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader(for: section.day)
                        ForEach(section.events, id: \.self) { event in
                            EventRow(event: event, isPast: event.endDate < store.now)
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sectionHeader(for day: Date) -> some View {
        HStack(spacing: 6) {
            Text(day, format: .dateTime.month().day().weekday(.wide))
                .font(.system(size: 12, weight: .semibold))
            if let relative = relativeDayName(for: day) {
                Text(relative)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tint)
            }
        }
        .foregroundStyle(.secondary)
    }

    private func relativeDayName(for day: Date) -> LocalizedStringKey? {
        let calendar = store.calendar
        if calendar.isDate(day, inSameDayAs: store.now) { return "오늘" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: store.now),
           calendar.isDate(day, inSameDayAs: tomorrow) { return "내일" }
        return nil
    }
}

private struct EventRow: View {
    let event: EKEvent
    let isPast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(event.calendar.map { Color(cgColor: $0.cgColor) } ?? .accentColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title ?? "제목 없음")
                    .font(.system(size: 14))
                    .lineLimit(2)
                Text(timeText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .opacity(isPast ? 0.5 : 1)
    }

    private var timeText: String {
        if event.isAllDay { return String(localized: "종일") }
        let style = Date.FormatStyle(date: .omitted, time: .shortened).locale(CalendarStore.locale)
        let start = event.startDate.formatted(style)
        let end = event.endDate.formatted(style)
        return "\(start) – \(end)"
    }
}
