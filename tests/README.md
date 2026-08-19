# Contract and regression tests

Этот каталог содержит исполняемые smoke/regression-тесты SDLC Agent System. Тесты проверяют
launcher, runtime adapters, contracts, gates, документационные границы и fail-closed сценарии.

Shell-файлы сохраняются в нативном формате `.sh`, поэтому Obsidian может показывать каталог
пустым, если в настройках не включено отображение всех расширений.

## Запуск

Полный локальный набор запускается из корня `_agents`:

```bash
bash tests/system-contract-smoke.sh
```

Отдельный сценарий можно запустить напрямую, например:

```bash
bash tests/codex-app-launcher-compat-smoke.sh
```

`tests/lib/` содержит общие fixtures, которые подключаются несколькими сценариями и не являются
самостоятельными entrypoints.
