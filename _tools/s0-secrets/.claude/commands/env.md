---
description: Показать переменные окружения для проекта (без значений)
---

Покажи переменные окружения для проекта $ARGUMENTS.

Шаги:
1. Найди все секреты проекта:
   `pass ls sdlc/projects/$ARGUMENTS`
   и глобальные: `pass ls sdlc/`

2. Покажи только mapping `ENV_VAR → pass/path` без реальных значений и без создания файла:
```bash
ANTHROPIC_API_KEY → pass:sdlc/anthropic-api-key
GITHUB_TOKEN → pass:sdlc/github-token
PROJECT_DB_PASSWORD → pass:sdlc/projects/$ARGUMENTS/db-password
```

3. Покажи безопасную session/process-local загрузку (при выключенном shell tracing):
```bash
set +x
ANTHROPIC_API_KEY="$(pass show sdlc/anthropic-api-key)" command-that-needs-it
unset ANTHROPIC_API_KEY
```

Не используй `eval`, `xargs`, shell profile (`.bashrc`), history-bearing literal values или
plaintext env files. НЕ выводи реальные значения секретов.
