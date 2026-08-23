---
description: Проверить архитектурный impact и предложить Stage 4 path scope
---

Проведи независимую архитектурную проверку Change Scope `$ARGUMENTS`.

Прочитай:

1. `tracking/change-scopes/$ARGUMENTS/intent.yaml`;
2. `tracking/change-scopes/$ARGUMENTS/l1/project-map-v1.tsv`;
3. `tracking/change-scopes/$ARGUMENTS/l1/impact-v1.tsv`;
4. current HLD, ADR/index, API contract, Product Profile, requirements, quality policy,
   security requirements and test strategy по root Current Artifacts rule;
5. `_contract/CHANGE_SCOPE_V1.md`.

Проверь exact source/digests до анализа. Не доверяй L1 verdict без проверки. Сохрани
intentional complexity, архитектурные invariants и protected modules. При необходимости новой
архитектуры потребуй current ADR/HLD update и верни `BLOCKED`; не разрешай Stage 4 менять
архитектуру по ходу реализации.

Не изменяй Project вне `tracking/change-scopes/$ARGUMENTS/s3/`. Не пиши code/tests, не
запускай L1 и не создавай Human Approval.

Создай:

- `architecture-impact-v1.yaml` с exact flat schema из `_contract/CHANGE_SCOPE_V1.md`;
- `change-scope-paths-proposed-v1.tsv` с header
  `schema_version intent_id agent command operation path module_id module_mode origin`.

Назначай native test paths только `s4-qa-auto /write-tests`, production paths только
`s4-dev /dev-report`. `/run-tests`, `/update-notes` и `s4-techlead /review` не получают native
write paths. Каждая native row должна точно совпадать с high-confidence L1 impact row; origin
ставь `s3`. Не добавляй governance `declared-output`: их добавляет launcher из canonical
registry. Delete/rename и directory prefixes разрешай только когда они явно присутствуют в
L1 impact. Любая неопределённость даёт `verdict: BLOCKED`.

В конце выведи architecture verdict, protected modules и SHA-256 обоих файлов.
