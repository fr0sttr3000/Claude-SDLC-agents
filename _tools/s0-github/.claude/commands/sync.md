---
description: Безопасно подготовить commit и отдельно подтвердить push
---

Для project $ARGUMENTS выполни contract из CLAUDE.md:

1. Read-only preview: root, branch, remote, `git status --short`, candidate files.
2. Запроси подтверждение staging. Только затем `git add -A` внутри project root.
3. Просканируй staged snapshot и forbidden paths, не выводя совпавшие строки/значения.
4. При finding безопасно unstage, сохрани working files, верни BLOCKED с именами файлов.
5. Покажи staged name-status/stat и proposed commit message; запроси commit confirmation.
6. После commit покажи hash/summary и отдельно запроси push confirmation.
7. Push только подтверждённой branch/remote; silent fallback запрещён.
