# Runbook KI-[id] — [название] — {PROJECT}

> **Historical Cycle 3 template — FROZEN / NOT READY.** Не инстанцируется и не
> проверяется active Cycle 1. Сохранён только для инвентаризации перед redesign.
>
> Плейбук реакции на проявление известного дефекта KI-[id] в проде.
> Шаблон: s6-sre инстанцирует как `SRE-runbook-KI-[id].md` в `stage7-ops/outputs/` —
> по одному файлу на каждую запись `OPEN` из `known-issues.md` с user-facing impact.
> Связано: `known-issues.md` (KI-[id]) · `tech-debt.md` (TD-[N] — постоянный фикс).
> Структура совпадает с generic incident-runbook'ами + добавлены Diagnose и Auto-remediation.

---

## Symptoms — что видно
- алерт `KI-[id]`; сигнатура в метриках/логах; типичная жалоба пользователя

## Detect — подтвердить, что это именно KI-[id]
- условие алерта; запрос в логах/метриках для подтверждения

## Diagnose — отличить от похожего
- быстрый чек: если <условие> → это KI-[id]; иначе → см. SRE-runbook-<другой>.md

## Auto-remediation — что система делает сама
- действие (restart / retry / fallback / clear-cache / feature-flag-off), порог срабатывания, кулдаун
- как проверить, что автодействие отработало
- если не отработало за threshold из будущего NFR/escalation contract → перейти к Workaround
- (если авто-ремедиации нет — указать «нет, только ручной обход» и сразу к Workaround)

## Workaround — ручной обход
- пошаговые команды
- идемпотентность: безопасно ли повторять

## Verify — убедиться, что восстановились
- метрика вернулась к норме; алерт `KI-[id]` закрылся

## Escalate — если не помогло
- on-call → порог эскалации
- ссылка на постоянный фикс: TD-[N] в `tech-debt.md`
