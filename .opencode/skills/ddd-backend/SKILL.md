---
name: ddd-backend
description: Router maestro de skills para arquitectura backend DDD + CQRS + Hexagonal. SIEMPRE carga este skill primero al construir servicios backend con dominios de negocio complejos. Evalúa la tarea y dirige al sub-skill específico a cargar. Cubre entities, value objects, aggregates, domain events, repositories, buses de command/query/event de CQRS, patrón CDC outbox, pruebas con Object Mother, tests de arquitectura, puertos y adaptadores hexagonales, patrón criteria specification, patrón decorator, y estructuración de bounded contexts. Independiente de lenguaje y framework.
license: MIT
metadata:
  version: "2.0"
  supersedes: clean-ddd-hexagonal
  source-inspiration: codelytv/php-ddd-example
---

# Router de Arquitectura Backend DDD

**REGLA CRÍTICA:** NO adivines patrones arquitectónicos ni estructura de código. Antes de escribir o modificar cualquier código, identifica tu tipo de tarea abajo y usa tu herramienta de carga de skills para cargar **EXACTAMENTE UN** sub-skill.

Este skill es solo un **router**. No contiene reglas de implementación. Todas las reglas de implementación residen en los sub-skills.

## Tabla de Enrutamiento de Tareas

| Escenario | Carga Este Skill |
|---|---|
| Crear o modificar Entity, Value Object, Aggregate Root, Domain Event, interfaz Repository, Domain Service o Factory | `ddd-domain-patterns` |
| Crear o modificar Command/CommandHandler, Query/QueryHandler, EventBus, DomainEventSubscriber, CDC Outbox o Criteria/Filters | `ddd-cqrs-events` |
| Escribir CUALQUIER test (unitario, integración, arquitectura, BDD), crear Object Mothers o configurar infraestructura de testing | `ddd-testing` |
| Crear adaptadores de persistencia, adaptadores de message broker, decorators de caché o wrappers de monitoreo | `ddd-infrastructure` |
| Crear controladores HTTP, comandos CLI, consumidores de eventos, configuración de enrutamiento o bootstrap de aplicación | `ddd-entrypoints` |

## Principios de Arquitectura (Referencia Rápida)

1. **Regla de Dependencia:** Infrastructure depende de Application. Application depende de Domain. Nunca al revés.
2. **Un aggregate por transacción.** Consistencia entre aggregates = domain events (consistencia eventual).
3. **Un Repository por aggregate,** no por entity. Las interfaces Repository son ports en la capa Domain.
4. Los **Ports** definen interfaces en las capas Domain/Application. Los **Adapters** las implementan en la capa Infrastructure.
5. **Prueba el comportamiento, no la implementación.** Usa Object Mothers para datos de prueba. Usa tests de arquitectura para hacer cumplir las reglas de dependencia.

## Archivos de Referencia

| Archivo | Cuándo Usarlo |
|---|---|
| [references/DECISION-TREE.md](references/DECISION-TREE.md) | No estás seguro de dónde pertenece un fragmento de código |
| [references/PATTERNS-CATALOG.md](references/PATTERNS-CATALOG.md) | Necesitas ver todos los patrones disponibles de un vistazo |
| [references/ANTI-PATTERNS.md](references/ANTI-PATTERNS.md) | Algo huele mal en el código base |
| [references/SHARED-KERNEL.md](references/SHARED-KERNEL.md) | Necesitas estructurar la carpeta shared/ o decidir qué compartir entre bounded contexts |

## Plantillas

Copia desde [assets/templates/](assets/templates/) para puntos de partida consistentes con la arquitectura.

## Diagrama de Arquitectura

Consulta [assets/diagrams/dependency-flow.mermaid](assets/diagrams/dependency-flow.mermaid) para una vista general visual del flujo de dependencias.

## Script de Validación

Ejecuta [scripts/validate-structure.sh](scripts/validate-structure.sh) para verificar que la estructura de tu proyecto sigue la regla de dependencia.
