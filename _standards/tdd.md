# Стандарт Test-Driven Development — SDLC Vault

> Канонический контракт test-first разработки. Читается всеми агентами,
> которые создают или изменяют исполняемый код, миграции, инфраструктурную
> конфигурацию, CI/CD, правила мониторинга или auto-heal.

## 1. Неизменяемый порядок

Для каждого применимого изменения действует один порядок:

1. **Specify** — связать изменение с FR/NFR/AC и определить наблюдаемый результат.
2. **Red** — написать тест или исполняемую проверку до реализации и сохранить
   доказательство ожидаемого падения.
3. **Green** — написать минимальную реализацию, не меняя смысл теста.
4. **Run** — запустить весь затронутый набор тестов, а не только новый тест.
5. **Repair** — при FAIL вернуть задачу исполнителю кода/конфигурации.
6. **Refactor** — улучшить реализацию при зелёных тестах и снова запустить их.

Запрещено писать production-реализацию до подтверждённого Red. Если исходная
система уже случайно удовлетворяет тесту, SDET обязан доказать, что тест ловит
требуемый дефект (например, mutation/negative fixture), а не создавать
искусственное падение.

## 2. Применимость по типу артефакта

| Артефакт | Test-first доказательство | Исполнитель Green |
|----------|---------------------------|-------------------|
| Код приложения, библиотека, API | unit + integration + contract тесты | s4-dev |
| DB schema / migration | schema/migration test, upgrade→downgrade→upgrade | s3-dba / s4-dev |
| IaC, pipeline, deployment config | lint/schema/policy test + sandbox smoke | s4-devops |
| Monitoring/alert rules | rule test с временным рядом/fixture + fire-drill scenario | s4-devops / s6-sre |
| Auto-heal/playbook | failure-injection scenario + permissions/idempotency test | s4-devops / s6-sre |
| Документы/требования/дизайн | acceptance/validation checklist определяется до правки | владелец документа |

Документы не требуют фиктивного unit-теста. Для них test-first означает заранее
определённый проверяемый контракт: schema, checklist, traceability или gate
validator. Неприменимость должна быть записана с обоснованием.

## 3. Артефакты и передача состояния

- Стратегия: `stage2-requirements/outputs/QA-*-test-strategy.md`.
- TDD-отчёт: `stage4-dev/outputs/QA-*-tdd-report.md`.
- Машиночитаемое состояние: `stage4-dev/outputs/QA-TDD-status.md`.
- Cycle 2: `stage6-deploy/outputs/DEPLOY-TDD-status.md`, deploy test plan/report.
- Cycle 3: `stage7-ops/outputs/OPS-TDD-status.md`, ops test plan/report.
- Тесты пишутся в репозитории разрабатываемого проекта в принятой для его стека
  структуре.

`QA-TDD-status.md` содержит ровно одну актуальную запись:

```yaml
status: RED|PASS|FAIL|BLOCKED
project: <project>
scope: <FR/AC/change identifiers>
test_command: <exact command>
red_evidence: <path or concise observed failure>
last_run: <ISO-8601 UTC>
failed_tests: <integer>
repair_iteration: <integer>
```

Cycle 2/3 status дополнительно содержит
`goal_profile_revision: <integer>`. Несовпадение с текущей revision профиля
означает BLOCKED и требует новых tests/Red для изменённого scope.

Перед стартом Green статус обязан быть `RED`. После запуска тестов:

- `PASS` — можно продолжить к static QA/review;
- `FAIL` — оркестратор возвращает управление s4-dev;
- `BLOCKED` — цикл останавливается и сообщает причину пользователю.

Все три status-файла используют тот же обязательный минимум полей. Статус
Cycle 2/3 относится только к deliverables из актуального
`tracking/SDLC-goals.md`; изменение scope требует нового Red evidence.

## 4. Repair loop

Петля Stage 4:

```
s4-qa-auto /write-tests (Red)
  → s4-dev /dev-report (Green/Repair)
  → s4-qa-auto /run-tests
      PASS → следующий шаг
      FAIL → s4-dev → s4-qa-auto /run-tests
```

Количество автоматических возвратов ограничено
`TDD_MAX_REPAIR_ITERATIONS` (по умолчанию 3). Исчерпание лимита не разрешает
пропустить тесты: этап получает BLOCKED и требует решения пользователя.

Петля Cycle 2:

```
s4-devops /deploy-intake
  → s4-devops /write-deploy-tests (Red)
  → s4-devops /pipeline → /runbook → /prepare-delivery
  → s4-devops /run-deploy-tests
      PASS → s6-release /release-notes → /release-checklist
      FAIL → /pipeline → /runbook → /prepare-delivery → /run-deploy-tests
```

Петля Cycle 3:

```
s6-sre /ops-intake
  → s6-sre /write-ops-tests (Red)
  → s6-sre /configure-ops
  → s6-sre /run-ops-tests
      PASS → /post-deploy → /gate7
      FAIL → /configure-ops → /run-ops-tests
```

После исчерпания общего лимита TDD_MAX_REPAIR_ITERATIONS статус становится
BLOCKED. Обязательные test/gate steps нельзя пропустить.

## 5. Запреты

- Нельзя ослаблять assertion, удалять тест, добавлять skip/xfail или менять
  acceptance criteria ради Green.
- Нельзя мокировать сам предмет теста.
- Нельзя считать Red доказанным из-за ошибки окружения, синтаксиса теста или
  отсутствующей зависимости.
- Нельзя принимать выборочный запуск за полный regression run.
- Нельзя продолжать после FAIL и нельзя выполнять silent fallback.
- Тестовый агент не пишет production-код; агент реализации не подписывает
  собственный тестовый вердикт.

## 6. Циклы 2 и 3

TDD сохраняется после Cycle 1 и применяется только к явно выбранной цели:

- `tracking/SDLC-goals.md` — единый per-project контракт Cycle 2/3;
- Cycle 2 сначала пишет policy/schema/supply-chain/sandbox/rollback tests, затем
  создаёт только заказанные deliverables, затем запускает полный deploy suite;
- Cycle 3 сначала пишет rule/fixture/fire-drill/permissions/recovery tests,
  затем меняет только заказанную ops-конфигурацию, затем повторяет полный suite;
- если отдельного тестового агента нет, вердикт определяется exit code и
  измеряемым harness; bounded read-only subagent может проверять evidence, но
  не писать тест/конфигурацию/status и не подписывать gate.

Непроверенный monitoring rule, playbook или auto-heal action блокирует
соответствующий Quality Gate.
