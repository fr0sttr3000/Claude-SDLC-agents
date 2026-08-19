---
description: Сформировать security-требования (SG1) — классификация, abuse cases, ASVS, security NFR
---

Перед записью любого Markdown-артефакта прочитай `$SDLC_VAULT/_agents/_standards/artifact-metadata.md` и заполни обязательный frontmatter.

Сформируй security-требования (Security Gate SG1) для проекта $ARGUMENTS.

## Шаги

1. **Проверь DoR (CLAUDE.md):** BA-BRD.md, PO-backlog, PMO-constraints.md с
   `cycle1.criticality_tier`.
   Чего-то нет → запиши в `tracking/dor-violations.md`, сообщи и остановись. Не угадывай tier/классификацию.

2. **Верифицируй директорию:** прочитай существующий файл из
   `stage2-requirements/outputs/` — убедись, что путь верный.

3. **Прочитай вход** в порядке из CLAUDE.md: PMO-constraints → idea.md → BA-BRD → BA-NFR → PO-*.

4. **Классифицируй данные:** для каждой сущности — public/internal/confidential/PII/secret + обоснование.
   Если PII нет — явно `PII: нет`, отметь что privacy §6 (security.md) не применяется.

5. **Зафиксируй ASVS baseline и уровень** по `security.md §2`: `asvs_version: 5.0.0`,
   L1/L2/L3 по tier + классификации (бамп до L2 при PII). Каждый requirement reference
   записывай только как `v5.0.0-X.Y.Z`.

6. **Построй abuse cases:** для каждого критичного FR пройди STRIDE-вопросы (CLAUDE.md, лёгкая версия),
   сформулируй abuse case + требование-контрмеру. Включи security-риски из `critical_risks` (PMO).

7. **Сформируй Security NFR** с числами (authn/authz, crypto, session TTL, rate limit, логирование без PII)
   как контракт для s3-arch и s4-dev.

8. **Определи scope комплаенса** (GDPR/PCI/HIPAA) или явное «не применимо» с обоснованием.

9. **Вычисли exact bindings** из current BRD/NFR/backlog/constraints: их SHA-256 и текущую
   Product Profile revision. Заполни поля SG1 Validation v1 и machine-readable Scenario-строку
   для каждого critical FR.

10. **Запиши** `SEC-YYYY-MM-DD-security-requirements.md` по шаблону из CLAUDE.md через
   Write/Edit самостоятельно. Gate-advancing verdict только `sg1_status: PASS`; при пробеле
   используй `FAIL`.

11. Запусти `s0-validate/sg1-check.sh`; без `SG1 VERIFIED` не объявляй Gate 2 готовым.

## Вывод
Кратко: ASVS version/уровень, сводка классификации (есть ли PII), число abuse cases, вердикт SG1,
путь к артефакту. Напомни, что он передаётся в SG2 (s3-security) как вход для threat model.
