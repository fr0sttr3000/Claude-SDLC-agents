---
description: Обновить видение / беклог / требования для существующего проекта
---

Проект: $ARGUMENTS

Выполни режим REFRESH строго по CLAUDE.md:
1. Прочитай Dashboard.md и артефакты этапов 1-2, выведи текущее состояние проекта
2. Покажи меню выбора разделов для обновления (1-7), включая только Cycle 1
   reliability/observability NFR; delivery/operations tooling не собирай
3. Проведи целевое интервью только по выбранным разделам
4. Запиши соответствующие входные файлы:
   - PM-input-refresh-YYYY-MM-DD.md (если выбраны видение/OKR)
   - BA-input-refresh-YYYY-MM-DD.md (если выбраны требования/беклог/NFR/scope)
5. Сверь Product & CI facts. Если изменился хотя бы один — выполни `/product-ci-profile`,
   увеличь revision, сохрани snapshot и evidence invalidation record.
6. Сообщи какие агенты запустить следующими; при `PROFILE BLOCKED` Stage 1 не предлагай.
