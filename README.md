# Dalkong

macOS 메뉴 막대에서 달력과 일정을 확인하고 새 일정을 추가하는 앱입니다. 월간 달력 위젯도 함께 제공합니다.

## 주요 기능

- 메뉴 막대에서 월별 달력과 선택한 날짜의 일정을 확인합니다.
- 캘린더, 시작·종료 시간, 반복 및 알림을 지정해 일정을 추가합니다.
- 표시할 캘린더, 주 시작 요일, 주 번호와 메뉴 막대 날짜 형식을 설정합니다.
- 로그인 시 자동 실행과 월간 달력 위젯을 사용할 수 있습니다.

## 요구 사항 및 실행

- macOS 27 이상으로 설정된 프로젝트와 해당 SDK를 지원하는 Xcode
- 일정 조회와 추가를 위한 캘린더 접근 권한

```sh
git clone https://github.com/INT31302/Dalkong.git
cd Dalkong
open Dalkong.xcodeproj
```

Xcode에서 **Dalkong** 스킴과 My Mac을 선택해 실행합니다. 처음 실행할 때 캘린더 접근을 허용하세요. 거부한 경우 시스템 설정의 **개인정보 보호 및 보안 → 캘린더**에서 변경할 수 있습니다. 위젯을 실행하거나 배포할 때는 Xcode의 Signing & Capabilities에서 개발 팀과 번들 식별자를 확인하세요.

## 프로젝트 구성

- `Dalkong/`: 메뉴 막대 앱, 달력 및 일정 관리
- `MonthWidget/`: 월간 달력 위젯
- `Dalkong.xcodeproj/`: Xcode 프로젝트와 공유 스킴
