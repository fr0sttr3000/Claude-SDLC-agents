---
description: Проверить требования на тестируемость и вынести Gate 2 вердикт
---

Проведи Testability Review требований для проекта $ARGUMENTS.

Прочитай:
1. $SDLC_VAULT/_agents/_standards/quality.md
2. Все BA-*.md в $SDLC_VAULT/projects/$ARGUMENTS/stage2-requirements/outputs/
3. Все PO-*.md в $SDLC_VAULT/projects/$ARGUMENTS/stage2-requirements/outputs/

Создай файл QA-REQ-[дата]-review.md в:
$SDLC_VAULT/projects/$ARGUMENTS/stage2-requirements/outputs/

# QA Requirements Review — $ARGUMENTS
Дата: [сегодня]
Агент: s2-qa-req

## Анализ требований

Для каждого требования / User Story проверь:
□ Конкретный измеримый критерий успеха (не "быстро", а "p95 < 300ms")?
□ Нет субъективных оценок?
□ Состояние ДО и ПОСЛЕ однозначно описаны?
□ Можно написать автоматический тест?
□ Acceptance Criteria в формате Given/When/Then?

## Замечания
Формат каждого: [BLOCKER/MAJOR/MINOR] ID_требования: описание проблемы → рекомендация

| Уровень | ID | Описание | Рекомендация |
|---------|----|---------  |--------------|

## Gate 2 — Переход S2 → S3

□ DoR-1: BA-BRD.md и BA-NFR.md существуют в stage2-requirements/outputs/
□ DoR-2: Все требования SMART, без размытых формулировок
□ DoR-3: Каждая Must-story имеет AC в формате Given/When/Then
□ DoR-4: Все NFR с числами (не "быстро", а конкретный порог)
□ DoR-5: 0 открытых BLOCKER-вопросов
□ Testability: каждое требование можно автоматически протестировать
□ Трассируемость: все требования связаны с бизнес-целями

## ВЕРДИКТ
✅ GATE 2 PASSED — s3-arch может начинать
❌ GATE 2 FAILED — [список блокеров, s3-arch не начинает]
