# Tests de Integración

Los tests de integración verifican que los **adaptadores de infraestructura** funcionen correctamente con sistemas externos reales (bases de datos, brokers de mensajería). Prueban la frontera entre tu aplicación y el mundo exterior.

## Qué Testear con Integración

| Test | Sistema Externo |
|---|---|
| Implementaciones de Repository | Base de datos (MySQL, Postgres, MongoDB) |
| Repositorios de modelo de lectura | Elasticsearch, vistas materializadas |
| Implementaciones de EventBus | RabbitMQ, Kafka, outbox de base de datos |
| Consumidores CDC / Outbox | Pipeline Base de datos → Broker |

NO hagas tests de integración de:
- Lógica de dominio (usa tests unitarios en su lugar)
- Controladores HTTP (usa tests BDD/aceptación en su lugar)
- Funciones puras (usa tests unitarios en su lugar)

## Test Case Base de Infraestructura

```pseudocode
class CoursesModuleInfrastructureTestCase:
    // Real infrastructure, not mocks
    property repository: CourseRepository        // ← REAL implementation
    property databaseCleaner: DatabaseCleaner    // For test isolation

    method setUp():
        // Bootstrap real database connection
        self.repository = new PostgresCourseRepository(
            connection: TestDatabaseConnection.get()
        )
        self.databaseCleaner = new DatabaseCleaner(
            connection: TestDatabaseConnection.get()
        )
        // Clean database before each test
        self.databaseCleaner.truncate("courses")

    method tearDown():
        self.databaseCleaner.truncate("courses")
```

## Testear una Implementación de Repository

```pseudocode
class CourseRepositoryTest extends CoursesModuleInfrastructureTestCase:
    method testItSavesACourse():
        // Given
        course = CourseMother.random()

        // When
        self.repository.save(course)

        // Then — retrieve and compare
        found = self.repository.findById(course.id)
        assert found is not null
        assert found.id == course.id
        assert found.name == course.name
        assert found.duration == course.duration

    method testItReturnsNullWhenNotFound():
        nonExistentId = CourseIdMother.create()
        result = self.repository.findById(nonExistentId)
        assert result is null

    method testItSearchesByCriteria():
        // Given: multiple courses in the database
        draftCourse = CourseMother.random()
        publishedCourse = CourseMother.published()
        self.repository.save(draftCourse)
        self.repository.save(publishedCourse)

        // When: search for published courses
        criteria = new Criteria(
            filters: Filters.fromValues([
                { field: "status", operator: "=", value: "published" }
            ])
        )

        // Then
        results = self.repository.matching(criteria)
        assert results.length == 1
        assert results[0].id == publishedCourse.id

    method testItUpdatesAnExistingCourse():
        // Given
        course = CourseMother.random()
        self.repository.save(course)

        // When
        course.rename("Updated Name")
        self.repository.save(course)

        // Then
        found = self.repository.findById(course.id)
        assert found.name.value() == "Updated Name"
```

## Testear un EventBus con Broker Real

```pseudocode
class RabbitMqEventBusTest extends InfrastructureTestCase:
    property eventBus: RabbitMqEventBus
    property consumer: TestEventConsumer

    method setUp():
        connection = new RabbitMqConnection(testConfig)
        self.eventBus = new RabbitMqEventBus(connection)
        self.consumer = new TestEventConsumer(connection)
        // Ensure test queue is empty
        self.consumer.purgeQueue()

    method testItPublishesAndConsumesAnEvent():
        // Given
        event = CourseCreatedDomainEventMother.random()

        // When
        self.eventBus.publish([event])

        // Then — wait for the event to arrive
        received = self.consumer.waitForEvent(timeout: 5_seconds)
        assert received is not null
        assert received.eventName() == event.eventName()
        assert received.aggregateId() == event.aggregateId()
```

## Aislamiento de Base de Datos para Tests

```pseudocode
class DatabaseCleaner:
    property connection: DatabaseConnection

    method truncate(tables: string[]): void
        // Disable foreign key checks temporarily
        self.connection.execute("SET FOREIGN_KEY_CHECKS = 0")
        for table in tables:
            self.connection.execute("TRUNCATE TABLE " + table)
        self.connection.execute("SET FOREIGN_KEY_CHECKS = 1")

    method truncateAll(): void
        self.truncate(["courses", "courses_counter", "steps", "domain_events"])
```

## Errores Comunes

1. **Testear dos capas a la vez**: Test de integración que también verifica lógica de negocio (debería ser test unitario)
2. **Sin limpieza entre tests**: Tests que dependen de datos de tests anteriores
3. **Base de datos de producción en tests**: Usar la BD de producción en lugar de una base de datos de test
4. **Demasiados tests de integración**: Tests de integración para cada método del repositorio (suite de tests lenta)
5. **No probar casos límite**: Solo probar el happy path contra infraestructura real
6. **Datos de prueba hardcodeados**: Usar IDs fijos en lugar de Mothers (colisiones entre tests)
