---
description: Провести Threat Modeling (STRIDE + CVSS + OWASP)
---

Перед записью любого Markdown-артефакта прочитай `$SDLC_VAULT/_agents/_standards/artifact-metadata.md` и заполни обязательный frontmatter.

Проведи Threat Modeling для проекта $ARGUMENTS.

Прочитай:
1. $SDLC_VAULT/_agents/_standards/security.md
2. $SDLC_VAULT/_agents/_standards/quality.md
3. Current `project-constraints`, `business-requirements`, `nonfunctional-requirements`,
   `security-requirements` (SG1), `high-level-design`, `api-contract` по root Current
   Artifacts rule

Создай файлы в $SDLC_PROJECTS_DIR/$ARGUMENTS/stage3-design/outputs/:
- SEC-[дата]-threat-model.md

Frontmatter обязан соответствовать Artifact Metadata v1 и дополнительно содержать уникальные
`product_profile_revision`, `sg1_sha256`, `hld_sha256`, `asvs_version: 5.0.0`,
`component_scope` и `sg2_status: PASS|FAIL`.

Не создавай повторно security requirements: SG1 принадлежит `s2-security`; здесь он развивается
в design controls и SG2 evidence.

# Threat Model — $ARGUMENTS
Дата: [сегодня]
Агент: s3-security

## Компоненты системы (из HLD)
[Перечисли все компоненты и границы доверия]

## STRIDE Analysis
Для каждого компонента/потока данных:

| Компонент | S | T | R | I | D | E |
|-----------|---|---|---|---|---|---|

Для каждого проверяемого решения добавь machine-readable строку SG2 Validation v1:
`Threat trace: THREAT-001 | Scenario: SEC-SC-001 | Component: CMP-API | Control: CTRL-001 | Test: SEC-TEST-001 | ASVS: v5.0.0-1.2.3 | Severity: Medium | Status: MITIGATED`.

- **S**poofing — подмена идентичности
- **T**ampering — модификация данных
- **R**epudiation — отрицание действий
- **I**nformation Disclosure — утечка данных
- **D**enial of Service — отказ в обслуживании
- **E**levation of Privilege — повышение привилегий

## Severity (для каждой подтверждённой уязвимости)
Используй CVSS и уровни из `_standards/security.md`; DREAD можно добавить только как
неблокирующий design-prioritization signal, но не как release severity.

## OWASP Top 10 — статус по каждому пункту
| A0N | Название | Применимо? | Контроль | Статус |
|-----|----------|-----------|---------|--------|
| A01 | Broken Access Control | | | |
| A02 | Cryptographic Failures | | | |
| A03 | Injection | | | |
| A04 | Insecure Design | | | |
| A05 | Security Misconfiguration | | | |
| A06 | Vulnerable Components | | | |
| A07 | Auth Failures | | | |
| A08 | Software Integrity | | | |
| A09 | Logging Failures | | | |
| A10 | SSRF | | | |

## Design Controls (для s4-dev и security tests)
[Контрмеры с ссылками на SG1/FR/NFR/threat IDs и проверяемыми test criteria]

## Gate 3 — Security Checklist
□ STRIDE выполнен для всех компонентов из HLD
□ CVSS severity выставлена для каждой подтверждённой уязвимости
□ 0 открытых Critical/High по CVSS
□ OWASP Top 10 проверен и каждый пункт адресован
□ SG1 requirements развиты в design controls и test criteria

## ВЕРДИКТ
**PASS** / **CONDITIONAL PASS** / **FAIL**
Обоснование: ...

FAIL или открытые Critical/High → Gate 3 заблокирован.

Перед завершением запусти `s0-validate/sg2-check.sh`; prose/checklist без `SG2 VERIFIED`
не закрывает SG2.
