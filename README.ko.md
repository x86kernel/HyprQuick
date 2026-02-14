# HyprQuick

[English](./README.md) | [한국어](./README.ko.md)

HyprPanel 스타일에서 영감을 받은, Hyprland용 QuickShell 커스텀 상단 바 설정입니다.  
QuickShell 기반으로 작성되었고, 좌/중/우 블록형 UI와 팝업 위젯(알림, 달력+날씨, WiFi, Bluetooth, CPU, 스크린샷, 토스트)을 포함합니다.

## Preview

![HyprQuick Preview](./docs/screenshots/hyprquick-overview.jpg)

## 기능

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
- `docs/screenshots/`: README 미리보기 이미지
- `settings.json`: 사용자 설정

## 요구사항

- Hyprland
- [QuickShell](https://quickshell.org/docs/master/)
- (권장) `curl` 또는 `wget` (날씨/공휴일 API 호출)
- (선택) `wpctl` 또는 `pactl` (볼륨 블록)

## 설치

기존 QuickShell 설정을 백업하고 이 저장소를 `~/.config/quickshell`에 배치합니다.

```bash
# 1) 기존 설정 백업
mv ~/.config/quickshell ~/.config/quickshell.backup.$(date +%Y%m%d-%H%M%S)

# 2) 이 저장소를 QuickShell 설정 경로에 클론
git clone https://github.com/x86kernel/HyprQuick.git ~/.config/quickshell

# 3) 설정 파일 생성
cp ~/.config/quickshell/settings.example.json ~/.config/quickshell/settings.json
```


## 설정

먼저 샘플 파일을 복사해서 로컬 설정 파일을 만드세요:

```bash
cp settings.example.json settings.json
```

`settings.json` 예시:

```json
{
  "general": {
    "locale": "ko-KR"
  },
  "integrations": {
    "weather": {
      "apiKey": "",
      "location": "auto:ip"
    },
    "holidays": {
      "countryCode": "KR"
    }
  },
  "power": {
    "lockCommand": ""
  },
  "theme": {
    "font": {
      "family": "SF Pro Text",
      "size": 13,
      "iconFamily": "SauceCodePro Nerd Font",
      "iconSize": 15,
      "weight": 600
    }
  }
}
```

- `general.locale`: `ko-KR`, `en-US`
- `integrations.weather.apiKey`: WeatherAPI 키
- `integrations.weather.location`: 예) `auto:ip`, `Seoul`, `37.56,126.97`
- `integrations.holidays.countryCode`: 공휴일 국가 코드 (예: `KR`)
- `power.lockCommand`: 잠금 커맨드 오버라이드 (비우면 기본값 사용)
- `theme.font.family`: 기본 UI 폰트 패밀리
- `theme.font.size`: 기본 UI 폰트 크기
- `theme.font.iconFamily`: 아이콘 폰트 패밀리
- `theme.font.iconSize`: 아이콘 폰트 크기
- `theme.font.weight`: 폰트 굵기(QFont weight 숫자, 예: `400`, `500`, `600`, `700`)
- `settings.example.json`: 초기 설정용 템플릿 파일

## i18n

로케일 문자열은 `i18n/*.json`에서 관리합니다.

- `ko-KR.json`
- `en-US.json`

새 언어를 추가하려면:

1. `i18n/<locale>.json` 파일 추가
2. `components/I18n.qml`의 `availableLocales`에 코드 추가
3. `settings.json`의 `general.locale` 값 변경

## 테마

색상/폰트/사이즈/간격은 `components/Theme.qml`에서 조정합니다.

## 참고

- QuickShell Docs: https://quickshell.org/docs/master/
- Inspiration: https://github.com/Jas-SinghFSU/HyprPanel

## TODO

1. 설정 패널
