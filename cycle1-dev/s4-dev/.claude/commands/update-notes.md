---
description: Создать Update Notes для PR (обязательно после каждого PR)
---

Перед записью Markdown-артефакта прочитай `$SDLC_VAULT/_agents/_standards/artifact-metadata.md` и заполни обязательный frontmatter.

Создай Update Notes для PR проекта $ARGUMENTS.

Прочитай current approved Change Scope по `_contract/CHANGE_SCOPE_V1.md`. Эта команда может
изменять только launcher-registered `s4-dev /update-notes` governance output. Не меняй code,
tests, README, API spec или другие Project paths; описывай уже выполненные изменения. Если
нужного факта нет в current evidence — пометь `BLOCKED`, не расширяй scope.

Создай файл DEV-[дата]-update-notes-PR[N].md в:
$SDLC_PROJECTS_DIR/$ARGUMENTS/stage4-dev/outputs/

Уточни у пользователя номер PR (если не указан в задаче).

# Update Notes — PR #[N] — [дата]
Проект: $ARGUMENTS
Агент: s4-dev

## Что изменилось
[Кратко: добавлено / изменено / удалено]

## Влияние на API
[Новые endpoints / изменённые контракты / удалённые endpoints]
Если изменений нет — написать "Нет изменений".

## Влияние на схему БД
[Новые таблицы / изменённые столбцы / новые индексы / миграции]
Если изменений нет — написать "Нет изменений".

## Влияние на конфигурацию
[Новые env-переменные / изменённые дефолты / удалённые переменные]
| Переменная | Тип | Обязательна | По умолчанию | Описание |
|-----------|-----|-------------|--------------|---------|

## Runtime/compatibility considerations
[Миграция/config change/restart impact как информация для будущего planning; не выполнять
deploy, migration или production action.] Если влияния нет — написать "Нет".

## Обновлённая документация
- README: [да/нет + что изменилось]
- Current API contract alignment: [ссылка + соответствует / N/A]
- Stage 3 artifacts: не изменяются этой командой
- Требуемое изменение API contract/HLD/ADR: [нет | BLOCKED для launcher-mediated s3-arch
  handoff, затем fresh Change Scope и отдельное Human Approval]
- CHANGELOG/release notes: не изменяются этой командой; только отдельная release preparation
- Source-local docs/docstring: [exact approved paths + что изменилось]
