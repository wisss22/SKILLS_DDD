# Repositories (Puertos)

Un Repository es un **puerto** (interfaz) definido en la capa de Dominio que proporciona la ilusión de una colección en memoria de aggregates. Abstrae los detalles de persistencia del dominio.

## Reglas Fundamentales

### 1. Repository por Aggregate Root

Una interfaz Repository por aggregate root. Nunca crees repositories para entities hijas.

```pseudocode
// CORRECTO: Repository para el aggregate root
interface CourseRepository:
    method save(course: Course): void
    method findById(id: CourseId): Course?
    method searchByCriteria(criteria: Criteria): Courses

// INCORRECTO: Repository para una entity hija
interface LessonRepository:    // ← NO debería existir
    method save(lesson: Lesson): void
// Las Lessons se acceden a través de Course, no directamente
```

### 2. Definido en Dominio, Implementado en Infraestructura

La interfaz vive en `domain/`, la implementación en `infrastructure/persistence/`.

```pseudocode
// domain/CourseRepository (PUERTO - sin dependencias externas)
interface CourseRepository:
    method save(course: Course): void
    method findById(id: CourseId): Course?

// infrastructure/persistence/PostgresCourseRepository (ADAPTADOR)
class PostgresCourseRepository implements CourseRepository:
    method save(course: Course): void
        // Convertir objeto de dominio a fila de BD, ejecutar SQL
        primitives = course.toPrimitives()
        db.execute("INSERT INTO courses ...", primitives)

    method findById(id: CourseId): Course?
        row = db.query("SELECT * FROM courses WHERE id = ?", id.value())
        return Course.fromPrimitives(row) if row else null
```

### 3. Trabaja con Objetos de Dominio, No con Objetos de Base de Datos

```pseudocode
// CORRECTO: Devuelve objeto de dominio
interface CourseRepository:
    method findById(id: CourseId): Course?

// INCORRECTO: Devuelve fila de base de datos o entidad ORM
interface CourseRepository:
    method findById(id: CourseId): DatabaseRow?    // ← Fuga de infraestructura
    method findById(id: CourseId): DoctrineEntity?  // ← Fuga de framework
```

### 4. Métodos Comunes de Repository

```pseudocode
interface CourseRepository:
    // Escritura
    method save(course: Course): void
    method delete(courseId: CourseId): void

    // Lectura por identidad
    method findById(id: CourseId): Course?

    // Lectura por criterio (búsqueda flexible)
    method searchByCriteria(criteria: Criteria): CourseCollection

    // Leer todo (usar con moderación — puede ser costoso)
    method all(): CourseCollection
```

### 5. Los Métodos de Consulta Deben Usar el Patrón Criteria

En lugar de crear métodos específicos para cada consulta, usa un patrón Criteria/Specification:

```pseudocode
// MAL: Explosión de métodos
interface CourseRepository:
    method findByName(name: string): Course?
    method findByStatus(status: string): Courses
    method findByDurationGreaterThan(duration: int): Courses
    method findByNameAndStatus(name: string, status: string): Courses
    // ... 50 métodos más

// BIEN: Un solo método flexible
interface CourseRepository:
    method matching(criteria: Criteria): Courses
```

### 6. Save, No Update

Los repositories deben tener `save()`, no métodos separados `create()` e `update()`. El adaptador de persistencia determina si hacer INSERT o UPDATE.

```pseudocode
// CORRECTO
interface CourseRepository:
    method save(course: Course): void

// INCORRECTO (fuga de preocupaciones de persistencia al dominio)
interface CourseRepository:
    method insert(course: Course): void   // ← ¿Cómo sabe el dominio que es nuevo?
    method update(course: Course): void   // ← ¿Cómo sabe el dominio que existe?
```

## Repository en el Flujo

```pseudocode
// El CommandHandler usa el puerto repository
class CreateCourseCommandHandler:
    property repository: CourseRepository  // ← INTERFAZ, no implementación

    method invoke(command):
        course = Course.create(command.id, command.name, command.duration)
        this.repository.save(course)       // ← El dominio no sabe dónde se guarda
```

## Errores Comunes

1. **Repository por entity**: `LessonRepository`, `OrderItemRepository`
2. **Detalles de persistencia en el dominio**: Tipos de retorno como `DatabaseRow`, entidades ORM
3. **Explosión de métodos**: 50+ métodos finder en lugar de usar Criteria
4. **Falta de save**: Repo con solo métodos `find` (anémico)
5. **Métodos de consulta que devuelven primitivos**: `findNames(): string[]` en lugar de devolver objetos de dominio
6. **Repository en la capa de aplicación**: Los puertos van en Dominio, no en Aplicación
