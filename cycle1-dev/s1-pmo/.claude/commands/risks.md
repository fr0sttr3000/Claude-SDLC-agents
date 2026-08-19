---
description: Создать Risk Register
---

Перед записью любого Markdown-артефакта прочитай `$SDLC_VAULT/_agents/_standards/artifact-metadata.md` и заполни обязательный frontmatter.

Создай Risk Register для проекта $ARGUMENTS.

Прочитай: $SDLC_PROJECTS_DIR/$ARGUMENTS/stage1-planning/
Создай: $SDLC_PROJECTS_DIR/$ARGUMENTS/stage1-planning/outputs/PMO-risk-register.md

Требования:
- Минимум 20 рисков
- Не менее 10 рисков оформи exact rows:
  `RISK-NNN | Category: technical | Probability: 3 | Impact: 4 | Score: 12 | Owner: role | Mitigation: concrete action | Trigger: observable condition | Status: OPEN`.
  Score обязан равняться P×I; ID уникален; owner/mitigation/trigger и status обязательны;
  placeholder/unknown запрещены.
- Все 6 категорий представлены
- Сортировка по Risk Score (убыв.)
- Для каждого Critical/High: детальный план митигации
- Явно классифицируй safety-impact risks. Сверь результат с
  `tracking/product-ci-profile.yaml:safety_validation`; mismatch не исправляй сам — запроси
  refresh профиля через `s0-kickoff` до `s0-quality-gates /configure`.
- Дашборд в конце: количество по severity, топ-3 по score
