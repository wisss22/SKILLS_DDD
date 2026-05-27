# Domain Events

Un Domain Event es un **registro inmutable** de algo que **sucedió** en el dominio. Captura el resultado de un cambio de estado en un aggregate, permitiendo que otras partes del sistema reaccionen.

## Cuándo Emitir un Domain Event

Emite un Domain Event cuando:
- Ocurre un cambio de estado de negocio significativo (curso creado, pedido realizado, pago recibido)
- Otros aggregates o bounded contexts necesitan reaccionar
- Necesitas un registro de auditoría de lo que sucedió

NO emitas eventos para:
- Cada cambio de propiedad (demasiado granular)
- Eventos puramente técnicos (base de datos guardada, caché calentada)
- Eventos sin subscribers

## Reglas Fundamentales

### 1. Nomenclatura en Tiempo Pasado

Siempre nombra los eventos en tiempo pasado. Describen algo que YA sucedió.

| MAL | BIEN |
|---|---|
| `CreateCourse` | `CourseCreated` |
| `UpdateUserName` | `UserNameChanged` |
| `ProcessPayment` | `PaymentReceived` |
| `ShipOrder` | `OrderShipped` |

### 2. Inmutable

Los eventos no pueden modificarse después de su creación. Son registros históricos.

```pseudocode
class CourseCreated:
    property eventId: Uuid
    property aggregateId: CourseId
    property occurredOn: DateTime
    property name: CourseName
    property duration: CourseDuration

    // Todas las propiedades se establecen en el constructor. SIN setters.
    constructor(aggregateId, name, duration, eventId = null, occurredOn = null):
        self.eventId = eventId ?? Uuid.generate()
        self.aggregateId = aggregateId
        self.occurredOn = occurredOn ?? DateTime.now()
        self.name = name
        self.duration = duration
```

### 3. Llevan Qué Sucedió, No Cómo Reaccionar

Los eventos deben contener los datos que describen QUÉ sucedió. Los subscribers deciden CÓMO reaccionar.

```pseudocode
// BIEN: Contiene datos sobre el evento
class CourseCreated:
    property aggregateId: string     // Qué curso
    property name: string            // Cómo se nombró
    property duration: int           // Cuánto dura

// MAL: Contiene instrucciones para los subscribers
class CourseCreated:
    property aggregateId: string
    property shouldIndexInSearch: bool     // ← Preocupación del consumidor, no dato del evento
    property sendWelcomeEmail: bool        // ← Preocupación del consumidor, no dato del evento
```

### 4. Nombre de Evento Único

Cada tipo de evento debe tener un nombre único para el enrutamiento:

```pseudocode
class CourseCreated:
    static eventName(): string
        return "mooc.course.created"  // Convención: contexto.aggregate.verbo
```

### 5. Registrar en el Aggregate, Publicar en el Handler

```pseudocode
// PASO 1: Registrar el evento EN el aggregate
class Course:
    method publish():
        self.status = CourseStatus.PUBLISHED
        self.record(new CoursePublished(self.id, now()))

// PASO 2: Publicar DESPUÉS de la persistencia en el handler
class PublishCourseCommandHandler:
    method invoke(command):
        course = this.repository.findById(command.id)
        course.publish()
        this.repository.save(course)
        // Publicar DESPUÉS de guardar exitosamente
        this.eventBus.publish(course.pullEvents())
```

### 6. Serialización

Los eventos necesitan `toPrimitives()` y `fromPrimitives()` para almacenamiento y transmisión:

```pseudocode
class CourseCreated:
    method toPrimitives(): map
        return {
            id: self.eventId.value(),
            aggregateId: self.aggregateId.value(),
            occurredOn: self.occurredOn.format(),
            name: self.name.value()
        }

    static fromPrimitives(aggregateId, body, eventId, occurredOn): CourseCreated
        return new CourseCreated(
            aggregateId: CourseId.fromValue(aggregateId),
            name: CourseName.fromValue(body.name),
            eventId: Uuid.fromValue(eventId),
            occurredOn: DateTime.parse(occurredOn)
        )
```

## El Flujo de Eventos

```
1. El aggregate registra el evento durante una operación de negocio
2. El aggregate retorna al CommandHandler
3. El handler persiste el aggregate (y opcionalmente el evento al outbox, misma TX)
4. El handler publica eventos a través del EventBus
5. El EventBus entrega el evento a todos los subscribers
6. Cada subscriber reacciona independientemente
```

## Errores Comunes

1. **Eventos sin subscribers**: Emitir eventos que nadie escucha
2. **Demasiados datos**: Incluir el estado completo del aggregate en el evento
3. **Muy pocos datos**: No incluir suficientes datos para que los subscribers actúen
4. **Nomenclatura tipo comando**: `CreateCourse` en lugar de `CourseCreated`
5. **Mutación de eventos**: Modificar un evento después de su creación
6. **Publicar antes de persistir**: Si el guardado falla, el evento ya fue publicado
7. **Sin ID de evento**: La falta de identificador único de evento imposibilita la deduplicación
