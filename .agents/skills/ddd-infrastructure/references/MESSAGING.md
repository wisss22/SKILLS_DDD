# Adaptadores de Mensajería

Los adaptadores de mensajería **implementan** el puerto EventBus de la capa de Dominio, conectando tu aplicación a brokers de mensajería (RabbitMQ, Kafka, SQS, etc.) y manejando la serialización, enrutamiento y consumo de eventos.

## Reglas Fundamentales

### 1. El Adaptador Implementa el Puerto EventBus

```pseudocode
// Domain port
interface EventBus:
    method publish(events: DomainEvent[]): void

// Adapter for RabbitMQ
class RabbitMqEventBus implements EventBus:
    property connection: RabbitMqConnection
    property serializer: DomainEventJsonSerializer
    property exchangeFormatter: ExchangeNameFormatter

    method publish(events): void
        for event in events:
            exchange = self.exchangeFormatter.format(event.eventName())
            serialized = self.serializer.serialize(event)
            self.connection.publish(exchange, serialized)
```

### 2. Nomenclatura de Exchange / Tópico

Cada tipo de evento va a su propio exchange/tópico para escalado independiente:

```pseudocode
class ExchangeNameFormatter:
    method format(eventName: string): string
        // "mooc.course.created" → "domain_events.mooc.course.created"
        return "domain_events." + eventName
```

### 3. Nomenclatura de Colas para Consumidores

Cada suscriptor obtiene su propia cola, vinculada al exchange del evento:

```pseudocode
class QueueNameFormatter:
    method format(subscriber: DomainEventSubscriber, eventName: string): string
        // "domain_events.mooc.course.created.backoffice.create_backoffice_course"
        subscriberName = subscriber.constructor.name
        return "domain_events." + eventName + "." + subscriberName
```

### 4. Serialización de Eventos

Convierte los Domain Events a JSON para su transmisión:

```pseudocode
class DomainEventJsonSerializer:
    method serialize(event: DomainEvent): string
        return JSON.encode({
            data: {
                id: event.eventId.value(),
                type: event.eventName(),
                occurredOn: event.occurredOn.format(),
                attributes: event.toPrimitives()  // Event-specific data
            },
            meta: {
                aggregateId: event.aggregateId.value(),
                host: self.hostName(),
                version: 1
            }
        })
```

### 5. Deserialización de Eventos (Lado del Consumidor)

Convierte JSON de vuelta a Domain Events:

```pseudocode
class DomainEventJsonDeserializer:
    property mapping: DomainEventMapping

    method deserialize(json: string): DomainEvent
        data = JSON.parse(json)
        eventClass = self.mapping.for(data.data.type)
        return eventClass.fromPrimitives(
            aggregateId: data.data.attributes.aggregateId,
            body: data.data.attributes,
            eventId: data.data.id,
            occurredOn: data.data.occurredOn
        )

class DomainEventMapping:
    property mappings: map[string, DomainEventClass]

    constructor():
        // Register all event types
        self.mappings["mooc.course.created"] = CourseCreated
        self.mappings["mooc.course.renamed"] = CourseRenamed
        self.mappings["mooc.video.created"] = VideoCreated

    method for(eventName: string): DomainEventClass
        return self.mappings[eventName] ?? throw UnknownEventType(eventName)
```

### 6. Consumidor (Proceso de Larga Ejecución)

```pseudocode
class RabbitMqDomainEventsConsumer:
    property connection: RabbitMqConnection
    property deserializer: DomainEventJsonDeserializer
    property eventBus: EventBus  // Internal event bus (in-memory)
    property subscriberLocator: DomainEventSubscriberLocator

    method consume():
        // Connect to broker
        self.connection.connect()

        // For each subscriber, bind its queue to the exchanges it listens to
        for subscriber in self.subscriberLocator.all():
            for eventType in subscriber.subscribedTo():
                queue = QueueNameFormatter.format(subscriber, eventType)
                exchange = ExchangeNameFormatter.format(eventType)
                self.connection.bindQueue(queue, exchange)

        // Start consuming
        self.connection.consume(callback: self.processMessage)

    method processMessage(message):
        event = self.deserializer.deserialize(message.body)
        // Publish to internal event bus for subscribers to handle
        self.eventBus.publish([event])
        message.ack()  // Acknowledge successful processing
```

### 7. Configuración de Supervisor (Producción)

Los consumidores de larga ejecución necesitan supervisión de procesos:

```ini
# Example supervisor configuration
[program:rabbitmq_consumer_courses]
command=php bin/console app:domain-events:rabbitmq:consume
numprocs=1
autostart=true
autorestart=true
startretries=10
redirect_stderr=true
stdout_logfile=/var/log/app/consumer_courses.log
```

## Gestión de Conexiones

```pseudocode
class RabbitMqConnection:
    property host: string
    property port: int
    property user: string
    property password: string
    property vhost: string
    property channel: Channel

    method connect(): void
        // Establish connection with retries
        retries = 0
        while retries < maxRetries:
            try:
                self.channel = self.createChannel()
                return
            catch ConnectionError:
                retries += 1
                sleep(retryDelay * retries)

    method publish(exchange: string, message: string): void
        self.channel.publish(exchange, "", message)

    method consume(callback: function): void
        self.channel.consume(callback)
```

## Múltiples Implementaciones de Mensajería

| Adaptador | Caso de Uso |
|---|---|
| **InMemoryEventBus** | Desarrollo, pruebas (síncrono, sin broker) |
| **RabbitMqEventBus** | Producción (asíncrono, durable, enrutamiento flexible) |
| **KafkaEventBus** | Alto rendimiento, retención basada en logs, reproducción |
| **SqsEventBus** | Nativo de AWS, cola simple |

## Errores Comunes

1. **Cadenas de conexión hardcodeadas**: credenciales en código en lugar de configuración/variables de entorno
2. **Sin dead letter queue**: los mensajes fallidos se pierden o bloquean al consumidor
3. **Sin reintento de conexión**: el consumidor falla ante indisponibilidad temporal del broker
4. **Procesamiento en el hilo del publicador**: bloquear la solicitud HTTP con llamadas al broker de mensajería
5. **Falta de confirmación de mensajes**: los consumidores que fallan dejan mensajes en el limbo
6. **Una cola para todos los eventos**: no se pueden escalar suscriptores de forma independiente
7. **Sin monitoreo**: sin visibilidad sobre la profundidad de cola, tasa de procesamiento, errores
