---
description: Запустить локальный проект и проверить работоспособность
---

Запусти проект $ARGUMENTS локально.

Шаги:
1. Прочитай заметки проекта:
   /home/host-gui-car/Documents/Obsidian Vault/Claude/Local_Run/$ARGUMENTS/

2. Загрузи переменные окружения если нужно:
   `source /home/host-gui-car/Projects/claude/$ARGUMENTS/.env` (или через pass)

3. Активируй окружение:
   - Python: `source venv/bin/activate`
   - Node.js: `nvm use` (если .nvmrc)

4. Определи команду запуска (из package.json scripts / Makefile / README)

5. Запусти в dev-режиме:
   `cd /home/host-gui-car/Projects/claude/$ARGUMENTS && [команда]`

6. Smoke test — проверь что запустилось:
   - Найди порт из конфига или вывода
   - `curl -s http://localhost:[порт]/` или `/health`
   - Если web UI — покажи URL

7. При ошибках запуска:
   - Покажи полный вывод
   - Диагностируй (порт занят? зависимость не запущена? нет .env?)
   - Исправь и перезапусти

8. Создай/обнови заметку:
   /home/host-gui-car/Documents/Obsidian Vault/Claude/Local_Run/$ARGUMENTS/run.md

   Зафиксируй: команда, порты, URL, как остановить.
