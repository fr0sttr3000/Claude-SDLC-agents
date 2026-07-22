---
description: Подготовить отдельную ветку, commit и push с независимыми подтверждениями
---

Для project $ARGUMENTS покажи root/status/current branch/remote и proposed branch name.
Создай или переключи ветку только после подтверждения. Затем выполни тот же обязательный
flow, что `/sync`: candidate preview → подтверждённый `git add -A` → staged secrets scan
без вывода значений → staged preview → подтверждение commit → отдельное подтверждение push.

Если repository/remote отсутствует, scan нашёл finding, branch неоднозначна или auth
не работает — BLOCKED. Не переходи на main, не force-push и не меняй remote автоматически.
