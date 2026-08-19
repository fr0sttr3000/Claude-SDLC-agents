---
description: Создать ADR из HLD candidates или для явно указанного решения
---

Перед записью любого Markdown-артефакта прочитай `$SDLC_VAULT/_agents/_standards/artifact-metadata.md` и заполни обязательный frontmatter.

Первый токен $ARGUMENTS — PROJECT. Остаток, если он есть, — точное решение для
standalone ADR. Launcher может передать только PROJECT.

Прочитай ARCH-HLD.md и существующие ADR в:
$SDLC_PROJECTS_DIR/{PROJECT}/stage3-design/outputs/.

Если решение явно передано — создай ADR для него. Если передан только PROJECT,
извлеки из HLD все ADR candidates/нетривиальные решения и создай недостающие ADR.
Не выдумывай candidate, которого нет в HLD. Для каждого ADR сравни минимум три
реально применимых варианта по проектным критериям; если вариантов меньше,
зафиксируй evidence и причину, а не добавляй фиктивный вариант.

Для каждого ADR добавь exact machine block и frontmatter из
`_contract/ARCHITECTURE_DECISION_TRACE_V1.md`, обе стороны trade-off и текущую Product Profile
revision. Создай/обнови `stage3-design/outputs/ARCH-decision-trace-v1.tsv`: ровно одна строка
на каждый ADR artifact, без неиндексированных решений. Затем запусти
`s0-validate/architecture-decision-trace-check.sh`; `BLOCKED` не является завершением.
