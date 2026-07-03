---
description: Проанализировать структуру локального проекта и создать заметку
---

Проанализируй проект $ARGUMENTS.

Путь к проекту: $LOCALRUN_PROJECTS/$ARGUMENTS

Шаги:
1. Проверь что проект существует: `ls $LOCALRUN_PROJECTS/$ARGUMENTS`
2. Определи GitHub-источник: `git -C $LOCALRUN_PROJECTS/$ARGUMENTS remote -v`
3. Изучи структуру: `find $LOCALRUN_PROJECTS/$ARGUMENTS -maxdepth 3 -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/venv/*" -not -path "*/__pycache__/*"`
4. Прочитай README: README.md / README.rst / README.txt
5. Найди файлы зависимостей и прочитай их
6. Найди .env.example или .env.sample
7. Найди docker-compose.yml, Makefile, Dockerfile
8. Определи точку входа

Создай папку заметок:
$SDLC_VAULT/Local_Run/$ARGUMENTS/

Создай файл overview.md используя шаблон из:
$SDLC_VAULT/Local_Run/_templates/project.md

Заполни все разделы на основе найденной информации.
Неизвестные поля помечай [УТОЧНИТЬ].

В конце выведи:
- Стек одной строкой
- Следующий шаг: запусти `/setup $ARGUMENTS` у агента `l2-setup` через выбранный runtime
