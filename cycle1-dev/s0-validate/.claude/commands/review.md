---
description: Провести scoped read-only review проекта, Cycle, Stage или Agent artifacts
---

Проведи только read-only review проекта $ARGUMENTS.
Ожидаемый scope: `project`, `cycle:1|2|3`, `stage:0..7`, `agent:<id>` или `ai-routes`.
Если scope отсутствует или неоднозначен, сначала спроси. До анализа повтори абсолютный project
path, включённый scope и excluded scope.

Проверь структуру, обязательные inputs/outputs, DoR/DoD/TDD/SG evidence, трассировку и
соответствие актуальному goal revision. Для agent scope читай только его contract и связанные
artifact paths. Для ai-routes проверяй exact profiles, полноту routes и отсутствие fallback.

Ничего не редактируй, не создавай report-файл, не запускай workflow/deploy/tests с side effects.
Верни findings в терминал: severity, evidence path, violated contract, exact repair scope.
