---
date: 2026-06-20
tags: [standards, security, devsecops]
---

# Стандарт безопасности — SDLC Vault (Security Gates)

> Параллельный трек к `quality.md`. Безопасность по ISO/IEC 25010 — одна из характеристик
> качества, но операционно ведётся отдельно (DevSecOps, NIST SSDF, OWASP SAMM, Microsoft SDL):
> свой язык severity (CVSS, не баги S1–S4), свой каденс (непрерывно + вехи + пост-прод),
> свой владелец (`s3-security`, в S2 — `s2-security`/shift-left).
>
> Смежные стандарты: `quality.md` (качество), `data-formats.md` (форматы данных).
>
> Правило перехода: этап пройден, только когда зелёный **И** Quality Gate (quality.md §4)
> **И** соответствующий Security Gate (этот файл §3).

---

## 1. Язык severity — CVSS, не баги

Security-находки оцениваются по **CVSS v3.1/v4.0 + CWE/CVE**, а не по шкале багов S1–S4.
Это разные системы координат — не смешивать.

| Уровень | CVSS | Политика релиза |
|---------|------|-----------------|
| Critical | 9.0–10.0 | **Блокирует релиз** (BLOCKER), фикс до деплоя |
| High | 7.0–8.9 | **Блокирует релиз** (BLOCKER), фикс до деплоя |
| Medium | 4.0–6.9 | Фикс или risk-accept с дедлайном (≤ след. спринт), запись в `tracking/security-debt.md` |
| Low | 0.1–3.9 | Backlog как Known Issue |
| None | 0.0 | — |

Critical/High в релизе = безусловный BLOCKER (совпадает с quality.md §8).
Risk-accept Medium допускается только с владельцем, причиной и дедлайном — как технический долг.

> **Security Low/Medium с user-facing проявлением в проде** дополнительно промотируются в
> операционный реестр `tracking/known-issues.md` (quality.md §6.1) — алерт + runbook + auto-remediation,
> severity по CVSS. `security-debt.md` при этом остаётся источником дедлайна фикса (как tech-debt).

---

## 2. Security Level по tier — «только вверх»

Базовый уровень — **OWASP ASVS**, выбирается по `operational.tier` (PMO-constraints.md)
и классификации данных. Принцип тот же, что у `s0-quality-gates`: проектный уровень
может только **повышаться** относительно глобального минимума, не понижаться.

| Tier | ASVS уровень | Кому |
|------|:------------:|------|
| 0 / 1 | **L1** (baseline) | любое приложение |
| 2 | **L2** (standard) | приложения с чувствительными данными / большинство |
| 3 | **L3** (advanced) | критичные, высокоценные системы |

**Бамп по данным:** любая классификация `confidential / PII / secret` поднимает уровень
минимум до **L2** независимо от tier. Классификацию фиксирует SG1.

Конфигурацию security-уровня проекта ведёт `s0-quality-gates` (расширение)
или фиксирует SG1 в `tracking/quality-gates.md`. До автоматизации — берётся из таблицы выше.

---

## 3. Security Gates (SG1–SG5)

Параллельны Quality Gates G1–G7. Проверяет владелец трека ПЕРВЫМ делом на своём этапе.

| SG | Фаза | Владелец | Каденс |
|----|------|----------|--------|
| **SG1** Requirements | S2 | `s2-security` | веха |
| **SG2** Design | S3 | `s3-security` + `s3-rbac` | веха |
| **SG3** Build | S4 | `s3-security` / CI | **непрерывно, каждый PR** |
| **SG4** Pre-Prod | S5 → S6 | `s5-security` | веха |
| **SG5** Production | S7 | `s6-sre` + `s3-security` | пост-прод, непрерывно |

### SG1 — Requirements (S2) — владелец `s2-security`
```
□ Abuse / misuse cases определены для каждого критичного FR
□ Классификация данных зафиксирована: public / internal / confidential / PII / secret
□ ASVS-уровень выбран по tier + классификации данных (§2)
□ Security NFR с числами: authn/authz, crypto, session, rate limit, логирование
□ Scope комплаенса определён (GDPR / PCI-DSS / HIPAA) — или явно «не применимо» с обоснованием
```
Артефакт: `SEC-YYYY-MM-DD-security-requirements.md` в `stage2-requirements/outputs/`.

### SG2 — Design (S3) — *перенесено из quality.md Gate 3*
```
□ Threat model (STRIDE) по ARCH-HLD/api-spec: 0 открытых Critical/High угроз
□ Authorization model (RBAC/ABAC/ACL или иной выбранный механизм): все субъекты и действия из BRD покрыты
□ Permission matrix/политики полны; `not-applicable` возможно только с явным threat-based обоснованием
□ Enforcement реализован stack-native: SQL/RLS для PostgreSQL — один из вариантов, не default
□ SoD-конфликты выявлены и задокументированы
□ Owner-ресурсы защищены deny-by-default policy в фактическом enforcement layer
□ Key management: где хранятся ключи (pass), ротация, отзыв
□ Data protection design: шифрование at-rest / in-transit по классификации данных
```
Артефакты: `SEC-*-threat-model.md`, `RBAC-*` в `stage3-design/outputs/`.

### SG3 — Build (S4, непрерывно на каждый PR) — *SAST/secrets из quality.md Gate 4*
```
□ SAST: 0 Critical/High
□ SCA (зависимости): 0 Critical/High CVE (pip-audit / Trivy / Dependabot)
□ Secrets-scan: 0 находок (код, логи, .md, история PR)
□ Container image scan: 0 Critical/High (Trivy / Grype)
□ SBOM сгенерирован (состав артефакта)
□ Зависимости запинены (lockfile), нет «плавающих» версий
□ License compliance: нет запрещённых лицензий
```
Артефакт: `SEC-YYYY-MM-DD-build-scan-PR[N].md` в `stage4-dev/outputs/`.

### SG4 — Pre-Prod (S5 → S6) — владелец `s5-security`
```
□ DAST по работающему приложению: 0 Critical/High
□ Pentest / security review проведён (Tier ≥ 2 — обязательно; Tier 0/1 — по решению)
□ Security-тест-кейсы из threat model (SG2) выполнены, результаты зафиксированы
□ Все находки SG3 закрыты или risk-accepted с дедлайном
□ Verified: секреты только в pass, не в образе/конфиге/env-файле
```
Артефакт: `SEC-YYYY-MM-DD-pentest-report.md` в `stage5-testing/outputs/`.

### SG5 — Production (S7)
```
□ Vuln monitoring зависимостей активен (постоянный CVE-watch)
□ Patch SLA определён: Critical ≤ 7 дней, High ≤ 30 дней (или строже по tier)
□ Audit-лог настроен и ревьюится — если классификация данных требует (§6)
□ Ротация секретов по расписанию настроена
□ Incident response runbook для security-инцидента существует в stage7-ops/outputs/
□ Алерты на аномалии безопасности (всплеск 4xx/401/403, brute-force)
```
Артефакт: раздел Security в `SRE-*-ops-report.md`.

---

## 4. Непрерывные контроли (DevSecOps pipeline)

В отличие от quality-вех, эти проверки идут **на каждый PR** (SG3) и постоянно (SG5):

```
PR → SAST → SCA → secrets-scan → container scan → SBOM   (блокируют merge при Critical/High)
PROD → CVE-watch → patch SLA → secret rotation → security alerts
```

Принцип shift-left: чем раньше найдено, тем дешевле. SG1 (abuse cases) и SG2 (threat model)
ловят дефекты дизайна до написания кода.

---

## 5. Маппинг на фреймворки

| Фреймворк | Где покрыт |
|-----------|-----------|
| **NIST SSDF (SP 800-218)** | PO (§2 уровни), PS (SG3 SBOM/целостность), PW (SG2 дизайн, SG3 SAST), RV (SG4 pentest, SG5 vuln mgmt) |
| **OWASP SAMM** | Governance (§1–2), Design (SG2), Implementation (SG3), Verification (SG4), Operations (SG5) |
| **OWASP ASVS** | §2 — уровень L1/L2/L3 по tier |
| **OWASP Top 10** | A06 Vulnerable Components → SG3 SCA; A01 Access Control → SG2 RBAC; A02 Crypto → SG2 |
| **Microsoft SDL** | Requirements→SG1, Design/Threat Model→SG2, Implementation→SG3, Verification→SG4, Release/Response→SG5 |
| **SLSA** | SG3 — SBOM (L1), pinning/provenance (L2+), подпись артефактов (L3) |

---

## 6. Privacy & Data Protection — УСЛОВНЫЙ раздел

> **Активируется только при классификации данных `confidential / PII / secret` (фиксируется в SG1).**
> Это **per-project дименсия**, привязанная к данным проекта — а **НЕ свойство самого vault**.
> Сам `_agents` — markdown-система стандартов без пользовательских данных, к нему §6 не применяется.
>
> Проект без чувствительных данных: SG1 помечает `PII: нет` → раздел §6 не применяется,
> обоснование фиксируется в `SEC-*-security-requirements.md` / `quality-gates.md`. Не навешивать
> privacy-контроли «про запас».

При активации (GDPR Art.25 «Privacy by Design», ISO/IEC 29100):
```
□ Минимизация данных: собирается только необходимое
□ Retention policy: срок хранения определён, авто-удаление настроено
□ Right to erasure: механизм удаления данных субъекта
□ DPIA проведён для высокорисковой обработки
□ Data residency: требования по региону хранения соблюдены
□ Audit trail: доступ к чувствительным данным журналируется
□ PII не попадает в логи / метрики / трейсы (совпадает с quality.md §5.2)
```

---

## 7. Запрещено (security BLOCKER)

### Auto-Heal / Playbook Executor

- Executor identity получает least privilege только на явно разрешённые
  `Auto-Heal Authorization.allowed_actions` и только в указанных средах.
- Все автоматические действия содержат audit event: actor, target, action,
  reason/alert fingerprint, timestamp UTC и result — без секретов.
- Playbook обязан быть идемпотентным, иметь retry limit и безопасную остановку.
- Действие вне allowlist или без Operations Owner/escalation contract блокируется.
- Секреты executor не записываются в playbook/monitoring config; источник — `pass`.

```
✗ Critical/High (CVSS ≥ 7.0) в релизе
✗ Секреты в коде, логах, .md, git-истории, Docker-образе, env-файле без pass
✗ Зависимости с известными Critical/High CVE без митигации
✗ Деплой без пройденного SG соответствующего этапа
✗ Threat model отсутствует или с открытыми Critical/High угрозами (Tier ≥ 1)
✗ Owner/tenant-ресурсы без stack-native deny-by-default enforcement;
  PostgreSQL RLS обязателен только если он выбран в HLD как слой enforcement
✗ Privacy-контроли отключены при классификации PII (§6 активен)
✗ Снижение security-уровня проекта ниже глобального минимума по tier (§2)
```

---

## 8. Владелец и каденс — сводка

| SG | Этап | Владелец | Когда |
|----|------|----------|-------|
| SG1 | S2 | s2-security | веха перед Gate 2 |
| SG2 | S3 | s3-security + s3-rbac | веха перед Gate 3 |
| SG3 | S4 | s3-security / CI | каждый PR |
| SG4 | S5→S6 | s5-security | веха перед Gate 6 |
| SG5 | S7 | s6-sre + s3-security | непрерывно после деплоя |

## Хранение секретов
Все секреты хранятся ТОЛЬКО в pass. Никаких исключений.
