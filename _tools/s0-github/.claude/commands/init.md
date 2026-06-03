---
description: Инициализировать git-репозиторий и подключить к GitHub
---

Инициализируй git-репозиторий для проекта $ARGUMENTS и подключи к GitHub.

Шаги:
1. Перейди в папку проекта:
   $SDLC_VAULT/projects/$ARGUMENTS

2. Проверь, существует ли уже .git:
   - Если да — сообщи об этом и спроси продолжать ли
   - Если нет — инициализируй: `git init`

3. Создай .gitignore с содержимым из CLAUDE.md

4. Создай GitHub-репозиторий:
   `gh repo create sdlc-$ARGUMENTS --private --description "SDLC артефакты: $ARGUMENTS"`
   (если уже существует — пропусти создание, только добавь remote)

5. Добавь remote:
   `git remote add origin https://github.com/$(gh api user --jq .login)/sdlc-$ARGUMENTS.git`

6. Создай ветки по этапам SDLC (из CLAUDE.md)

7. Сделай первый коммит:
   `git add .`
   `git commit -m "[SYNC] init: initial project structure for $ARGUMENTS"`

8. Push в main:
   `git push -u origin main`

9. Push всех веток:
   `git push --all`

В конце покажи:
- URL репозитория на GitHub
- Список созданных веток
- Что было закоммичено
