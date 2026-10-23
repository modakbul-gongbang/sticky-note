# Sticky Notes

개인 Mac에서 `Option+\``로 꺼내 쓰는 로컬 전용 AppKit 스티키 노트 앱입니다.
노트 수에 제품 제한을 두지 않으며 서식과 이미지를 RTFD 패키지로, 검색 메타데이터를 원자적 JSON 인덱스로 Application Support에 저장합니다.

<p align="center">
  <img src="docs/screenshots/editor.png" alt="Sticky Notes 편집 화면" width="420">
</p>

## 주요 기능

- `Option+\``로 어디서든 노트를 열고 숨깁니다.
- 창 위쪽에 이번 주 달력과 그날 할 일이, 아래쪽에 노트가 함께 보입니다. `Option+Shift+\``는 오늘 할 일로 바로 가고, 달력 버튼은 위쪽을 접거나 펼칩니다.
- 주간 달력 아래 `⌄`(또는 `⌘⇧K`)로 월 달력을 엽니다. 할 일이 있는 날은 날짜 아래에 `완료/전체`(예: `2/5`)가 표시되고, 다 끝낸 날은 빨간색이 됩니다.
- `⌘=`/`⌘+`, `⌘-`, `⌘0`으로 두 편집 영역의 글자를 확대, 축소, 원래 크기로 되돌립니다.
- Obsidian 등에서 복사한 `- [ ]`, `- [x]`, `#### 제목`을 붙여넣으면 체크박스와 굵은 제목으로 바뀝니다.
- `Control+Tab`과 `Control+Shift+Tab`으로 노트를 빠르게 전환합니다.
- 체크리스트, 불릿, 번호 목록, 링크, 굵게, 이미지 붙여넣기를 지원합니다.
- 노트와 휴지통을 한 화면에서 검색하고 관리합니다.
- 모든 노트는 이 Mac에만 저장됩니다.

| 빠른 노트 전환 | 노트 검색과 관리 |
| --- | --- |
| <img src="docs/screenshots/note-switcher.png" alt="노트 전환 알림" width="360"> | <img src="docs/screenshots/note-browser.png" alt="노트 검색 화면" width="360"> |

## 빌드와 설치

```sh
swift test
./scripts/install-app.sh
```

설치 결과는 `/Applications/Sticky Notes.app`이며 앱 콘텐츠는 `~/Library/Application Support/Sticky Notes/`에 남습니다.
앱은 네트워크 권한, 분석, 충돌 보고, 업데이트 확인을 포함하지 않습니다.

## 단축키 이전

앱은 Carbon으로 `Option+\`` 등록을 시도하고 실제 OSStatus를 화면에 표시합니다.
Raycast Notes가 이미 단축키를 쓰는 경우 Raycast의 보이는 설정 화면에서 Notes 단축키 하나만 해제한 뒤 메뉴 막대의 단축키 상태를 눌러 다시 시도합니다.
Raycast의 내부 데이터베이스나 암호화된 설정은 읽거나 수정하지 않습니다.

이전 작업 중 새 앱 등록이 실패하면 같은 보이는 Raycast 설정 화면에서 캡처해 둔 원래 키 조합을 다시 지정합니다.
다른 Raycast 설정은 변경하지 않습니다.
