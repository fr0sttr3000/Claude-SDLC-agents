---
date: 2026-08-23
tags: [release, v2.001.001, cycle1, change-scope, runtime-boundary, quality]
version: 2.001.001
status: PREPARED_NOT_PUBLISHED
---

# Release Notes — v2.001.001

**Тип:** Cycle 1 patch / Stage 4 change-boundary and current-artifact hardening

**Дата подготовки:** 2026-08-23

**Базируется на:** подготовленной platform-линии v2.001.000

**Статус:** PREPARED / NOT PUBLISHED

## Кратко

Релиз добавляет обязательный Change Scope перед изменяющими шагами Stage 4. До записи launcher
фиксирует Change Intent, получает независимые L1- и S3-оценки влияния, собирает точную таблицу
owners/paths и требует отдельное Human Approval. Runtime получает только разрешённые write paths,
а launcher проверяет полный before/after manifest Project.

Одновременно исправлено разрешение current artifacts в архитектурных и QA-проверках: retained
history больше не может подменить manifest-selected current artifact. QA verdict связывается с
точным current requirements review, а quality checks используют только зарегистрированные metric
IDs.

Cycle 1 сохраняет каноническую последовательность из 28 обязательных шагов. Cycle 2/3 остаются
`FROZEN / NOT READY`, worker execution — fail-closed.

## Основные изменения

### 1. Change Scope v1

- Добавлен typed contract для Change Intent, L1 impact, S3 architecture/path impact, assembled
  owner/path table и отдельного Human Approval.
- Scope preparation разделена между независимыми процессами: L1 и S3 не подтверждают собственный
  результат, а Stage 4 не может расширить выданную границу.
- Current scope и его digest проверяются перед каждым изменяющим шагом Stage 4.
- Изменение HLD, API contracts или ADR возвращается владельцу Stage 3 и требует нового scope.

### 2. Scoped-write runtime boundary

- Для Stage 4 зарегистрированы `scoped-write` capabilities с owner-specific write allowlist.
- Launcher сопоставляет полный Project manifest до и после запуска: create, delete, rename,
  content, mode, type и symlink changes входят в verdict.
- `USE|LOCKED`, notes, ambient home, sibling Projects, VCS metadata и неуказанные Project paths
  остаются недоступными для записи.
- Нарушение scope сохраняется как launcher-owned evidence и блокирует последующие mutations до
  восстановления Project или отдельного свежего approval; автоматический rollback не выполняется.

### 3. Governance output ownership

- Registry-owned Stage 4 governance outputs нельзя заявить как native paths агента.
- Такие outputs добавляются launcher-ом только как зарегистрированные `declared-output`
  alternatives.
- Postflight требует одновременно корректный full diff и все обязательные declared output groups.
- TDD repair использует тот же scope и postflight contract, что исходная Stage 4 команда.

### 4. Current artifacts и QA binding

- Gate 2/3 consumers принимают только artifact, выбранный current-artifact manifest.
- Missing, stale или malformed manifest row блокирует проверку без fallback на history glob либо
  fixed filename.
- QA decision record обязан ссылаться на exact current requirements review и его digest.
- Retained historical artifacts сохраняются, но не участвуют в current verdict.

### 5. Quality и implementation principles

- Dev Report использует канонический metric ID `branch_coverage_percent`.
- Semantic regression checks отклоняют metric IDs, отсутствующие в authoritative quality-policy
  registry.
- KISS закреплён для implementation-writing roles: минимальный достаточный diff без ослабления
  architecture, quality, security, reliability, recovery или test controls.
- Function size определяется SRP и эффективной complexity policy, а не отдельным prose-only
  лимитом строк.
- Feasibility handoff больше не выводит HTTP endpoints, monitoring stack или executable runbooks
  из одного criticality tier.

### 6. Launcher, contracts и документация

- Utilities и Project Console описывают полный Change Scope workflow и его approval boundary.
- Runtime access и command capability registries синхронизированы с новыми scoped-write routes.
- README, OVERVIEW, principles, roadmap, role contracts и shared command templates приведены к
  одной семантике.
- Поставленный Change Scope v1 перенесён из активного roadmap в changelog и release notes.

## Критические изменения поведения

- Stage 4 mutation без current approved Change Scope теперь блокируется.
- Exit code runtime и наличие отчёта не подтверждают mutation без прошедшего full-diff verifier.
- Stale/tampered scope либо current-artifact reference не получают fallback и завершаются
  `BLOCKED/UNVERIFIED`.
- Scope violation не откатывается автоматически: оператор должен восстановить Project либо
  отдельно подтвердить новый scope.
- Agent-owned paths не могут включать launcher-owned governance artifacts.

## Требуемые действия при обновлении

1. Перед первым изменяющим шагом Stage 4 открыть `Utilities → Change Scope` и зафиксировать exact
   intent/task/FR references.
2. Проверить результаты isolated L1/S3 impact, owner/path modes и только затем подтвердить Human
   Approval.
3. Для уже начатого Project пересоздать stale scope/current references штатным launcher workflow;
   не править digest-bound verdict вручную.
4. Если зафиксировано scope violation, восстановить Project до разрешённого состояния либо создать
   и отдельно подтвердить свежий scope.
5. Не добавлять governance outputs в native Stage 4 path lists: их выдаёт capability registry.

## Миграции и совместимость

- Репозиторная data migration не требуется.
- Existing Project получает Change Scope artifacts additively; исторические материалы не
  переписываются.
- Каноническая 28-step Cycle 1 sequence и active role ordering не изменены.
- Claude, Codex, Gemini и зарегистрированные Local hosts сохраняются как primary runtimes без
  silent fallback.
- Linux/WSL2 остаётся поддерживаемой execution boundary; Windows adapter остаётся experimental.
- Cycle 2/3 остаются `FROZEN / NOT READY`; `SDLC_SUBAGENTS=off` остаётся единственным
  поддерживаемым worker mode.

## Проверка

- `sdlc.sh` прошёл `bash -n`.
- User-facing launcher navigation, first-run, Preview/dispatch, runtime scopes, Journal, Gate
  orchestration, Review/Repair, Change Scope, TDD, Tracker/capability routes и Local Repositories
  прошли соответствующие smoke-сценарии.
- Release-notes utility завершилась с `PASS: release notes utility smoke`.
- Windows wrapper прошёл platform-neutral static smoke; реальный Windows runtime не выполнялся.
- Внешняя positive runtime matrix с синтетическим Project вне repository не выполнялась;
  релиз не заявляет её PASS.

## Известные ограничения

- Live representative Codex App Cycle 1 E2E ещё не подтверждён.
- Внешняя Project runtime matrix не входит в evidence этой подготовки релиза.
- Windows остаётся `EXPERIMENTAL / NOT TESTED ON WINDOWS`.
- Worker execution недоступен до capability-enforced bounded read scope.
- Cycle 2/3 остаются `FROZEN / NOT READY`.
- Этот документ не выполняет commit, tag, push, PR, GitHub Release, build, deploy или production
  action.
