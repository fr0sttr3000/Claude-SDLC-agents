---
description: Начать новый спринт — выбрать задачи из backlog и установить цель
---

Инициализируй новый спринт для проекта $ARGUMENTS.

Шаги:
1. Сначала запусти `tracker-ledger-init.sh PROJECT`. Он идемпотентно создаёт canonical
   governance ledgers через same-directory temp+rename и никогда не заменяет существующие
   записи. Любой symlink/non-regular target блокирует init.

   Затем прочитай backlog:
   $SDLC_PROJECTS_DIR/$ARGUMENTS/tracking/backlog.md
   Если файла нет — создай пустой backlog и сообщи пользователю о необходимости добавить задачи через /task-add.

   Не создавай и не переписывай ledger-файлы вручную.

2. Определи номер нового спринта:
   Посмотри папку sprints/ и найди последний sprint-NN.md.
   Новый = последний + 1. Если папки нет — это sprint-01.

3. Покажи пользователю список задач из backlog со статусом TODO.
   Предложи выбрать задачи для спринта (с учётом приоритизации из CLAUDE.md).

4. Спроси:
   - Цель спринта (одна строка)
   - Даты начала и окончания (по умолчанию: сегодня + 14 дней)
   - Какие задачи включить (по ID или диапазону)

5. Создай файл спринта:
   $SDLC_PROJECTS_DIR/$ARGUMENTS/tracking/sprints/sprint-NN.md
   по формату из CLAUDE.md, заполнив выбранные задачи со статусом TODO.

6. Обнови current-sprint.md — укажи номер активного спринта и скопируй таблицу задач.

7. В backlog.md обнови поле "Спринт" у выбранных задач с "backlog" на "N".

8. После записи sprint artifact запусти
   `tracker-tech-debt-materialize.sh PROJECT N YYYY-MM-DD`, передав exact подтверждённый
   `end` из sprint-NN. Helper атомарно материализует `Target sprint: NEXT` и
   `Дедлайн устранения: PENDING`, проверяет SLA и при любой ошибке откатывает ledger.
   Не редактируй эти поля вручную и не придумывай дату без подтверждения шага 4.

9. Запусти:
   `bash $SDLC_VAULT/_agents/cycle1-dev/s0-validate/tech-debt-check.sh $SDLC_PROJECTS_DIR/$ARGUMENTS sprint-init N`.
   При BLOCKED не объявляй sprint созданным.

Выведи подтверждение: спринт создан, N задач, M SP запланировано.

ОБЯЗАТЕЛЬНО: в конце вывести task board по формату из CLAUDE.md.
