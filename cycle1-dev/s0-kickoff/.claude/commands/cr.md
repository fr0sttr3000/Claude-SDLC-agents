---
description: Провести Change Request и определить затронутые artifacts/gates
---

Проведи Change Request для проекта $ARGUMENTS по контракту `s0-kickoff/CLAUDE.md`.

1. Прочитай текущие idea/PMO constraints, BRD/NFR/RTM, backlog и открытые DoR violations.
2. Проведи четыре блока интервью: что меняется; точное before/after; причина и ожидаемый эффект;
   срочность/ограничения/authorization.
3. Не угадывай ответы и не изменяй downstream outputs.
4. Создай новый `stage{N}/inputs/CR-YYYY-MM-DD-[N]-input.md` с уникальным CR ID.
5. Добавь в `tracking/dor-violations.md` impact matrix: затронутые FR/NFR/artifacts/tests/gates,
   сброшенные DoR/SG/TDD evidence и список ролей, которые пользователь должен перезапустить.
6. Покажи scope до записи; не запускай агентов и не начинай разработку автоматически.
