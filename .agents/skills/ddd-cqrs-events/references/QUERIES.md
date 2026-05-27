# Queries + QueryHandlers

Las Queries representan una **solicitud de datos** sin efectos secundarios. Se despachan a través de un QueryBus hacia un QueryHandler que obtiene y devuelve los datos solicitados.

## Reglas Fundamentales

### 1. Las Queries son DTOs Nombrados como Preguntas

| MAL | BIEN |
|---|---|
| `CourseDataRequest` | `FindCourseQuery` |
| `GetCourses` | `SearchAllCoursesQuery` |
| `UserSearch` | `SearchUsersByCriteriaQuery` |

### 2. Las Queries Siempre Devuelven Datos

```pseudocode
// A Query returns a Response DTO (never void)
class FindCourseQuery:
    property courseId: string
    constructor(courseId):
        self.courseId = courseId

class FindCourseQueryHandler:
    method invoke(query: FindCourseQuery): CourseResponse  // ← Returns data
        course = self.repository.findById(
            CourseId.fromValue(query.courseId)
        )
        if course is null:
            throw CourseNotFoundError
        return CourseResponse.fromAggregate(course)
```

### 3. Los QueryHandlers Pueden Acceder a Read Models Directamente

A diferencia de los CommandHandlers que pasan por el dominio, los QueryHandlers pueden omitir el modelo de dominio para consultas optimizadas para lectura:

```pseudocode
class SearchCoursesQueryHandler:
    property readRepository: CourseReadRepository  // Optimized for reads

    method invoke(query: SearchCoursesQuery): CoursesResponse
        // Can query a read-optimized model (Elasticsearch, materialized view, etc.)
        criteria = Criteria.fromQuery(query)
        results = self.readRepository.search(criteria)
        return CoursesResponse.fromResults(results)
```

### 4. Response DTOs

Las Queries devuelven Response DTOs, no objetos de dominio:

```pseudocode
class CourseResponse:
    property id: string
    property name: string
    property status: string
    property duration: int
    property totalSteps: int

    static fromAggregate(course: Course): CourseResponse
        return new CourseResponse(
            id: course.id.value(),
            name: course.name.value(),
            status: course.status.value(),
            duration: course.duration.value(),
            totalSteps: course.steps().count()  // ← Calculated from aggregate
        )

class CoursesResponse:
    property courses: array
    property total: int

    static fromResults(courses: Collection, total: int): CoursesResponse
        return new CoursesResponse(
            courses: courses.map(c => CourseResponse.fromAggregate(c)),
            total: total
        )
```

### 5. Interfaz QueryBus

```pseudocode
interface QueryBus:
    method ask(query: Query): Response  // ← Returns data

// Infrastructure adapter
class InMemoryQueryBus implements QueryBus:
    property handlers: map[QueryType, QueryHandler]

    method register(queryType, handler):
        self.handlers[queryType] = handler

    method ask(query): Response
        handler = self.handlers[typeOf(query)]
        if handler is null:
            throw QueryNotRegisteredError
        return handler.invoke(query)
```

## Resumen Query vs Command

| Criterion | Command | Query |
|---|---|---|
| Purpose | Change state | Read state |
| Naming | `Create`, `Update`, `Delete` | `Find`, `Search`, `Get` |
| Returns | void | Response DTO |
| Side effects? | Yes | No (idempotent) |
| Through domain? | Yes | Optional (can use read models) |

## Errores Comunes

1. **Queries con efectos secundarios**: Una Query que modifica datos — usa un Command
2. **Commands que devuelven datos**: Un CommandHandler que devuelve un Response — divide en Command + Query
3. **Objetos de dominio en respuestas**: Exponer entities directamente (acopla la API al dominio)
4. **QueryHandlers modificando estado**: Los QueryHandlers deben ser de solo lectura
5. **Demasiadas queries específicas**: Más de 50 tipos de query — considera el patrón Criteria para búsqueda flexible
6. **Queries saltándose el bus**: Controladores llamando a QueryHandlers directamente
