---
description: Настроить локальный проект (зависимости, .env, конфигурация)
---

Настрой проект $ARGUMENTS для локального запуска.

Шаги:
1. Прочитай заметку: $SDLC_VAULT/Local_Run/$ARGUMENTS/overview.md
   (если нет — сначала запусти /analyze у агента l1-analyze)

2. Определи стек и выбери стратегию установки из CLAUDE.md

3. Проверь наличие .env.example:
   `ls $LOCALRUN_PROJECTS/$ARGUMENTS/.env*`

4. Установи зависимости согласно стеку

5. Подготовь environment contract:
   - `.env.example` можно скопировать только как список имён/несекретных defaults;
   - значения из `pass` не записывай в `.env`, notes или generated shell scripts;
   - передавай секреты process-local при запуске; если tool требует env-file, остановись и
     запроси явное согласие на временный файл с mode 600, cleanup plan и запретом Git;
   - неизвестные значения спроси у пользователя, не угадывай.

6. Запусти docker-compose если есть:
   `docker compose up -d`

7. Создай/обнови заметку:
   $SDLC_VAULT/Local_Run/$ARGUMENTS/setup.md

   Зафиксируй: что установлено, что изменено, какие переменные нужны.

8. В конце выведи чеклист:
   - [ ] зависимости установлены
   - [ ] .env настроен
   - [ ] docker сервисы запущены (если нужно)
   - Следующий шаг: запусти `/build $ARGUMENTS` у агента `l3-build` через выбранный runtime
