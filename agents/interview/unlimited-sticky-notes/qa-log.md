---
topic: "단축키로 꺼내 쓰는 무제한 스티키 노트"
status: "active"
where: "greenfield"
selected_packs: "ux,data,operation,verification"
created_at: "2026-09-07"
updated_at: "2026-09-07"
question_count: 0
normalization_policy: "transcript-sync-with-checkpoint-backfill"
normalization_checkpoint_every: 10
---

# Interview Log: 단축키로 꺼내 쓰는 무제한 스티키 노트

## Current Understanding

- Raycast Notes처럼 단축키로 바로 꺼내 쓰는 별도 메모 앱을 원한다.
- 사용자는 현재 Option+`로 Notes를 열며 sticky한 사용감을 중요하게 여긴다.
- 노트 개수 제한 없이 쓰는 것이 핵심 동기다.
- sticky의 정확한 동작, 편집 범위, 저장과 복구 정책은 인터뷰에서 확인한다.

## Intake Cursor

- next_decision_id: D-03
- next_question: (owned by the live conversation until checkpoint)
- last_materiality_sweep: preflight
- outstanding_raw_entries: none
- next_checkpoint_at: Q10

## Transcript Sources

| Runtime | Session ID | Start ref |
| --- | --- | --- |
| codex | 01a07b7a-30de-7063-8c65-7aa28f503c76 | msg_01a07b80-30f4-7a23-97f4-48a5a75ea5eb |

## Decision Register

| ID | Kind | Area | Decision / fact | Priority | Source / owner | Status | PRD mapping / revisit |
| --- | --- | --- | --- | --- | --- | --- | --- |
| D-01 | fact | repository | 현재 저장소에는 워크플로 설정과 에이전트 지침만 있으며 앱 코드와 검증 명령은 없다. | P1 | repo: AGENTS.md; agents/config.json; git ls-files | resolved | 구현 기반 및 검증 구성 |
| D-02 | decision | product | Raycast Notes처럼 단축키로 꺼내 쓰되 노트 개수 제한이 없는 별도 메모 앱을 만든다. | P0 | user invocation: codex:01a07b7a-30de-7063-8c65-7aa28f503c76:msg_01a07b80-30f4-7a23-97f4-48a5a75ea5eb | resolved | 핵심 제품 요구사항 및 노트 개수 제한 없음 검증 |

## Raw Q&A

## UX Scenario Cards

## Evidence From Code, Docs, Or Research

## Documented Domain Checks

- docs inspected:
- canonical terms:
- glossary or code conflicts:
- concrete scenarios tested:
- docs mutation:
- ADR candidate:

## Checkpoint And Sweep History

## Audit History
