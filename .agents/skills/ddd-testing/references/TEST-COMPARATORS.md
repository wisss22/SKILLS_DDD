# Comparadores de Test

Los comparadores de test personalizados resuelven el problema de **comparar objetos de dominio complejos** en aserciones de test. Las comprobaciones de igualdad por defecto a menudo fallan porque los aggregates incluyen IDs generados, timestamps y listas de eventos que hacen que las comparaciones simples no sean fiables.

## El Problema

```pseudocode
// This FAILS even if the course is logically the same:
course = CourseMother.random()
repository.save(course)
found = repository.findById(course.id)

assert found == course  // FALSE!
// Why? course has recorded events (CourseCreated) with generated IDs.
// The found course has no pending events.
// The event IDs and timestamps differ.
```

## Solución: Comparadores Personalizados

En lugar de verificar igualdad completa, compara solo los **campos relevantes para el negocio**:

```pseudocode
class AggregateRootSimilarComparator:
    method equals(actual, expected): bool
        if actual.id != expected.id:
            return false
        if actual.name != expected.name:
            return false
        if actual.duration != expected.duration:
            return false
        if actual.status != expected.status:
            return false
        // Skip: events list, timestamps, generated IDs
        return true
```

## Tipos de Comparadores

### Comparador de Aggregate Root

Ignora: Domain Events registrados, IDs de eventos, timestamps de eventos.
Compara: identidad, todos los atributos de negocio, entidades/colecciones hijas.

```pseudocode
class CourseSimilarComparator:
    method matches(actual: Course, expected: Course): bool
        // Business identity
        if actual.id.value() != expected.id.value():
            return false

        // Business attributes
        if actual.name.value() != expected.name.value():
            return false
        if actual.duration.value() != expected.duration.value():
            return false
        if actual.status.value() != expected.status.value():
            return false

        return true
```

### Comparador de Domain Events

Ignora: ID del evento, timestamp occurredOn (o permite comparación difusa).
Compara: tipo de evento, ID del aggregate, atributos del cuerpo del evento.

```pseudocode
class DomainEventSimilarComparator:
    method matches(actual: DomainEvent, expected: DomainEvent): bool
        // Same event type
        if actual.eventName() != expected.eventName():
            return false

        // Same aggregate
        if actual.aggregateId() != expected.aggregateId():
            return false

        // Same business data (but skip generated IDs/timestamps)
        actualBody = actual.toPrimitives()
        expectedBody = expected.toPrimitives()

        // Remove generated fields before comparing
        delete actualBody.id
        delete actualBody.occurredOn
        delete expectedBody.id
        delete expectedBody.occurredOn

        return actualBody == expectedBody
```

### Comparador de DateTime (Difuso)

Ignora: diferencias de milisegundos.
Compara: fecha/hora dentro de una ventana de tolerancia.

```pseudocode
class DateTimeSimilarComparator:
    property toleranceMs: int = 1000  // 1 second tolerance

    method matches(actual: DateTime, expected: DateTime): bool
        diff = abs(actual.timestamp - expected.timestamp)
        return diff <= self.toleranceMs
```

## Uso en Aserciones de Test

```pseudocode
// Using them in tests:

// Built-in assertion with comparator
test "it saves a course correctly":
    course = CourseMother.random()
    repository.save(course)
    found = repository.findById(course.id)
    assert found is similarTo(course)  // Uses AggregateRootSimilarComparator

// Mock verification with comparator
test "repository save is called with the correct course":
    handler.invoke(command)
    verify(repository).save(similarTo(expectedCourse))
```

## Implementar una Aserción "SimilarTo" Genérica

```pseudocode
class IsSimilarAssertion:
    property comparators: map[string, Comparator]

    method assertSimilar(expected, actual):
        comparator = self.findComparator(typeOf(expected))
        if comparator is null:
            // Fall back to regular equality
            assert expected == actual
        else:
            assert comparator.matches(actual, expected)
            else fail("Objects are not similar: " + comparator.describeDifference())

    method findComparator(type): Comparator?
        return self.comparators[type] ?? null

// Register comparators at test bootstrap:
isSimilar = new IsSimilarAssertion()
isSimilar.register(Course, new CourseSimilarComparator())
isSimilar.register(CourseCreated, new DomainEventSimilarComparator())
isSimilar.register(DateTime, new DateTimeSimilarComparator())
```

## Cuándo Usar Comparadores vs Igualdad Normal

| Escenario | Usar |
|---|---|
| Comparar dos aggregates del mismo tipo | Comparator (ignorar eventos, timestamps) |
| Comparar Value Objects | Igualdad normal (sin campos generados) |
| Comparar DTOs de Command/Query | Igualdad normal (datos simples) |
| Verificar llamadas a mock con aggregates | Comparator (los mocks necesitan lógica de matching) |
| Comparar Domain Events | Comparator (ignorar event ID, timestamp) |

## Errores Comunes

1. **Sin comparadores**: Usar `==` para aggregates (los tests siempre fallan o dan falsos negativos)
2. **Sobre-comparación**: Comparator que verifica cada campo incluyendo la lista de eventos
3. **Sub-comparación**: Comparator que solo verifica el ID (pasa por alto cambios de atributos)
4. **Comparar primitivos manualmente**: `assert course.name.value() == "x"` Y `assert course.duration.value() == 120` Y ... (usa un comparator en su lugar)
5. **No usar comparadores en verificación de mocks**: `verify(repo).save(any())` en lugar de `verify(repo).save(similarTo(course))`
