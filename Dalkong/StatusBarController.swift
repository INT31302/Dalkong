#if os(macOS)
import AppKit
import SwiftUI
import WidgetKit

/// 메뉴 막대 항목을 관리합니다. 왼쪽 클릭은 달력 팝오버, 오른쪽 클릭(또는 ⌃클릭)은 설정·종료 메뉴를 엽니다.
///
/// SwiftUI `MenuBarExtra`는 오른쪽 클릭 메뉴를 지원하지 않아 AppKit의 `NSStatusItem`을 직접 사용합니다.
final class StatusBarController: NSObject, NSApplicationDelegate {
    let store = CalendarStore()

    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var settingsWindow: NSWindow?
    private var defaultsTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item

        let content = ContentView(onOpenSettings: { [weak self] in self?.openSettings() })
            .environment(store)
            .environment(\.locale, CalendarStore.locale)
        let hostingController = NSHostingController(rootView: content)
        // 일정 목록·추가 폼 높이에 맞춰 팝오버 크기가 따라 바뀌도록 합니다.
        hostingController.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hostingController
        popover.behavior = .transient

        updateTitle()
        // 앱 실행 시 위젯 타임라인 즉시 새로고침
        WidgetCenter.shared.reloadAllTimelines()

        // 설정에서 날짜 형식을 바꾸면 메뉴 막대 제목을 다시 그립니다.
        defaultsTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: UserDefaults.didChangeNotification) {
                self?.updateTitle()
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    // MARK: - Widget URL Handling

    func application(_ application: NSApplication, open urls: [URL]) {
        openSystemCalendar()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSystemCalendar()
        return true
    }

    @objc func openSystemCalendar() {
        if let calendarAppURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: calendarAppURL, configuration: config, completionHandler: nil)
        }
    }

    /// 현재 시각(`store.now`)이 바뀔 때마다 메뉴 막대 제목을 갱신합니다.
    private func updateTitle() {
        let format = UserDefaults.standard.string(forKey: "menuBarFormat") ?? CalendarStore.defaultMenuBarFormat
        withObservationTracking {
            statusItem?.button?.title = store.menuBarTitle(format: format)
        } onChange: {
            // 컨트롤러는 앱이 끝날 때까지 살아 있으므로 강한 참조로 충분합니다.
            Task { @MainActor in self.updateTitle() }
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showContextMenu()
        } else {
            togglePopover(sender)
        }
    }

    private func togglePopover(_ button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        // 메뉴 막대에서 열 때마다 오늘 날짜를 기준으로 표시하고 권한을 확인합니다.
        store.goToToday()
        store.refreshAuthorization()
        WidgetCenter.shared.reloadAllTimelines()

        // 클릭된 모니터의 해상도에 맞춰 팝오버 최대 높이를 동적으로 조절 (상단 잘림 완벽 방지)
        let screen = button.window?.screen ?? NSScreen.main
        let screenHeight = screen?.visibleFrame.height ?? 800
        let maxPopoverHeight = max(420, screenHeight - 40)

        let content = ContentView(
            maxHeight: maxPopoverHeight,
            onOpenSettings: { [weak self] in self?.openSettings() }
        )
        .environment(store)
        .environment(\.locale, CalendarStore.locale)

        let hostingController = NSHostingController(rootView: content)
        hostingController.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hostingController

        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func showContextMenu() {
        popover.performClose(nil)

        let menu = NSMenu()
        let settingsItem = menu.addItem(withTitle: "설정…", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(.separator())
        let quitItem = menu.addItem(withTitle: "달콩 종료", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self

        // 메뉴를 잠시 연결해 클릭하면 시스템 기본 위치·하이라이트로 메뉴가 열립니다. 이후 다시 떼어야 왼쪽 클릭이 팝오버로 동작합니다.
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func openSettingsFromMenu() {
        openSettings()
    }

    func openSettings() {
        popover.performClose(nil)
        if settingsWindow == nil {
            let controller = NSHostingController(
                rootView: SettingsView()
                    .environment(store)
                    .environment(\.locale, CalendarStore.locale)
            )
            let window = NSWindow(contentViewController: controller)
            window.title = "달콩 설정"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
#endif
