# Subagent Contract

Supervisor + Worker — сохранённый опциональный принцип исполнения. Он не создаёт второй SDLC,
не меняет artifact/gate/security contracts и никогда не передаёт worker-у ownership этапа.

## Текущий исполняемый статус

**Workers: `BLOCKED / NOT SUPPORTED`.** Единственное допустимое значение —
`SDLC_SUBAGENTS=off`.

- `SDLC_SUBAGENTS=auto|cross-runtime` отклоняется launcher-ом и `_runtimes/agent-run.sh`;
- прямой `_runtimes/subagent-run.sh` всегда возвращает non-zero;
- Cycle 2/3 target сначала отклоняется общим frozen guard как `FROZEN / NOT READY`;
- legacy profile/task/max settings не включают capability и не обходят dispatcher;
- silent fallback на другой runtime/model запрещён.

Причина fail-closed режима: текущие adapters способны запретить worker-у запись, но не доказывают
ограничение чтения одним exact project scope на уровне runtime/OS. Prompt с `READ_SCOPE`, allowlist
задач или последующая проверка supervisor-ом не являются security boundary.

## Инварианты будущего включения

Workers можно вернуть только отдельным evidence-backed изменением, которое одновременно докажет:

1. canonical active-agent guard применяется primary и worker dispatcher-ами;
2. read scope ограничен capability-механизмом runtime/OS, а не текстом prompt;
3. worker не имеет write tools, write mounts или доступа к sibling projects/secrets;
4. environment строится allowlist-ом без vendor session state и secret values;
5. nested delegation, gate signing и operational actions запрещены технически;
6. negative fixtures покрывают `/`, HOME, sibling project, symlink/path traversal, frozen target,
   secret leakage, write attempt и unsupported runtime;
7. primary остаётся единственным writer/gate signer и проверяет advisory findings;
8. worker failure означает `BLOCKED` или явный retry без fallback.

До выполнения всех условий нельзя публиковать capability matrix с поддержанными workers.

## Допустимая будущая модель

Каждый пакет должен содержать один разрешённый task kind, один конкретный вопрос, exact read scope
и формат ответа. Conversation history, secrets, sibling-worker results и unbounded context не
передаются. Worker output остаётся advisory session data, а межэтапный handoff — только файловым.

Подходящие задачи после будущего включения: bounded analysis/research/review и интерпретация уже
полученных test results внутри active Cycle 1. Deploy, rollback, production drill, auto-heal,
редактирование artifacts, подписание gates и любые frozen Cycle 2/3 actions запрещены.
