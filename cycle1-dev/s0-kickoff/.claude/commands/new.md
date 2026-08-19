---
description: Принудительно запустить полное интервью для нового проекта
---

Проект: $ARGUMENTS

Выполни режим NEW строго по CLAUDE.md:
1. Уведоми: "Режим: NEW — новый проект"
2. Проведи все 5 блоков интервью из CLAUDE.md. В Блоке 3 получи только подтверждённые
   runtime constraints и измеримые reliability/observability expectations Cycle 1.
   Не собирай delivery/operations tooling: Cycle 2/3 FROZEN / NOT READY.
   Правило: вопросы ПОСЛЕДОВАТЕЛЬНО, по одному. Жди ответа. После каждого блока — резюме + подтверждение.
3. Запиши:
   - stage1-planning/inputs/idea.md (заполненный)
   - stage1-planning/inputs/PM-input-interview-YYYY-MM-DD.md
4. Выполни `/product-ci-profile`: сначала observed repository/CI facts, затем только
   неизвестные обязательные вопросы; запиши revision 1 + snapshot и получи `PROFILE VALID`.
5. Сообщи следующий шаг: s1-pm /feasibility. При `PROFILE BLOCKED` Stage 1 не предлагай.
