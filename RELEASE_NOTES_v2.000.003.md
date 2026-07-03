---
date: 2026-07-03
tags: [release, v2.000.003, runtime, codex, gemini]
version: 2.000.003
---

# Release Notes — v2.000.003

**Тип:** Compatibility / Runtime architecture
**Дата:** 2026-07-03
**Базируется на:** v2.000.002

---

## Кратко

Добавлен **Universal Runtime Contract**: SDLC Agent System теперь можно запускать через
Claude, Codex и Gemini без раздвоения правил, gates, агентов и артефактов.

Runtime выбирается явно: через `AGENT_RUNTIME`, сохранённый config или меню первого запуска/настроек. Неявного fallback на Claude нет; Claude, Codex и Gemini подключаются через адаптеры.

---

## Что добавилось

### 1. Universal Runtime Contract

Новый vendor-neutral слой:

- `_contract/GLOBAL.md` — инварианты: канон правил, совместимость runtime, запрет vendor-only SDLC-логики.
- `_contract/README.md` — описание canonical sources и runtime adapters.

Канонические источники:
- `_standards/*.md`
- root `CLAUDE.md`
- `cycle*/{agent}/CLAUDE.md`
- `.claude/commands/*.md`
- `$SDLC_PROJECTS_DIR/{PROJECT}/...`

### 2. Runtime dispatcher

Новый файл:

- `_runtimes/agent-run.sh`
- `SDLC_PROJECTS_DIR` — явный родительский каталог SDLC-проектов, настраивается при первом запуске или через env; launcher поддерживает режим коллекции проектов и режим одной папки проекта (`SDLC_PROJECTS_MODE`, `SDLC_SINGLE_PROJECT`)

Он принимает готовый prompt от `sdlc.sh` / `localrun.sh` и вызывает нужный CLI:

```bash
AGENT_RUNTIME=claude bash sdlc.sh
AGENT_RUNTIME=codex bash sdlc.sh
AGENT_RUNTIME=gemini bash sdlc.sh
```

Runtime также можно сменить в меню `Настройки`. Launcher не выбирает каталог проектов автоматически; пользователь явно выбирает каталог-коллекцию или папку одного проекта.

Первый запуск без env:

```bash
bash sdlc.sh   # launcher спросит runtime и сохранит выбор
```

### 3. Runtime adapters

Добавлены:

| Файл | Назначение |
|------|------------|
| `AGENTS.md` | Codex bridge: использовать `CLAUDE.md` как канон |
| `GEMINI.md` | Gemini bridge: использовать `CLAUDE.md` как канон |
| `.codex/config.toml` | Codex project config: `CLAUDE.md` как fallback instruction file |
| `_runtimes/adapters/claude.md` | Описание Claude runtime |
| `_runtimes/adapters/codex.md` | Описание Codex runtime |
| `_runtimes/adapters/gemini.md` | Описание Gemini runtime |

---

## Изменено

- `sdlc.sh` больше не вызывает `claude` напрямую; запуск идёт через `_runtimes/agent-run.sh`, выбранный runtime валидируется перед запуском, silent fallback на Claude запрещён.
- `localrun.sh` также использует runtime dispatcher и явную настройку `LOCALRUN_PROJECTS`.
- `localrun.sh` теперь раскрывает `.claude/commands/*.md` в обычный prompt, как `sdlc.sh`, и корректно ищет command templates L-агентов в `cycle1-dev/l*/`.
- Документация синхронизирована под multi-runtime режим:
  - `README.md`
  - `OVERVIEW.md`
  - `GETTING_STARTED.md`
  - `CLAUDE.md`
  - `plans/principles.md`
  - `plans/roadmap.md`
  - `CHANGELOG.md`

---

## Совместимость

Claude остаётся доступен как явный runtime:

```bash
AGENT_RUNTIME=claude bash sdlc.sh
```

Если в config уже сохранён `AGENT_RUNTIME=claude`, `bash sdlc.sh` использует его; чистый запуск сначала спрашивает runtime.

Новые Codex/Gemini файлы являются адаптерами и не вводят отдельную SDLC-логику.
Если новый агент, gate, команда или правило нужны всем runtime, они должны быть добавлены
в канонические markdown-файлы.

---

## Правило разработки после v2.000.003

**Contract is canonical. Runtimes are replaceable. Artifacts and gates are invariant.**

Запрещено добавлять:
- новый gate только в `AGENTS.md`;
- новую команду только в `.gemini/commands`;
- нового агента только в Codex skill;
- новое правило только в runtime adapter.

Правильно:
- новое правило → `_standards/*.md` или `CLAUDE.md`;
- новый агент → `cycle*/{agent}/CLAUDE.md`;
- новая команда → `.claude/commands/*.md`;
- runtime-specific слой → только bridge/adapter.
