# Patrón Decorator

El **patrón Decorator** adjunta responsabilidades adicionales a un objeto dinámicamente envolviéndolo en otro objeto que implementa la misma interfaz. En la arquitectura DDD + Hexagonal, los decoradores se usan para **preocupaciones transversales** sin modificar la lógica de negocio principal.

## ¿Por Qué Decoradores?

Sin decoradores, las preocupaciones transversales se filtran en el código de negocio:

```pseudocode
// BAD: Cache logic mixed with repository logic
class PostgresCourseRepository:
    method findById(id):
        // CACHE concern
        cached = cache.get("course:" + id)
        if cached: return cached

        // BUSINESS concern
        course = db.query("SELECT ...")

        // CACHE concern
        cache.set("course:" + id, course)

        // MONITORING concern
        metrics.increment("course.find_by_id")

        return course
    // ← Violates Single Responsibility!
```

Con decoradores, cada preocupación es una clase separada:

```pseudocode
// Each class has ONE job
class PostgresCourseRepository:     // Persistence only
class CachedCourseRepository:       // Caching only
class MonitoredCourseRepository:    // Monitoring only
```

## Estructura Principal

Todos los decoradores implementan la MISMA interfaz del puerto:

```pseudocode
interface CourseRepository:
    method findById(id: CourseId): Course?
    method save(course: Course): void

// Real adapter
class PostgresCourseRepository implements CourseRepository: ...

// Decorator 1: Caching
class CachedCourseRepository implements CourseRepository:
    property wrapped: CourseRepository
    property cache: Cache

    method findById(id): Course?
        cached = self.cache.get("course:" + id.value())
        if cached:
            return cached
        course = self.wrapped.findById(id)
        if course:
            self.cache.set("course:" + id.value(), course, ttl: 300)
        return course

    method save(course): void
        self.wrapped.save(course)
        self.cache.invalidate("course:" + course.id.value())

// Decorator 2: Monitoring
class MonitoredCourseRepository implements CourseRepository:
    property wrapped: CourseRepository
    property monitor: Monitor

    method findById(id): Course?
        start = now()
        result = self.wrapped.findById(id)
        duration = now() - start
        self.monitor.recordExecution("course_repository.findById", duration)
        return result

    method save(course): void
        start = now()
        self.wrapped.save(course)
        duration = now() - start
        self.monitor.recordExecution("course_repository.save", duration)
```

## Composición (Orden de Envolvimiento)

Los decoradores se componen en el momento de la inyección de dependencias. El orden importa:

```pseudocode
// DI wiring — outer to inner:
repository = new MonitoredCourseRepository(
    new CachedCourseRepository(
        new PostgresCourseRepository(connection),
        cache
    ),
    monitor
)

// At runtime, findById flows:
// Monitored → Cached → Postgres → Database
```

## Casos de Uso Comunes de Decoradores

### 1. Decorador de Caché

```pseudocode
class CachedRepository implements [Entity]Repository:
    property wrapped: [Entity]Repository
    property cache: Cache

    method findById(id):
        key = self.cacheKey(id)
        cached = self.cache.get(key)
        if cached:
            return cached
        result = self.wrapped.findById(id)
        if result:
            self.cache.set(key, result, ttl: self.cacheTtl())
        return result

    method save(aggregate):
        self.wrapped.save(aggregate)
        self.cache.delete(self.cacheKey(aggregate.id))

    method cacheKey(id): string
        return "[entity]:" + id.value()
```

### 2. Decorador de Logging

```pseudocode
class LoggingEventBus implements EventBus:
    property wrapped: EventBus
    property logger: Logger

    method publish(events): void
        self.logger.info("Publishing " + events.length + " events")
        try:
            self.wrapped.publish(events)
            self.logger.info("Events published successfully")
        catch error:
            self.logger.error("Failed to publish events: " + error.message)
            throw error
```

### 3. Decorador de Reintentos

```pseudocode
class RetryEventBus implements EventBus:
    property wrapped: EventBus
    property maxRetries: int = 3

    method publish(events): void
        retries = 0
        while true:
            try:
                self.wrapped.publish(events)
                return
            catch TemporaryError:
                retries += 1
                if retries >= self.maxRetries:
                    throw error
                sleep(retries * 100)  // Exponential backoff
```

### 4. Decorador de Monitoreo

```pseudocode
class MonitoredEventBus implements EventBus:
    property wrapped: EventBus
    property monitor: Monitor

    method publish(events): void
        self.monitor.increment("event_bus.publish.count", events.length)
        start = now()
        self.wrapped.publish(events)
        duration = now() - start
        self.monitor.recordDuration("event_bus.publish.duration", duration)
```

## Cuándo Usar Decorator vs Herencia

| Decorator | Herencia |
|---|---|
| Añade comportamiento en tiempo de ejecución | Comportamiento fijo en tiempo de compilación |
| Combina múltiples comportamientos | Cadena de un solo padre |
| Respeta el principio abierto/cerrado | Modifica la jerarquía de clases |
| Más clases, acoplamiento suelto | Menos clases, acoplamiento más estrecho |

## Errores Comunes

1. **Decorador obeso**: decorador que hace demasiado (debe ser una preocupación por decorador)
2. **Decoradores dependientes del orden**: el decorador A debe envolver a B — frágil, evita esto
3. **Fuga de estado interno**: decorador que depende del estado interno del objeto envuelto
4. **Delegación faltante**: decorador que no llama al método envuelto
5. **Demasiadas capas de decoradores**: 5+ decoradores anidados (difícil de depurar)
6. **Decorar la interfaz equivocada**: decorar la implementación en lugar de la interfaz del puerto
