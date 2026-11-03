import SwiftUI

@main struct MyApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(StatusBarController.self) private var statusBarController
    #else
    @State private var store = CalendarStore()
    #endif

    var body: some Scene {
        #if os(macOS)
        // Itsycal처럼 Dock 아이콘 없이 메뉴 막대에서만 동작합니다 (Info.plist의 LSUIElement).
        // 메뉴 막대 항목·팝오버·설정 창은 StatusBarController가 관리하며, 앱에는 장면이 하나 이상 필요해 빈 Settings를 둡니다.
        Settings {
            EmptyView()
        }
        #else
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(\.locale, CalendarStore.locale)
        }
        #endif
    }
}
