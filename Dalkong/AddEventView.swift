import SwiftUI
import EventKit
#if os(macOS)
import AppKit
#endif

/// 새 일정 입력 폼. 달력 패널의 ＋ 버튼에서 옆으로 펼쳐지는 팝오버로 열립니다 (Itsycal 방식).
struct AddEventView: View {
    let store: CalendarStore
    let onFinish: () -> Void

    /// 알림 없음을 나타내는 선택 값.
    private static let noAlert = -1
    /// 일정 시작 몇 분 전에 알릴지 고를 수 있는 선택지.
    private static let alertOptions: [(minutes: Int, title: LocalizedStringKey)] = [
        (noAlert, "없음"),
        (0, "이벤트 시작 시"),
        (5, "5분 전"),
        (10, "10분 전"),
        (15, "15분 전"),
        (30, "30분 전"),
        (60, "1시간 전"),
        (60 * 24, "1일 전"),
    ]

    enum Repeat: Hashable, CaseIterable {
        case none, daily, weekly, monthly, yearly

        var title: LocalizedStringKey {
            switch self {
            case .none: "없음"
            case .daily: "매일"
            case .weekly: "매주"
            case .monthly: "매월"
            case .yearly: "매년"
            }
        }

        var frequency: EKRecurrenceFrequency? {
            switch self {
            case .none: nil
            case .daily: .daily
            case .weekly: .weekly
            case .monthly: .monthly
            case .yearly: .yearly
            }
        }
    }

    @State private var title = ""
    @State private var location = ""
    @State private var notes = ""
    @State private var urlText = ""
    @State private var isAllDay = false
    @State private var start: Date
    @State private var end: Date
    @State private var calendarIdentifier: String
    @State private var repeatRule = Repeat.none
    @State private var alertMinutes = AddEventView.noAlert
    @State private var errorMessage: String?
    @FocusState private var isTitleFocused: Bool

    init(store: CalendarStore, onFinish: @escaping () -> Void) {
        self.store = store
        self.onFinish = onFinish
        let start = store.defaultNewEventStart()
        _start = State(initialValue: start)
        _end = State(initialValue: start.addingTimeInterval(60 * 60))
        let calendarIdentifier = store.defaultCalendarForNewEvents?.calendarIdentifier
            ?? store.writableCalendars.first?.calendarIdentifier
            ?? ""
        _calendarIdentifier = State(initialValue: calendarIdentifier)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var dateComponents: DatePickerComponents {
        isAllDay ? [.date] : [.date, .hourAndMinute]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                TextField("새 이벤트", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20))
                    .focused($isTitleFocused)
                calendarPicker
            }

            TextField("위치 추가", text: $location)
                .textFieldStyle(.plain)
                .font(.system(size: 13))

            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    label("종일:")
                    Toggle("종일", isOn: $isAllDay)
                        .labelsHidden()
                }
                GridRow {
                    label("시작:")
                    DatePicker("시작", selection: $start, displayedComponents: dateComponents)
                        .labelsHidden()
                }
                GridRow {
                    label("종료:")
                    DatePicker("종료", selection: $end, in: start..., displayedComponents: dateComponents)
                        .labelsHidden()
                }
                GridRow {
                    label("반복:")
                    Picker("반복", selection: $repeatRule) {
                        ForEach(Repeat.allCases, id: \.self) { rule in
                            Text(rule.title).tag(rule)
                        }
                    }
                    .labelsHidden()
                    .buttonSizing(.flexible)
                }
                GridRow {
                    label("알림:")
                    Picker("알림", selection: $alertMinutes) {
                        ForEach(Self.alertOptions, id: \.minutes) { option in
                            Text(option.title).tag(option.minutes)
                        }
                    }
                    .labelsHidden()
                    .buttonSizing(.flexible)
                }
            }
            .padding(.vertical, 4)

            TextField("메모 추가", text: $notes, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .lineLimit(1...5)
            TextField("URL 추가", text: $urlText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("취소", role: .cancel, action: onFinish)
                    .keyboardShortcut(.cancelAction)
                Button("이벤트 저장하기", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedTitle.isEmpty || calendarIdentifier.isEmpty)
            }
        }
        .font(.system(size: 13))
        .padding(16)
        .frame(width: 330)
        .onChange(of: start) { oldStart, newStart in
            // 시작 시각을 옮기면 일정 길이를 유지한 채 종료 시각도 함께 옮깁니다.
            end = newStart.addingTimeInterval(end.timeIntervalSince(oldStart))
        }
        .task {
            isTitleFocused = true
        }
    }

    private func label(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .gridColumnAlignment(.trailing)
    }

    /// 캘린더 색 점만 보이는 작은 선택 버튼. 메뉴를 열면 이름과 색이 함께 나옵니다.
    private var calendarPicker: some View {
        Picker("캘린더", selection: $calendarIdentifier) {
            ForEach(store.writableCalendars, id: \.calendarIdentifier) { calendar in
                Label {
                    Text(calendar.title)
                } icon: {
                    colorDot(calendar.cgColor)
                }
                .tag(calendar.calendarIdentifier)
            }
        }
        .labelsHidden()
        .fixedSize()
        .help("캘린더")
    }

    /// 메뉴 항목에서도 색이 유지되도록 템플릿이 아닌 색 원 이미지를 만듭니다.
    private func colorDot(_ color: CGColor) -> Image {
        #if os(macOS)
        let size = NSSize(width: 10, height: 10)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor(cgColor: color)?.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        image.isTemplate = false
        return Image(nsImage: image)
        #else
        return Image(systemName: "circle.fill")
        #endif
    }

    private func save() {
        guard !trimmedTitle.isEmpty, !calendarIdentifier.isEmpty else { return }
        let trimmedURL = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try store.addEvent(
                title: trimmedTitle,
                start: start,
                end: end,
                isAllDay: isAllDay,
                calendarIdentifier: calendarIdentifier,
                location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                url: trimmedURL.isEmpty ? nil : URL(string: trimmedURL),
                repeatFrequency: repeatRule.frequency,
                alertMinutesBefore: alertMinutes == Self.noAlert ? nil : alertMinutes
            )
            onFinish()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    AddEventView(store: CalendarStore()) {}
        .environment(\.locale, CalendarStore.locale)
}
