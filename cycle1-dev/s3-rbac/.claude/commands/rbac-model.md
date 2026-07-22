---
description: Спроектировать stack-neutral authorization model и native enforcement artifacts
---

Спроектируй RBAC-модель для проекта $ARGUMENTS.

Прочитай (в таком порядке):
1. $SDLC_PROJECTS_DIR/$ARGUMENTS/stage2-requirements/outputs/ — найди BA-BRD.md (роли пользователей, бизнес-правила доступа)
2. $SDLC_PROJECTS_DIR/$ARGUMENTS/stage3-design/outputs/ — найди ARCH-HLD.md (ресурсы системы) и SEC-*-threat-model.md (угрозы несанкционированного доступа)

Сначала определи применимость RBAC. Если проект использует другой authorization
model или не имеет субъектов/защищённых ресурсов, создай
RBAC-{ДАТА}-not-applicable.md с HLD/security evidence.

Для применимого authorization model:

1. **Роли** — извлеки все бизнес-роли из BRD, опиши каждую, построй иерархию
2. **Ресурсы** — извлеки все объекты доступа из HLD (сущности, endpoints, функции)
3. **Действия** — определи набор действий для каждого ресурса (CREATE/READ/UPDATE/DELETE/PUBLISH/APPROVE/EXECUTE)
4. **Матрица прав** — для каждой пары роль × ресурс × действие: ✓ / ✗ / ✓(own) / ✓(cond)
5. **SoD** — найди конфликтующие права, задокументируй
6. **Enforcement points** — опиши stack-native deny-by-default проверки для API,
   service, datastore и background actions
7. **Native artifact** — policy/schema/config только в формате выбранного stack;
   PostgreSQL RLS/SQL создавай лишь если они выбраны в HLD

Применяй принципы: Deny by Default, Least Privilege, Separation of Duties.

Создай применимые файлы в $SDLC_PROJECTS_DIR/$ARGUMENTS/stage3-design/outputs/:
- RBAC-{ДАТА}-model.md
- RBAC-{ДАТА}-matrix.md
- RBAC-{ДАТА}-schema.{native-format}, только если нужен отдельный native artifact

После создания выведи Gate 3 checklist: model, matrix, enforcement points,
deny-by-default tests/design, SoD и native artifact/N-A evidence.
