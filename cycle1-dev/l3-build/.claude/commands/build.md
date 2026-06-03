---
description: Собрать локальный проект
---

Собери проект $ARGUMENTS.

Шаги:
1. Прочитай заметку setup.md:
   $SDLC_VAULT/Local_Run/$ARGUMENTS/setup.md

2. Определи команду сборки (в порядке приоритета):
   - Makefile → `make`
   - package.json → `npm run build`
   - go.mod → `go build ./...`
   - pom.xml → `mvn package`
   - build.gradle → `./gradlew build`
   - Dockerfile → `docker build`
   - requirements.txt → `pip install -e .`

3. Активируй окружение если нужно:
   - Python: `source venv/bin/activate`
   - Node.js: `nvm use` (если .nvmrc)

4. Запусти сборку из папки проекта:
   `(cd "$LOCALRUN_PROJECTS/$ARGUMENTS" && [команда сборки])`

5. При ошибках:
   - Покажи полный вывод ошибки
   - Диагностируй и исправь
   - Перезапусти сборку

6. Создай/обнови заметку:
   $SDLC_VAULT/Local_Run/$ARGUMENTS/build.md

7. В конце:
   - Статус: ✅ Собрано / ❌ Ошибка
   - Где находится результат сборки
   - Следующий шаг: `claude /run $ARGUMENTS` у агента l4-run
