---
description: Построить/обновить проектные пороги quality gates из risk-профиля
---

Настрой пороги quality gates для проекта $ARGUMENTS.

## Шаги

1. **Верифицируй директорию (INC-01):** прочитай
   `$SDLC_VAULT/projects/$ARGUMENTS/tracking/PMO-constraints.md`.
   Если файла нет — S1 не завершён: запиши нарушение DoR-1 в
   `tracking/dor-violations.md`, сообщи что нужно запустить `s1-pmo`, остановись.
   Не угадывай tier.

2. **Прочитай вход:**
   - `_agents/_standards/quality.md` §3 (NFR-дефолты) и §4 (Gates) — глобальные минимумы
   - `tracking/PMO-constraints.md` — `operational.tier`, `topology`, `critical_risks`, `mandatory_standards`
   - `stage1-planning/inputs/idea.md` — деньги / PII / отраслевые требования

3. **Определи драйверы ужесточения:**
   - tier → базовая колонка из таблицы рекомендаций (CLAUDE.md)
   - деньги/финансы → coverage ≥ 90%, pass rate 100%
   - PII → усиленные security/error-rate пороги
   - каждый `critical_risk` с `blocker_for: Gate N` → ужесточи пороги этого gate
   - каждый `mandatory_standard` → доп. пункт соответствующего gate

4. **Заполни** `tracking/quality-gates.md` по шаблону из CLAUDE.md.
   Для каждого порога — значение + Δ (= / ↑ / ↓) + обоснование. Пустых ячеек быть не должно.

5. **Самопроверка (= /validate-gates):** убедись, что КАЖДЫЙ порог не слабее глобального
   с учётом направления метрики (↑-метрики ≥ глобал, ↓-метрики ≤ глобал).
   Если хоть один слабее — исправь, не сохраняй ослабленный порог.

6. **Запиши** артефакт через Write/Edit (самостоятельно, не сабагентом — INC-03).
   Проставь `date:` в frontmatter на сегодня.

## Вывод
Краткий отчёт: tier проекта, какие пороги ужесточены относительно глобальных и почему,
путь к созданному `quality-gates.md`.
