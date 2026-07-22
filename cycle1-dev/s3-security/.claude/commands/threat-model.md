---
description: Провести Threat Modeling (STRIDE + CVSS + OWASP)
---

Проведи Threat Modeling для проекта $ARGUMENTS.

Прочитай:
1. $SDLC_VAULT/_agents/_standards/security.md
2. $SDLC_VAULT/_agents/_standards/quality.md
3. $SDLC_PROJECTS_DIR/$ARGUMENTS/tracking/PMO-constraints.md
4. $SDLC_PROJECTS_DIR/$ARGUMENTS/stage2-requirements/outputs/BA-*-BRD.md
5. $SDLC_PROJECTS_DIR/$ARGUMENTS/stage2-requirements/outputs/BA-*-NFR.md
6. $SDLC_PROJECTS_DIR/$ARGUMENTS/stage2-requirements/outputs/SEC-*-security-requirements.md (SG1)
7. $SDLC_PROJECTS_DIR/$ARGUMENTS/stage3-design/outputs/ARCH-*-HLD.md
8. $SDLC_PROJECTS_DIR/$ARGUMENTS/stage3-design/outputs/ARCH-*-api-spec.yaml (если применимо)

Создай файлы в $SDLC_PROJECTS_DIR/$ARGUMENTS/stage3-design/outputs/:
- SEC-[дата]-threat-model.md

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
