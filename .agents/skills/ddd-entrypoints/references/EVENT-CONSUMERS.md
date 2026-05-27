# Consumidores de Eventos

Los consumidores de eventos son **procesos en segundo plano de larga duración** que consumen domain events de brokers de mensajes y los enrutan a DomainEventSubscribers. Son el puente entre la infraestructura de mensajería externa y la lógica interna de la aplicación.

## Arquitectura del Consumidor

```
Message Broker (RabbitMQ / Kafka)
    │
    ▼
Event Consumer (proceso de larga duración)
    │  Deserializa JSON → DomainEvent
    │
    ▼
EventBus Interno (En Memoria)
    │  Enruta el evento a los subscribers correspondientes
    │
    ▼
DomainEventSubscriber 1    DomainEventSubscriber 2    DomainEventSubscriber N
    (maneja el evento)       (maneja el evento)         (maneja el evento)
```

## Componentes Principales

### 1. Proceso Consumidor

```pseudocode
class RabbitMqDomainEventsConsumer:
    property connection: RabbitMqConnection
    property deserializer: DomainEventJsonDeserializer
    property eventBus: EventBus                    // Internal EventBus (In-Memory)
    property subscriberLocator: DomainEventSubscriberLocator
    property logger: Logger

    method consume(): void
        // 1. Connect to broker
        self.connection.connect()

        // 2. For every subscriber, bind its queue to the correct exchange
        for subscriber in self.subscriberLocator.all():
            for eventType in subscriber.subscribedTo():
                queueName = self.queueNameFor(subscriber, eventType)
                exchangeName = self.exchangeNameFor(eventType)
                self.connection.bindQueue(
                    queue: queueName,
                    exchange: exchangeName
                )

        // 3. Start consuming messages (blocks forever)
        self.logger.info("Consumer started. Waiting for messages...")
        self.connection.consume(
            callback: self.processMessage
        )

    method processMessage(message: RawMessage): void
        try:
            // Deserialize the message body into a DomainEvent
            event = self.deserializer.deserialize(message.body)

            // Publish to internal EventBus (synchronous, in-memory)
            // This calls all registered subscribers
            self.eventBus.publish([event])

            // Acknowledge successful processing
            message.ack()

            self.logger.debug("Processed event: " + event.eventName())

        catch DeserializationError:
            // Bad message — don't retry, move to dead letter
            self.logger.error("Cannot deserialize message: " + message.body)
            message.reject(requeue: false)  // Send to dead letter queue

        catch TemporaryError:
            // Transient error — retry later
            self.logger.warn("Temporary error, will retry")
            message.nack(requeue: true)  // Return to queue for retry

        catch PermanentError:
            // Business logic error — don't retry
            self.logger.error("Permanent error processing event")
            message.reject(requeue: false)  // Send to dead letter queue
```

### 2. Localizador de Subscribers

```pseudocode
class DomainEventSubscriberLocator:
    property subscribers: DomainEventSubscriber[]

    constructor(subscribers: DomainEventSubscriber[]):
        self.subscribers = subscribers

    method all(): DomainEventSubscriber[]
        return self.subscribers

    method findForEvent(eventName: string): DomainEventSubscriber[]
        return self.subscribers.filter(sub =>
            sub.subscribedTo().contains(eventName)
        )
```

### 3. Deserialización de Eventos

```pseudocode
class DomainEventJsonDeserializer:
    property mapping: DomainEventMapping

    method deserialize(json: string): DomainEvent
        data = JSON.parse(json)

        eventType = data.data.type
        eventClass = self.mapping.for(eventType)

        return eventClass.fromPrimitives(
            aggregateId: data.meta.aggregateId,
            body: data.data.attributes,
            eventId: data.data.id,
            occurredOn: data.data.occurredOn
        )
```

### 4. Configuración de Colas y Exchanges

```pseudocode
class RabbitMqConfigurer:
    property connection: RabbitMqConnection
    property subscriberLocator: DomainEventSubscriberLocator

    method configure(): void
        self.connection.connect()

        for subscriber in self.subscriberLocator.all():
            for eventType in subscriber.subscribedTo():
                exchangeName = "domain_events." + eventType
                queueName = self.queueName(subscriber, eventType)

                // Create exchange (durable, survives broker restart)
                self.connection.createExchange(
                    name: exchangeName,
                    type: "topic",
                    durable: true
                )

                // Create queue (durable)
                self.connection.createQueue(
                    name: queueName,
                    durable: true
                )

                // Bind queue to exchange
                self.connection.bindQueue(
                    queue: queueName,
                    exchange: exchangeName,
                    routingKey: eventType
                )
```

## Estrategia de Manejo de Errores

| Tipo de Error | Acción | Justificación |
|---|---|---|
| **DeserializationError** | Rechazar (sin reencolar) → Dead Letter | Mensaje defectuoso, reintentar no ayudará |
| **TemporaryError** (BD caída, red) | Nack (reencolar) con retraso | Transitorio, reintentar tendrá éxito |
| **PermanentError** (regla de negocio) | Rechazar (sin reencolar) → Dead Letter | Evento válido, pero el procesamiento falló |
| **Tipo de evento desconocido** | Rechazar (sin reencolar) → Dead Letter | Falta subscriber, necesita investigación |

## Cola de Mensajes Muertos (DLQ)

Los mensajes fallidos se enrutan a una DLQ para investigación:

```pseudocode
// Broker configuration
class RabbitMqConfigurer:
    method configureDeadLetter():
        // Create dead letter exchange
        self.connection.createExchange(
            name: "domain_events.dead_letter",
            type: "topic"
        )

        // Create dead letter queue
        self.connection.createQueue(
            name: "domain_events.dead_letter",
            durable: true,
            arguments: {
                "x-message-ttl": 7 * 24 * 60 * 60 * 1000  // Retain for 7 days
            }
        )

        // For each domain event queue, set the dead letter exchange
        for queue in self.allQueues():
            self.connection.setDeadLetterExchange(
                queue: queue,
                exchange: "domain_events.dead_letter"
            )
```

## Idempotencia en Consumidores

Los eventos pueden entregarse más de una vez. Dos enfoques:

### Enfoque A: El Consumidor Rastrea los IDs de Eventos Procesados

```pseudocode
class IdempotentConsumer:
    property processedEvents: Set<string>

    method processMessage(message): void
        event = self.deserializer.deserialize(message.body)

        // Already processed this exact event?
        if self.processedEvents.contains(event.eventId):
            message.ack()  // Acknowledge but skip processing
            return

        self.eventBus.publish([event])
        self.processedEvents.add(event.eventId)
        message.ack()
```

### Enfoque B: El Subscriber Maneja Duplicados

```pseudocode
class CreateBackofficeCourseOnCourseCreated implements DomainEventSubscriber:
    method invoke(event): void
        // Idempotent: if the course already exists, do nothing
        if self.repository.exists(event.aggregateId):
            return

        course = BackofficeCourse.create(event.aggregateId, event.name, event.duration)
        self.repository.save(course)
```

## Comando CLI del Consumidor

```pseudocode
class ConsumeRabbitMqDomainEventsCommand:
    method run(): int
        consumer = self.buildConsumer()
        consumer.consume()  // Blocks forever
        return 0
```

## Errores Comunes

1. **Sin cola de mensajes muertos**: Los mensajes fallidos se pierden o bloquean el consumidor
2. **Sin idempotencia**: Los eventos duplicados causan efectos secundarios duplicados
3. **No confirmar mensajes**: El consumidor falla, los mensajes se pierden
4. **Procesamiento en serie**: Eventos de diferentes aggregates procesados uno a la vez (deberían ser en paralelo)
5. **Misma cola para todos los subscribers**: No se puede escalar subscribers de forma independiente
6. **Sin monitoreo**: Sin visibilidad de profundidad de cola, tasa de procesamiento o errores
7. **Procesamiento largo en el consumidor**: Subscribers lentos bloquean la cola para ese subscriber
8. **Sin reintento de conexión**: El consumidor muere ante indisponibilidad temporal del broker
