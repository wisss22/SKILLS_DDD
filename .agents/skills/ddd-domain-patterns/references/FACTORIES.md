# Factories

Una Factory encapsula la **lógica de creación** de objetos de dominio complejos. Cuando crear un objeto requiere múltiples pasos, reglas o dependencias, una Factory mantiene esa complejidad fuera del constructor de la entity y fuera de los application services.

## Cuándo Usar una Factory

Usa una Factory cuando:
- La creación del objeto tiene reglas de negocio que deben aplicarse
- Crear el objeto requiere ensamblar múltiples objetos relacionados
- El proceso de creación es lo suficientemente complejo como para justificar su propia clase
- Necesitas múltiples vías de creación con reglas diferentes

NO uses una Factory cuando:
- La creación es una simple llamada al constructor → Usa un método factory estático en la entity
- La única lógica es asignación de campos → El constructor de la entity es suficiente

## Método Factory Estático (Casos Simples)

Para creación simple con validación básica, coloca un método estático en la propia entity:

```pseudocode
class Course:
    private constructor(id, name, duration):
        self.id = id
        self.name = name
        self.duration = duration

    // Método factory estático — simple y suficiente
    static create(id: CourseId, name: CourseName, duration: CourseDuration): Course
        return new Course(id, name, duration)
```

## Clase Factory Dedicada (Casos Complejos)

Cuando la creación es compleja, extrae una factory dedicada:

```pseudocode
class CourseFactory:
    method createFromTemplate(template: CourseTemplate, instructor: Instructor): Course
        // Regla de negocio: Validar plantilla
        ensure template.isActive()
        ensure instructor.canCreateCourses()

        // Ensamblar el curso
        course = new Course(
            CourseId.generate(),
            template.name(),
            template.defaultDuration()
        )

        // Agregar secciones de la plantilla como contenido inicial
        for section in template.sections():
            course.addSection(
                Section.create(section.title(), section.defaultContent())
            )

        course.record(new CourseCreatedFromTemplate(course.id, template.id))
        return course

    method createImported(rawData: map, importedBy: User): Course
        // Reglas de creación diferentes para importaciones
        ensure importedBy.hasImportPermission()

        course = new Course(
            CourseId.fromValue(rawData.externalId),
            CourseName.fromValue(rawData.title),
            CourseDuration.fromValue(rawData.durationHours)
        )

        course.record(new CourseImported(course.id, rawData.externalId, importedBy.id))
        return course
```

## Factory vs Builder

| Criterio | Factory | Builder |
|---|---|---|
| Creación | Un paso: `factory.create(...)` | Múltiples pasos: `builder.withX().withY().build()` |
| Validación | Todo de una vez | Puede validar al momento de construir |
| Cuándo usar | El grafo del objeto tiene estructura fija | El objeto tiene muchos componentes opcionales |

## Factory en la Capa de Dominio

Las Factories viven en la capa de Dominio. Trabajan solo con objetos de dominio. NO deben:
- Llamar a repositories (eso es responsabilidad del Application Service)
- Acceder a infraestructura
- Generar IDs que requieran llamadas externas (usa un puerto UuidGenerator si es necesario)

```pseudocode
// CORRECTO: Factory de dominio con un puerto para generación de ID
class CourseFactory:
    property uuidGenerator: UuidGenerator  // ← PUERTO (interfaz), no infraestructura

    method create(name: CourseName, duration: CourseDuration): Course
        id = CourseId.fromValue(self.uuidGenerator.generate())
        return new Course(id, name, duration)

// El UuidGenerator es un puerto en Dominio.
// La implementación real (UUID v4, ULID, etc.) está en Infraestructura.
```

## Errores Comunes

1. **Factory como utilidad estática**: Sobrecargada con demasiados métodos de creación
2. **Factory llamando a repositories**: Las factories crean objetos, no los persisten
3. **Factory anémica**: Factory que solo llama a `new` — usa un método factory estático en la entity en su lugar
4. **Validación ausente**: Factory que no aplica reglas de creación
5. **Factory en la capa de Aplicación**: La lógica de creación del dominio debe permanecer en Dominio
