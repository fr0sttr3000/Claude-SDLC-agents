---
description: Построить/обновить проектные пороги quality gates из risk-профиля
---

Перед записью любого Markdown-артефакта прочитай `$SDLC_VAULT/_agents/_standards/artifact-metadata.md` и заполни обязательный frontmatter.

Настрой пороги quality gates для проекта $ARGUMENTS.

## Шаги

1. **Верифицируй директорию:** прочитай
   `$SDLC_PROJECTS_DIR/$ARGUMENTS/tracking/PMO-constraints.md`.
   Если файла нет — S1 не завершён: запиши нарушение DoR-1 в
   `tracking/dor-violations.md`, сообщи что нужно запустить `s1-pmo`, остановись.
   Не угадывай tier.

2. **Прочитай вход:**
   - `_contract/quality-policy-v1.tsv` через `quality-policy-read.sh --all` — exact global
     metric/operator/threshold/unit; `_standards/quality.md` — semantics и Gates
   - `tracking/PMO-constraints.md` — `cycle1.criticality_tier`,
     `cycle1.runtime_constraints`, `critical_risks`, `mandatory_standards`
   - validated schema v5 `tracking/product-ci-profile.yaml` — exact applicability facts
   - `stage1-planning/inputs/idea.md` — деньги / PII / отраслевые требования

3. **Определи драйверы ужесточения:**
   - tier/risks → обоснованное ужесточение относительно каждой registry row
   - деньги/финансы → рассмотри stricter coverage/pass/error thresholds
   - PII → усиленные security/error-rate пороги
   - каждый `critical_risk` с `blocker_for: Gate N` → ужесточи пороги этого gate
   - каждый `mandatory_standard` → доп. пункт соответствующего gate

4. **Собери candidate** versioned `quality-gates.md` по machine-validatable шаблону из
   CLAUDE.md и `_contract/QUALITY_POLICY_V1.md`. Для каждого metric id — оператор, число и
   обоснование. Пустых ячеек быть не должно.

5. **Создай Quality Characteristics v1:** exact TSV index и Obsidian Markdown view по
   `_contract/QUALITY_CHARACTERISTICS_V1.md`. Не меняй fixed owners/contracts/gates. Для
   optional rows используй только exact current Product Profile values. Каждый N/A снабди
   concrete rationale; каждый minimum policy оставь `GLOBAL_MINIMUM_OR_STRICTER`.

6. **Самопроверка (= /validate-gates):** запусти `quality-gates-check.sh` и
   `quality-characteristics-check.sh`. КАЖДЫЙ порог
   должен быть не слабее глобального с учётом направления метрики. Agent self-review без
   успешного deterministic exit не считается проверкой.

7. **Не публикуй файлы по одному.** Запиши полный набор в
   `tracking/quality-config-candidate/`: policy, byte-identical snapshot, TSV, Markdown view и
   immutable `quality-policy-invalidations/revision-{N}.md` при revision >1 с точным
   `previous_snapshot_sha256` предыдущего snapshot. Затем запусти
   `quality-configuration-commit.sh PROJECT`. Только `QUALITY CONFIG TRANSACTION COMMITTED`
   считается успешной записью; при BLOCKED предыдущая complete configuration сохраняется.
   Числовые global значения читай только из `quality-policy-v1.tsv` через reader.

## Вывод
Краткий отчёт: tier проекта, какие пороги ужесточены, profile-bound applicability/N/A и пути
к `quality-gates.md`, `quality-characteristics-v1.tsv`, `quality-characteristics.md`.
