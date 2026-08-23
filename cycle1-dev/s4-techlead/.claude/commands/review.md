---
description: Провести Code Review PR и подтвердить Gate 4 перед переходом в S5
---

Проведи Code Review для проекта $ARGUMENTS. Gate 4 разрешает только переход S4 → S5;
он не разрешает release, build, push или deploy.

Прочитай:
1. $SDLC_VAULT/_agents/_standards/quality.md
2. $SDLC_VAULT/_agents/_standards/tdd.md
3. $SDLC_VAULT/_agents/_standards/artifact-metadata.md
4. $SDLC_VAULT/_agents/_contract/EVIDENCE_V1.md
5. $SDLC_VAULT/_agents/_contract/SG3_POLICY_V1.md
6. $SDLC_VAULT/_agents/_contract/TDD_STATUS_V1.md
7. $SDLC_VAULT/_agents/_contract/QUALITY_CHARACTERISTICS_V1.md
8. Current `product-ci-profile`, `quality-policy`, `quality-characteristics-index`
9. Current `tdd-status`
10. Current `architecture-decisions` и `architecture-decision-index`
11. Current `development-pr-summary` и `development-update-notes`
12. Все Project artifacts выше разрешай по root Current Artifacts rule
13. $SDLC_VAULT/_agents/_contract/HUMAN_APPROVAL_V1.md
14. $SDLC_VAULT/_agents/_contract/CURRENT_ARTIFACTS_V1.md
15. Current approved Change Scope и `_contract/CHANGE_SCOPE_V1.md`

Уточни у пользователя PR и расположение кода. Из current `tdd-status` возьми exact
`source_revision`, затем до смыслового review выполни для одного и того же Project/source:

```bash
bash "$SDLC_VAULT/_agents/cycle1-dev/s0-validate/tdd-status-check.sh" \
  "$SDLC_PROJECTS_DIR/$ARGUMENTS" PASS
bash "$SDLC_VAULT/_agents/cycle1-dev/s0-validate/pr-evidence-check.sh" \
  "$SDLC_PROJECTS_DIR/$ARGUMENTS" "<EXACT_SOURCE_REVISION>"
bash "$SDLC_VAULT/_agents/cycle1-dev/s0-validate/sg3-policy-check.sh" \
  "$SDLC_PROJECTS_DIR/$ARGUMENTS" "<EXACT_SOURCE_REVISION>"
```

Любой non-zero, RED/FAIL/BLOCKED/UNVERIFIED, stale profile/source или selective regression
блокирует review. Свободный Markdown `PASS` и фраза «SAST прошёл» не являются evidence.
Не переподписывай raw results: запиши только verified evidence ids и exact source.

Создай `$SDLC_PROJECTS_DIR/$ARGUMENTS/stage4-dev/outputs/TL-[дата]-review-PR[N].md`.
Файл обязан иметь общий Artifact Metadata v1, Obsidian Links и дополнительные поля
`product_profile_revision`, `source_revision`, `status: PASS|FAIL|BLOCKED`.

# Code Review — PR #[N] — $ARGUMENTS

## Machine evidence

- TDD status: VERIFIED, source `<EXACT_SOURCE_REVISION>`
- PR evidence ids: `<EV-...>`
- SG3 evidence ids: `<EV-...>`
- Effective quality policy/profile revision: `<revision>`
- Change Scope digest: `<SDLC_CHANGE_SCOPE_SHA256>`

## Change Scope Review

- Intent/Project Map/L1/S3 bindings: PASS|BLOCKED
- Approved native paths versus observed PR diff: PASS|FAIL
- QA-only test paths and Dev-only production paths: PASS|FAIL
- `USE|LOCKED` modules unchanged: PASS|FAIL
- Unapproved create/delete/rename/mode/symlink changes: none|exact findings

Любое несовпадение scope, source или полного PR diff — `CHANGES REQUESTED`. Не расширяй scope
из review и не исправляй code/tests; запроси свежую L1 → S3 preparation и Human Approval.

## Замечания

Формат: `[BLOCKER|MAJOR|MINOR|SUGGESTION|QUESTION|PRAISE] файл:строка — описание`.
BLOCKER и MAJOR запрещают approve.

## Maintainability Review

Каждую характеристику оцени отдельно по exact code/evidence; один общий SOLID verdict
не заменяет пять измерений.

Modularity: PASS|FAIL
Reusability: PASS|FAIL
Analysability: PASS|FAIL
Modifiability: PASS|FAIL
Testability: PASS|FAIL
Maintainability rationale: <конкретное обоснование и change impact>
Maintainability evidence ids: <EV-...,...>

## Stack-applicable review

Применяй правила только к реально выбранному стеку из Product Profile/HLD. Для
Python/PostgreSQL/aiogram проверь соответствующие lessons learned роли; отсутствие этих
компонентов не является дефектом. Для другого стека используй его эквивалентные проверки.

## DoD Checklist — Gate 4

- Бизнес-логика и edge cases соответствуют AC.
- Security, performance, error handling и maintainability проверены.
- Complexity, duplication, branch/mutation и другие числа взяты из effective quality policy.
- Integration/component evidence есть для каждого изменённого внешнего адаптера.
- Contract evidence есть для каждого затронутого API-контракта.
- DEV update notes и применимая README/API/docstring документация обновлены.
- Все minimum PR/SG3 checks verified для exact source; Critical/High и запрещённые
  security exceptions отсутствуют.

## РЕШЕНИЕ

- `APPROVED` — все применимые DoD/Gate 4 checks verified, 0 BLOCKER/MAJOR.
- `APPROVED WITH COMMENTS` — только MINOR/SUGGESTION, merge после оговорённых исправлений.
- `CHANGES REQUESTED` — любой BLOCKER/MAJOR/FAIL/BLOCKED/UNVERIFIED.

После `APPROVED` только покажи human preview: exact `source_revision`, verified build
`subject_digest` и однострочный `scope` со всеми `DOD-1`–`DOD-11` и
`techlead-review:<PROJECT_RELATIVE_REF>@<SHA256>`. Launcher добавляет к нему
`execution-run:<active-run-id>`; агент этот идентификатор не придумывает. Не создавай,
не редактируй, не подтверждай и не имитируй файл Human Approval. Пользователь или
уполномоченный независимый Tech Lead
запускает отдельное интерактивное действие `_runtimes/human-approval-record.sh` вне primary
agent dispatch. При полном Cycle 1 это действие вызывает сам launcher после exact request
preview. Только оно создаёт Project record и недоступный агенту launcher receipt.

После сообщения пользователя о выполненном human action проверь результат:

```bash
bash "$SDLC_VAULT/_agents/cycle1-dev/s0-validate/dod-approval-check.sh" \
  "$SDLC_PROJECTS_DIR/$ARGUMENTS" "<EXACT_SOURCE_REVISION>"
```
