---
description: Проверить требования на тестируемость и подготовить QA contribution для Gate 2
---

Проведи Testability Review требований для проекта $ARGUMENTS.

Прочитай:
1. $SDLC_VAULT/_agents/_standards/quality.md
2. Все BA-*.md в $SDLC_PROJECTS_DIR/$ARGUMENTS/stage2-requirements/outputs/
3. Все PO-*.md в $SDLC_PROJECTS_DIR/$ARGUMENTS/stage2-requirements/outputs/

Создай файл QA-REQ-[дата]-review.md в:
$SDLC_PROJECTS_DIR/$ARGUMENTS/stage2-requirements/outputs/

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

## QA contribution для Gate 2

□ DoR-1: BA-BRD.md и BA-NFR.md существуют в stage2-requirements/outputs/
□ DoR-2: Все требования SMART, без размытых формулировок
□ DoR-3: Каждая Must-story имеет AC в формате Given/When/Then
□ DoR-4: Все NFR с числами (не "быстро", а конкретный порог)
□ DoR-5: 0 открытых BLOCKER-вопросов
□ Testability: каждое требование можно автоматически протестировать
□ Трассируемость: все требования связаны с бизнес-целями

## ВЕРДИКТ QA
`QA contribution: PASS` — testability checks пройдены.
`QA contribution: FAIL` — [список блокеров].

Не подписывай весь Gate 2: финальный Gate 2 требует также BA-BRD/NFR/RTM,
backlog, test strategy и SG1 evidence; его полноту проверяет s0-validate перед S3.
