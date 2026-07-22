---
description: Запустить локальный проект и проверить работоспособность
---

Запусти проект $ARGUMENTS локально.

Шаги:
1. Прочитай заметки проекта:
   $SDLC_VAULT/Local_Run/$ARGUMENTS/

2. Подготовь переменные окружения безопасно:
   - никогда не выполняй repository `.env` через `source`, `eval` или `xargs`;
   - используй нативный dotenv/env-file loader выбранного runtime только как parser данных;
   - секреты получай из `pass` только в environment конкретного процесса и сразу очищай;
   - не печатай значения и не включай shell tracing.

3. Активируй окружение:
   - Python: `source venv/bin/activate`
   - Node.js: `nvm use` (если .nvmrc)

4. Определи команду запуска (из package.json scripts / Makefile / README)

5. Запусти в dev-режиме:
   `(cd "$LOCALRUN_PROJECTS/$ARGUMENTS" && [команда])`

6. Smoke test — проверь что запустилось:
   - Найди порт из конфига или вывода
   - `curl -s http://localhost:[порт]/` или `/health`
   - Если web UI — покажи URL

7. При ошибках запуска:
   - Покажи полный вывод
   - Диагностируй (порт занят? зависимость не запущена? нет .env?)
   - Исправь и перезапусти

8. Создай/обнови заметку:
   $SDLC_VAULT/Local_Run/$ARGUMENTS/run.md

   Зафиксируй: команда, порты, URL, как остановить.
