---
description: Построить Project Map и технический impact для Change Scope
---

Подготовь L1 impact для Change Scope `$ARGUMENTS`. Это отдельный launcher-owned workflow,
а не обычный Local Repositories analysis.

Прочитай в Project:

1. `tracking/change-scopes/$ARGUMENTS/intent.yaml`;
2. current Product Profile, requirements, backlog, architecture and test-strategy artifacts по
   root Current Artifacts rule;
3. repository manifests, source tree, public interfaces, native tests, generated-code markers
   и dependency graph.

Не изменяй Project вне `tracking/change-scopes/$ARGUMENTS/l1/`. Не пиши production code,
tests или архитектурное решение. Не вызывай S3 и не одобряй собственный результат.

Создай:

- `tracking/change-scopes/$ARGUMENTS/l1/project-map-v1.tsv` с exact header из
  `_contract/CHANGE_SCOPE_V1.md`;
- `tracking/change-scopes/$ARGUMENTS/l1/impact-v1.tsv` с exact header из того же contract.

Project Map обязан покрыть затрагиваемые модули, их прямые зависимости, public interface,
native test root, generated root, classification и confidence. Impact обязан привязать каждую
операцию к exact `intent_id`, module id и safe Project-relative path. Используй
`USE|EXTEND|MODIFY|LOCKED`; запись допустима только при `high` confidence. Неизвестная граница,
неоднозначный repository root, generated ownership или архитектурный конфликт дают `BLOCKED`,
а не расширенный scope.

В конце выведи exact относительные пути созданных файлов и их SHA-256.
