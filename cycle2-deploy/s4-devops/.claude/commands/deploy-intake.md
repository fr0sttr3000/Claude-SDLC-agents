---
description: Сверить цель, инфраструктуру, authorization и точный scope Cycle 2
---

# /deploy-intake

Подготовь проверяемый intake Cycle 2 до тестов и реализации.

1. Прочитай tracking/SDLC-goals.md, tracking/PMO-constraints.md, HLD,
   security requirements и готовый build/test evidence Cycle 1.
2. Используй только поля cycle2_*. Не выбирай инфраструктуру, registry,
   orchestrator или способ поставки по умолчанию.
3. Проверь, что cycle2_deliverables содержит только явно заказанные результаты.
   Значение images означает: не создавать IaC, CI/CD, GitOps или deploy action.
4. Для execute-deploy проверь точную среду, executor identity, authorization,
   maintenance window и rollback. Секреты не запрашивай и не записывай.
5. Разреши bounded read-only subagents для отдельных проверок infrastructure
   discovery, supply-chain и test design. Они не пишут артефакты и не выполняют
   deploy; основной агент сводит выводы.
6. Запиши stage6-deploy/outputs/DEVOPS-YYYY-MM-DD-deploy-intake.md с матрицей:
   цель → deliverable → тест → evidence → owner и со всеми BLOCKED-вопросами.

Если профиль неполон или противоречив — BLOCKED, без silent fallback.
