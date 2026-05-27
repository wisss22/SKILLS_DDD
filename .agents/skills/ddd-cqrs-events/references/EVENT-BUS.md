# Event Bus

El EventBus es un **puerto** (interfaz en la capa Domain) que publica domain events a los suscriptores interesados. Desacopla al productor de eventos de los consumidores de eventos.

## Reglas Fundamentales

### 1. El EventBus es un Puerto de Domain

```pseudocode
// Domain port (interface — no implementation)
interface EventBus:
    method publish(events: DomainEvent[]): void
```

### 2. Publicar Después de una Persistencia Exitosa

```pseudocode
class SomeCommandHandler:
    method invoke(command): void
        aggregate = self.repository.findById(command.id)
        aggregate.doSomething()  // Records domain events internally
        self.repository.save(aggregate)
        // NOW publish — if save fails, no events are published
        self.eventBus.publish(aggregate.pullEvents())
```

Nunca publiques antes de la persistencia. Si el guardado falla, el evento ya fue enviado.

### 3. Múltiples Implementaciones (Adaptadores)

Diferentes implementaciones para diferentes entornos:

| Implementation | Environment | Guarantees |
|---|---|---|
| **InMemoryEventBus** | Dev / Test | Synchronous, no durability |
| **RabbitMqEventBus** | Production | Async, durable messages |
| **MySqlEventBus (CDC)** | Production | Sync via DB, eventual delivery to broker |
| **KafkaEventBus** | Production | Async, log-based retention |

```
EventBus (Domain Port)
    ├── InMemoryEventBus          (dev/test)
    ├── RabbitMqEventBus          (production — direct to broker)
    ├── MySqlEventBus (CDC)       (production — via outbox + CDC)
    └── DecoratedEventBus         (wraps another bus with monitoring/logging)
```

### 4. EventBus con Monitoreo (Patrón Decorator)

```pseudocode
// Decorator that wraps any EventBus implementation
class MonitoredEventBus implements EventBus:
    property wrappedBus: EventBus
    property monitor: Monitor

    method publish(events): void
        start = now()
        self.wrappedBus.publish(events)
        duration = now() - start
        self.monitor.recordEventPublish(
            count: events.length,
            duration: duration
        )
```

### 5. Implementación en Memoria (Desarrollo/Test)

```pseudocode
class InMemoryEventBus implements EventBus:
    property subscribers: map[string, DomainEventSubscriber[]]

    method register(subscriber, eventType):
        self.subscribers[eventType].append(subscriber)

    method publish(events): void
        for event in events:
            eventType = event.eventName()
            subs = self.subscribers[eventType] ?? []
            for subscriber in subs:
                subscriber.invoke(event)
```

### 6. Implementación con Message Broker (Producción)

```pseudocode
class RabbitMqEventBus implements EventBus:
    property connection: RabbitMqConnection
    property serializer: DomainEventJsonSerializer

    method publish(events): void
        for event in events:
            exchangeName = self.exchangeNameFor(event)
            serialized = self.serializer.serialize(event)
            self.connection.publish(exchangeName, serialized)
```

### 7. Serialización de Eventos

Los eventos se serializan para su transmisión. Incluye todos los metadatos:

```pseudocode
// Serialized event format (JSON):
{
    "data": {
        "id": "evt-uuid-here",          // Unique event ID
        "type": "mooc.course.created",   // Event type (for routing)
        "occurredOn": "2025-01-15T...",  // Timestamp
        "attributes": {                  // Event-specific data
            "id": "course-uuid",
            "name": "DDD Course",
            "duration": 120
        }
    },
    "meta": {
        "aggregateId": "course-uuid",    // For ordering guarantees
        "host": "server-1",
        "version": 1
    }
}
```

## Mapeo de Eventos

Una configuración de mapeo le indica a la infraestructura cómo mapear cadenas de tipo de evento a clases de evento:

```pseudocode
class DomainEventMapping:
    // Maps event name strings → event class, used for deserialization
    method for(eventName: string): DomainEventClass
        // "mooc.course.created" → CourseCreated class
        return self.mappings[eventName]
```

## Errores Comunes

1. **Publicar antes de la persistencia**: Evento enviado pero datos no guardados (inconsistencia)
2. **Sin event ID**: No se puede deduplicar si el mensaje llega dos veces
3. **Pensamiento solo síncrono**: Asumir que todo el procesamiento de eventos ocurre inmediatamente
4. **Falta de metadatos de serialización**: Event type, aggregate ID, occurredOn
5. **Llamadas directas al broker en el dominio**: Domain llamando a RabbitMQ directamente en lugar de hacerlo a través del puerto
6. **Sin monitoreo**: Eventos publicados pero sin visibilidad de volumen, errores, latencia
