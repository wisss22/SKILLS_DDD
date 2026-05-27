# Patrón CDC / Outbox

El patrón **CDC (Change Data Capture) + Outbox** garantiza la publicación confiable de domain events. En lugar de publicar eventos directamente a un message broker (lo cual puede fallar), los eventos se escriben primero en una **tabla outbox** en la misma transacción de base de datos que el aggregate. Luego, un proceso separado lee el outbox y publica en el broker.

## El Problema: Escrituras Duales

```
// NAIVE approach — not reliable!
transaction:
    repository.save(aggregate)    // Step 1: Write to DB
    eventBus.publish(events)      // Step 2: Publish to broker
    // What if Step 2 fails? Data is saved but events are not sent.
    // What if the transaction rolls back AFTER Step 2? Events were sent for data that doesn't exist.
```

## La Solución: Tabla Outbox

```
transaction:
    repository.save(aggregate)       // Write aggregate
    outbox.save(events)              // Write events to outbox table (SAME transaction)
// After transaction commits:
// A separate process reads the outbox and publishes to the broker
```

### Estructura de la Tabla Outbox

```sql
CREATE TABLE domain_events (
    id UUID PRIMARY KEY,
    aggregate_id VARCHAR(36) NOT NULL,
    name VARCHAR(255) NOT NULL,       -- Event type: "mooc.course.created"
    body JSON NOT NULL,                -- Event payload
    occurred_on TIMESTAMP NOT NULL,
    published_on TIMESTAMP NULL        -- NULL = not yet published
);
```

### Escritura en el Outbox

```pseudocode
class SomeCommandHandler:
    property repository: AggregateRepository
    property outbox: DomainEventOutbox

    method invoke(command): void
        transaction:
            aggregate = Aggregate.create(...)
            self.repository.save(aggregate)

            events = aggregate.pullEvents()
            for event in events:
                self.outbox.save(event)     // Same transaction!
```

### Publicación desde el Outbox (Proceso CDC)

Dos enfoques para consumir el outbox:

#### Enfoque A: Sondeo de la Tabla Outbox

```pseudocode
// Runs as a background process (cron, daemon)
class PublishDomainEventsCommand:
    method run():
        while true:
            events = outbox.findUnpublished(limit: 100)
            for event in events:
                eventBus.publishToBroker(event)     // Publish to RabbitMQ/Kafka
                outbox.markAsPublished(event.id)     // Mark as done

            if events.length == 0:
                sleep(pollInterval)
```

#### Enfoque B: Database Change Data Capture (CDC)

En lugar de sondear, escucha el log de cambios de la base de datos:

```pseudocode
class DatabaseMutationToDomainEvent:
    // Converts a raw database mutation to a domain event
    method transform(mutation: DatabaseMutation): DomainEvent?
        if mutation.table == "courses" AND mutation.action == INSERT:
            return new CourseCreated(
                aggregateId: mutation.row.id,
                name: mutation.row.name,
                duration: mutation.row.duration
            )
        return null  // Not a domain event mutation
```

```
Database Binary Log
    → CDC Connector (Debezium, Maxwell, custom)
    → DatabaseMutationToDomainEvent (converts row changes to events)
    → EventBus.publishToBroker()
    → RabbitMQ / Kafka
```

## ¿Qué Enfoque Usar?

| Approach | Pros | Cons |
|---|---|---|
| **Outbox Polling** | Simple, no external tools | Polling latency, table grows |
| **CDC (Binlog)** | Real-time, no table overhead | Requires DB CDC tooling |
| **Direct to Broker** | Simplest | No reliability guarantee |

## Integración Outbox + EventBus

```pseudocode
// The MySQL event bus writes to outbox, then a consumer publishes to RabbitMQ
class MySqlEventBus implements EventBus:
    method publish(events): void
        // Events are already in the same TX as the aggregate
        // (written by the outbox in the handler)
        // This bus just sends them to a background processor
        for event in events:
            self.outbox.save(event)  // Idempotent — skip if already in outbox

// Separate consumer process
class ConsumeMySqlDomainEvents:
    method run():
        events = self.consumer.consume()  // Reads from outbox table
        for event in events:
            // Publish to the real broker (RabbitMQ)
            // AND notify in-memory subscribers
            self.eventBus.publish(event)
            self.consumer.markAsProcessed(event)
```

## Consideraciones de Idempotencia

| Scenario | Solution |
|---|---|
| Outbox entry saved, broker publish fails | Retry — outbox entry still marked as unpublished |
| Outbox entry saved, broker publish succeeds, mark fails | Broker has duplicate, consumer must be idempotent |
| Consumer processes same event twice | Event ID in consumer — skip if already processed |

## Errores Comunes

1. **Publicar fuera de la transacción**: EventBus llamado antes/después pero no en la misma transacción
2. **Sin limpieza del outbox**: La tabla outbox crece indefinidamente — archiva/elimina eventos publicados
3. **Errores de mapeo CDC**: Mutaciones de base de datos no mapeadas correctamente a domain events
4. **Sondeo del outbox demasiado frecuente**: Carga excesiva en la base de datos por sondear cada 100ms
5. **Falta de ordenamiento de eventos**: Los eventos del mismo aggregate deben procesarse en orden
6. **Sin dead letter queue**: El procesamiento de eventos fallidos hace que el consumidor se detenga
