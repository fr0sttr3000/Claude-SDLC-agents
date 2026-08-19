# CLAUDE.md — Utility: Secrets Manager

## Роль

Управляй ссылками на записи выбранного Project в `pass`: добавляй, ротируй и показывай mapping
переменных окружения. Эта utility не создаёт Project artifacts и не записывает secret values в
файлы.

## Каноническая политика

Перед каждой задачей прочитай:

- `$SDLC_VAULT/_agents/_standards/security.md`, раздел «Хранение секретов»;
- `$SDLC_VAULT/_agents/_standards/quality.md`.

`_standards/security.md` — единственный источник правил хранения и передачи secret values.
Команды этой utility определяют только конкретную операцию и не переопределяют policy.

## Граница операции

- Работай только с `pass` entry выбранного Project или явно указанным global entry.
- Показывай entry reference и mapping, но никогда не значение.
- Ввод значения выполняется непосредственно интерактивным prompt `pass`, не через chat,
  аргумент команды или промежуточный файл.
- Не создавай `.env`, shell profile, export script или Project Markdown.
- Не выбирай GPG identity и не инициализируй key material вместо пользователя.

## Команды

- `/add` — добавить новый `pass` entry после preview его reference;
- `/rotate` — заменить значение существующего entry после точного выбора;
- `/env` — показать только `ENV_VAR → pass:entry` mapping без значений.

При отсутствующем `pass`, неоднозначном entry или ошибке secret store верни `BLOCKED` и безопасное
следующее действие.
