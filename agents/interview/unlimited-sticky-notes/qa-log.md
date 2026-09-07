---
topic: "단축키로 꺼내 쓰는 무제한 스티키 노트"
status: "active"
where: "greenfield"
selected_packs: "ux,data,operation,verification"
created_at: "2026-09-07"
updated_at: "2026-09-07"
question_count: 10
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
- 기존 Raycast 단축키와의 충돌 처리, 노트 탐색 범위, 기존 노트 이전, 상세 편집 및 복구 동작은 아직 미확정이다.

## Intake Cursor

- next_decision_id: D-14
- next_question: (owned by the live conversation until checkpoint)
- last_materiality_sweep: checkpoint 1
- outstanding_raw_entries: none
- next_checkpoint_at: Q20

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
| D-13 | decision | shortcut | 기존 Raycast Notes의 Option+`와 새 앱 단축키가 겹칠 때의 설정 정책은 미확정이다. | P1 | user: 초기 요청에서 현재 사용 단축키 설명; Q6 | open | 후속 질문: 기존 할당 해제 또는 변경 가능한 단축키 |

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
- immediate_notes: decision: 창 하나에서 노트 전환; reasoning: 사용자가 첨부한 Raycast Notes 사용 흐름; constraints: 다중 노트 창을 만들지 않음; explicit non-goals: 여러 메모 창 동시 사용; verified facts: 첨부 화면에 편집 창, 검색 입력이 있는 노트 목록, 액션 메뉴가 보임; unresolved follow-up: 검색 범위와 액션 메뉴의 필수 기능; source: Q2. 스크린샷의 모든 기능을 구현 승인으로 간주하지 않는다.
- needs_normalization: false

### Q3: 서식과 이미지 붙여넣기
- decision_ids: D-05
- route: user-decision
- source_ref: codex:01a07b7a-30de-7063-8c65-7aa28f503c76:msg_01a07b8c-61df-7ea3-9faa-bdfc4d71cc01
- asked: **창 하나에서 검색 가능한 노트 목록을 열고, 선택한 노트로 전환하는 방식**으로 잡겠습니다. 첨부 화면을 사용감과 디자인의 기준으로 삼을게요.
  
  편집 기능도 예시처럼 **제목·굵게·목록·체크리스트·링크 등을 지원하는 서식 있는 편집기**가 필요하신가요?
- recommended: none
- answer: ㅇㅇㅇ 이미지도 복붙되면 좋겠어
- immediate_notes: decision: 질문에 열거한 서식과 이미지 복붙 지원; reasoning: 사용자가 이미지 지원을 추가 요청; constraints: 서식과 이미지가 실제 편집 및 저장 대상; explicit non-goals: 없음; verified facts: 아직 앱 구현 없음; unresolved follow-up: 이미지 편집 범위; source: Q3.
- needs_normalization: false

### Q4: 이 Mac에만 저장
- decision_ids: D-06
- route: user-decision
- source_ref: codex:01a07b7a-30de-7063-8c65-7aa28f503c76:msg_01a07b8c-bb8a-78c2-8f44-f25d4f203739
- asked: 서식 편집에 **이미지 복사·붙여넣기**도 포함하겠습니다.
  
  노트와 이미지는 **이 Mac에만 저장하면 될까요, 아니면 다른 Mac과 동기화도 필요할까요?**
- recommended: none
- answer: 이 Mac 에만
- immediate_notes: decision: 노트와 이미지는 이 Mac에만 저장; reasoning: 사용자 선택; constraints: 기기 간 동기화 제외; explicit non-goals: 다른 Mac 동기화; verified facts: 없음; unresolved follow-up: 백업 및 이전; source: Q4.
- needs_normalization: false

### Q5: 자동 저장과 복원
- decision_ids: D-07
- route: user-decision
- source_ref: codex:01a07b7a-30de-7063-8c65-7aa28f503c76:msg_01a07b8d-aa16-7c82-b405-1a5602a072ad
- asked: 노트와 이미지는 이 Mac에만 저장하는 것으로 정하겠습니다.
  
  **메모는 입력할 때 자동 저장하고, 창을 닫거나 Mac을 재시작해도 그대로 복원되는 방식이면 될까요?**
- recommended: asked에 명시한 동작을 제안했고 사용자가 수락함
- answer: ㅇㅇㅇ
- immediate_notes: 자동 저장과 창 닫기 및 Mac 재시작 이후 복원을 명시적으로 수락했다. 저장 실패와 비정상 종료 복구는 품질 요구로 후속 정리한다.
- needs_normalization: false

### Q6: 단축키 토글
- decision_ids: D-08
- route: user-decision
- source_ref: codex:01a07b7a-30de-7063-8c65-7aa28f503c76:msg_01a07b8e-b2bb-7b71-96da-f30bc777fee1
- asked: 자동 저장하고 재시작 후에도 복원되도록 하겠습니다.
  
  **Option + `를 다시 누르면 메모가 숨겨지고, 한 번 더 누르면 마지막으로 보던 노트가 열리는 방식이면 될까요?**
- recommended: asked에 명시한 동작을 제안했고 사용자가 수락함
- answer: ㅇㅇㅇ
- immediate_notes: Option+`로 숨김 및 마지막 노트 재열기를 명시적으로 수락했다. 기존 Raycast 할당 해제나 시스템 설정 변경은 아직 승인되지 않았다.
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

## UX Scenario Cards

### UX-01: 작업 중 메모 호출
- trigger: 다른 앱에서 Option+` 입력.
- happy path: 현재 작업 화면에 마지막 노트가 나타나고 다른 앱을 클릭해도 위에 유지되며 같은 단축키로 숨긴다.
- state / failure: 전역 단축키 충돌, 전체 화면이나 다른 Space에서 호출되지 않음.
- recovery: 충돌 안내 및 단축키 설정 정책은 사용자 확인 예정.
- proof: 설치된 단일 앱 인스턴스로 일반 앱, 전체 화면, Space 이동 후 실제 호출 및 숨김을 확인하고 스크린샷을 남긴다.
- linked decisions: D-03, D-08, D-09, D-12

### UX-02: 노트 편집과 전환
- trigger: 노트를 선택하거나 새 메모를 작성.
- happy path: 단일 창에서 서식 텍스트와 이미지를 편집하고 다른 노트로 전환했다 돌아와도 내용이 보존된다.
- state / failure: 첫 실행의 빈 목록, 이미지 붙여넣기 실패, 저장 실패.
- recovery: 오류를 드러내고 입력을 보존하는 품질 요구를 후속 정리하며 저장 성공으로 오인시키지 않는다.
- proof: 한글 조합 입력, 서식, 실제 클립보드 이미지, 6개 이상 노트 생성, 전환 후 재열기, 앱 재시작으로 확인.
- linked decisions: D-02, D-04, D-05, D-06, D-07

### UX-03: 삭제한 메모 복구
- trigger: 노트 삭제 후 휴지통 열기.
- happy path: 삭제한 노트를 찾아 복원하고 원래 서식과 이미지를 다시 본다.
- state / failure: 휴지통이 비어 있음, 영구 삭제의 되돌릴 수 없음.
- recovery: 직접 비우기 전에는 복원 가능하며 영구 삭제 확인 동작은 후속 정리.
- proof: 이미지 포함 노트를 삭제한 뒤 앱을 재실행하고 복원해 원본 내용과 비교.
- linked decisions: D-05, D-07, D-10

### UX-04: 설치와 로그인 이후 사용
- trigger: 사용자 Mac에 설치하고 로그인.
- happy path: 메뉴 막대에 앱이 상주하고 Dock 아이콘 없이 단축키로 저장된 노트를 꺼낸다.
- state / failure: 자동 실행 비활성화 또는 실패, 앱 인스턴스 중복.
- recovery: 수동 실행 및 자동 실행 상태 확인 방법은 후속 정리.
- proof: 설치 번들과 프로세스를 식별한 뒤 실제 메뉴 막대, Dock, 로그인 후 호출을 확인. 재로그인 검증은 사용자 작업을 방해하지 않도록 별도 조율.
- linked decisions: D-07, D-11, D-12

## Evidence From Code, Docs, Or Research

- AGENTS.md: Harness Namespace 지침만 있는 신규 저장소.
- agents/config.json: local 전달 모드이며 검증 명령은 미등록.
- 사용자 Q2 첨부 화면: 어두운 단일 편집 창, 제목 표시줄, 노트 검색 목록, 액션 메뉴가 보인다. 표시된 기능 전체를 요구사항으로 확대하지 않는다.
- 첨부 원본: /var/folders/_c/xjlzc0fd7gg04kcy18q5bd240000gn/T/codex-clipboard-e7t3xq.png
- 첨부 원본: /var/folders/_c/xjlzc0fd7gg04kcy18q5bd240000gn/T/codex-clipboard-J3Qw9y.png
- 첨부 원본: /var/folders/_c/xjlzc0fd7gg04kcy18q5bd240000gn/T/codex-clipboard-OIZyZF.png
- Raycast의 현재 요금 정책은 독립 검증하지 않았다. 제품 요구는 사용자가 원하는 노트 개수 제한 해제이며 경쟁 제품의 요금 검증에 의존하지 않는다.

## Documented Domain Checks

- docs inspected: AGENTS.md; agents/config.json; interview-me/SKILL.md.
- canonical terms: sticky는 다른 앱 위에 유지되는 창, 노트는 단일 창 안에서 전환하는 저장 문서, 휴지통은 수동 비우기 전 복원 가능한 삭제 상태.
- glossary or code conflicts: 기존 앱 코드 없음. Option+`는 사용자가 기존 Raycast Notes에 사용 중이라고 설명하여 단축키 충돌 정책 확인 필요.
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

## Audit History
