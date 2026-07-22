# Первый запуск

Это пошаговое руководство для пользователя, который впервые открывает SDLC Agent System.
Cycle 1 содержит 28 обязательных шагов; launcher показывает их до запуска и не разрешает
пропуск обязательного шага как success.

## 1. Запустите launcher

Перейдите в `_agents` и выполните:

```bash
bash sdlc.sh
```

Команда не начинает разработку. До появления Project Console wizard только сохраняет настройки.
Для изолированной проверки без старого config можно использовать:

```bash
XDG_CONFIG_HOME="$(mktemp -d)" \
SDLC_PROJECTS_DIR="$TEST_PROJECTS" \
bash sdlc.sh
```

## 2. Выберите вид

- Подробный — объясняет результат, scope и следующий шаг. Рекомендуется новичку.
- Краткий — те же actions и клавиши, но меньше текста.

Позже вид переключается клавишей `v`; functionality не меняется.

## 3. Укажите Projects

Выберите каталог, внутри которого находятся несколько SDLC Projects, либо один конкретный
Project. В single mode launcher всё равно передаёт агентам parent directory через
`SDLC_PROJECTS_DIR` и имя через `SDLC_SINGLE_PROJECT`.

Project name — безопасное имя каталога без `/` и `..`. После выбора launcher показывает absolute
path. Выбор Project только открывает его Console.

## 4. Настройте primary AI

Primary выполняет этап, пишет artifacts и отвечает за результат. Выберите Claude, Codex,
Gemini либо Local. Для Local нужны:

- agent host (`codex-oss` встроен);
- provider (`ollama` или `lmstudio` для встроенного host);
- точный model id, существующий у provider.

Модель по умолчанию не выбирается, а недоступный profile не заменяется другим.

Затем выберите routing:

1. одна модель для всех шагов (`single`);
2. разные profiles по Cycle/Stage (`per-stage`);
3. базовый profile и overrides отдельных Agents (`per-agent`);
4. собрать назначения каждого шага перед Preview (`ask`).

Routing меняет только исполнителя, не состав и порядок SDLC.

## 5. Настройте AI-помощников

- Off — primary работает один.
- Auto — native subagents выбранного runtime, если capability поддерживается.
- Supervisor + Worker — отдельный exact worker profile для bounded read-only задач.

Worker не пишет Project и не закрывает gates. Enforced workers: Claude, Codex, Local
`codex-oss`. Gemini и custom local hosts пока можно использовать primary, но не worker.

## 6. Выберите Project

Появится `LAUNCHER ГОТОВ`. Здесь можно:

- выбрать существующий Project;
- создать новый (`n`);
- открыть Локальные репозитории (`l`);
- изменить launcher settings (`g`);
- выйти (`q`).

После выбора Project появляется сообщение `КОНТЕКСТ ПРОЕКТА ОТКРЫТ`; работа всё ещё не запущена.

## 7. Выберите первое действие

Рекомендуемый новый Project:

1. `1 Kickoff` — заполнить/обновить idea, constraints и infrastructure questions.
2. Вернуться в Console. Успешный Kickoff не стартует development сам.
3. При необходимости `3 Review` — проверить входы read-only.
4. `8 Goal/Cycle 2/Cycle 3` — выбрать, что должно готовиться после development.
5. `9 AI routing/workers` — проверить назначения Project.
6. `5 Режим цели` либо `6 Один Cycle`.

Если нужно только проверить/починить существующий Project, используйте `3 Review`, затем `4 Repair`
с тем же scope. Если нужен только один агент/команда — `7 Один Agent`.

## 8. Понимайте Preview

Перед execution проверьте:

- правильный Project и absolute path;
- `SCOPE` — что войдёт;
- `EXCLUDED` — что точно не войдёт;
- ordered steps;
- primary/supervisor и worker profiles;
- exact Local model;
- `Fallback OFF`.

`r` подтверждает показанный план, `b` возвращает без запуска. Review запускается read-only;
Repair/Cycle пишут только после подтверждения.

## Частые сценарии

### Только Cycle 1

Project Console → `6 Один Cycle` → Cycle 1. Cycle 2/3 исключены независимо от Goal route.

### Cycle 1 и подготовка доставки

Сначала `8` настройте Cycle 2 deliverables/infrastructure/authorization, затем `5 Режим цели`
и выберите route Cycle 1 → 2.

### Изменить доставку после разработки

Откройте тот же Project → `8` → частично измените Cycle 2/3 → `6` → запустите только нужный
Cycle. Полный Cycle 1 повторять не нужно.

### Проверить один Agent

`3 Review` → Agent scope → exact agent id. Это не запуск роли на запись.

### Исправить один Agent scope

Сначала Agent Review, затем `4 Repair` → тот же agent id. Preview покажет исключённые scopes.

### Локально запустить repository

Project Console → `l Локальные репозитории`. Это отдельная developer utility:
Clone/Pull → Analyze → Install & configure → Build → Start & smoke. Git push запрещён.

## Если запуск прерван

В Project Console выберите `0`. Launcher покажет immutable plan/state/events. Retry создаёт
child run с доказанного следующего шага. Он не продолжает vendor chat и не считает RUNNING/
UNKNOWN успешным.

## Диагностика

- Runtime binary не найден: установите exact CLI или выберите другой profile; fallback не будет.
- Local model недоступен: исправьте provider/model id; другой model не выбирается.
- Worker profile отклонён: используйте Claude, Codex или Local codex-oss.
- Review на Gemini: назначьте `s0-validate` поддержанный read-only profile через per-agent route.
- Gate/DoR BLOCKED: откройте evidence и Repair; не ослабляйте threshold/test.
- Full Local pipeline неполный: запустите пропущенный/упавший шаг; skip не является success.
- Batch update Local notes неполный: продолжите с первого пропущенного/упавшего агента;
  launcher не запускает следующие notes steps после такого результата.

Далее: [полный README](README.md), [архитектура](OVERVIEW.md),
[принципы](plans/principles.md), [карта документов](plans/document-map.md).
