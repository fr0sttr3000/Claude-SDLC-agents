# Стандарт Test-Driven Development — SDLC Vault

> Канонический контракт test-first разработки. Читается всеми агентами,
> которые создают или изменяют исполняемый код и миграции поддерживаемого Cycle 1.
> Cycle 2/3 имеют статус `FROZEN / NOT READY`: их прежние loops ниже сохранены
> только как historical implementation baseline и не являются действующим standard.

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
| DB schema / migration | Stage 3 design defines schema/migration test requirements; Stage 4 QA proves Red and runs upgrade→downgrade→upgrade | s4-dev |
| Документы/требования/дизайн | acceptance/validation checklist определяется до правки | владелец документа |

Документы не требуют фиктивного unit-теста. Для них test-first означает заранее
определённый проверяемый контракт: schema, checklist, traceability или gate
validator. Неприменимость должна быть записана с обоснованием.

`s3-dba` owns only data design and migration runbook (DoD Type D). It never creates or
executes the Green migration. `s4-qa-auto` writes the native migration test first and records
Red; `s4-dev` owns the minimum Green implementation; independent QA then executes the full
affected suite.

## 3. Артефакты и передача состояния

- Стратегия: `stage2-requirements/outputs/QA-*-test-strategy.md`.
- TDD-отчёт: `stage4-dev/outputs/QA-*-tdd-report.md`.
- Машиночитаемое состояние: `stage4-dev/outputs/QA-TDD-status.md`.
- Тесты пишутся в репозитории разрабатываемого проекта в принятой для его стека
  структуре.

`QA-TDD-status.md` содержит ровно одну актуальную запись:

```yaml
status: RED|PASS|FAIL|BLOCKED
schema_version: 1
project: <project>
scope: <FR/AC/change identifiers>
source_revision: <40/64-hex VCS object id or sha256:64-hex source-tree digest>
test_command: <exact command>
red_evidence: <path or concise observed failure>
last_run: <ISO-8601 UTC>
failed_tests: <integer>
repair_iteration: <integer>
regression_scope: not-yet-run|full-affected|partial
affected_test_manifest: stage4-dev/outputs/QA-affected-tests-v1.tsv|none
affected_test_manifest_sha256: <64-hex|none>
expected_test_count: <integer>
executed_test_count: <integer>
```

Полная schema, `QA-affected-tests-v1.tsv` и deterministic validation определены в
`_contract/TDD_STATUS_V1.md`. `PASS` допустим только для `full-affected`, когда manifest
связан с той же source revision, каждый scope id имеет native test file, нет skip/xfail и
expected/executed counts совпадают.

Перед стартом Green статус обязан быть `RED`, вызванным ожидаемым функциональным падением
теста. Ошибка environment/infrastructure, отсутствующий tool/dependency, permission/network
failure или незапустившийся test runner означает `BLOCKED`, а не `RED`. После запуска тестов:

Каждый статус, включая Red, привязан к точной ревизии исходников. Свободное имя ветки,
`latest`, короткий SHA и текст вроде `current` не являются exact revision.

- `PASS` — можно продолжить к static QA/review;
- `FAIL` — оркестратор возвращает управление s4-dev;
- `BLOCKED` — цикл останавливается и сообщает причину пользователю.

Historical `DEPLOY-TDD-status.md` и `OPS-TDD-status.md` могут существовать в старых
проектах, но не являются входом active gates и не дают права запускать Cycle 2/3.

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

## 6. Historical implementation baseline — Cycle 2/3 (FROZEN / NOT SUPPORTED)

Раздел ниже сохраняет прежнюю последовательность для инвентаризации и будущего redesign.
Он ненормативен: launcher не запускает эти loops, active gates их не требуют, а изменение
текста не считается развитием Cycle 2/3.

Прежняя петля Cycle 2:

```
s4-devops /deploy-intake
  → s4-devops /write-deploy-tests (Red)
  → s4-devops /pipeline → /runbook → /prepare-delivery
  → s4-devops /run-deploy-tests
      PASS → s6-release /release-notes → /release-checklist
      FAIL → /pipeline → /runbook → /prepare-delivery → /run-deploy-tests
```

Прежняя петля Cycle 3:

```
s6-sre /ops-intake
  → s6-sre /write-ops-tests (Red)
  → s6-sre /configure-ops
  → s6-sre /run-ops-tests
      PASS → /post-deploy → /gate7
      FAIL → /configure-ops → /run-ops-tests
```

Прежний scope был привязан к следующим артефактам:

- `tracking/SDLC-goals.md` — единый per-project контракт Cycle 2/3;
- Cycle 2 сначала пишет policy/schema/supply-chain/sandbox/rollback tests, затем
  создаёт только заказанные deliverables, затем запускает полный deploy suite;
- Cycle 3 сначала пишет rule/fixture/fire-drill/permissions/recovery tests,
  затем меняет только заказанную ops-конфигурацию, затем повторяет полный suite;
- `DEPLOY-TDD-status.md` и `OPS-TDD-status.md`;
- `goal_profile_revision` и старый `tracking/SDLC-goals.md`.

Эти artifacts не подтверждают readiness и не блокируют завершение поддерживаемого Cycle 1.
