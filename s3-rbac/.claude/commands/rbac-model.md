---
description: Спроектировать полную RBAC-модель (роли, ресурсы, иерархия, SoD, RLS, SQL схема)
---

Спроектируй RBAC-модель для проекта $ARGUMENTS.

Прочитай (в таком порядке):
1. /home/host-gui-car/Documents/Obsidian Vault/Claude/projects/$ARGUMENTS/stage2-requirements/outputs/ — найди BA-BRD.md (роли пользователей, бизнес-правила доступа)
2. /home/host-gui-car/Documents/Obsidian Vault/Claude/projects/$ARGUMENTS/stage3-design/outputs/ — найди ARCH-HLD.md (ресурсы системы) и SEC-*-threat-model.md (угрозы несанкционированного доступа)

Выполни полное проектирование RBAC:

1. **Роли** — извлеки все бизнес-роли из BRD, опиши каждую, построй иерархию
2. **Ресурсы** — извлеки все объекты доступа из HLD (сущности, endpoints, функции)
3. **Действия** — определи набор действий для каждого ресурса (CREATE/READ/UPDATE/DELETE/PUBLISH/APPROVE/EXECUTE)
4. **Матрица прав** — для каждой пары роль × ресурс × действие: ✓ / ✗ / ✓(own) / ✓(cond)
5. **SoD** — найди конфликтующие права, задокументируй
6. **RLS** — для каждого owner-ресурса напиши PostgreSQL RLS политику
7. **SQL схема** — таблицы roles, permissions, role_permissions, user_roles + функция current_user_id()

Применяй принципы: Deny by Default, Least Privilege, Separation of Duties.

Создай файлы в /home/host-gui-car/Documents/Obsidian Vault/Claude/projects/$ARGUMENTS/stage3-design/outputs/:
- RBAC-{ДАТА}-model.md
- RBAC-{ДАТА}-matrix.md
- RBAC-{ДАТА}-schema.sql

После создания выведи Gate 3 чеклист (RBAC) со статусом каждого пункта.
