---
topic: "단축키로 꺼내 쓰는 무제한 스티키 노트"
status: "active"
where: "greenfield"
selected_packs: "ux,data,operation,verification"
created_at: "2026-09-07"
updated_at: "2026-09-07"
question_count: 16
normalization_policy: "transcript-sync-with-checkpoint-backfill"
normalization_checkpoint_every: 10
---

# Interview Log: 단축키로 꺼내 쓰는 무제한 스티키 노트

## Current Understanding

- 개인용 macOS 메모 앱이며 노트 개수에 제품 차원의 제한을 두지 않는다.
- 창 하나에서 노트를 전환하며, 다른 앱을 조작해도 최상위에 남는다.
- Option+`로 숨김과 마지막 노트 열기를 전환하며 전체 화면 앱과 다른 Space에서도 현재 작업 화면에서 호출한다.
- 제목, 굵게, 목록, 체크리스트, 링크와 이미지 붙여넣기를 지원한다.
- 노트와 이미지는 이 Mac에 자동 저장하며 창 닫기와 재시작 이후에도 보존한다.
- 삭제한 노트는 휴지통에서 직접 비우기 전까지 복원할 수 있다.
- 로그인 시 자동 실행하며 Dock 대신 메뉴 막대에 상주한다.
- 기존 Raycast 단축키를 해제하고 새 앱에 연결하며 기존 노트 이전 없이 빈 상태에서 시작한다.
- 노트는 제목과 본문으로 검색하고 최근 수정순으로 보여준다.
- 이미지는 창 너비에 맞게 표시하고 크기 조절, 삭제, 클릭 확대를 지원한다.
- 첨부 화면처럼 어두운 작은 창을 사용하고 노트 목록과 기능 메뉴는 필요할 때만 연다.
- 임시 메모 용도이므로 별도 파일 백업 및 복원 기능은 제외한다. 자동 저장과 휴지통 요구는 유지된다.
- 사용자 Q16의 종료 의사에 따라 질문은 16개에서 마친다. 추가 제품 선택을 사용자 동의로 꾸미지 않는다.
- 최종 목표: 이 Mac에서 Option+`로 어디서나 꺼내고 숨길 수 있는 단일 최상위 창에서, 개수 제한 없이 서식과 이미지를 담은 임시 노트를 작성하고 검색하며 로컬에 자동 저장하는 개인용 앱.

## Intake Cursor

- next_decision_id: D-27
- next_question: (owned by the live conversation until checkpoint)
- last_materiality_sweep: checkpoint 3
- outstanding_raw_entries: none
- next_checkpoint_at: Q26

## Transcript Sources

| Runtime | Session ID | Start ref |
| --- | --- | --- |
| codex | 01a07b7a-30de-7063-8c65-7aa28f503c76 | msg_01a07b80-30f4-7a23-97f4-48a5a75ea5eb |

## Decision Register

| ID | Kind | Area | Decision / fact | Priority | Source / owner | Status | PRD mapping / revisit |
| --- | --- | --- | --- | --- | --- | --- | --- |
| D-01 | fact | repository | 현재 저장소에는 워크플로 설정과 에이전트 지침만 있으며 앱 코드와 검증 명령은 없다. | P1 | repo: AGENTS.md; agents/config.json; git ls-files | resolved | 구현 기반 및 검증 구성 |
| D-02 | decision | product | Raycast Notes처럼 단축키로 꺼내 쓰되 노트 개수 제한이 없는 별도 메모 앱을 만든다. | P0 | user invocation: codex:01a07b7a-30de-7063-8c65-7aa28f503c76:msg_01a07b80-30f4-7a23-97f4-48a5a75ea5eb | resolved | 핵심 제품 요구사항 및 노트 개수 제한 없음 검증 |
| D-03 | decision | window | 다른 앱을 클릭하고 작업해도 메모 창이 그 위에 계속 떠 있어야 한다. | P0 | user-accepted answer: Q1 | resolved | R: 최상위 창; V: 실제 앱 간 전환 확인 |
| D-04 | decision | navigation | 여러 메모 창 대신 하나의 창에서 노트를 바꿔 본다. | P0 | user-accepted answer: Q2 | resolved | R: 단일 창 노트 전환; V: 노트 전환 시 창 수와 내용 확인 |
| D-05 | decision | editor | 제목, 굵게, 목록, 체크리스트, 링크를 지원하는 서식 편집기와 이미지 복사 및 붙여넣기를 제공한다. | P0 | user-accepted answer: Q3 | resolved | R: 서식 및 이미지 편집; V: 실제 클립보드 붙여넣기와 재열기 |
| D-06 | decision | data | 노트와 이미지는 이 Mac에만 저장한다. 다른 Mac과의 동기화는 현재 범위에서 제외한다. | P0 | user-accepted answer: Q4 | resolved | R: 로컬 저장; non-goal: 기기 동기화; 재검토: 다중 기기 요구 발생 |
| D-07 | decision | persistence | 입력한 메모를 자동 저장하고 창을 닫거나 Mac을 재시작해도 복원한다. | P0 | user-accepted answer: Q5 | resolved | R: 자동 저장 및 영속성; V: 창 닫기, 앱 재실행, Mac 재시작 |
| D-08 | decision | shortcut | Option+`를 누르면 메모를 숨기고 다시 누르면 마지막으로 보던 노트를 연다. | P0 | user-accepted answer: Q6 | resolved | R: 전역 단축키 토글; V: 다른 앱에 포커스가 있을 때 반복 호출 |
| D-09 | decision | spaces | 전체 화면 앱과 다른 데스크탑에서도 단축키로 현재 작업 중인 화면 위에 메모를 연다. | P0 | user-accepted answer: Q7 | resolved | R: 전체 화면 및 Spaces; V: 실제 전체 화면 앱과 Space 이동 |
| D-10 | decision | deletion | 삭제한 노트는 휴지통에 보관하고 사용자가 직접 비우기 전까지 복원할 수 있다. | P1 | user-accepted answer: Q8 | resolved | R: 삭제 및 복원; V: 이미지 포함 노트 복원; 영구 삭제 확인 UX는 후속 정리 |
| D-11 | decision | delivery | 우선 사용자 본인이 이 Mac에 설치하여 사용하는 개인용 앱으로 완성한다. 타인 배포는 현재 범위가 아니다. | P1 | user-accepted answer: Q9 | resolved | R: 로컬 설치; non-goal: 공개 배포; 재검토: 타인 배포 요청 |
| D-12 | decision | lifecycle | Mac 로그인 시 자동 실행하고 Dock 대신 메뉴 막대에 상주하며 단축키로 메모를 꺼내 쓴다. | P1 | user-accepted answer: Q10 | resolved | R: 로그인 실행 및 메뉴 막대 상주; V: 설치 앱, Dock 부재, 로그인 후 호출 |
| D-13 | decision | shortcut | 새 앱 사용 시 Raycast Notes의 기존 단축키를 해제하고 새 앱에 Option+`를 할당한다. | P1 | user: Q11 | resolved | R: 설치 시 단축키 이전; V: Raycast 중복 호출 없이 새 앱 토글 |
| D-14 | decision | migration | 기존 Raycast 노트를 이전하지 않고 새 앱은 빈 상태에서 시작한다. | P1 | user: Q12 | resolved | non-goal: 기존 노트 가져오기; 사용자 결과: 직접 새로 작성; 재검토: 사용자 이전 요청 |
| D-15 | decision | navigation | 노트 목록은 제목과 본문 검색을 지원하며 최근 수정한 순으로 표시한다. | P1 | user: Q13 | resolved | R: 노트 탐색; V: 제목 및 본문 일치, 최근 수정순, 검색 결과 없음 |
| D-16 | decision | images | 붙여넣은 이미지를 창 너비에 맞춰 표시하고 크기 조절, 삭제, 클릭해서 크게 보기를 제공한다. | P1 | user: Q14 | resolved | R: 이미지 조작; V: 실제 클립보드, 크기 조절 후 재열기, 확대 닫기, 삭제 |
| D-17 | decision | design | 첨부 화면처럼 어두운 배경의 작은 창에 편집 영역을 넓게 두고 노트 목록과 기능 메뉴는 필요할 때만 연다. | P1 | user: Q15 | resolved | R: 디자인 방향; V: 실제 설치 앱 스크린샷과 첨부 기준 비교; human review: 시각적 완성도 |
| D-18 | decision | backup | 임시 메모 용도이므로 전체 내용을 파일 하나로 백업하고 복원하는 기능은 제외한다. 기존에 합의한 자동 저장과 휴지통은 철회되지 않았다. | P1 | user: Q16 | resolved | non-goal: 별도 백업 및 복원; 사용자 결과: 앱 외부 백업 파일 없음; 이유: 임시 메모; 재검토: 장기 보관 또는 Mac 교체 요구 |
| D-19 | fact | compatibility | 확인한 사용자 Mac 환경은 macOS 15.1 (24B2083), arm64다. | P1 | local: sw_vers; uname -m (2026-09-07) | resolved | V: 이 환경에서 설치 번들 실행과 네이티브 동작 검증 |
| D-20 | fact | quality | 공유 원칙은 실패를 외부에서 관찰 가능하게 드러내고 파괴적 동작 전에 결과를 알리도록 요구한다. | P1 | repo: ~/projects/oh-my-principle/engineering/principles.md #4,#10; design/principles.md #6 | resolved | R: 저장 및 이미지 처리 오류 표시, 영구 삭제 결과 안내; V: 실패 조건에서 저장 성공 오표시 없음 |
| D-21 | fact | verification | 공유 지침은 설치 또는 개발 빌드를 식별하고 정확히 한 앱 인스턴스에서 실제 스크린샷으로 네이티브 UI를 검증하도록 요구한다. | P1 | user: AGENTS.md Desktop App Verification; Q9 개인용 실제 설치 | resolved | V: 설치 및 동작 검증; 사용자 화면 및 재로그인 방해 없이 확인; 미실행 검사 명시 |
| D-22 | decision | empty state | 첫 노트가 없을 때의 화면과 제목 없는 새 초안의 생성 및 취소 세부 동작은 미결정이다. | P1 | gap-audit findings F1; user Q16 asks to stop questions | deferred | PRD 시작 화면 결정; owner: user; 재검토: PRD 준비 재개 시 |
| D-23 | decision | destructive lifecycle | 휴지통 복원은 합의했으나 비우기의 확인 및 취소, 전체 또는 개별 영구 삭제 범위와 이미지 정리 세부 정책은 미결정이다. | P0 | gap-audit findings F2,F5,F6; user Q16 asks to stop questions | deferred | 영구 삭제 정책; owner: user; 재검토: PRD 준비 재개 시; 실제 사용자 데이터 삭제 승인은 별개 |
| D-24 | decision | multi-monitor | 다중 모니터에서 현재 작업 화면을 고르는 기준과 창 위치 규칙은 미결정이다. | P1 | gap-audit findings F3,F9; user Q16 asks to stop questions | deferred | 다중 모니터 위치 정책; owner: user; 재검토: PRD 준비 재개 시 |
| D-25 | decision | shortcut operation | Raycast 단축키 해제와 새 앱 연결은 승인했으나 변경을 수행하는 주체와 실패 시 복원 정책은 미결정이다. | P1 | gap-audit findings F4,F7; user Q16 asks to stop questions | deferred | 단축키 설정 주체 및 실패 경계; owner: user; 재검토: PRD 준비 재개 시 |
| D-26 | decision | privacy | 로컬 저장은 합의했으나 외부 통신 및 분석, 충돌 보고, 업데이트 확인 허용 여부는 미결정이다. | P1 | gap-audit findings F8; user Q16 asks to stop questions | deferred | 네트워크 경계; owner: user; 재검토: PRD 준비 재개 시 |

## Raw Q&A

### Q1: 최상위 창 유지
- decision_ids: D-03
- route: user-decision
- source_ref: codex:01a07b7a-30de-7063-8c65-7aa28f503c76:msg_01a07b89-da1c-7bc3-8f16-0ea9783155f5
- asked: 말씀하신 **“sticky하게 열린다”**는, 단축키로 메모를 꺼낸 뒤 **다른 앱을 클릭하고 작업해도 메모가 그 위에 계속 떠 있는 동작**을 뜻하나요?
- recommended: asked에 명시한 동작을 제안했고 사용자가 수락함
- answer: ㅇㅇㅇ Raycast note
- immediate_notes: 다른 앱을 클릭해도 메모가 위에 남는다는 질문을 명시적으로 수락했다.
- needs_normalization: false

### Q2: 단일 창 노트 전환
- decision_ids: D-04
- route: user-decision
- source_ref: codex:01a07b7a-30de-7063-8c65-7aa28f503c76:msg_01a07b8b-743f-7272-9501-578f96eea079
- asked: 다른 앱에서 작업해도 메모가 위에 계속 떠 있는 방식이군요.
  
  **여러 메모를 각각 별도 창으로 동시에 띄워두고 싶으신가요, 아니면 하나의 창에서 노트를 바꿔 보는 방식이면 될까요?**
- recommended: none
- answer: <image name=[Image #1] path="/var/folders/_c/xjlzc0fd7gg04kcy18q5bd240000gn/T/codex-clipboard-e7t3xq.png">
  </image>
  <image name=[Image #2] path="/var/folders/_c/xjlzc0fd7gg04kcy18q5bd240000gn/T/codex-clipboard-J3Qw9y.png">
  </image>
  <image name=[Image #3] path="/var/folders/_c/xjlzc0fd7gg04kcy18q5bd240000gn/T/codex-clipboard-OIZyZF.png">
  </image>
  하나의 창에 노트 바꿔가면서 ㅇㅇㅇ [Image #1][Image #2][Image #3]
- immediate_notes: decision: 창 하나에서 노트 전환; reasoning: 사용자가 첨부한 Raycast Notes 사용 흐름; constraints: 다중 노트 창을 만들지 않음; explicit non-goals: 여러 메모 창 동시 사용; verified facts: 첨부 화면에 편집 창, 검색 입력이 있는 노트 목록, 액션 메뉴가 보임; unresolved follow-up: 검색은 Q13으로 해결; 첨부된 모든 액션은 승인 범위가 아님; source: Q2. 스크린샷의 모든 기능을 구현 승인으로 간주하지 않는다.
- needs_normalization: false

### Q3: 서식과 이미지 붙여넣기
- decision_ids: D-05
- route: user-decision
- source_ref: codex:01a07b7a-30de-7063-8c65-7aa28f503c76:msg_01a07b8c-61df-7ea3-9faa-bdfc4d71cc01
- asked: **창 하나에서 검색 가능한 노트 목록을 열고, 선택한 노트로 전환하는 방식**으로 잡겠습니다. 첨부 화면을 사용감과 디자인의 기준으로 삼을게요.
  
  편집 기능도 예시처럼 **제목·굵게·목록·체크리스트·링크 등을 지원하는 서식 있는 편집기**가 필요하신가요?
- recommended: none
- answer: ㅇㅇㅇ 이미지도 복붙되면 좋겠어
- immediate_notes: decision: 질문에 열거한 서식과 이미지 복붙 지원; reasoning: 사용자가 이미지 지원을 추가 요청; constraints: 서식과 이미지가 실제 편집 및 저장 대상; explicit non-goals: 없음; verified facts: 아직 앱 구현 없음; unresolved follow-up: Q14로 이미지 조작 범위 해결; source: Q3.
- needs_normalization: false

### Q4: 이 Mac에만 저장
- decision_ids: D-06
- route: user-decision
- source_ref: codex:01a07b7a-30de-7063-8c65-7aa28f503c76:msg_01a07b8c-bb8a-78c2-8f44-f25d4f203739
- asked: 서식 편집에 **이미지 복사·붙여넣기**도 포함하겠습니다.
  
  노트와 이미지는 **이 Mac에만 저장하면 될까요, 아니면 다른 Mac과 동기화도 필요할까요?**
- recommended: none
- answer: 이 Mac 에만
- immediate_notes: decision: 노트와 이미지는 이 Mac에만 저장; reasoning: 사용자 선택; constraints: 기기 간 동기화 제외; explicit non-goals: 다른 Mac 동기화; verified facts: 없음; unresolved follow-up: Q12와 Q16에서 모두 제외로 해결; source: Q4.
- needs_normalization: false

### Q5: 자동 저장과 복원
- decision_ids: D-07
- route: user-decision
- source_ref: codex:01a07b7a-30de-7063-8c65-7aa28f503c76:msg_01a07b8d-aa16-7c82-b405-1a5602a072ad
- asked: 노트와 이미지는 이 Mac에만 저장하는 것으로 정하겠습니다.
  
  **메모는 입력할 때 자동 저장하고, 창을 닫거나 Mac을 재시작해도 그대로 복원되는 방식이면 될까요?**
- recommended: asked에 명시한 동작을 제안했고 사용자가 수락함
- answer: ㅇㅇㅇ
- immediate_notes: 자동 저장과 창 닫기 및 Mac 재시작 이후 복원을 명시적으로 수락했다. 저장 실패를 성공처럼 표시하지 않는 품질 요구는 D-20에 근거하며, 정상 저장된 내용의 재시작 복원은 D-07의 검증 대상이다.
- needs_normalization: false

### Q6: 단축키 토글
- decision_ids: D-08
- route: user-decision
- source_ref: codex:01a07b7a-30de-7063-8c65-7aa28f503c76:msg_01a07b8e-b2bb-7b71-96da-f30bc777fee1
- asked: 자동 저장하고 재시작 후에도 복원되도록 하겠습니다.
  
  **Option + `를 다시 누르면 메모가 숨겨지고, 한 번 더 누르면 마지막으로 보던 노트가 열리는 방식이면 될까요?**
- recommended: asked에 명시한 동작을 제안했고 사용자가 수락함
- answer: ㅇㅇㅇ
- immediate_notes: Option+`로 숨김 및 마지막 노트 재열기를 명시적으로 수락했다. Q11에서 기존 Raycast Notes 단축키 해제 및 새 앱 할당을 후속 승인했다.
- needs_normalization: false

### Q7: 전체 화면과 Spaces
- decision_ids: D-09
- route: user-decision
- source_ref: codex:01a07b7a-30de-7063-8c65-7aa28f503c76:msg_01a07b8f-3c70-7c22-b9da-6ef5134f10cd
- asked: **전체 화면 앱이나 다른 데스크탑으로 이동했을 때도**, 단축키를 누르면 현재 작업 중인 화면 위에 메모가 나타나야 할까요?
- recommended: asked에 명시한 동작을 제안했고 사용자가 수락함
- answer: ㅇㅇㅇ
- immediate_notes: 전체 화면 앱과 다른 데스크탑에서도 현재 작업 화면에 나타나는 동작을 명시적으로 수락했다. 여러 모니터에서의 위치 선택은 미확정이다.
- needs_normalization: false

### Q8: 휴지통과 복원
- decision_ids: D-10
- route: user-decision
- source_ref: codex:01a07b7a-30de-7063-8c65-7aa28f503c76:msg_01a07b93-46da-7e12-a3d3-bf6fc868c2b5
- asked: 노트를 실수로 지웠을 때를 위해 **휴지통에 보관하고, 직접 비우기 전까지 복원할 수 있는 방식**으로 할까요?
- recommended: asked에 명시한 동작을 제안했고 사용자가 수락함
- answer: 음 ㅇㅇㅇㅇ
- immediate_notes: 사용자가 휴지통 보관과 직접 비우기 전까지의 복원을 수락했다. 영구 삭제 실행 승인은 이 답변에 포함되지 않는다.
- needs_normalization: false

### Q9: 개인용 설치
- decision_ids: D-11
- route: user-decision
- source_ref: codex:01a07b7a-30de-7063-8c65-7aa28f503c76:msg_01a07b97-c466-7750-8b6d-d3445c949584
- asked: 삭제한 노트는 휴지통에서 복원할 수 있도록 하겠습니다.
  
  이 앱은 **호연님이 이 Mac에서 직접 쓸 용도**인가요, 아니면 다른 사람도 설치해서 쓰도록 배포할 생각이 있으신가요?
- recommended: none
- answer: 내가 Mac에서 쓸 수 있게 우선
- immediate_notes: decision: 우선 본인의 Mac에 설치해서 사용; reasoning: 사용자 직접 지정; constraints: 개인용 실제 설치와 검증; explicit non-goals: 현재 타인 대상 배포; verified facts: 없음; unresolved follow-up: 배포 범위 재검토는 타인 배포 요청 때; source: Q9.
- needs_normalization: false

### Q10: 로그인 실행과 메뉴 막대
- decision_ids: D-12
- route: user-decision
- source_ref: codex:01a07b7a-30de-7063-8c65-7aa28f503c76:msg_01a07b97-e78e-7463-a999-e48922c5152a
- asked: 우선 호연님 Mac에 설치해서 쓰는 개인용 앱으로 잡겠습니다.
  
  **Mac 로그인 시 자동으로 실행되고, Dock 대신 메뉴 막대에 상주하면서 단축키로 꺼내 쓰는 방식**이면 될까요?
- recommended: asked에 명시한 동작을 제안했고 사용자가 수락함
- answer: ㅇㅇㅇㅇㅇ
- immediate_notes: 로그인 자동 실행, Dock 대신 메뉴 막대 상주, 단축키 호출이라는 명시적 제안을 수락했다.
- needs_normalization: false

### Q11: Raycast 단축키 이전
- decision_ids: D-13
- route: user-decision
- source_ref: codex:01a07b7a-30de-7063-8c65-7aa28f503c76:msg_01a07b9c-0089-7851-98eb-574394efcbcf
- asked: 지금은 Raycast Notes가 **Option + `**를 쓰고 있으니 단축키가 겹칠 수 있습니다.
  
  **새 앱을 사용할 때 Raycast Notes의 기존 단축키를 해제하고, 새 앱에 Option + `를 할당하는 방식**으로 괜찮을까요?
- recommended: asked의 구체적 동작 제안, 사용자 수락
- answer: ㅇㅇㅇㅇ 그렇게
- immediate_notes: decision: 기존 Raycast Notes 단축키를 해제하고 새 앱에 Option+` 할당; reasoning: 단축키 충돌 방지; constraints: 기존 노트 데이터 삭제를 뜻하지 않음; explicit non-goals: 없음; verified facts: 사용자가 기존 단축키 사용을 설명함; unresolved follow-up: 없음; source: Q11의 명시적 수락.
- needs_normalization: false

### Q12: 기존 노트 이전 제외
- decision_ids: D-14
- route: user-decision
- source_ref: codex:01a07b7a-30de-7063-8c65-7aa28f503c76:msg_01a07b9c-9f2f-7912-9f9a-abc00beac2bf
- asked: 기존 Raycast Notes 단축키를 해제하고 새 앱에 연결하는 것으로 정하겠습니다.
  
  **지금 Raycast에 있는 노트도 새 앱으로 옮겨야 하나요, 아니면 새 앱은 빈 상태에서 시작해도 될까요?**
- recommended: none
- answer: ㄴㄴ 새로
- immediate_notes: decision: 기존 노트 이전 없이 새로 시작; reasoning: 사용자 직접 선택; constraints: 기존 Raycast 노트는 가져오지 않음; explicit non-goals: 기존 노트 마이그레이션; verified facts: 없음; unresolved follow-up: 없음; source: Q12.
- needs_normalization: false

### Q13: 제목 본문 검색과 수정순
- decision_ids: D-15
- route: user-decision
- source_ref: codex:01a07b7a-30de-7063-8c65-7aa28f503c76:msg_01a07b9c-d425-7623-8952-13da06876b51
- asked: 기존 노트 이전 없이 새로 시작하겠습니다.
  
  노트가 많아졌을 때 찾기 쉽도록, **노트 목록에서 제목과 본문을 검색하고 최근 수정한 순으로 보여주는 방식**이면 될까요?
- recommended: asked의 구체적 동작 제안, 사용자 수락
- answer: ㅇㅇ 그정도면 될듯
- immediate_notes: decision: 제목과 본문 검색 및 최근 수정순 목록; reasoning: 사용자 수락; constraints: 이미지 OCR 등 별도 검색 범위를 이 답변에서 추론하지 않음; explicit non-goals: 없음; verified facts: 없음; unresolved follow-up: 없음; source: Q13.
- needs_normalization: false

### Q14: 이미지 표시와 조작
- decision_ids: D-16
- route: user-decision
- source_ref: codex:01a07b7a-30de-7063-8c65-7aa28f503c76:msg_01a07b9d-35ea-7fe0-be80-f4a9f477ae53
- asked: 노트는 제목·본문 검색과 최근 수정순 목록으로 찾도록 하겠습니다.
  
  붙여넣은 이미지는 **창 너비에 맞춰 표시하고, 크기 조절·삭제·클릭해서 크게 보기**까지 지원하면 충분할까요?
- recommended: asked의 구체적 동작 제안, 사용자 수락
- answer: ㅇㅇㅇㅇ
- immediate_notes: decision: 이미지의 창 너비 맞춤 표시, 크기 조절, 삭제, 클릭 확대; reasoning: 사용자가 구체적 기능 제안을 수락; constraints: 실제 클립보드 붙여넣기 및 저장 후 유지; explicit non-goals: 없음; verified facts: 없음; unresolved follow-up: 없음; source: Q14.
- needs_normalization: false

### Q15: 어두운 작은 창 디자인
- decision_ids: D-17
- route: user-decision
- source_ref: codex:01a07b7a-30de-7063-8c65-7aa28f503c76:msg_01a07ba0-7a26-7120-b778-e0de76230467
- asked: 디자인은 첨부하신 화면처럼 **어두운 배경의 작은 창에 편집 영역을 넓게 두고, 노트 목록과 기능 메뉴는 필요할 때만 여는 형태**로 맞추면 될까요?
- recommended: asked의 구체적 동작 제안, 사용자 수락
- answer: ㅇㅇㅇㅇ
- immediate_notes: decision: 어두운 작은 창에 넓은 편집 영역, 필요 시 노트 목록과 기능 메뉴; reasoning: 사용자 첨부 기준과 명시적 수락; constraints: 스크린샷의 모든 액션 기능을 복제 승인으로 확대하지 않음; explicit non-goals: 없음; verified facts: Q2 첨부 화면; unresolved follow-up: 실제 시각적 완성도는 구현 결과로 검토; source: Q15.
- needs_normalization: false

### Q16: 백업 제외 및 인터뷰 종료
- decision_ids: D-18
- route: user-decision
- source_ref: codex:01a07b7a-30de-7063-8c65-7aa28f503c76:msg_01a07ba6-a02f-7c41-8db8-45ab5a686741
- asked: 노트와 이미지가 이 Mac에만 남으니, **전체 내용을 파일 하나로 백업하고 나중에 복원하는 기능**도 넣을까요? 실수나 Mac 교체에 대비해 포함하는 쪽을 권합니다.
- recommended: 별도 백업 및 복원 포함을 권했으나 사용자가 거절
- answer: 아니 괜찮아 임시라서 
  이정도면 되지 않겟ㄴ ㅑ
- immediate_notes: decision: 별도 백업 및 복원 기능 제외, 질문 종료; reasoning: 임시 메모 용도이고 현재 범위면 충분하다고 사용자 판단; constraints: 자동 저장과 휴지통을 철회하거나 데이터 손실을 허용한 답변이 아님; explicit non-goals: 파일 하나로 전체 백업 및 복원; verified facts: 없음; unresolved follow-up: 누락 검사에 차단점이 있으면 추가 질문 대신 미해결로 보고; source: Q16.
- needs_normalization: false

## UX Scenario Cards

### UX-01: 작업 중 메모 호출
- trigger: 다른 앱에서 Option+` 입력.
- happy path: 현재 작업 화면에 마지막 노트가 나타나고 다른 앱을 클릭해도 위에 유지되며 같은 단축키로 숨긴다.
- state / failure: 전역 단축키 충돌, 전체 화면이나 다른 Space에서 호출되지 않음.
- recovery: Q11에 따라 Raycast Notes의 기존 단축키를 해제하고 새 앱에 연결한다. 등록 실패는 원인을 드러내며 자동으로 다른 단축키를 선택하지 않는다.
- proof: 설치된 단일 앱 인스턴스로 일반 앱, 전체 화면, Space 이동 후 실제 호출 및 숨김을 확인하고 스크린샷을 남긴다.
- linked decisions: D-03, D-08, D-09, D-12, D-13, D-20, D-21

### UX-02: 노트 편집과 전환
- trigger: 노트를 선택하거나 새 메모를 작성.
- happy path: 빈 상태에서 새 노트를 만들고 단일 창에서 서식 텍스트와 이미지를 편집한다. 제목 또는 본문 검색과 최근 수정순 목록으로 다른 노트를 선택했다 돌아와도 내용이 보존된다.
- state / failure: 첫 실행의 빈 목록, 검색 결과 없음, 이미지 붙여넣기 실패, 저장 실패, 디스크 공간 부족.
- recovery: 빈 목록에서는 새 노트 생성 흐름이 도달 가능해야 한다. 검색을 지우면 노트 목록으로 돌아간다. 오류를 드러내고 기존의 정상 저장 내용을 훼손하거나 저장 성공으로 오인시키지 않는다.
- proof: 한글 조합 입력, 서식, 실제 클립보드 이미지, 6개 이상 노트 생성, 전환 후 재열기, 앱 재시작으로 확인.
- linked decisions: D-02, D-04, D-05, D-06, D-07, D-14, D-15, D-16, D-20

### UX-03: 삭제한 메모 복구
- trigger: 노트 삭제 후 휴지통 열기.
- happy path: 삭제한 노트를 찾아 복원하고 원래 서식과 이미지를 다시 본다.
- state / failure: 휴지통이 비어 있음, 영구 삭제의 되돌릴 수 없음.
- recovery: 직접 비우기 전에는 복원 가능하다. 휴지통 비우기 전에는 복구할 수 없다는 결과를 분명히 알린다(D-20). 실제 사용자 노트 영구 삭제는 검증에 사용하지 않는다.
- proof: 이미지 포함 노트를 삭제한 뒤 앱을 재실행하고 복원해 원본 내용과 비교.
- linked decisions: D-05, D-07, D-10, D-20

### UX-04: 설치와 로그인 이후 사용
- trigger: 사용자 Mac에 설치하고 로그인.
- happy path: 메뉴 막대에 앱이 상주하고 Dock 아이콘 없이 단축키로 저장된 노트를 꺼낸다.
- state / failure: 자동 실행 비활성화 또는 실패, 앱 인스턴스 중복.
- recovery: 설치한 앱을 수동으로 실행할 수 있어야 한다. 자동 실행 등록 실패는 성공으로 숨기지 않고 원인을 표시한다. 중복 실행으로 별도 노트 상태가 갈라져서는 안 된다.
- proof: 설치 번들과 프로세스를 식별한 뒤 실제 메뉴 막대, Dock, 로그인 후 호출을 확인. 재로그인 검증은 사용자 작업을 방해하지 않도록 별도 조율.
- linked decisions: D-07, D-11, D-12, D-19, D-20, D-21

## Evidence From Code, Docs, Or Research

- AGENTS.md: Harness Namespace 지침만 있는 신규 저장소.
- agents/config.json: local 전달 모드이며 검증 명령은 미등록.
- 사용자 Q2 첨부 화면: 어두운 단일 편집 창, 제목 표시줄, 노트 검색 목록, 액션 메뉴가 보인다. 표시된 기능 전체를 요구사항으로 확대하지 않는다.
- 첨부 원본: /var/folders/_c/xjlzc0fd7gg04kcy18q5bd240000gn/T/codex-clipboard-e7t3xq.png
- 첨부 원본: /var/folders/_c/xjlzc0fd7gg04kcy18q5bd240000gn/T/codex-clipboard-J3Qw9y.png
- 첨부 원본: /var/folders/_c/xjlzc0fd7gg04kcy18q5bd240000gn/T/codex-clipboard-OIZyZF.png
- Raycast의 현재 요금 정책은 독립 검증하지 않았다. 제품 요구는 사용자가 원하는 노트 개수 제한 해제이며 경쟁 제품의 요금 검증에 의존하지 않는다.

- 로컬 환경 확인: sw_vers는 macOS 15.1 (24B2083), uname -m은 arm64를 반환했다.
- 공유 원칙의 적용: engineering #4 및 #10에 따라 저장과 이미지 처리 실패를 숨기지 않는다. design #6에 따라 영구 삭제 전에 결과를 알린다.
- 구현 단계의 일반 품질 검증: 한글 IME 조합, 실행 취소 및 다시 실행, 키보드 탐색과 포커스, 아이콘 접근성 이름, 읽을 수 있는 대비, 창 크기 변경 시 편집 및 이미지 표시를 확인한다. 이들은 별도 기능 확장이 아니라 합의한 편집 흐름의 정상 사용 검증이다.
- 노트 개수 무제한은 제품 차원의 개수 제한이 없다는 의미다. 메모리나 디스크가 무한하다는 보장을 만들지 않고 다수 노트 및 이미지에서 응답성과 자원 부족 실패 처리를 검증한다.
- 미선택 세부 사항: 앱 이름, 정확한 창 크기, 제목 편집 제스처와 툴바 위치는 PRD 또는 디자인 단계의 제안 사항으로 남긴다. 사용자 승인 사실로 기록하지 않는다.

## Documented Domain Checks

- docs inspected: AGENTS.md; agents/config.json; interview-me/SKILL.md; ~/projects/oh-my-principle/engineering/principles.md; ~/projects/oh-my-principle/design/principles.md.
- canonical terms: sticky는 다른 앱 위에 유지되는 창, 노트는 단일 창 안에서 전환하는 저장 문서, 휴지통은 수동 비우기 전 복원 가능한 삭제 상태.
- glossary or code conflicts: 기존 앱 코드 없음. Option+`는 사용자가 기존 Raycast Notes에 사용 중이라고 설명하여 Q11에서 기존 할당 해제 및 새 앱 연결을 승인했다.
- concrete scenarios tested: 첨부 화면만 관찰했으며 앱 동작 검증은 구현 후 수행.
- docs mutation: 이 qa-log만 변경.
- ADR candidate: 현재 없음. 저장 및 네이티브 창 구현 방식은 요구사항 인터뷰 이후 결정.

## Checkpoint And Sweep History

### Checkpoint 1
- after_question: Q10
- normalized_entries: Q1, Q2, Q3, Q4, Q5, Q6, Q7, Q8, Q9, Q10
- register_changes: Q1-Q10을 D-03부터 D-12로 정리하고 UX 시나리오 및 원본 화면 근거 기록. 단축키 충돌 정책 D-13은 미확정으로 유지.
- reopened_decisions: none
- highest_remaining_gap: 기존 Raycast 단축키와 새 앱이 충돌할 때의 사용 정책

### Checkpoint 2
- after_question: Q16
- normalized_entries: Q11, Q12, Q13, Q14, Q15, Q16
- register_changes: Q11-Q16 결정 반영, 단축키 충돌 해소, 이전 및 백업 제외 근거와 종료 의사 기록, UX 및 실패 검증 근거 정리
- reopened_decisions: none
- highest_remaining_gap: 핵심 목표의 모순 없음. 추가 제품 결정 없이 독립 누락 검사로 종료 가능 여부 확인.

### Checkpoint 3
- after_question: Q16
- normalized_entries: none
- register_changes: 누락 검사 NEEDS_HUMAN의 중복 항목을 D-22부터 D-26으로 묶어 보류. Q16 종료 의사에 따라 추가 질문 및 임의 결정 없음.
- reopened_decisions: none
- highest_remaining_gap: D-22~D-26 미결정으로 PRD-ready 판정 보류. 재개 시 사용자 판단 필요.

## Audit History

### Audit 1
- type: gap-audit-gate
- at: 2026-09-07T11:39:04.945Z
- cycle: 1
- result: needs-human
- open findings: F1 [P1/empty state] 첫 실행 또는 노트가 0개일 때 Option+` 호출과 새 노트 생성의 구체적인 사용자 흐름이 정의되지 않았다.
  F2 [P1/destructive recovery] 휴지통 비우기라는 영구 삭제의 범위, 확인·취소 동작, 삭제 후 결과가 사용자 승인 없이 미정이다.
  F3 [P1/multi-monitor behavior] 여러 모니터 환경에서 현재 작업 화면에 메모 창을 표시할 모니터와 위치 규칙이 정의되지 않았다.
  F4 [P1/external provider] Q11 authorizes changing the Raycast Notes shortcut but does not define whether the app edits Raycast settings or the user does, what permissions or missing-provider failures mean, or whether the original shortcut is restored when disabled or uninstalled.
  F5 [P1/data lifecycle] The log requires restoring formatting and images from the trash but leaves the permanent-empty operation and attachment lifecycle unresolved, including whether associated images are irreversibly purged and how that result is confirmed.
  F6 [P0/destructive lifecycle] 휴지통 비우기와 영구 삭제가 실제 범위인지, 실행 전 확인과 이미지 포함 데이터의 비가역 삭제 결과가 정의되지 않았고 영구 삭제 권한은 명시적으로 승인되지 않았다.
  F7 [P1/external shortcut operation] Raycast 단축키 해제 후 새 단축키 등록이 실패하거나 Raycast에 접근할 수 없을 때 기존 단축키를 복원할지 여부와 부분 변경 상태가 정의되지 않았다.
  F8 [P1/privacy boundary] 노트와 이미지를 로컬에 저장한다는 결정만 있고 네트워크 전송, 분석·충돌 보고, 업데이트 확인 등 외부로 데이터가 나갈 수 있는 경계가 정의되지 않았다.
  F9 [P1/multi-monitor behavior] 전체 화면과 Spaces 호출은 정해졌지만 여러 모니터에서 어느 화면에 창을 표시하고 Space 전환 시 어떻게 배치할지 결정되지 않았다.
- warnings: none
- artifact: agents/runs/unlimited-sticky-notes/gates/artifacts/gap-audit-2026-09-07T11-39-04-946Z-b08d09c3.json
