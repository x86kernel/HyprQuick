# HyprQuick

[English](./README.md) | [한국어](./README.ko.md)

HyprPanel 스타일에서 영감을 받은, Hyprland용 QuickShell 커스텀 상단 바 설정입니다.  
QuickShell 기반으로 작성되었고, 좌/중/우 블록형 UI와 팝업 위젯(알림, 달력+날씨, WiFi, Bluetooth, CPU, 스크린샷, 토스트)을 포함합니다.

## 기능

- 좌/중/우 바 레이아웃
- Workspace / Focused Window / System Tray / Volume / Notification / DateTime 인디케이터
- 팝업 UI 분리 구조 (`popups/`)
- 날씨 + 달력 위젯
  - WeatherAPI 연동
  - KR 공휴일 표시 (Nager API)
- 토스트/알림센터
- JSON 기반 설정 파일 (`settings.json`)
- i18n 지원 (`i18n/ko-KR.json`, `i18n/en-US.json`)

## 프로젝트 구조

- `shell.qml`: 메인 엔트리
- `components/`: 인디케이터, 테마, i18n 로더
- `popups/`: 각 팝업 컴포넌트
- `i18n/`: 로케일 문자열 JSON
- `assets/`: UI 에셋
- `settings.json`: 사용자 설정

## 요구사항

- Hyprland
- [QuickShell](https://quickshell.org/docs/master/)
- (권장) `curl` 또는 `wget` (날씨/공휴일 API 호출)
- (선택) `wpctl` 또는 `pactl` (볼륨 블록)

## 설정

먼저 샘플 파일을 복사해서 로컬 설정 파일을 만드세요:

```bash
cp settings.example.json settings.json
```

`settings.json` 예시:

```json
{
  "weatherApiKey": "",
  "weatherLocation": "auto:ip",
  "holidayCountryCode": "KR",
  "locale": "ko-KR"
}
```

- `weatherApiKey`: WeatherAPI 키
- `weatherLocation`: 예) `auto:ip`, `Seoul`, `37.56,126.97`
- `holidayCountryCode`: 공휴일 국가 코드 (예: `KR`)
- `locale`: `ko-KR`, `en-US`
- `settings.example.json`: 초기 설정용 템플릿 파일

## i18n

로케일 문자열은 `i18n/*.json`에서 관리합니다.

- `ko-KR.json`
- `en-US.json`

새 언어를 추가하려면:

1. `i18n/<locale>.json` 파일 추가
2. `components/I18n.qml`의 `availableLocales`에 코드 추가
3. `settings.json`의 `locale` 값 변경

## 테마

색상/폰트/사이즈/간격은 `components/Theme.qml`에서 조정합니다.

## 참고

- QuickShell Docs: https://quickshell.org/docs/master/
- Inspiration: https://github.com/Jas-SinghFSU/HyprPanel

## TODO

1. 설정 패널
