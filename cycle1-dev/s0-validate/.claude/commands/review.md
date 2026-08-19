---
description: Провести scoped read-only review проекта, Cycle, Stage или Agent artifacts
---

Проведи только read-only review проекта $ARGUMENTS.
Ожидаемый scope: `project`, `cycle:1`, `stage:0..5` или `agent:<active-id>`.
Если scope отсутствует или неоднозначен, сначала спроси. До анализа повтори абсолютный project
path, включённый scope и excluded scope.

Проверь active структуру, обязательные inputs/outputs, DoR/DoD/TDD/SG1–SG4 evidence и трассировку.
Project scope исключает historical Stage 6/7 content, кроме подтверждения их frozen status.
Для agent scope читай только active contract и связанные artifact paths. Проверка AI routes
принадлежит отдельному launcher workflow и не выполняется этой project-review командой.

Ничего не редактируй, не создавай report-файл, не запускай workflow/tests с side effects.
Запрос Cycle 2/3, Stage 6/7 или frozen agent верни как `FROZEN / NOT READY`, без анализа readiness.
Верни findings только как machine-readable строки с tab-разделителями:

```text
REVIEW_FINDING\tFND-ID\tCRITICAL|HIGH|MEDIUM|LOW\tproject-relative-target|none\tcontract-id\trepair-scope\tкраткое описание
```

Для чистого scope верни ровно одну строку:

```text
REVIEW_FINDING\tCLEAN\tINFO\tnone\tnone\t<exact requested scope>\tNo findings
```

Не добавляй tab внутрь полей, секреты, абсолютные локальные пути или неподтверждённый CLEAN.
Launcher сохраняет только эти проверенные строки в immutable findings artifact вне Project.
