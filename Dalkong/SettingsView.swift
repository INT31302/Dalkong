#if os(macOS)
import SwiftUI
import ServiceManagement
import EventKit

/// 환경설정 창 (⌘,).
struct SettingsView: View {
    @Environment(CalendarStore.self) private var store
    @AppStorage("showWeekNumbers") private var showWeekNumbers = false
    @AppStorage("menuBarFormat") private var menuBarFormat = CalendarStore.defaultMenuBarFormat
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        @Bindable var store = store

        Form {
            Section("메뉴 막대") {
                TextField("날짜 형식", text: $menuBarFormat, prompt: Text(CalendarStore.defaultMenuBarFormat))
                LabeledContent("미리보기", value: store.menuBarTitle(format: menuBarFormat))
                Text("예: `M월 d일 (E)`, `E HH:mm`, `yyyy.MM.dd`. 비워두면 날짜 숫자만 표시합니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("달력") {
                Picker("주 시작 요일", selection: $store.firstWeekday) {
                    ForEach(1...7, id: \.self) { weekday in
                        Text(store.calendar.standaloneWeekdaySymbols[weekday - 1]).tag(weekday)
                    }
                }
                Toggle("주 번호 표시", isOn: $showWeekNumbers)
                Stepper(value: $store.agendaDayCount, in: 1...31) {
                    LabeledContent("일정 표시 기간", value: "\(store.agendaDayCount)일")
                }
            }

            if store.calendarGroups.isEmpty {
                Section("표시할 캘린더") {
                    Text("캘린더 접근 권한을 허용하면 목록이 나타납니다.")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(store.calendarGroups) { group in
                    Section(group.sourceTitle.isEmpty ? "표시할 캘린더" : "표시할 캘린더 – \(group.sourceTitle)") {
                        ForEach(group.calendars, id: \.calendarIdentifier) { calendar in
                            Toggle(isOn: Binding(
                                get: { store.isCalendarVisible(calendar) },
                                set: { store.setCalendar(calendar, visible: $0) }
                            )) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color(cgColor: calendar.cgColor))
                                        .frame(width: 10, height: 10)
                                    Text(calendar.title)
                                }
                            }
                        }
                    }
                }
            }

            Section("일반") {
                Toggle("로그인 시 자동 실행", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        updateLaunchAtLogin(enabled)
                    }
            }
        }
        .formStyle(.grouped)
        // 캘린더가 많아도 창이 화면을 넘지 않도록 높이를 고정하고 폼 안에서 스크롤합니다.
        .frame(width: 420, height: 600)
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // 등록에 실패하면 실제 상태로 되돌립니다.
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
#endif
