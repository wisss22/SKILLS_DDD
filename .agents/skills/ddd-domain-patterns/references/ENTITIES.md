# Entities

Los Entities son objetos de dominio con una **identidad única** que persiste en el tiempo. Un entity es el mismo entity incluso si sus atributos cambian — la identidad es el hilo de continuidad.

## Cuándo Modelar como un Entity

Usa un Entity cuando:
- El concepto tiene un ciclo de vida (creado → modificado → archivado/eliminado)
- La identidad importa: "¿Es este EL MISMO pedido?" no "¿Tiene esto los mismos datos?"
- El objeto puede cambiar con el tiempo sin dejar de ser lo mismo
- Necesitas rastrear cambios en esta instancia específica

## Reglas Fundamentales

### 1. Identidad por ID, No por Atributos

```pseudocode
// Los entities se comparan por ID, no por todos los atributos
class Order:
    property id: OrderId
    property items: Collection
    property status: OrderStatus

    method equals(other: Order): bool
        return self.id == other.id  // SOLO ID

// Incluso si dos pedidos tienen exactamente los mismos items y estado,
// son pedidos DIFERENTES si tienen IDs diferentes.
```

### 2. Constructor Privado + Métodos Factory con Nombre

No expongas `new Entity(...)` directamente. Usa métodos estáticos que expresen la intención del dominio.

```pseudocode
class Course:
    private constructor(id, name, duration):
        self.id = id
        self.name = name
        self.duration = duration
        self.status = CourseStatus.DRAFT

    // Factory con nombre: expresa QUÉ está sucediendo
    static create(id, name, duration): Course
        ensure name is not empty
        ensure duration > 0
        course = new Course(id, name, duration)
        course.record(new CourseCreated(course.id, course.name, course.duration))
        return course

    // Otro factory para diferentes escenarios de creación
    static fromImport(id, name, duration, importedAt): Course
        course = new Course(id, name, duration)
        course.record(new CourseImported(course.id, importedAt))
        return course
```

### 3. Métodos de Comportamiento, No Setters

```pseudocode
// MAL: Anémico - expone estado interno
course.setName("New Name")       // No hagas esto
course.setStatus("PUBLISHED")    // No hagas esto

// BIEN: Comportamiento rico - expresa intención de negocio
course.rename("New Name")        // Puede registrar evento CourseRenamed
course.publish()                 // Puede validar reglas, registrar evento CoursePublished
course.archive()                 // Puede verificar si ya está archivado, registrar evento CourseArchived
```

### 4. Protege los Invariantes

Cada método de comportamiento debe validar que la operación es válida:

```pseudocode
method publish():
    ensure self.status == CourseStatus.DRAFT
        else throw CourseAlreadyPublishedError
    ensure self.hasAtLeastOneLesson()
        else throw CourseCannotBePublishedWithoutLessons
    self.status = CourseStatus.PUBLISHED
    self.publishedAt = now()
    self.record(new CoursePublished(self.id, self.publishedAt))
```

## Entities vs Value Objects

| Criterio | Entity | Value Object |
|---|---|---|
| ¿Tiene identidad única? | Sí | No |
| Igualdad | Por ID | Por todos los atributos |
| Mutabilidad | Mutable (dentro de TX) | Inmutable |
| ¿Se puede compartir/reemplazar? | No (único) | Sí (libremente compartible) |
| ¿Repository? | Parte del aggregate | Ninguno |

## Errores Comunes

1. **Entities anémicos**: Entities con solo getters/setters y sin métodos de comportamiento
2. **Constructor público**: Exponer `new Entity()` evade las reglas de creación
3. **Demasiados atributos en el entity**: Extrae atributos relacionados en Value Objects
4. **Identidad como primitivo**: Siempre envuelve el ID en un tipo Value Object dedicado (`CourseId`, no `string`)
5. **Equals del entity comparando todos los atributos**: Compara solo por ID
