---
description: Подготовить локальный repository и опциональный GitHub remote по подтверждённому плану
---

Для project $ARGUMENTS сначала покажи абсолютный root, существующий `.git`, proposed
default branch, `.gitignore`, repository owner/name/visibility и remote URL. Не выбирай
owner, visibility или имя по умолчанию молча.

Отдельно подтверди: локальный `git init`; создание GitHub repository; добавление remote;
первый staging/commit; первый push. Перед commit обязателен staged secrets scan из
CLAUDE.md без вывода совпавших строк/значений. Не создавай набор stage branches без
явного запроса; branch создаётся по мере необходимости через `/branch`.
