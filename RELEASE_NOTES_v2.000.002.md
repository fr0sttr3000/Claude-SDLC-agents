---
date: 2026-06-21
tags: [release, v2.000.002, security, quality]
version: 2.000.002
---

# Release Notes — v2.000.002

**Тип:** Feature (по содержанию minor; нумерация — patch по схеме проекта)
**Дата:** 2026-06-21
**Базируется на:** v2.000.001

---

## Кратко

Большое расширение системы качества и надёжности по общепризнанным фреймворкам
(ISO/IEC 25010, ISTQB, DORA/Accelerate, Google SRE, NIST SSDF / OWASP / Microsoft SDL, ITIL).
Три новых направления: **отдельный Security-трек SG1–SG5**, **углублённые Quality Gates**
(пирамида тестов, метрики, ISO 25010) и **операционный контракт для известных дефектов (KEDB)**.

---

## Что добавилось

### 1. Security-трек SG1–SG5 (отдельный от Quality)

Безопасность выведена в параллельный трек со своим языком severity (CVSS, не баги S1–S4),
своим каденсом и владельцем.

- Новый стандарт `_standards/security.md`: Security Gates SG1–SG5, политика CVSS,
  ASVS-уровни по tier («только вверх»), маппинг на NIST SSDF / OWASP SAMM / ASVS / SDL / SLSA,
  условный раздел Privacy (GDPR/ISO 29100).
- Из `quality.md` security-специфика вырезана → заменена кросс-ссылками; правило перехода:
  этап пройден только когда зелёный **И** Quality Gate, **И** Security Gate.
- Новые агенты:
  - `s2-security` (`/security-requirements`) — SG1: abuse cases, классификация данных, ASVS, security NFR (shift-left).
  - `s5-security` (`/security-test`) — SG4: DAST/pentest, tier-aware.
  - `s0-quality-gates` (`/configure`, `/validate-gates`) — проектные пороги gates из risk-профиля (после S1, до S2).
- `s3-security` назначен владельцем трека (SG2/SG3).

### 2. Quality Gates overhaul

- **Пирамида тестов (`quality.md §3.1`):** branch coverage ≥80% (вместо line) + mutation score
  ≥60% критичных модулей; добавлены уровни **integration** и **contract** (consumer-driven);
  пороги растут по tier.
- **Code duplication ≤3%** нового кода (DoD-1).
- **Маппинг на ISO/IEC 25010 (`§4.1`)** — таблица покрытия 9 характеристик качества, осознанные
  пробелы помечены со ссылками на roadmap.
- **Functional Suitability в Gate 5** — каждый Must-FR покрыт приёмочным тестом (трассировка по RTM).
- **Метрики (`§7`):** DORA расширена 5-й метрикой **Reliability**; добавлены механизм сбора и тренд
  по циклам; **defect-метрики** — Defect Density, DRE (≥95%), Escaped Defects.

### 3. Known Issues — операционный контракт (KEDB)

Некритичный дефект (S3/S4, security Low/Medium) уходит в прод только с операционным контрактом
(ITIL Known Error + SRE-runbooks + auto-remediation).

- `quality.md §6.1`: правило промоушена, обязательные поля, единый join-ключ (алерт = KI-id =
  имя runbook), Patch SLA (S3 ≤ 1 спринт / S4 ≤ 3), критерии в Gate 5/6/7.
- Новые шаблоны: `_standards/known-issues-template.md` (реестр), `_standards/runbook-KI-template.md`.
- Реестр `tracking/known-issues.md` (создаёт `s0-tracker`) — операционный срез для `s6-sre`
  (мониторинг проявления + диагностика + обход + авто-ремедиация).

---

## Изменено

- Gate-контролёры читают `tracking/quality-gates.md` первыми (`s2-qa-req`, `s4-techlead`, `s5-qa`, `s5-perf`).
- `s5-qa` / `s6-release` / `s6-sre` / `s0-tracker` / `s4-dev` / `s4-techlead` / `s5-qa-auto` —
  обновлены под новые критерии (тесты, метрики, Known Issues).
- `dod-check.sh`: DoD-2 → branch/mutation/integration/contract (best-effort), DoD-1 → warn про duplication.
- Убрана проект-специфика «живой Telegram» → «реальная система» в Gate 5 / UAT.
- Документация-зеркала синхронизированы: `CLAUDE.md`, `OVERVIEW.md`, `README.md`, `plans/roadmap.md`.

---

## Новые файлы

| Файл | Назначение |
|------|-----------|
| `_standards/security.md` | Security-трек SG1–SG5 |
| `_standards/known-issues-template.md` | Шаблон реестра известных дефектов (KEDB) |
| `_standards/runbook-KI-template.md` | Шаблон per-KI runbook |
| `cycle1-dev/s0-quality-gates/` | Агент Quality Gates Configurator |
| `cycle1-dev/s2-security/` | Агент Security Requirements (SG1) |
| `cycle1-dev/s5-security/` | Агент Security Test (SG4) |

---

## Совместимость

- Обратно совместимо: существующие проекты продолжают работать; новые контроли применяются
  с момента запуска соответствующих агентов/гейтов.
- Новые проекты получают `known-issues.md` при `/sprint-init`.
- Изменений в публичных интерфейсах лаунчера нет; `sdlc.sh` уже содержит новые шаги (с v2.000.001-ветки).
