---
description: Сформировать security-требования (SG1) — классификация, abuse cases, ASVS, security NFR
---

Сформируй security-требования (Security Gate SG1) для проекта $ARGUMENTS.

## Шаги

1. **Проверь DoR (CLAUDE.md):** BA-BRD.md, PO-backlog, PMO-constraints.md с `operational.tier`.
   Чего-то нет → запиши в `tracking/dor-violations.md`, сообщи и остановись. Не угадывай tier/классификацию.

2. **Верифицируй директорию (INC-01):** прочитай существующий файл из
   `stage2-requirements/outputs/` — убедись, что путь верный.

3. **Прочитай вход** в порядке из CLAUDE.md: PMO-constraints → idea.md → BA-BRD → BA-NFR → PO-*.

4. **Классифицируй данные:** для каждой сущности — public/internal/confidential/PII/secret + обоснование.
   Если PII нет — явно `PII: нет`, отметь что privacy §6 (security.md) не применяется.

5. **Выбери ASVS-уровень** по `security.md §2`: tier + классификация (бамп до L2 при PII).

6. **Построй abuse cases:** для каждого критичного FR пройди STRIDE-вопросы (CLAUDE.md, лёгкая версия),
   сформулируй abuse case + требование-контрмеру. Включи security-риски из `critical_risks` (PMO).

7. **Сформируй Security NFR** с числами (authn/authz, crypto, session TTL, rate limit, логирование без PII)
   как контракт для s3-arch и s4-dev.

8. **Определи scope комплаенса** (GDPR/PCI/HIPAA) или явное «не применимо» с обоснованием.

9. **Запиши** `SEC-YYYY-MM-DD-security-requirements.md` по шаблону из CLAUDE.md через Write/Edit
   (самостоятельно — INC-03). Проставь `date:` на сегодня. Вердикт: PASS / CONDITIONAL PASS / FAIL.

## Вывод
Кратко: ASVS-уровень, сводка классификации (есть ли PII), число abuse cases, вердикт SG1,
путь к артефакту. Напомни, что он передаётся в SG2 (s3-security) как вход для threat model.
