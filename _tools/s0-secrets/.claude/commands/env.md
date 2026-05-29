---
description: Показать переменные окружения для проекта (без значений)
---

Покажи переменные окружения для проекта $ARGUMENTS.

Шаги:
1. Найди все секреты проекта:
   `pass ls sdlc/projects/$ARGUMENTS`
   и глобальные: `pass ls sdlc/`

2. Сформируй env.sh БЕЗ реальных значений — только структуру:
```bash
#!/bin/bash
# Переменные окружения для проекта: $ARGUMENTS
# Загрузка: source <(pass sdlc/projects/$ARGUMENTS/env.sh)
# Или построчно:

export ANTHROPIC_API_KEY=$(pass sdlc/anthropic-api-key)
export GITHUB_TOKEN=$(pass sdlc/github-token)
# export PROJECT_DB_PASSWORD=$(pass sdlc/projects/$ARGUMENTS/db-password)
# export PROJECT_API_KEY=$(pass sdlc/projects/$ARGUMENTS/api-key)
```

3. Покажи как загрузить переменные перед запуском агентов:
```bash
# Вариант 1 — загрузить в текущую сессию
eval $(pass sdlc/anthropic-api-key | xargs -I{} echo "export ANTHROPIC_API_KEY={}")

# Вариант 2 — добавить в ~/.bashrc
echo 'export ANTHROPIC_API_KEY=$(pass sdlc/anthropic-api-key)' >> ~/.bashrc
```

НЕ выводи реальные значения секретов.
