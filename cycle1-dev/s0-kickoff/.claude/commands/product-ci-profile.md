---
description: Собрать или обновить versioned Product & CI Profile перед Stage 1
---

Для Project `$ARGUMENTS` прочитай `_contract/PRODUCT_CI_PROFILE.md`, `idea.md`, существующий
profile и только доступные read-only repository/CI config files. Сначала покажи observed
facts и источники. Затем спроси только неизвестные обязательные facts по одному блоку.

Не выбирай за пользователя product type, SCM/review policy, CI provider, required checks,
build/package toolchain, compliance или approvals. Не запускай build/release, не запрашивай
secret values и не собирай delivery/operations scope Cycle 2/3.

Для нового/обновляемого профиля используй schema version 5. Подтверди один из трёх evidence
source profiles (`repository-ci|connected-runner|local-offline`), project-relative repository
path, executor identity, trusted producer identities, freshness/signature/merge semantics,
build subject и SBOM applicability. Для minimum check set ничего не удаляй: неприменимость
позже фиксируется structured `NOT_APPLICABLE`. Не генерируй vendor pipeline и не объявляй
capability, которую нельзя наблюдать или подтвердить.

Отдельно подтверди фактический `user_interface`
(`graphical|terminal|api-only|library-only|none`). Для `graphical|terminal` запиши
`ux_brief_requirement: required`; для `api-only|library-only|none` — `not-applicable`.
Не выводи interface из product type, stack или собственного предположения.

Отдельно подтверди S5 facts: фактический validation environment profile
(`connected-representative|local-representative|not-available`), его concrete identity и
необходимость отдельной authorization. Независимо подтверди `performance_validation` и
`runtime_security_validation` как `required|not-applicable` из NFR/risk facts. Не выводи их
из product type и не создавай test/deployment platform. `not-available` — честный факт,
который оставляет обязательные S5 streams BLOCKED, а не разрешает их пропустить.

Отдельным блоком подтверди `compatibility_validation`, `accessibility_validation`,
`flexibility_validation` и `safety_validation` как `required|not-applicable`. Основание —
stakeholder requirements, риски и ограничения, а не product type, stack или удобство
исполнителя. Required accessibility требует UI/UX brief; non-UI профиль фиксирует explicit
accessibility N/A. Эти поля выбирают применимость, но никогда не снижают глобальные quality
minimums.

Отдельно, без вывода из product type или stack, подтверди архитектурную применимость:
`api_contract_design`, `data_store_design`, `authorization_design` как
`required|not-applicable`. Это одна all-or-none группа schema v5. Наличие service не означает
автоматически API/БД/RBAC, а CLI/library не означает их отсутствия. Для каждого поля сохрани
`observed|user-confirmed` provenance; неизвестное оставляет Gate 3 BLOCKED.

Отдельно подтверди `environment_format_validation: required|not-applicable` для формата
runtime configuration/environment. Не выводи это из языка или наличия `.env`; сохрани
`observed|user-confirmed` provenance. Это значение вместе с data/API applicability управляет
profile-aware DoD-11.

Запиши exact flat YAML schema в `tracking/product-ci-profile.yaml` и идентичный snapshot
`tracking/product-ci-profile-history/revision-{N}.yaml`. Новый profile имеет revision 1.
Любое обновление увеличивает revision ровно на 1, сохраняет previous snapshot и добавляет
в `tracking/evidence-invalidations.md` текущую revision с `invalidates: revisions<N`.

После записи запусти canonical `product-ci-profile-check.sh`. При BLOCKED не запускай Stage 1;
перечисли только отсутствующие/неподтверждённые facts.
