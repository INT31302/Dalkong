import SwiftUI
import EventKit
#if os(macOS)
import AppKit
#endif

/// 메뉴 막대 아이콘을 클릭하면 나타나는 달력 + 일정 패널.
struct ContentView: View {
    @Environment(CalendarStore.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var isAddingEvent = false

    var maxHeight: CGFloat?
    @State private var dynamicMaxHeight: CGFloat = 600
    @State private var measuredAgendaHeight: CGFloat?

    /// 설정 창을 엽니다. macOS에서는 StatusBarController가 넘겨줍니다.
    var onOpenSettings: () -> Void = {}

    private var effectiveMaxHeight: CGFloat {
        maxHeight ?? dynamicMaxHeight
    }

    var body: some View {
        VStack(spacing: 0) {
            // 상단 캘린더 영역: 어떤 해상도에서도 상단이 잘리지 않도록 고정 노출
            header
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)

            MonthGridView(store: store)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)

            Divider()

            toolbar
                .padding(.horizontal, 10)
                .padding(.vertical, 6)

            Divider()

            // 하단 일정 영역: 화면 해상도에 맞춰 남은 공간 내에서 표시되며, 초과 시 부드럽게 스크롤
            if store.hasAccess {
                let maxAgendaHeight = max(120, effectiveMaxHeight - 340)
                ScrollView(.vertical, showsIndicators: true) {
                    AgendaView(store: store)
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(key: AgendaHeightPreferenceKey.self, value: geo.size.height)
                            }
                        )
                }
                .frame(height: measuredAgendaHeight.map { min($0, maxAgendaHeight) })
                .frame(maxHeight: maxAgendaHeight)
                .onPreferenceChange(AgendaHeightPreferenceKey.self) { height in
                    measuredAgendaHeight = height
                }
            } else {
                accessPrompt
            }
        }
        .frame(width: 320)
        .frame(maxHeight: effectiveMaxHeight)
        .task {
            updateDynamicHeight()
            // 시스템 설정에서 권한이 바뀌었을 수 있으므로 열 때마다 확인합니다.
            store.refreshAuthorization()
            if store.authorizationStatus == .notDetermined {
                await store.requestAccess()
            }
        }
    }

    private func updateDynamicHeight() {
        #if os(macOS)
        if let screen = NSApp.keyWindow?.screen ?? NSScreen.main {
            dynamicMaxHeight = max(400, screen.visibleFrame.height - 40)
        }
        #endif
    }

    private var header: some View {
        HStack(spacing: 4) {
            Text(store.displayedMonth, format: .dateTime.year().month(.wide))
                .font(.title3.weight(.semibold))
            Spacer()
            Button("이전 달", systemImage: "chevron.left") { store.showMonth(offset: -1) }
                .keyboardShortcut(.leftArrow, modifiers: [])
            Button("오늘", systemImage: "circle.fill") { store.goToToday() }
                .imageScale(.small)
                .keyboardShortcut("t", modifiers: [])
            Button("다음 달", systemImage: "chevron.right") { store.showMonth(offset: 1) }
                .keyboardShortcut(.rightArrow, modifiers: [])
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
    }

    private var accessPrompt: some View {
        VStack(spacing: 8) {
            Text("캘린더 접근 권한이 필요합니다")
                .font(.callout.weight(.medium))
            if store.authorizationStatus == .notDetermined {
                Button("접근 허용") {
                    Task { await store.requestAccess() }
                }
            } else {
                Text("시스템 설정 › 개인정보 보호 및 보안 › 캘린더에서 허용해 주세요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                #if os(macOS)
                Button("시스템 설정 열기") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                        openURL(url)
                    }
                }
                #endif
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button("캘린더 앱 열기", systemImage: "calendar") { openCalendarApp() }
                .help("캘린더 앱 열기")
            Spacer()
            Button("일정 추가", systemImage: "plus") {
                isAddingEvent = true
            }
            .help("일정 추가")
            .keyboardShortcut("n")
            .disabled(!store.hasAccess)
            // Itsycal처럼 달력 패널 왼쪽으로 펼쳐지는 팝오버로 입력 폼을 엽니다.
            .popover(isPresented: $isAddingEvent, arrowEdge: .leading) {
                AddEventView(store: store) { isAddingEvent = false }
            }
            #if os(macOS)
            Menu {
                Button("설정…", action: onOpenSettings)
                    .keyboardShortcut(",")
                Divider()
                Button("종료") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            } label: {
                Image(systemName: "gearshape")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            #endif
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
    }

    private func openCalendarApp() {
        #if os(macOS)
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.open(url)
        }
        #else
        if let url = URL(string: "calshow://") {
            openURL(url)
        }
        #endif
    }
}

private struct AgendaHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview {
    ContentView()
        .environment(CalendarStore())
}
