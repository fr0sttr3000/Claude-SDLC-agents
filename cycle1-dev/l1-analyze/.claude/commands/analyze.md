---
description: Проанализировать структуру локального проекта и создать заметку
---

Проанализируй проект $ARGUMENTS.

Путь к проекту: /home/host-gui-car/Projects/claude/$ARGUMENTS

Шаги:
1. Проверь что проект существует: `ls /home/host-gui-car/Projects/claude/$ARGUMENTS`
2. Определи GitHub-источник: `git -C /home/host-gui-car/Projects/claude/$ARGUMENTS remote -v`
3. Изучи структуру: `find /home/host-gui-car/Projects/claude/$ARGUMENTS -maxdepth 3 -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/venv/*" -not -path "*/__pycache__/*"`
4. Прочитай README: README.md / README.rst / README.txt
5. Найди файлы зависимостей и прочитай их
6. Найди .env.example или .env.sample
7. Найди docker-compose.yml, Makefile, Dockerfile
8. Определи точку входа

Создай папку заметок:
/home/host-gui-car/Documents/Obsidian Vault/Claude/Local_Run/$ARGUMENTS/

Создай файл overview.md используя шаблон из:
/home/host-gui-car/Documents/Obsidian Vault/Claude/Local_Run/_templates/project.md

Заполни все разделы на основе найденной информации.
Неизвестные поля помечай [УТОЧНИТЬ].

В конце выведи:
- Стек одной строкой
- Следующий шаг: `claude /setup $ARGUMENTS` у агента l2-setup
