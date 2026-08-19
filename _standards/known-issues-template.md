# Known Issues — {PROJECT}

> Реестр известных дефектов с user-facing impact, выявленных к завершению Cycle 1.
> Файл создаётся s0-tracker при инициализации проекта.
> В active Cycle 1 файл читает **s5-qa**; ключ поиска = Detection signal.
> Production consumer, алерты и runbook — historical Cycle 3 scope (`FROZEN / NOT READY`).
> Owner, дедлайн и план исправления — в `tech-debt.md` (поле «→ tech-debt»).
> Принятие ограничения — отдельный Human Approval v1; агент его не создаёт и не имитирует.

---

## Правила записи

- Дефект попадает сюда ТОЛЬКО если выполнены ВСЕ условия:
  - severity = S3/S4 либо security Low/Medium по CVSS;
  - `Impact` = user-facing (есть наблюдаемое проявление);
  - определены Trigger, Workaround и Detection signal;
  - связанный Tech Debt содержит owner, план исправления и Patch SLA;
  - отдельный Human Approval v1 связан с exact source revision, KI ID и digest строки дефекта.
- Иначе дефект/долг живёт обычной строкой в `tech-debt.md` (только планирование, без мониторинга).
- S1/S2 и security Critical/High нельзя принять как Known Issue. Known Issue также не является
  waiver для проваленного обязательного контроля.
- Security Medium дополнительно требует Risk Exception v3. Он не заменяет принятие Known Issue.
- Каждая запись обязана иметь: Severity, Trigger, Impact, Workaround, Detection signal,
  Auto-remediation, `→ tech-debt` и ссылку на Human Approval v1.
- `Auto-remediation` — опционально (только где автоматизируемо); если нет — явно «нет».
- Дублировать дедлайн/исполнителя из `tech-debt.md` ЗАПРЕЩЕНО — только ссылка (единый источник правды).
- Historical Cycle 3 mapping: имя алерта = id записи (KI-NN) = имя runbook'а
  (SRE-runbook-KI-NN.md). Он не является active требованием.

---

## Жизненный цикл

- **Создание:** s5-qa на go/no-go (Gate 5) — дефект промотируется в known issue.
- **Cycle 2/3:** `FROZEN / NOT READY`; Gate 7, alert/fire drill и runbook не проверяются.
- **Закрытие:** повторная Cycle 1 validation подтверждает исправление, но запись остаётся `OPEN`,
  пока evidence не подтвердит точную выпущенную версию/build с исправлением. Только после этого
  статус меняется на `FIXED` и закрывается связанный TD. Alert/runbook снимаются лишь при наличии
  соответствующего operational scope.
- **Release notes:** каждая `OPEN` запись включается в Known limitations подготовленной версии;
  подготовка notes не разрешает публикацию, build, release или deploy.

---

## Индекс (быстрый скан для on-call)

| ID    | Sev | Impact (1 строка) | Detection signal / алерт | Auto-rem | Status | → tech-debt | Human Approval v1 |
|-------|-----|-------------------|--------------------------|----------|--------|-------------|-------------------|
|       |     |                   |                          |          |        |             |                   |

---

## Формат записи

```
### KI-[N] — [краткое название дефекта]
- Severity: S3 | S4 | CVSS-MEDIUM | CVSS-LOW
- Trigger: при каком условии/нагрузке/вводе проявляется
- Impact: user-facing — что видит пользователь и каков blast radius
- Detection signal: конкретное условие (метрика/лог-сигнатура); имя алерта = KI-[N]
- Auto-remediation: автодействие + порог + кулдаун — ИЛИ «нет (только ручной обход)»
- Workaround: ручной обход кратко (пошаговые детали — в runbook)
- Runbook: N/A (Cycle 3 FROZEN); historical name SRE-runbook-KI-[N].md
- → tech-debt: TD-[M]     (там дедлайн фикса и Patch SLA)
- Human Approval v1: tracking/approvals/APPROVAL-KI-[ID].yaml
- Fix release version: none | vMAJOR.MINOR.PATCH
- Fix build evidence ref: none | tracking/evidence/v1/EV-[ID].yaml
- Fix build evidence sha256: none | {64-hex digest Evidence v1 record}
- Fix source revision: none | {40/64-hex или sha256:64-hex}
- Fix verification test id: none | TEST-[ID]
- Operational scope: FROZEN_NOT_READY | ACTIVE
- Alert cleanup evidence: none | ref=tracking/operations/evidence/[FILE];sha256={64-hex}
- Runbook cleanup evidence: none | ref=tracking/operations/evidence/[FILE];sha256={64-hex}
- Status: OPEN | FIXED
```

Для Gate 5 `subject_digest` Human Approval v1 — SHA-256 канонической TSV-строки дефекта без
поля `acceptance_approval_ref`; `scope` содержит `known-issue:KI-[N]` и `defect:DEF-[ID]`.
Так approval нельзя циклически включить в собственный digest или переиспользовать для другого
дефекта.

`OPEN` требует `none` во всех Fix/cleanup fields и active связанный Tech Debt.
`FIXED` требует exact version/source/test, digest-bound Build Evidence v1 с non-source subject,
`build_identity: release:vMAJOR.MINOR.PATCH` и raw JSON, где exact KI/test перечислены как
included fix evidence; связанный Tech Debt одновременно имеет `RESOLVED`. Validation report
без released build subject не закрывает KI. Cleanup evidence требуется только при
`Operational scope: ACTIVE`; для `FROZEN_NOT_READY` оба cleanup field остаются `none`.

---

## Записи

<!-- Новые записи добавляются снизу вверх (новые первыми) -->
