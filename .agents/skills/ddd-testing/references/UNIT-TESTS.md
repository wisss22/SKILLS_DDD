# Tests Unitarios

Los tests unitarios verifican el comportamiento de una **única clase** (objeto de dominio, servicio de aplicación o handler) de forma aislada. Las dependencias se reemplazan con dobles de test (mocks, stubs).

## Qué Testear Unitaria-mente

| Test | Por qué |
|---|---|
| Domain Entities / VOs | Reglas de negocio, invariantes, métodos de comportamiento |
| Value Objects | Validación, igualdad, inmutabilidad |
| Domain Services | Lógica de negocio que involucra múltiples entidades |
| CommandHandlers | Orquestación de casos de uso (con puertos mockeados) |
| QueryHandlers | Lógica de obtención de datos (con repositorios de lectura mockeados) |
| DomainEventSubscribers | Lógica de reacción (con puertos mockeados) |

## Patrón de Test Case Base

Crea un test case base específico del módulo que proporcione dependencias mockeadas:

```pseudocode
// Base class for all unit tests in the Courses module
class CoursesModuleUnitTestCase:
    // Mocked ports — all dependencies of handlers/subscribers
    property repository: Mock<CourseRepository>
    property eventBus: Mock<EventBus>
    property queryBus: Mock<QueryBus>

    method setUp():
        // Create mocks for ALL ports used in this module
        self.repository = mock(CourseRepository)
        self.eventBus = mock(EventBus)
        self.queryBus = mock(QueryBus)

    // Helper: Assert an entity was saved
    method assertSaveWasCalled(aggregate):
        verify(self.repository).save(similarTo(aggregate))

    // Helper: Assert an event was published
    method assertEventWasPublished(event):
        verify(self.eventBus).publish(containsSimilar(event))
```

## Testear un CommandHandler

```pseudocode
class CreateCourseCommandHandlerTest extends CoursesModuleUnitTestCase:
    property handler: CreateCourseCommandHandler

    method setUp():
        super.setUp()
        // Inject mocked ports into the handler
        self.handler = new CreateCourseCommandHandler(
            self.repository,
            self.eventBus
        )

    method testItCreatesAValidCourse():
        // Given
        command = CreateCourseCommandMother.create(
            id: "course-uuid",
            name: "DDD in Practice",
            duration: 120
        )

        // When
        self.handler.invoke(command)

        // Then — assert on outputs, not implementation details
        self.assertSaveWasCalled()
        self.assertEventWasPublished(CourseCreated)

    method testItRejectsEmptyName():
        // Given
        command = CreateCourseCommandMother.create(name: "")

        // When + Then
        expect(() => self.handler.invoke(command)).toThrow(InvalidCourseNameError)

        // Assert nothing was saved
        verify(self.repository, never()).save(any())
```

## Testear una Domain Entity

```pseudocode
class CourseTest:
    method testItStartsInDraftStatus():
        course = CourseMother.random()
        assert course.status() == CourseStatus.DRAFT

    method testItCanBePublished():
        course = CourseMother.random()
        course.publish()
        assert course.status() == CourseStatus.PUBLISHED

    method testItCannotBePublishedTwice():
        course = CourseMother.published()
        expect(() => course.publish()).toThrow(CourseAlreadyPublishedError)

    method testItRecordsEventWhenPublished():
        course = CourseMother.random()
        course.publish()
        events = course.pullEvents()
        assert events.length == 1
        assert events[0] instanceof CoursePublished
```

## Testear un DomainEventSubscriber

```pseudocode
class IncrementCoursesCounterOnCourseCreatedTest extends CoursesModuleUnitTestCase:
    property subscriber: IncrementCoursesCounterOnCourseCreated
    property counterRepository: Mock<CoursesCounterRepository>

    method setUp():
        super.setUp()
        self.counterRepository = mock(CoursesCounterRepository)
        self.subscriber = new IncrementCoursesCounterOnCourseCreated(
            self.counterRepository
        )

    method testItIncrementsCounter():
        // Given: counter exists
        currentCounter = CoursesCounterMother.create(total: 5)
        when(self.counterRepository.find()).thenReturn(currentCounter)
        event = CourseCreatedDomainEventMother.random()

        // When
        self.subscriber.invoke(event)

        // Then
        verify(self.counterRepository).save(aggregateMatch(
            counter => counter.total.value() == 6
        ))

    method testItCreatesCounterIfNotExists():
        // Given: no counter exists
        when(self.counterRepository.find()).thenReturn(null)
        event = CourseCreatedDomainEventMother.random()

        // When
        self.subscriber.invoke(event)

        // Then: counter initialized with 1
        verify(self.counterRepository).save(aggregateMatch(
            counter => counter.total.value() == 1
        ))
```

## Matchers / Comparadores Personalizados

Los objetos de dominio a menudo incluyen IDs y timestamps generados. Usa comparadores personalizados que los ignoren:

```pseudocode
class AggregateRootSimilarComparator:
    // Compares two aggregates ignoring: event ID, timestamps
    method equals(actual, expected): bool
        // Compare identity
        if actual.id != expected.id: return false
        // Compare business fields (skip event ID, occurredOn)
        if actual.name != expected.name: return false
        if actual.duration != expected.duration: return false
        return true
```

## Errores Comunes

1. **Testear detalles de implementación**: Hacer asserts sobre llamadas a métodos privados o estado interno
2. **Mockear objetos de dominio**: Los objetos de dominio deben ser reales en los tests (rápidos, sin I/O)
3. **Sin test case base**: Duplicar la configuración de mocks en 20 archivos de test
4. **Sobre-mockeo**: Mockear Value Objects o DTOs simples
5. **Testear el mock**: `verify(mock).method()` sin asserts reales sobre el comportamiento
6. **Hacer asserts sobre valores generados**: `assert course.id == "expected-uuid"` cuando se usa Mother.random()
