# Patrón Object Mother

El patrón **Object Mother** crea objetos de datos de prueba con **valores predeterminados sensatos**, de modo que los tests solo especifiquen los valores que les importan. Esto elimina código de setup repetitivo y hace que los tests sean legibles.

## ¿Por qué Object Mother?

```pseudocode
// MAL: Sin Object Mother — verboso, repetitivo, difícil de mantener
test "it creates a course":
    course = new Course(
        CourseId.fromValue("a1b2c3d4-..."),
        CourseName.fromValue("Test Course"),
        CourseDuration.fromValue(120),
        CourseStatus.DRAFT,
        DateTime.now(),
        DateTime.now()
    )
    repository.save(course)
    // ... actual test

// BIEN: Con Object Mother — conciso, revela la intención
test "it creates a course":
    course = CourseMother.random()
    repository.save(course)
    // ... actual test
```

## Estructura

Las Mothers forman una jerarquía:

```
MotherCreator          ← Generador central de valores aleatorios (Faker)
    └── Primitive Mothers  ← UuidMother, WordMother, IntegerMother
        └── Value Object Mothers  ← CourseIdMother, CourseNameMother
            └── Entity Mothers     ← CourseMother
                └── Event Mothers  ← CourseCreatedDomainEventMother
```

### MotherCreator (Generador Aleatorio Central)

```pseudocode
class MotherCreator:
    static faker: DataFaker

    static method random(): DataFaker
        if self.faker is null:
            self.faker = DataFaker.create()
        return self.faker
```

### Mothers de Valores Primitivos

```pseudocode
class UuidMother:
    static method create(value: string = null): string
        return value ?? MotherCreator.random().uuid()

class WordMother:
    static method create(value: string = null): string
        return value ?? MotherCreator.random().word()

class IntegerMother:
    static method create(value: int = null): int
        return value ?? MotherCreator.random().numberBetween(0, 10000)

class DateTimeMother:
    static method create(value: DateTime = null): DateTime
        return value ?? DateTime.now()

    static method past(): DateTime
        daysAgo = MotherCreator.random().numberBetween(1, 365)
        return DateTime.now().subtractDays(daysAgo)
```

### Mothers de Value Objects

```pseudocode
class CourseIdMother:
    static method create(value: string = null): CourseId
        return new CourseId(UuidMother.create(value))

class CourseNameMother:
    static method create(value: string = null): CourseName
        return new CourseName(
            value ?? MotherCreator.random().sentence(3)
        )

class CourseDurationMother:
    static method create(value: int = null): CourseDuration
        return new CourseDuration(
            value ?? MotherCreator.random().numberBetween(1, 300)
        )
```

### Mother de Entity / Aggregate

```pseudocode
class CourseMother:
    // Default factory: random but valid entity
    static method create(
        id: CourseId = null,
        name: CourseName = null,
        duration: CourseDuration = null
    ): Course
        return Course.create(
            id: id ?? CourseIdMother.create(),
            name: name ?? CourseNameMother.create(),
            duration: duration ?? CourseDurationMother.create()
        )

    // Named variant factories for common scenarios
    static method random(): Course
        return CourseMother.create()

    static method withName(name: string): Course
        return CourseMother.create(
            name: CourseNameMother.create(name)
        )

    static method withDuration(duration: int): Course
        return CourseMother.create(
            duration: CourseDurationMother.create(duration)
        )

    static method archived(): Course
        course = CourseMother.random()
        course.archive()
        return course

    static method published(): Course
        course = CourseMother.random()
        course.publish()
        return course
```

### Mothers de Command / Query

```pseudocode
class CreateCourseCommandMother:
    static method create(
        id: string = null,
        name: string = null,
        duration: int = null
    ): CreateCourseCommand
        return new CreateCourseCommand(
            id: id ?? UuidMother.create(),
            name: name ?? WordMother.create(),
            duration: duration ?? IntegerMother.create()
        )

    static method random(): CreateCourseCommand
        return CreateCourseCommandMother.create()
```

### Mothers de Domain Events

```pseudocode
class CourseCreatedDomainEventMother:
    static method fromCourse(course: Course): CourseCreatedDomainEvent
        return new CourseCreatedDomainEvent(
            aggregateId: course.id.value(),
            name: course.name.value(),
            duration: course.duration.value()
        )

    static method create(
        aggregateId: string = null,
        name: string = null,
        duration: int = null
    ): CourseCreatedDomainEvent
        return new CourseCreatedDomainEvent(
            aggregateId: aggregateId ?? UuidMother.create(),
            name: name ?? WordMother.create(),
            duration: duration ?? IntegerMother.create()
        )

    static method random(): CourseCreatedDomainEvent
        return CourseCreatedDomainEventMother.create()
```

## Patrones de Uso en Tests

### Patrón 1: Sobrescribir solo lo que importa

```pseudocode
test "it rejects an empty course name":
    command = CreateCourseCommandMother.create(name: "")
    expect(() => handler.invoke(command)).toThrow(InvalidCourseNameError)
```

### Patrón 2: Datos aleatorios para campos irrelevantes

```pseudocode
test "it saves the course":
    command = CreateCourseCommandMother.random()  // All fields random
    handler.invoke(command)
    // Assert only that it was saved
    repository.assertSaveWasCalled()
```

### Patrón 3: Variante con nombre para un estado específico

```pseudocode
test "it prevents publishing an already published course":
    course = CourseMother.published()
    expect(() => course.publish()).toThrow(CourseAlreadyPublishedError)
```

## Organización de Archivos

```
tests/[BoundedContext]/[Module]/Domain/
    ├── CourseMother.php
    ├── CourseIdMother.php
    ├── CourseNameMother.php
    ├── CourseDurationMother.php
    └── CourseCreatedDomainEventMother.php

tests/[BoundedContext]/[Module]/Application/[UseCase]/
    ├── CreateCourseCommandMother.php
    └── CreateCourseCommandHandlerTest.php
```

## Errores Comunes

1. **Sin valores predeterminados**: Cada test debe pasar todos los parámetros — una "Mother" que requiere todos los campos
2. **Hacer asserts sobre valores predeterminados**: `assert course.name == "random word"` — no hagas asserts sobre valores generados
3. **Muy pocos métodos variante**: Solo `random()` pero los tests necesitan `.archived()`, `.withName()`, etc.
4. **Mother llamando infraestructura**: Mothers que crean conexiones a base de datos
5. **Mother haciendo demasiado**: Mother con 15 parámetros y lógica de creación compleja
6. **Datos aleatorios inconsistentes**: Cada mother usando su propio generador aleatorio en lugar de MotherCreator
