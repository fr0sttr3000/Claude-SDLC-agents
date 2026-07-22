---
date: 2026-07-22
tags: [release, v2.000.004, principles, launcher, quality, security]
version: 2.000.004
---

# Release Notes — v2.000.004

**Тип:** Principles alignment / Reliability / UX hardening

**Дата:** 2026-07-22

**Базируется на:** v2.000.003

## Кратко

Релиз синхронизирует весь активный проект с `plans/principles.md` и фактическим поведением
launcher-а. Review/Repair теперь имеют реальные отдельные scopes, worker read-only обеспечивается
adapter-ом, validators проверяют правильные Gate/Stage artifacts, а текущая документация заново
описывает один Project Console и три активных test-first Cycle.

## Основные изменения

### 1. Реальный scoped Review и Repair

- Project, Cycle, Stage и Agent review формируют разные `/review scope=...` commands.
- Review вызывает runtime с `--access read-only`; mutation/interactive mode недоступны.
- Repair использует тот же scope и отдельный `structure`, показывает Preview и excluded areas.
- AI routes и multi-project structure остаются отдельными read-only обзорами.

### 2. Supervisor + Worker hardening

- Claude worker ограничен `Read,Glob,Grep` и no-session persistence.
- Codex/Local `codex-oss` используют read-only sandbox + ephemeral session.
- Worker read scope обязан находиться внутри configured project root; `/`, HOME и внешние
  paths блокируются.
- Gemini и custom Local остаются primary profiles, но не принимаются как workers до появления
  capability-enforced adapter. Silent fallback отсутствует.
- Worker environment формируется allowlist и не наследует произвольные secret variables.

### 3. Gate/DoR/DoD и TDD

- Исправлены validator counters под `set -e`, Gate numbering и artifact paths.
- Gate 2 требует BRD/NFR/RTM, backlog, QA contribution, test strategy и SG1.
- Stage 3 API/Auth/Data artifacts applicability-based; N/A требует evidence.
- Cycle 2 пишет Stage 6 delivery evidence и подписывается `s6-release` на Gate 6.
- Cycle 3 пишет только Stage 7 operations evidence и использует exact NFR/project thresholds.
- Release docs проверяются только при явной release preparation.

### 4. Stack-neutral agent contracts

- Markdown-first уточнён как governance, а code/tests/OpenAPI/SQL/DBML/YAML/IaC остаются native.
- PM/Architecture/Developer/DBA/RBAC/DevOps/SRE больше не навязывают стек как silent default.
- Threat model использует CVSS вместо локальной DREAD шкалы.
- DBA Stage 3 проектирует migration strategy/tests, но executable migration начинается в Stage 4
  после настоящего RED.
- QA Requirements выдаёт `QA contribution: PASS|FAIL`, а не подписывает весь Gate 2 заранее.

### 5. Runtime и Execution Journal

- Claude task mode стал non-persistent `--print`; read-only access передаётся явно.
- Journal безопасно quotes YAML-sensitive fields.
- Resume доверяет только anchored success/optional-skip events; текст evidence не может подделать step.
- Lease сверяет PID и process start time, защищаясь от PID reuse.

### 6. Local Repositories и utilities

- Skip обязательного шага полного pipeline возвращает incomplete (`3`) и не печатает success.
- Repository `.env` не source/eval, pass-derived secrets не сохраняются, build не skip-tests.
- GitHub flow: candidate preview → stage confirmation → staged scan без вывода values → commit
  confirmation → отдельный push confirmation.
- Добавлены недостающие `/branch`, `/task-block`, `/backlog` и validation/architecture commands.

### 7. Документация

Полностью синхронизированы:

- `README.md` — актуальный Project Console, routes, worker matrix и три Cycle;
- `GETTING_STARTED.md` — первый запуск и CJM новичка;
- `OVERVIEW.md` — layers, Stage 6/7 paths, Journal, Review/Repair и utilities;
- root `CLAUDE.md`, `_contract/*`, runtime adapters;
- `plans/roadmap.md` и `plans/document-map.md`.

`plans/principles.md` сохранён отдельным каноническим источником. Исторические release notes
не изменялись.

### 8. Follow-up hardening

- Проверены 170 regular files, 64 runtime-adapter symlinks и все 76 command templates.
- Launcher menu indexes валидируются до dispatch и не могут выбрать действие вне меню.
- Execution Journal сохраняет точные failing step, agent и task в BLOCKED state/event.
- Applicability contracts покрывают non-API, non-DB, CLI/library, images-only и
  operations-artifacts-only проекты без скрытых PostgreSQL/RLS/UUID/NFR defaults.
- Local Repositories notes update показывает exact Preview и завершает batch как incomplete
  на первом обязательном skip/failure.

## Критические изменения

- Gemini и произвольные Local profiles больше не принимаются как read-only workers, пока для них
  нет capability-enforced adapter. Они по-прежнему поддерживаются как primary profiles.
- Worker scope вне configured project root теперь блокируется вместо исполнения.
- Скрипты, которые полагались на прежний ложный success после обязательного Local Repositories
  skip, должны обрабатывать exit code `3` как incomplete.

## Требуемые действия при обновлении

- Миграции данных: не требуются.
- Новые env-переменные и секреты: не требуются.
- Если Gemini/custom Local назначен worker-ом, переназначить worker на Claude, Codex или Local
  `codex-oss`; primary profile менять не нужно.
- Проверить project-local AI routes и разрешённые worker scopes через Preview до первого запуска.
- Для автоматизации Local Repositories учитывать exit code `3` как незавершённый batch.

## Известные проблемы

Открытых release-blocking defects для `v2.000.004` по результатам полного локального аудита
не обнаружено. Нереализованные роли Discovery/UAT/Exploratory/Defect/Regression и пробелы
ISO/IEC 25010 остаются явно запланированными roadmap items, а не дефектами этого релиза.

## Проверка

Пройдены все 12/12 локальных smoke/regression scripts:

- Gate validator behavior;
- principles consistency;
- Cycle 1/2/3 TDD and Goal orchestration;
- first-run, UI/navigation, Preview/dispatch and advanced parity;
- Execution Journal;
- Local Repositories UX;
- Supervisor + Worker security;
- full system contract.

Дополнительно `bash -n` прошёл для всех shell-файлов, а `git diff --check` не обнаружил
ошибок whitespace.

## Совместимость и действия пользователя

- Existing primary Claude/Codex/Gemini/Local profiles сохраняются.
- Если Gemini/custom Local был выбран worker-ом, переназначьте worker на Claude, Codex или Local
  `codex-oss`; primary менять не требуется.
- Для read-only Review с Gemini primary назначьте `s0-validate` поддержанный per-agent profile.
- Старые Project journals остаются читаемыми; новые runs записывают безопасный quoted state/lease.
- После обновления рекомендуется открыть Project Console → `3 Review` и проверить нужный scope.

## Ограничения

Будущие роли Discovery/UAT/Exploratory/Defect/Regression и возможный перенос release preparation
из Cycle 2 в Cycle 1 остаются roadmap items. Они не представлены как реализованные в этом релизе.
