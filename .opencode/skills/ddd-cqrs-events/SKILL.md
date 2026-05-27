---
name: ddd-cqrs-events
description: Separación CQRS de command/query, bus de eventos, suscriptores de eventos de dominio, patrón CDC outbox para publicación confiable de eventos y patrón criteria specification para consultas flexibles. Usar al crear Commands, Queries, CommandHandlers, QueryHandlers, EventBus, DomainEventSubscribers, al implementar el patrón outbox o al construir búsquedas basadas en Criteria. Independiente del lenguaje y del framework.
license: MIT
metadata:
  version: "1.0"
  part-of: ddd-backend
---

# CQRS + Patrones Orientados a Eventos

Command/Query Responsibility Segregation (CQRS) separa las operaciones de escritura (Commands) de las operaciones de lectura (Queries). Los Domain Events y el Event Bus permiten la comunicación entre aggregates y bounded contexts. El patrón CDC Outbox garantiza la publicación confiable de eventos.

## Recordatorio de la Regla de Dependencia

```
Infrastructure → Application → Domain
```

- Las **interfaces** de Command/Query (puertos) residen en la capa Domain o Application
- La **interfaz** del EventBus (puerto) reside en la capa Domain
- Las **implementaciones** (adaptadores) de buses y publicadores de eventos residen en la capa Infrastructure
- Nunca importes código de Infrastructure en Domain o Application

## Resumen de Patrones

| Pattern | Purpose | Direction | Returns |
|---|---|---|---|
| **Command** | Intent to change state | Client → Handler | Void |
| **CommandHandler** | Executes business logic for a Command | Handler → Domain | Void |
| **Query** | Request for data | Client → Handler | Response DTO |
| **QueryHandler** | Fetches data for a Query | Handler → Read Model | Response DTO |
| **EventBus** | Publishes domain events | Publisher → Subscribers | Void |
| **DomainEventSubscriber** | Reacts to a specific domain event | Event → Side Effect | Void |
| **CDC Outbox** | Captures events from DB changes | DB → EventBus | (Pattern) |
| **Criteria** | Composable query filters | Query → Repository | (Pattern) |

## Reglas Rápidas

1. Los **Commands** se nombran de forma imperativa: `CreateCourse`, `UpdateUser`, `DeleteOrder`. Son DTOs simples.
2. **Los Commands devuelven void.** Si se necesitan datos después de un command, emite una query separada.
3. **Un CommandHandler por Command.** El Handler es un **traductor delgado**: convierte primitivos del Command en Value Objects del dominio y delega en el Application Service. El Application Service es el **orquestador real** (crea aggregates, persiste, publica eventos). Para el patron completo de 3 capas, consulta [references/APPLICATION-SERVICES.md](references/APPLICATION-SERVICES.md).
4. Las **Queries** se nombran como preguntas: `FindCourse`, `SearchUsers`, `GetAllOrders`.
5. El **EventBus** publica eventos DESPUÉS de una persistencia exitosa. Nunca antes.
6. Los **DomainEventSubscribers** reaccionan a eventos de otros aggregates/contextos. Mantenlos idempotentes.
7. Patrón **CDC Outbox**: escribe los eventos en una tabla outbox en la misma transacción que el aggregate, luego un proceso separado los publica en el message broker.
8. Patrón **Criteria**: usa value objects de Filter, Order y paginación para consultas de repositorio. Evita pasar SQL/query DSL crudo a los repositorios.

## Archivos de Referencia

| Archivo | Contenido |
|---|---|
| [references/COMMANDS.md](references/COMMANDS.md) | Command DTOs, CommandBus, CommandHandlers, cableado |
| [references/QUERIES.md](references/QUERIES.md) | Query DTOs, QueryBus, QueryHandlers, Response DTOs |
| [references/EVENT-BUS.md](references/EVENT-BUS.md) | Interfaz EventBus, implementaciones (en memoria, broker, CDC) |
| [references/EVENT-SUBSCRIBERS.md](references/EVENT-SUBSCRIBERS.md) | Patrón DomainEventSubscriber, comunicación entre contextos |
| [references/CDC-OUTBOX.md](references/CDC-OUTBOX.md) | Patrón CDC/Outbox para publicación confiable de eventos |
| [references/CRITERIA-PATTERN.md](references/CRITERIA-PATTERN.md) | Criteria, Filters, Order para consultas flexibles de repositorio |
| [references/APPLICATION-SERVICES.md](references/APPLICATION-SERVICES.md) | Patron de 3 capas CQRS: Command → Handler (traductor) → Application Service (orquestador) |

## Skills Relacionadas

| Tarea | Cargar |
|---|---|
| Necesitas los objetos de dominio sobre los que operan estos commands/queries | `ddd-domain-patterns` |
| Necesitas implementar adaptadores de bus (RabbitMQ, base de datos) | `ddd-infrastructure` |
| Necesitas probar handlers de command/query | `ddd-testing` |
| Necesitas controladores HTTP que despachen commands/queries | `ddd-entrypoints` |
