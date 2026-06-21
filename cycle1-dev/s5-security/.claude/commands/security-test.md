---
description: Прогнать динамические security-тесты (SG4) — DAST, pentest, security-тест-кейсы
---

Прогони динамическое тестирование безопасности (Security Gate SG4) для проекта $ARGUMENTS.

## Шаги

1. **Проверь DoR (CLAUDE.md):** threat model (SG2), security-requirements (SG1), приложение доступно,
   SG3 без открытых Critical/High. Чего-то нет → `tracking/dor-violations.md`, сообщи, остановись.

2. **Верифицируй директорию (INC-01):** прочитай существующий файл из `stage5-testing/outputs/`.

3. **Определи глубину по tier** (PMO-constraints.operational.tier, таблица «Tier-aware» в CLAUDE.md):
   Tier 0/1 — лёгкий DAST; Tier ≥ 2 — полный DAST + обязательный pentest.

4. **Собери тест-кейсы:** из threat model (SG2 — STRIDE-сценарии) + abuse cases (SG1) + OWASP Top 10/WSTG.

5. **Прогони:**
   - DAST по endpoints из api-spec (инъекции, authz-обходы, broken access control, mis-config)
   - каждый security-тест-кейс из SG2 → результат
   - abuse cases из SG1 → запрещённое действительно запрещено
   - pentest (Tier ≥ 2): ручная логика, цепочки эксплойтов
   - проверь, что находки SG3 закрыты, секреты только в pass (runtime-проверка)

6. **Оцени находки по CVSS** (security.md §1), не по S1–S4. Для каждой: score, PoC/шаги, рекомендация.

7. **Запиши** `SEC-YYYY-MM-DD-pentest-report.md` через Write/Edit (самостоятельно — INC-03),
   `date:` на сегодня. Вердикт: PASS / CONDITIONAL PASS / FAIL (любой открытый Critical/High = FAIL).

## Вывод
Кратко: tier и глубина, число находок по CVSS-уровням, вердикт SG4, путь к отчёту.
Напомни: вердикт идёт в `s5-qa /go-no-go` и закрывает SG4 перед Gate 6. FAIL = No-Go по security.
