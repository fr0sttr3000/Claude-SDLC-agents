---
description: Провести Threat Modeling (STRIDE + DREAD + OWASP Top 10)
---

Проведи Threat Modeling для проекта $ARGUMENTS.

Прочитай:
1. /home/host-gui-car/Documents/Obsidian Vault/Claude/_agents/_standards/quality.md
2. /home/host-gui-car/Documents/Obsidian Vault/Claude/projects/$ARGUMENTS/stage3-design/outputs/ARCH-HLD.md
3. /home/host-gui-car/Documents/Obsidian Vault/Claude/projects/$ARGUMENTS/stage2-requirements/outputs/BA-BRD.md

Создай файлы в /home/host-gui-car/Documents/Obsidian Vault/Claude/projects/$ARGUMENTS/stage3-design/outputs/:
- SEC-[дата]-threat-model.md
- SEC-[дата]-security-requirements.md

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

## DREAD Scoring (для каждой угрозы)
| Угроза | D | R | E | A | D | Score | Severity |
|--------|---|---|---|---|---|-------|----------|

Score = среднее. Critical >8 / High 6-8 / Medium 4-6 / Low <4

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

## Security Requirements (для s4-dev)
[Сформировать как FR/NFR с конкретными требованиями к реализации]

## Gate 3 — Security Checklist
□ STRIDE выполнен для всех компонентов из HLD
□ DREAD scoring выполнен для каждой угрозы
□ 0 нераскрытых Critical угроз (DREAD > 8)
□ 0 нераскрытых High угроз (DREAD 6-8)
□ OWASP Top 10 проверен и каждый пункт адресован
□ Security requirements переданы s4-dev

## ВЕРДИКТ
**PASS** / **CONDITIONAL PASS** / **FAIL**
Обоснование: ...

FAIL или открытые Critical/High → Gate 3 заблокирован.
