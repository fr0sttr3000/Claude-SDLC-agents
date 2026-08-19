---
description: Полный отчёт SDLC-цикла — план vs факт по всем спринтам и этапам
---

Перед записью любого Markdown-артефакта прочитай `$SDLC_VAULT/_agents/_standards/artifact-metadata.md` и заполни обязательный frontmatter.

Создай полный отчёт о выполненной работе за SDLC-цикл для проекта $ARGUMENTS.

До записи прочитай `_contract/CYCLE1_COMPLETION_V2.md`. `/report` выполняется после Gate 5:
`s5-qa` уже владеет решением, а `s0-tracker` только агрегирует существующие verified references.

Шаги:

1. Собери данные из tracking/:
   $SDLC_PROJECTS_DIR/$ARGUMENTS/tracking/

   - Прочитай все `sprint-NN.md` из явно перечисленных sprint refs (в порядке возрастания);
     не выбирай current artifact по glob/mtime
   - Прочитай backlog.md
   - Прочитай current-sprint.md (если активный спринт — отметить это)

2. Собери plan/Gate 5 facts только через `tracking/current-artifacts-v1.tsv` и canonical resolver:
   - `project-charter` → deliverables/dates;
   - `product-backlog` → planned user stories;
   - `gate5-decision`, `s5-test-analysis`, `defect-index` → validation fact;
   - verified Gate 5/evidence refs → exact source/build/profile binding.
   Legacy schedule-файл не является обязательным контрактом. Если logical id не разрешён,
   укажи `UNVERIFIED / current reference unavailable`; не выбирай похожий файл по имени.
   Для дефектов используй resolved row `defect-index`. Это stable logical IDs/machine
   contracts; произвольный Markdown-текст, имя похожего файла и память агента не являются
   metric input.

3. Сформируй current Completion v2 до отчёта:

   - создай `tracking/completion/CYCLE1-evidence-bundle-v1.tsv` и
     `tracking/completion/CYCLE1-completion-v2.yaml` точно по completion contract v2;
   - используй source/build/profile из verified Gate 5 и Build Evidence v1, digest каждого
     referenced artifact, earliest evidence expiry, UAT approval, active risk exceptions и
     known issues;
   - любые non-verified материалы перечисляй только в `unverified_evidence_refs`;
   - runtime-owned поля бери только из окружения: `SDLC_EXECUTION_RUN_ID`,
     `SDLC_EXECUTION_PLAN_SHA256` и `SDLC_CURRENT_ARTIFACT_MANIFEST_SHA256`; не вычисляй и не
     подменяй их;
   - укажи `current_artifact_manifest_ref: tracking/current-artifacts-v1.tsv` и current
     `full_dod_approval_ref` из logical artifact resolver.

   Затем запусти `cycle1-completion-check.sh "$SDLC_PROJECTS_DIR/$ARGUMENTS"`. Если он вернул
   BLOCKED, не создавай cycle-summary и не объявляй цикл завершённым: укажи exact owner/ref,
   который должен быть исправлен.

4. Сформируй отчёт и сохрани в:
   $SDLC_PROJECTS_DIR/$ARGUMENTS/tracking/cycle-summary.md

   Структура отчёта:
   ```markdown
   ---
   date: YYYY-MM-DD
   project: $ARGUMENTS
   type: cycle-report
   ---

   # SDLC Cycle Report — $ARGUMENTS
   Дата: YYYY-MM-DD  |  Спринтов: N  |  Всего задач: M

   ## 1. Сводка по задачам

   | Статус | Задач | Story Points |
   |--------|-------|-------------|
   | ✅ DONE | N | M SP |
   | ❌ НЕ ВЫПОЛНЕНО | N | M SP |
   | 🚫 ОТМЕНЕНО | N | M SP |
   | 📦 В BACKLOG | N | M SP |
   | **ИТОГО** | **N** | **M SP** |

   Процент выполнения: X%

   ## 2. История спринтов

   ### Спринт 1 — [цель]
   Период: ... → ...
   Запланировано: N задач, M SP  |  Выполнено: N задач, M SP  |  Velocity: X SP
   ✅ Выполнено:
     - T-001 [3SP] Название
   ❌ Не выполнено:
     - T-005 [5SP] Название — причина

   ### Спринт 2 — [цель]
   ...

   ## 3. Сравнение с планом

   | Артефакт / Задача | Запланировано | Факт | Статус |
   |-------------------|---------------|------|--------|
   | Feasibility Study | Спринт 1 | Спринт 1 | ✅ В срок |
   | BRD | Спринт 1 | Спринт 2 | ⚠️ Задержка |
   | HLD | Спринт 2 | — | ❌ Не выполнено |
   ...

   ## 4. Артефакты созданные за цикл

   Перечисли только verified current rows из `tracking/current-artifacts-v1.tsv`, сгруппировав
   их по stage/owner. Не используй `ls`, `find`, mtime или filename glob как current selector.
   Exact source/build/profile, evidence bundle и boundary statuses бери только из уже
   проверенного `tracking/completion/CYCLE1-completion-v2.yaml`.

   ## 5. Задачи в бэклоге (не вошли в цикл)

   | ID | Название | SP | Причина |
   |----|----------|----|---------|

   ## 6. Метрики доставки и качества (quality.md §7)

   ### DORA delivery performance — fact vs previous observation
   | Метрика | Факт | Evidence ref | Прошлое сопоставимое наблюдение + evidence ref | Тренд |
   |---------|------|--------------|-----------------------------------------------|-------|
   | Change lead time | NOT_OBSERVED / deferred | none | none | N/A |
   | Deployment frequency | NOT_OBSERVED / deferred | none | none | N/A |
   | Failed deployment recovery time | NOT_OBSERVED / deferred | none | none | N/A |
   | Change fail rate | NOT_OBSERVED / deferred | none | none | N/A |
   | Deployment rework rate | NOT_OBSERVED / deferred | none | none | N/A |

   Факт допустим только с exact Project-relative verified evidence ref и его contract-bound
   source/build/profile. Тренд допустим только между двумя exact observations с одинаковыми
   metric definition, unit, subject и observation scope; иначе `N/A / not comparable`.
   Без exact production evidence не подставляй target/band/value. Reliability (SLO/error
   budget) покажи отдельной строкой operational characteristic, не как шестую DORA metric:
   `NOT_OBSERVED / deferred (Cycle 3 FROZEN)`.

   ### Defect-метрики — эффективность гейтов
   | Метрика | Effective policy / режим | Факт | Evidence ref | Прошлый цикл + evidence ref | Тренд |
   |---------|---------------------------|------|--------------|-----------------------------|-------|
   | Defect Density (деф./KLOC или /SP) | NOT_DEFINED / observational | NOT_OBSERVED | none | none | N/A |
   | DRE (% дефектов пойманных до прода) | NOT_DEFINED / observational | NOT_OBSERVED | none | none | N/A |
   | Escaped Defects (найдены в проде) | NOT_DEFINED / observational | NOT_OBSERVED / deferred | none | none | N/A |

   Для каждой defect-метрики сначала вызови `quality-policy-read.sh PROJECT METRIC_ID`.
   Только существующая effective policy row задаёт operator/threshold/unit; если metric id не
   определён, оставь `NOT_DEFINED / observational` и не придумывай цель. Факт бери только из
   exact current defect index или verified production evidence с явным numerator/denominator,
   unit и observation scope.

   > Деградация наблюдаемой метрики 2 цикла подряд → запись в tracking/tech-debt.md.
   > NOT_OBSERVED не является деградацией и не получает выдуманный тренд.
   > Escaped Defect S1/S2 в доступной Cycle 1 среде → ретро s5-qa; production post-mortem
   > deferred.

   ## 7. Выводы и рекомендации

   ### Что пошло хорошо
   [3-5 пунктов]

   ### Что улучшить в следующем цикле
   [3-5 пунктов]

   ### Рекомендации для следующего спринта
   [топ-5 задач из backlog с обоснованием]
   ```

5. После сохранения файла — выведи краткую версию отчёта в консоль.

6. Не создавай release notes/CHANGELOG, не выполняй push, release build, deploy или production
   action и не читай Cycle 2/3 как prerequisite. Зафиксируй boundary statuses из contract и
   `client_next_action: s0-tracker:/release-notes`.

7. После записи cycle-summary повторно проверь, что completion manifest и current-artifact
   manifest не изменились относительно прошедшего шага 3. При drift верни `BLOCKED` и не
   объявляй цикл завершённым.

ОБЯЗАТЕЛЬНО: в самом конце вывести итоговый task board со статусами всех задач из всех спринтов.
