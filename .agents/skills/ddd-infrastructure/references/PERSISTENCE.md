# Adaptadores de Persistencia

Los adaptadores de persistencia **implementan** el puerto Repository (interfaz) de la capa de Dominio. Manejan todas las preocupaciones específicas de la base de datos: gestión de conexiones, mapeo ORM, traducción de consultas y conversión de tipos.

## Reglas Fundamentales

### 1. El Adaptador Implementa el Puerto de Dominio

```pseudocode
// Domain port (interface — NO infrastructure deps)
interface CourseRepository:
    method save(course: Course): void
    method findById(id: CourseId): Course?
    method matching(criteria: Criteria): Courses
    method delete(id: CourseId): void

// Infrastructure adapter (implements the port)
class PostgresCourseRepository implements CourseRepository:
    property connection: DatabaseConnection

    constructor(connection):
        self.connection = connection

    method save(course: Course): void
        primitives = self.toPersistence(course)
        self.connection.upsert("courses", primitives)

    method findById(id: CourseId): Course?
        row = self.connection.query(
            "SELECT * FROM courses WHERE id = ?", id.value()
        )
        return self.toDomain(row) if row else null
```

### 2. Mapeo: Dominio ↔ Persistencia

El adaptador es dueño de la lógica de mapeo. El objeto de dominio NO debe conocer las columnas de la base de datos.

```pseudocode
class PostgresCourseRepository:
    // Domain → Database row
    method toPersistence(course: Course): map
        return {
            id: course.id.value(),
            name: course.name.value(),
            duration: course.duration.value(),
            status: course.status.value(),
            created_at: course.createdAt.format(),
            updated_at: course.updatedAt.format()
        }

    // Database row → Domain
    method toDomain(row: map): Course
        return new Course(
            CourseId.fromValue(row.id),
            CourseName.fromValue(row.name),
            CourseDuration.fromValue(row.duration)
        )
        // Note: status and timestamps are set from persisted data
        course.setPersistedState(
            CourseStatus.fromValue(row.status),
            DateTime.parse(row.created_at),
            DateTime.parse(row.updated_at)
        )
```

### 3. Mapeo de Tipos Personalizados

Para Value Objects, define convertidores de tipo personalizados:

```pseudocode
class CourseIdType:
    // Converts between CourseId (domain) and string (database)
    method convertToDatabaseValue(value: CourseId): string
        return value.value()

    method convertToDomainValue(dbValue: string): CourseId
        return new CourseId(dbValue)
```

### 4. Traducción de Criteria a Consulta

El adaptador convierte el objeto Criteria de dominio en consultas específicas de la base de datos:

```pseudocode
class PostgresCourseRepository:
    method matching(criteria: Criteria): Courses
        query = "SELECT * FROM courses"
        params = []

        if not criteria.filters.isEmpty():
            whereClauses = []
            for filter in criteria.filters.all():
                column = self.fieldMapping[filter.field.value()]
                whereClauses.append(
                    column + " " + filter.operator.value() + " ?"
                )
                params.append(filter.value.value())
            query += " WHERE " + whereClauses.join(" AND ")

        if criteria.hasOrder():
            orderCol = criteria.order.orderBy.value()
            orderDir = criteria.order.orderType.value()
            query += " ORDER BY " + orderCol + " " + orderDir

        if criteria.hasPagination():
            query += " LIMIT ? OFFSET ?"
            params.append(criteria.limit)
            params.append(criteria.offset)

        rows = self.connection.query(query, params)
        return new Courses(rows.map(r => self.toDomain(r)))
```

### 5. Múltiples Adaptadores para el Mismo Puerto

Diferentes implementaciones para diferentes casos de uso, intercambiables mediante DI:

```pseudocode
// Write side: relational database
class PostgresCourseRepository implements CourseRepository: ...

// Read side: search engine
class ElasticsearchCourseRepository implements BackofficeCourseRepository: ...

// Caching decorator
class CachedCourseRepository implements CourseRepository:
    property wrapped: CourseRepository
    property cache: Cache

    method findById(id): Course?
        cached = self.cache.get("course:" + id.value())
        if cached:
            return cached
        course = self.wrapped.findById(id)
        self.cache.set("course:" + id.value(), course, ttl: 300)
        return course
```

### 6. Clase Base de Repository Compartida

Extrae la lógica común en una clase base:

```pseudocode
abstract class BaseRepository:
    property connection: DatabaseConnection

    abstract method tableName(): string
    abstract method toDomain(row: map): AggregateRoot
    abstract method toPersistence(aggregate): map

    method save(aggregate): void
        primitives = self.toPersistence(aggregate)
        self.connection.upsert(self.tableName(), primitives)

    method findById(id): AggregateRoot?
        row = self.connection.query(
            "SELECT * FROM " + self.tableName() + " WHERE id = ?",
            id.value()
        )
        return self.toDomain(row) if row else null

    method delete(id): void
        self.connection.execute(
            "DELETE FROM " + self.tableName() + " WHERE id = ?",
            id.value()
        )
```

## Patrones de Adaptadores de Repository

| Patrón | Descripción | Ejemplo |
|---|---|---|
| **Adaptador ORM** | Usa un ORM para el mapeo | Doctrine, Hibernate, Entity Framework |
| **Adaptador SQL** | Consultas SQL escritas a mano | SQL crudo, query builder |
| **Adaptador de Documentos** | Base de datos documental | MongoDB, DynamoDB |
| **Adaptador de Búsqueda** | Motor de búsqueda para lecturas | Elasticsearch, Algolia |
| **Adaptador InMemory** | Almacenamiento en memoria para pruebas | Repositorio basado en HashMap |
| **Adaptador Cacheado** | Decorador que envuelve otro repositorio | Capa de caché Redis/Memcached |

## Errores Comunes

1. **Objetos de dominio que conocen la base de datos**: anotaciones ORM en entidades de dominio
2. **Adaptador en la capa equivocada**: `PostgresCourseRepository` en `domain/`
3. **Sin capa de mapeo**: devolver filas de base de datos directamente en lugar de objetos de dominio
4. **Fuga de DSL de consultas**: pasar objetos de consulta ORM a través del límite del puerto
5. **Persistencia incorrecta para el caso de uso**: usar ORM completo para una lectura simple clave-valor
6. **Sin clase base**: duplicar la lógica de save/find/delete en 10+ repositorios
