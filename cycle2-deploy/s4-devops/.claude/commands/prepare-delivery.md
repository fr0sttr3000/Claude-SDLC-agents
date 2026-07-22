---
description: Подготовить только явно выбранные delivery artifacts после RED
---

# /prepare-delivery

Подготовь только явно заказанные результаты из cycle2_deliverables.

- images — versioned images, SBOM/signature/provenance по профилю;
- runtime-bundle — stack-native runtime package;
- orchestrator, iac, cicd, gitops — только если каждый пункт выбран;
- operations-pack — runbook, rollback, validation и handoff evidence;
- execute-deploy — действие только при явной authorization и с rollback.

Читай tracking/SDLC-goals.md непосредственно перед работой: поздняя частичная
корректировка профиля имеет приоритет над ранними предположениями. Не создавай
лишние артефакты «на будущее». Секреты не записывай.

При активных subagents делегируй только bounded read-only проверки. Основной
агент единолично изменяет deliverables и формирует итоговый evidence.
