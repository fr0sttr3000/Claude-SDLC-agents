# Local agent hosts

Этот каталог содержит исполняемые adapters для `AGENT_RUNTIME=local`. Они преобразуют
универсальный вызов SDLC dispatcher в команду конкретного локального agent host.

Файлы adapters намеренно сохраняются в нативном исполняемом формате и могут не иметь
расширения. Поэтому Obsidian может показывать каталог пустым, если в настройках не включено
отображение всех расширений.

## Текущий adapter

- `codex-oss` — запускает точную локальную модель через Codex CLI с provider
  `ollama` или `lmstudio`.

`_runtimes/agent-run.sh` выбирает adapter по `LOCAL_AGENT_HOST`. Отсутствующий host, provider
или точный model id блокирует запуск; автоматического fallback нет.

Требования к регистрации других local hosts описаны в
[local runtime adapter](../adapters/local.md).
