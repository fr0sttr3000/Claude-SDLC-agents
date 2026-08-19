---
description: Прогнать динамические security-тесты (SG4) — DAST, pentest, security-тест-кейсы
---

Прогони динамическое тестирование безопасности (Security Gate SG4) для проекта $ARGUMENTS.

## Шаги

1. **Прочитай** `_standards/security.md`, `_standards/quality.md`,
   `_standards/artifact-metadata.md`, `_contract/S5_VALIDATION_V1.md`,
   `_contract/RISK_EXCEPTION_V3.md`, current Product Profile schema v5 (legacy v4 readable), exact-source Build Evidence и текущий
   `tracking/validation/S5-validation-v1.tsv`.

2. **Проверь DoR (CLAUDE.md):** threat model (SG2), security-requirements (SG1), приложение доступно,
   SG3 без открытых Critical/High. Чего-то нет → `tracking/dor-violations.md`, сообщи, остановись.

3. **Верифицируй директорию:** прочитай существующий файл из `stage5-testing/outputs/`.

4. **Определи глубину по tier** (`PMO-constraints.md → cycle1.criticality_tier`,
   таблица «Tier-aware» в CLAUDE.md):
   Tier 0/1 — лёгкий DAST; Tier ≥ 2 — полный DAST + обязательный pentest.

5. **Собери test catalog:** stable `SEC-SCENARIO-*` ids из одного current SG1 и одного current
   SG2 artifact. OWASP Top 10/WSTG дополняют глубину, но не заменяют exact catalog.

6. **Прогони:**
   - DAST по endpoints из api-spec (инъекции, authz-обходы, broken access control, mis-config)
   - каждый security-тест-кейс из SG2 → результат
   - abuse cases из SG1 → запрещённое действительно запрещено
   - pentest (Tier ≥ 2): ручная логика, цепочки эксплойтов
   - проверь, что находки SG3 закрыты, секреты только в pass (runtime-проверка)

7. **Оцени находки по CVSS** (security.md §1), не по S1–S4. Для каждой: score, PoC/шаги, рекомендация.

8. **Запиши** `SEC-YYYY-MM-DD-pentest-report.md` через Write/Edit самостоятельно,
   `date:` на сегодня. Используй общий Artifact Metadata v1 с Obsidian links и дополнительно
   `owner: s5-security`, exact `subject_digest/build_identity/environment_id`.

9. **Запиши machine evidence:** `tracking/validation/raw/security.json` с unique
   `scenario_results` exact-set-equivalent SG1/SG2 catalog, derived counters,
   findings/CVSS/status и добавь/замени только строку `security\ts5-security` общего индекса.
   Зафиксируй SHA-256; чужие строки сохрани byte-for-byte. Runtime N/A допустим только по
   current Product Profile как structured N/A. Нужен environment APPROVE. Открытый CVSS ≥ 7 —
   всегда FAIL. Medium требует exact typed Risk Exception v3 + matching TD; Low — exact TD без
   exception. User-facing Medium/Low дополнительно требует Known Issue и отдельный product
   acceptance Human Approval v1, создаваемый пользователем/уполномоченным владельцем продукта,
   а не security-агентом. Risk Exception и Known Issue acceptance не заменяют друг друга;
   CONDITIONAL_PASS не скрывает Critical/High.

## Вывод
Кратко: tier и глубина, число находок по CVSS-уровням, вердикт SG4, путь к отчёту.
Напомни: вердикт идёт в `s5-qa /go-no-go` и закрывает SG4 для Gate 5. FAIL = No-Go по security.
