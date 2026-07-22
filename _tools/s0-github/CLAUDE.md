# CLAUDE.md — Utility: GitHub Sync

## Роль и границы

Работай только с явно выбранным project repository. Git/GitHub действия меняют
внешнее состояние и никогда не выполняются как побочный эффект SDLC Cycle, Review
или Repair. Не меняй другой repository, remote, branch protection или history.

## Обязательный preview и подтверждения

До каждого mutation покажи repository root, current branch, remote, candidate files,
точную команду и последствия. Отдельное явное подтверждение требуется для:

1. init/create repository или изменения remote;
2. staging/commit;
3. push;
4. создания PR;
5. удаления ветки или любого history rewrite (по умолчанию запрещено).

Пустой ответ не является подтверждением. Force push в protected/default branch запрещён.

## Безопасный staged secrets scan

Secrets scan выполняется **после staging и до commit**, потому что сканируется ровно
содержимое будущего commit. Порядок:

1. Показать candidates и получить подтверждение staging.
2. Выполнить `git add -A` только внутри project root.
3. Проверить staged filenames на forbidden paths (`_secrets/`, `.env`, keys и project rules).
4. Запустить настроенный secret scanner по staged snapshot; fallback pattern scan допустим
   только как дополнительная проверка.
5. При finding: остановиться и убрать staged state без изменения working files.
   Сообщить только scanner rule и имена файлов; **не показывай совпавшие строки или значения**.
6. После чистого scan показать `git diff --cached --name-status`/`--stat`, получить
   подтверждение commit. Затем отдельно подтвердить push.

Не передавай diff с возможными секретами в prompt/chat/log. Не используй scan рабочего
дерева как замену staged snapshot. Не коммить `_agents/`, secrets или файлы вне scope.

## Команды

- `/init` — подготовить repository после preview;
- `/sync` — stage → scan → commit → отдельный push;
- `/push` — то же в отдельной ветке;
- `/status` — только чтение;
- `/branch` — создать/переключить ветку после подтверждения;
- `/pr` — проверить branch/gates и создать PR после подтверждения.

При конфликте, auth error или неоднозначном remote верни BLOCKED и точное безопасное
следующее действие. Не разрешай конфликт и не выбирай account/repository догадкой.
