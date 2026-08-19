---
date: 2026-06-20
tags: [standards, security, devsecops]
---

# Стандарт безопасности — SDLC Vault (Security Gates)

> Параллельный трек к `quality.md`. Безопасность по ISO/IEC 25010 — одна из характеристик
> качества, но ведётся отдельным shift-left треком (NIST SSDF, OWASP SAMM, Microsoft SDL):
> свой язык severity (CVSS, не баги S1–S4), свой каденс (PR + вехи),
> свой владелец (`s3-security`, в S2 — `s2-security`/shift-left).
>
> Смежные стандарты: `quality.md` (качество), `data-formats.md` (форматы данных).
>
> Правило перехода: этап пройден, только когда зелёный **И** Quality Gate (quality.md §4)
> **И** соответствующий active Security Gate (этот файл §3). Действующий scope —
> SG1–SG4 поддерживаемого Cycle 1. SG5/Cycle 3 — `FROZEN / NOT SUPPORTED`.

---

## 1. Язык severity — CVSS, не баги

Security-находки оцениваются по **CVSS v3.1/v4.0 + CWE/CVE**, а не по шкале багов S1–S4.
Это разные системы координат — не смешивать.

| Уровень | CVSS | Политика релиза |
|---------|------|-----------------|
| Critical | 9.0–10.0 | **Блокирует релиз** (BLOCKER), фикс до деплоя |
| High | 7.0–8.9 | **Блокирует релиз** (BLOCKER), фикс до деплоя |
| Medium | 4.0–6.9 | Фикс либо typed Risk Exception v3: expiry ≤90 дней **и** remediation не позже конца следующего sprint; запись в `tracking/tech-debt.md` |
| Low | 0.1–3.9 | `tracking/tech-debt.md`; при user-facing impact — полный Known Issue + отдельный Human Approval v1 |
| None | 0.0 | — |

Critical/High в релизе = безусловный BLOCKER (совпадает с quality.md §8).
Risk-accept Medium допускается только с владельцем, причиной и дедлайном — как технический долг.

> **Security Low/Medium с user-facing проявлением** дополнительно промотируются в
> `tracking/known-issues.md` (quality.md §6.1). Active Cycle 1 требует impact/workaround/detection
> signal, связанный Tech Debt/Patch SLA и отдельный Human Approval v1 от пользователя или
> уполномоченного владельца продукта; alert/runbook/auto-remediation deferred вместе с Cycle 3.
> Для Medium это принятие Known Issue не заменяет Risk Exception v3. Единым источником owner,
> finding ids и дедлайна остаётся `tracking/tech-debt.md`; отдельного security ledger нет.

Risk Exception v3 определён единым `_contract/RISK_EXCEPTION_V3.md` и использует два
независимых ограничения: технический expiry не позже 90 дней
после создания и sprint SLA не позже конца следующего sprint. Gate принимает Medium finding,
только если `risk-exception-check.sh` подтверждает оба ограничения и ссылку `tech_debt_id`.
Если target sprint/end date ещё не материализованы Project artifact, verdict — `BLOCKED`.

---

## 2. Security Level по tier — «только вверх»

Базовый уровень — **OWASP ASVS 5.0.0**, выбирается по `cycle1.criticality_tier`
(PMO-constraints.md) и классификации данных. Принцип тот же, что у
`s0-quality-gates`: проектный уровень может только **повышаться** относительно
глобального минимума, не понижаться.

Active baseline фиксирован как `asvs_version: 5.0.0`. Каждый requirement reference имеет
формат `v5.0.0-X.Y.Z`; голые `X.Y.Z` запрещены, потому что identifiers меняются между
версиями. Upgrade baseline выполняется только отдельным versioned изменением с миграцией
существующего evidence. Официальный источник:
<https://owasp.org/www-project-application-security-verification-standard/>.

| Tier | ASVS уровень | Кому |
|------|:------------:|------|
| 0 / 1 | **L1** (baseline) | любое приложение |
| 2 | **L2** (standard) | приложения с чувствительными данными / большинство |
| 3 | **L3** (advanced) | критичные, высокоценные системы |

**Бамп по данным:** любая классификация `confidential / PII / secret` поднимает уровень
минимум до **L2** независимо от tier. Классификацию фиксирует SG1.

Конфигурацию security-уровня проекта ведёт `s0-quality-gates` (расширение)
или фиксирует SG1 в `tracking/quality-gates.md`. Effective policy проверяется
`quality-gates-check.sh`; отсутствующая/stale policy с S2 означает `BLOCKED`.

---

## 3. Active Security Gates SG1–SG4 и historical SG5

SG1–SG4 параллельны active Quality Gates G1–G5. SG5 сохранён только как historical baseline.
Проверяет владелец active трека первым делом на своём этапе.

| SG | Фаза | Владелец | Каденс |
|----|------|----------|--------|
| **SG1** Requirements | S2 | `s2-security` | веха |
| **SG2** Design | S3 | `s3-security` + `s3-rbac` | веха |
| **SG3** Build | S4 | selected executor → `s0-validate` → `s4-techlead` | **непрерывно, каждый PR** |
| **SG4** Cycle 1 validation | S5 | `s5-security` | веха |
| **SG5** Production | S7, FROZEN | historical `s6-sre` + `s3-security` | не active |

### SG1 — Requirements (S2) — владелец `s2-security`
```
□ Abuse / misuse cases определены для каждого критичного FR
□ Классификация данных зафиксирована: public / internal / confidential / PII / secret
□ ASVS-уровень выбран по tier + классификации данных (§2)
□ asvs_version: 5.0.0
□ Каждый ASVS requirement reference имеет вид v5.0.0-X.Y.Z
□ Security NFR с числами: authn/authz, crypto, session, rate limit, логирование
□ Scope комплаенса определён (GDPR / PCI-DSS / HIPAA) — или явно «не применимо» с обоснованием
```
Артефакт: `SEC-YYYY-MM-DD-security-requirements.md` в `stage2-requirements/outputs/`.
Gate 2 принимает его только после SG1 Validation v1: exact current-input digests, Product
Profile revision, полный declared data-classification scope и полное
critical-FR→scenario→ASVS→countermeasure покрытие.

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
Gate 3 принимает threat model только после SG2 Validation v1: exact SG1/HLD digests,
повторная семантическая проверка SG1, совпадающие ASVS references, current
API/authorization applicability и полное scenario/component→threat→control→test покрытие.

### SG3 — Build (S4, непрерывно на каждый PR)
```
□ selected executor из Product Profile создал exact-source raw SAST/SCA/secrets results
□ s0-validate подтвердил producer, digest, freshness, subject и policy revision
□ SAST/SCA: 0 открытых Critical/High (CVSS ≥ 7.0)
□ Secrets-scan: 0 находок; исключения запрещены
□ Dependency integrity: pass; tampered/malicious dependencies = 0; исключения запрещены
□ Medium либо закрыт, либо имеет typed Risk Exception v3 с owner/rationale, `tech_debt_id`,
  expiry ≤90 дней и remediation до конца следующего sprint
□ Image scan и SBOM проверяются только для объявленного artifact subject
□ s4-techlead подписал Gate 4 после `SG3 VERIFIED`; s4-dev не создаёт и не подписывает verdict
```
Machine evidence: `tracking/evidence/v1/*.yaml` + native results в
`tracking/evidence/raw/` по `_contract/EVIDENCE_V1.md`. Markdown summary генерируется из
verified records и сам по себе не закрывает SG3. Policy и exceptions определены в
`_contract/SG3_POLICY_V1.md`.

### SG4 — Cycle 1 validation (S5) — владелец `s5-security`
```
□ DAST по работающему приложению: 0 Critical/High
□ Pentest / security review проведён (Tier ≥ 2 — обязательно; Tier 0/1 — по решению)
□ Security-тест-кейсы из threat model (SG2) выполнены, результаты зафиксированы
□ Все находки SG3 закрыты или risk-accepted с дедлайном
□ Verified: секреты только в pass, не в образе/конфиге/env-файле
```
Артефакт: `SEC-YYYY-MM-DD-pentest-report.md` в `stage5-testing/outputs/`.

SG4 подтверждает security validation Cycle 1, но не является разрешением deploy и не
запускает frozen Cycle 2/3.

### SG5 — Production (S7) — FROZEN / NOT SUPPORTED

Чеклист ниже сохранён как historical implementation baseline и не блокирует Cycle 1.
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

В отличие от quality-вех, SG3-проверки идут **на каждый PR**. Постоянные SG5-контроли
не входят в active scope:

```
PR → SAST → SCA → secrets-scan → container scan → SBOM   (блокируют merge при Critical/High)
SG5/PROD controls → FROZEN / NOT SUPPORTED до redesign Cycle 3
```

Принцип shift-left: чем раньше найдено, тем дешевле. SG1 (abuse cases) и SG2 (threat model)
ловят дефекты дизайна до написания кода.

---

## 5. Маппинг на фреймворки

| Фреймворк | Где покрыт |
|-----------|-----------|
| **NIST SSDF v1.1 / SP 800-218 final** | Active baseline: PO (§2 уровни), PS (SG3 SBOM/целостность), PW (SG2 дизайн, SG3 SAST), RV (SG4 pentest); SG5 vuln mgmt historical. SSDF v1.2 / SP 800-218 Rev. 1 draft не является active baseline |
| **OWASP SAMM** | Active: Governance (§1–2), Design (SG2), Implementation (SG3), Verification (SG4); Operations/SG5 historical |
| **OWASP ASVS 5.0.0** | §2 — version-pinned requirement references и уровень L1/L2/L3 по tier |
| **OWASP Top 10:2025** | Version-pinned mapping A01–A10 ниже |
| **Microsoft SDL** | Active: Requirements→SG1, Design/Threat Model→SG2, Implementation→SG3, Verification→SG4; Release/Response→historical SG5 |
| **SLSA** | SBOM/Evidence v1 не заявляют SLSA level; отдельный SLSA mapping в active scope не поддерживается |

Active NIST baseline: <https://csrc.nist.gov/pubs/sp/800/218/final>. Draft publications
проверяются отдельно и не меняют baseline автоматически:
<https://csrc.nist.gov/Projects/ssdf/publications>.

### OWASP Top 10:2025

Официальный выпуск: <https://owasp.org/Top10/2025/>.

| Категория | Active Cycle 1 controls/evidence |
|---|---|
| **A01 Broken Access Control** | SG1 authorization requirements; SG2 authorization/RBAC design; SG4 negative authorization tests |
| **A02 Security Misconfiguration** | SG1 secure-configuration requirements; SG2 defaults/hardening design; SG3 selected-executor policy evidence; SG4 validation |
| **A03 Software Supply Chain Failures** | SG3 SCA, SBOM, dependency and artifact/cache integrity evidence |
| **A04 Cryptographic Failures** | SG1 crypto/data-classification requirements; SG2 key/data-protection design; SG4 verification |
| **A05 Injection** | SG1 misuse cases; SG2 input/query boundaries; SG3 SAST; SG4 negative tests/DAST |
| **A06 Insecure Design** | SG1 abuse cases and security NFR; SG2 threat model and design controls |
| **A07 Authentication Failures** | SG1 authn/session requirements; SG2 authentication design; SG4 authentication tests |
| **A08 Software or Data Integrity Failures** | SG2 trust/integrity design; SG3 exact-source evidence and dependency/artifact integrity |
| **A09 Security Logging and Alerting Failures** | Cycle 1 logging/alerting requirements, design and test evidence; production operations execution remains frozen |
| **A10 Mishandling of Exceptional Conditions** | Failure-path requirements/design plus negative, recovery and error-handling tests |

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

### Auto-Heal / Playbook Executor — historical Cycle 3 scope

Раздел не является active requirement Cycle 1 и сохраняется только для будущего redesign.

- Executor identity получает least privilege только на явно разрешённые
  `Auto-Heal Authorization.allowed_actions` и только в указанных средах.
- Все автоматические действия содержат audit event: actor, target, action,
  reason/alert fingerprint, timestamp UTC и result — без секретов.
- Playbook обязан быть идемпотентным, иметь retry limit и безопасную остановку.
- Действие вне allowlist или без Operations Owner/escalation contract блокируется.
- Секреты executor не записываются в playbook/monitoring config; источник — `pass`.

```
✗ Critical/High (CVSS ≥ 7.0) в релизе
✗ Секреты в коде, логах, .md, VCS history, образе или любом plaintext env-файле
✗ Зависимости с известными Critical/High CVE без митигации
✗ Переход active этапа без пройденного соответствующего SG
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
| SG3 | S4 | selected executor → s0-validate → s4-techlead | каждый PR |
| SG4 | S5 | s5-security | веха Cycle 1 validation |
| SG5 | S7, FROZEN | historical s6-sre + s3-security | не active |

## Runtime-граница файловой системы

Каждый primary cycle/tool agent на поддерживаемом Linux запускается через общий
capability-enforced Landlock boundary. Метаданные VCS исходного checkout и checkout-local
runtime-denied roots запрещены для open/read/list/write, включая доступ через symlink.
Публичный канон остаётся читаемым, а exact Project/notes scopes сохраняют только права,
определённые runtime-контрактом. Отсутствие helper source, compiler, kernel support или
успешного enforcement блокирует dispatch. Эта граница не включает worker capability.

## Хранение секретов

`pass` — единственный secret store поддерживаемого scope. Project code, artifacts, Markdown,
logs и runtime arguments содержат только entry reference, но не secret value.

- Новое или заменяемое значение вводится непосредственно в интерактивный prompt `pass`; agent
  не запрашивает и не принимает его через chat.
- Команды могут показывать только entry references и `ENV_VAR → pass:entry` mappings.
- Получение значения допускается только process-locally для точной команды при отключённом shell
  tracing; plaintext `.env`, export scripts и shell profiles запрещены.
- GPG identity, key material и доступ к secret store настраивает пользователь; agent не создаёт
  и не ослабляет их автоматически.
- Missing или неоднозначный entry блокирует операцию; silent fallback на другое значение запрещён.
