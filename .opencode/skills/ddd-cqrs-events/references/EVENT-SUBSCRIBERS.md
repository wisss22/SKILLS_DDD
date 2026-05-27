# Domain Event Subscribers

Un DomainEventSubscriber **reacciona** a un domain event. Es el "pegamento" que permite la comunicación entre aggregates y bounded contexts sin acoplarlos directamente.

## Reglas Fundamentales

### 1. Los Suscriptores Declaran Qué Escuchan

```pseudocode
interface DomainEventSubscriber:
    method subscribedTo(): array  // List of event class names
    method invoke(event: DomainEvent): void

// Concrete subscriber
class IncrementCoursesCounterOnCourseCreated implements DomainEventSubscriber:
    property repository: CoursesCounterRepository

    method subscribedTo(): array
        return [CourseCreated]

    method invoke(event: CourseCreated): void
        counter = self.repository.find() ?? CoursesCounter.initialize()
        counter.increment()
        self.repository.save(counter)
```

### 2. Los Suscriptores Residen en la Capa Application

```
src/[BoundedContext]/[Module]/Application/[UseCase]/
    ├── Create/
    │   └── CreateCourseCommandHandler.php     ← Handles commands
    ├── Increment/
    │   └── IncrementCoursesCounterOnCourseCreated.php  ← Subscriber
    └── Find/
        └── FindCourseQueryHandler.php          ← Handles queries
```

### 3. Mantén los Suscriptores Idempotentes

Los eventos pueden entregarse más de una vez (entrega at-least-once). Los suscriptores deben manejar eventos duplicados con elegancia:

```pseudocode
class SendWelcomeEmailOnUserRegistered implements DomainEventSubscriber:
    method invoke(event: UserRegistered): void
        // Idempotency check: has this event already been processed?
        if self.alreadyProcessed(event.eventId):
            return  // Skip duplicate

        // Process the event
        self.emailService.sendWelcomeEmail(event.email)

        // Mark as processed
        self.markAsProcessed(event.eventId)
```

### 4. Comunicación entre Bounded Contexts

Los suscriptores son el mecanismo PRINCIPAL para la comunicación entre bounded contexts:

```
Bounded Context: Mooc                Bounded Context: Backoffice
┌─────────────────────────┐          ┌─────────────────────────────┐
│ Course Aggregate        │          │ BackofficeCourse Subscriber  │
│ ─────────────────       │          │ ───────────────────────────  │
│ course.publish()        │          │ subscribedTo: [CourseCreated]│
│   └→ CourseCreated event│──EventBus──→│ invoke(event)              │
│                         │          │   └→ Create backoffice course │
└─────────────────────────┘          └─────────────────────────────┘
```

```pseudocode
// In Mooc context: Course emits CourseCreated
// In Backoffice context: Subscriber creates a BackofficeCourse
class CreateBackofficeCourseOnCourseCreated implements DomainEventSubscriber:
    method subscribedTo(): array
        return [CourseCreated]

    method invoke(event: CourseCreated):
        backofficeCourse = BackofficeCourse.create(
            BackofficeCourseId.fromValue(event.aggregateId),
            BackofficeCourseName.fromValue(event.name),
            BackofficeCourseDuration.fromValue(event.duration)
        )
        self.repository.save(backofficeCourse)
```

### 5. El Suscriptor Puede Despachar Sus Propios Commands

Para efectos secundarios complejos, un suscriptor puede despachar un command en lugar de hacer el trabajo él mismo:

```pseudocode
class OnCourseCreated implements DomainEventSubscriber:
    property commandBus: CommandBus

    method subscribedTo():
        return [CourseCreated]

    method invoke(event: CourseCreated):
        // Delegate to a command for more complex orchestration
        command = CreateBackofficeCourseCommand(
            id: event.aggregateId,
            name: event.name,
            duration: event.duration
        )
        self.commandBus.dispatch(command)
```

### 6. Registro de Suscriptores

Los suscriptores se registran en el EventBus al iniciar la aplicación:

```pseudocode
// During DI/application bootstrap:
eventBus.register(
    subscriber: IncrementCoursesCounterOnCourseCreated(),
    eventType: CourseCreated
)
eventBus.register(
    subscriber: CreateBackofficeCourseOnCourseCreated(),
    eventType: CourseCreated
)
eventBus.register(
    subscriber: SendWelcomeEmailOnUserRegistered(),
    eventType: UserRegistered
)
```

## Subscriber vs Saga (Process Manager)

| Criterion | Subscriber | Saga / Process Manager |
|---|---|---|
| Complexity | Single event → Single action | Multiple events → Multi-step workflow |
| State | Stateless | Stateful (tracks process state) |
| Example | "On CourseCreated, increment counter" | "On OrderPlaced → ReserveInventory → On PaymentReceived → ShipOrder" |

## Errores Comunes

1. **No idempotente**: Entrega duplicada de eventos causa efectos secundarios duplicados
2. **Suscriptor haciendo demasiado**: Lógica compleja de múltiples pasos en un suscriptor (usa una saga)
3. **Suscriptor llamando a otros suscriptores directamente**: Siempre pasa por el EventBus
4. **Falta de manejo de errores**: Fallos en el suscriptor detienen todo el procesamiento de eventos
5. **Demasiados suscriptores para un evento**: Si más de 10 suscriptores reaccionan al mismo evento, considera si es posible agruparlos
6. **Suscriptor modificando el aggregate fuente**: Los suscriptores no deben modificar el aggregate que emitió el evento
