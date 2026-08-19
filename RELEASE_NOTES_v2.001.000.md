---
date: 2026-08-19
tags: [release, v2.001.000, cycle1, runtime-boundary, evidence, quality]
version: 2.001.000
status: PREPARED_NOT_PUBLISHED
---

# Release Notes — v2.001.000

**Тип:** Cycle 1 contract consolidation / Runtime and evidence hardening

**Дата подготовки:** 2026-08-19

**Базируется на:** v2.000.004
(`main@2ab00691366a55ba58ad194efe8f2d5136e2e761`)

**Статус:** PREPARED / NOT PUBLISHED

## Кратко

Релиз сводит поддерживаемый продукт к общей platform + Cycle 1 и делает launcher-owned
проверки источником исполняемого результата. Exit code runtime больше не может сам подтвердить
изменение: capability registry, exact output groups, current-artifact digests, gates, DoD и
completion proof должны согласоваться до verified handoff.

Cycle 2/3 остаются сохранённым historical baseline со статусом `FROZEN / NOT READY`.
Worker execution отключён fail-closed до появления доказуемой bounded read boundary.

## Основные изменения

### 1. Capability-enforced runtime boundary

- Все active commands классифицированы по access, declared outputs и result verifier.
- Supported Linux dispatcher применяет точную runtime access matrix; отсутствие enforcement
  блокирует запуск.
- Ambient user configuration не попадает в Codex task processes; каждый task ephemeral.
- Secret-like prompt input отклоняется до Preview и argv без вывода самого значения.

### 2. Evidence, approvals и current artifacts

- Evidence v1 связывает producer, source revision, subject и native result digest.
- Human decisions хранятся отдельно и привязаны к exact subject digest.
- Current Artifacts v1 отделяет versioned history от единственной current logical reference.
- Gate 1, PR-set/Gate 4, S5 и Cycle 1 Completion используют exact machine-verifiable handoff.

### 3. TDD, DoD и quality

- Канонический цикл: Specify → Red → Green → Run → Repair → Refactor.
- TDD Status проверяет RED provenance и полный affected regression result на одной source revision.
- Machine `DOD_AUTO_PASS` отделён от полного `DOD_PASS`, требующего независимых approvals и
  current Tech Lead reviews.
- Quality policy использует versioned only-up thresholds и typed metric evidence.
- Quality Characteristics связывают profile applicability с существующим owner, contract и Gate.

### 4. Security и risk lifecycle

- SG1/SG2 требуют versioned ASVS semantics и exact digest binding; SG3 остаётся независимой
  policy-проверкой.
- Risk Exception v3 ссылается на exact finding и создаёт проверяемый Tech Debt lifecycle.
- Known Issues используют канонические severity/status поля; неоднозначный legacy input не
  получает молчаливый PASS.
- Secret results разрешены только в зарегистрированных machine-readable форматах; plaintext
  temporary secret files не являются исключением.

### 5. Tracker и release preparation

- Tracker mutations доступны только через отдельный Utilities workflow с exact Preview,
  Journal и named postcondition verifier.
- Task/sprint state проверяется в active ledgers с точной cardinality; historical closed sprint
  не загрязняет текущий verdict.
- NEXT/overdue Tech Debt материализуется в backlog через отдельный проверяемый маршрут.
- Project release notes создаются только после verified Cycle 1 completion и не выполняют
  build, deploy или external publication.

### 6. Product and architecture contracts

- Product & CI Profile v5 фиксирует executor, UX, representative S5 environment и applicability
  без inferred defaults.
- Gate 1 planning, product acceptance, architecture decision trace и Runtime Constraints имеют
  отдельные typed/digest-bound contracts.
- Stage 4 authorization consumers используют current logical artifacts вместо history globs.
- Migration validation покрывает upgrade → downgrade → upgrade, а N/A требует structured reason.

### 7. Launcher и reporting

- Exit `0` означает только `PROCESS_OK`; mutation завершается после
  `ARTIFACT_VERIFIED`, read-only command — после `READ_ONLY_VERIFIED`.
- Resume/retry сохраняет frozen plan и launcher-owned digest chain без vendor session resume.
- Completion summary появляется только после completion verification.
- Environment/setup failure не маскируется под корректный RED test result.
- Local Repositories сохраняет provider-neutral source handling и прекращает batch при первом
  обязательном skip/failure.

### 8. Документация и platform scope

- README стал единым пользовательским руководством; отдельные устаревшие onboarding/map docs
  удалены.
- OVERVIEW описывает фактическую архитектуру, current data model и execution boundary.
- Principles, roadmap, contracts, changelog и release notes разделены по ответственности.
- Runtime adapters ссылаются на общий канон и не определяют собственные SDLC gates.

## Критические изменения

- Cycle 2/3 больше не являются исполняемыми launcher routes и не блокируют Cycle 1.
- Worker profiles больше не выполняются: поддерживается только `SDLC_SUBAGENTS=off`.
- Primary runtimes не получают VCS control-plane: commit, push, branch, PR и tag остаются
  действиями оператора вне agent dispatch.
- Legacy self-attested `PASS`, stale refs и process exit `0` без verifier считаются
  `UNVERIFIED/BLOCKED`.

## Требуемые действия при обновлении

1. Запускать Cycle 1 только после валидного Product & CI Profile v5.
2. Установить `SDLC_SUBAGENTS=off`; удалить ожидание автоматического worker fallback.
3. Проверить current-artifact registry и выполнить additive legacy migration report для
   существующего Project; массовая перезапись legacy artifacts не требуется.
4. Пересоздать stale evidence/approvals на exact source revision вместо ручного изменения PASS.
5. На Windows продолжать считать wrappers experimental до реального успешного matrix run.

## Миграции и совместимость

- Репозиторная data migration не требуется.
- Existing Project migration — additive/read-only inventory; legacy artifacts сохраняются как
  `LEGACY / UNVERIFIED` до касания owning role.
- Claude, Codex, Gemini и зарегистрированные Local hosts сохраняются как primary runtimes.
- Silent runtime/model/provider fallback отсутствует.

## Проверка

- Полный `tests/system-contract-smoke.sh` завершён с `PASS: system contract smoke`.
- Все обнаруженные публичные shell entrypoints прошли `bash -n`.
- `_runtimes/cycle-landlock.c` прошёл `cc -fsyntax-only`.
- Public root inventory и документационные contract/semantics checks прошли.
- `git diff --check` и `git diff --cached --check` не нашли whitespace errors.
- Windows adapter прошёл platform-neutral static tests; real Windows execution не выполнялся.

## Известные ограничения

- Live representative Codex App Cycle 1 E2E ещё не подтверждён.
- Windows остаётся `EXPERIMENTAL / NOT TESTED ON WINDOWS`.
- Worker execution недоступен до capability-enforced bounded read scope.
- Cycle 2/3 остаются `FROZEN / NOT READY`.
- Этот документ не выполняет commit, tag, GitHub Release, build, deploy или production action.

## Подготовка публикации

Рекомендуемый release commit:

`feat!: harden Cycle 1 runtime and evidence contracts`

Рекомендуемая PR base:
`main@2ab00691366a55ba58ad194efe8f2d5136e2e761`.

Публикация, tag и GitHub Release требуют отдельных операторских действий после merge.
