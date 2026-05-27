# Convenciones de Nomenclatura DDD

Todas las convenciones de nombres en este proyecto se basan en el **nombre del modulo** y el **nombre del agregado**. Esta seccion documenta los patrones exactos para cada tipo de artefacto.

## Regla de Oro

> Todo se nombra a partir del **nombre del agregado**. El agregado toma el nombre del modulo (singularizado si el modulo es plural).

```
src/<BC>/<Module>/Domain/
         ↑               ← Nombre del modulo: Courses, Videos, CoursesCounter, Auth
         ↓
src/Mooc/Courses/Domain/Course.php
                      ↑   ← Nombre del agregado: Course (singular del modulo)
```

## Tabla Resumen de Convenciones

| Artefacto | Convencion | Ejemplo |
|---|---|---|
| **Modulo** | `PascalCase`, concepto del dominio | `Courses`, `Videos`, `CoursesCounter` |
| **Agregado** | `PascalCase`, singular del modulo | `Course`, `Video`, `CoursesCounter` |
| **Value Object** | `<Aggregate><Attribute>` | `CourseId`, `CourseName`, `CourseDuration` |
| **Domain Event** | `<Aggregate><VerboPasado>DomainEvent` | `CourseCreatedDomainEvent` |
| **Domain Error** | `<Aggregate><CondicionError>` | `CourseNotExist` |
| **Repository (interfaz)** | `<Aggregate>Repository` | `CourseRepository` |
| **Repository (impl)** | `<Technology><Aggregate>Repository` | `DoctrineCourseRepository` |
| **Application Service** | `<Aggregate><Verbo~dor>` | `CourseCreator`, `CourseFinder`, `CourseRenamer` |
| **Command** | `<VerboImperativo><Aggregate>Command` | `CreateCourseCommand` |
| **CommandHandler** | `<VerboImperativo><Aggregate>CommandHandler` | `CreateCourseCommandHandler` |
| **Query** | `<VerboPregunta><Aggregate>Query` | `FindCoursesCounterQuery` |
| **QueryHandler** | `<VerboPregunta><Aggregate>QueryHandler` | `FindCoursesCounterQueryHandler` |
| **Query Response** | `<Aggregate>Response` o `<Aggregate>sResponse` | `CoursesCounterResponse` |
| **Controller** | `<Modulo><Accion>Controller` | `CoursesPutController`, `CoursesCounterGetController` |
| **Archivo de rutas** | `<modulo_en_snake_case>.yaml` | `courses.yaml`, `courses_counter.yaml` |

---

## Modulo

**Convencion:** `PascalCase`, nombre del concepto del dominio.

```
src/Mooc/
├── Courses/           ← plural (varios cursos)
├── Videos/            ← plural (varios videos)
├── CoursesCounter/    ← singular compuesto (un contador)
└── ...

src/Backoffice/
├── Courses/           ← plural
├── Auth/              ← singular (autenticacion como concepto)
└── ...
```

**Reglas:**
- Si el modulo representa una coleccion de entidades → plural (`Courses`, `Videos`)
- Si el modulo representa un concepto unico → singular compuesto (`CoursesCounter`, `Auth`)
- El nombre del modulo determina el nombre del agregado

---

## Agregado (Aggregate Root)

**Convencion:** `PascalCase`, singular del nombre del modulo.

```
// src/Mooc/Courses/Domain/Course.php
// Modulo: Courses → Agregado: Course

// src/Mooc/CoursesCounter/Domain/CoursesCounter.php
// Modulo: CoursesCounter → Agregado: CoursesCounter (ya es singular compuesto)

// src/Backoffice/Courses/Domain/BackofficeCourse.php
// Modulo: Courses en Backoffice → Agregado: BackofficeCourse (prefijo para evitar colision con Mooc/Course)
```

**Regla especial: Prefijo de BC para evitar colisiones**

Cuando el mismo concepto existe en 2+ Bounded Contexts, el agregado del BC "secundario" se prefija con el nombre del BC:

| BC | Modulo | Agregado | Por que |
|---|---|---|---|
| Mooc | Courses | `Course` | BC principal, sin prefijo |
| Backoffice | Courses | `BackofficeCourse` | Evita colision con Mooc/Course |

**Anti-patron:**

```php
// ❌ MAL: Ambos BCs usan el mismo nombre → colision de clases
// src/Mooc/Courses/Domain/Course.php
class Course { }
// src/Backoffice/Courses/Domain/Course.php
class Course { }  // ← Fatal error: Cannot redeclare class

// ✅ BIEN: Prefijo de BC para desambiguar
// src/Backoffice/Courses/Domain/BackofficeCourse.php
class BackofficeCourse { }
```

---

## Value Object

**Convencion:** `<AggregateName><Attribute>`

```php
// src/Mooc/Courses/Domain/CourseId.php
final class CourseId extends Uuid {}

// src/Mooc/Courses/Domain/CourseName.php
final class CourseName extends StringValueObject {}

// src/Mooc/Courses/Domain/CourseDuration.php
final class CourseDuration extends IntValueObject {}

// src/Mooc/CoursesCounter/Domain/CoursesCounterId.php
final class CoursesCounterId extends Uuid {}

// src/Mooc/CoursesCounter/Domain/CoursesCounterTotal.php
final class CoursesCounterTotal extends IntValueObject {}
```

**Reglas:**
- Siempre prefijar con el nombre del agregado
- No usar nombres genericos como `Id`, `Name`, `Duration` sueltos
- Si el VO es compartido entre modulos del mismo BC, va en `src/<BC>/Shared/Domain/<Module>/<VO>.php`

---

## Domain Event

**Convencion:** `<AggregateName><VerboEnPasado>DomainEvent`

```php
// src/Mooc/Courses/Domain/CourseCreatedDomainEvent.php
final class CourseCreatedDomainEvent extends DomainEvent {}

// src/Mooc/CoursesCounter/Domain/CoursesCounterIncrementedDomainEvent.php
final class CoursesCounterIncrementedDomainEvent extends DomainEvent {}
```

**Reglas:**
- El verbo SIEMPRE va en pasado (`Created`, `Renamed`, `Incremented`, `Deleted`)
- El sufijo `DomainEvent` es obligatorio
- El nombre completo del evento debe ser unico en el monorepo (se usa como identificador en serializacion)

---

## Domain Error

**Convencion:** `<AggregateName><Condicion>`

```php
// src/Mooc/Courses/Domain/CourseNotExist.php
final class CourseNotExist extends DomainError {}

// src/Mooc/CoursesCounter/Domain/CoursesCounterNotExist.php
final class CoursesCounterNotExist extends DomainError {}
```

**Reglas:**
- Describir la condicion de error, no la accion
- `CourseNotExist` (no existe), no `CourseNotFound` (eso es HTTP)
- Extender de `DomainError` (en Shared Domain)

---

## Repository (Interfaz / Puerto)

**Convencion:** `<AggregateName>Repository`

```php
// src/Mooc/Courses/Domain/CourseRepository.php
interface CourseRepository {
    public function save(Course $course): void;
    public function findById(CourseId $id): ?Course;
}
```

**Reglas:**
- Una interfaz por aggregate root, nunca por entity
- Vive en la capa Domain
- Define contratos, no implementaciones

---

## Repository (Implementacion / Adaptador)

**Convencion:** `<Technology><AggregateName>Repository`

```php
// src/Mooc/Courses/Infrastructure/Persistence/DoctrineCourseRepository.php
final class DoctrineCourseRepository extends DoctrineRepository implements CourseRepository {}

// src/Backoffice/Courses/Infrastructure/Persistence/ElasticsearchBackofficeCourseRepository.php
final class ElasticsearchBackofficeCourseRepository extends ElasticsearchRepository implements BackofficeCourseRepository {}
```

**Reglas:**
- Prefijo indica la tecnologia (`Doctrine`, `Elasticsearch`, `MySql`, `InMemory`)
- Implementa la interfaz del Domain
- Vive en `Infrastructure/Persistence/`

---

## Application Service (Caso de Uso / Orquestador)

**Convencion:** `<AggregateName><Verbo~dor>`

```php
// src/Mooc/Courses/Application/Create/CourseCreator.php
final readonly class CourseCreator {
    public function __invoke(CourseId $id, CourseName $name, CourseDuration $duration): void {
        $course = Course::create($id, $name, $duration);
        $this->repository->save($course);
        $this->bus->publish(...$course->pullDomainEvents());
    }
}

// src/Mooc/Courses/Application/Find/CourseFinder.php
final readonly class CourseFinder {
    public function __invoke(CourseId $id): CourseResponse { ... }
}

// src/Mooc/Courses/Application/Update/CourseRenamer.php
final readonly class CourseRenamer {
    public function __invoke(CourseId $id, CourseName $newName): void { ... }
}
```

**Reglas:**
- El sufijo es el "agente" que realiza la accion (`Creator`, `Finder`, `Renamer`, `Deleter`, `Searcher`)
- Para busquedas complejas: `<Aggregate>sByCriteriaSearcher` (ej: `BackofficeCoursesByCriteriaSearcher`)
- El Application Service es el **orquestador real** (crea aggregates, llama repositorios, publica eventos)
- El CommandHandler delega en el Application Service

---

## Command

**Convencion:** `<VerboImperativo><AggregateName>Command`

```php
// src/Mooc/Courses/Application/Create/CreateCourseCommand.php
final readonly class CreateCourseCommand implements Command {
    public function __construct(
        private string $id,
        private string $name,
        private string $duration
    ) {}
}
```

**Reglas:**
- Verbo en imperativo (`Create`, `Update`, `Delete`, `Rename`, `Increment`)
- El agregado va en singular (`CreateCourse`, no `CreateCourses`)
- Es un DTO puro: solo datos, sin comportamiento
- Implementa la interfaz `Command` (marker interface en Shared Domain)

---

## CommandHandler

**Convencion:** `<VerboImperativo><AggregateName>CommandHandler`

```php
// src/Mooc/Courses/Application/Create/CreateCourseCommandHandler.php
final readonly class CreateCourseCommandHandler implements CommandHandler {
    public function __construct(private CourseCreator $creator) {}

    public function __invoke(CreateCourseCommand $command): void {
        $id       = new CourseId($command->id());
        $name     = new CourseName($command->name());
        $duration = new CourseDuration($command->duration());

        $this->creator->__invoke($id, $name, $duration);
    }
}
```

**Reglas:**
- Mismo nombre que el Command + sufijo `Handler`
- Es un **traductor delgado**: convierte primitivas del DTO en Value Objects del dominio
- Delega en el Application Service (no orquesta directamente)
- Implementa la interfaz `CommandHandler` (marker interface en Shared Domain)

---

## Query

**Convencion:** `<VerboPregunta><AggregateName>Query`

```php
// src/Mooc/CoursesCounter/Application/Find/FindCoursesCounterQuery.php
final class FindCoursesCounterQuery implements Query {}

// src/Backoffice/Courses/Application/SearchByCriteria/SearchBackofficeCoursesByCriteriaQuery.php
final class SearchBackofficeCoursesByCriteriaQuery implements Query {
    public function __construct(
        private array $filters,
        private string $orderBy,
        private string $order,
        private ?int $limit,
        private ?int $offset
    ) {}
}
```

**Reglas:**
- Verbo de consulta (`Find`, `Search`, `Get`, `List`)
- El agregado va en singular o plural segun el contexto
- Es un DTO puro: solo datos de filtro/parametros
- Implementa la interfaz `Query` (marker interface en Shared Domain)

---

## QueryHandler

**Convencion:** `<VerboPregunta><AggregateName>QueryHandler`

```php
// src/Mooc/CoursesCounter/Application/Find/FindCoursesCounterQueryHandler.php
final readonly class FindCoursesCounterQueryHandler implements QueryHandler {
    public function __construct(private CoursesCounterFinder $finder) {}

    public function __invoke(FindCoursesCounterQuery $query): CoursesCounterResponse {
        return $this->finder->__invoke();
    }
}
```

**Reglas:**
- Mismo nombre que la Query + sufijo `Handler`
- Delega en el Application Service (Finder, Searcher, etc.)
- Retorna un Response DTO (nunca void, nunca un objeto de dominio)
- Implementa la interfaz `QueryHandler` (marker interface en Shared Domain)

---

## Query Response

**Convencion:** `<AggregateName>Response` o `<AggregateName>sResponse`

```php
// src/Mooc/CoursesCounter/Application/Find/CoursesCounterResponse.php
final readonly class CoursesCounterResponse implements Response {
    public function __construct(private int $total) {}
    public function total(): int { return $this->total; }
}

// src/Backoffice/Courses/Application/BackofficeCourseResponse.php
final readonly class BackofficeCourseResponse implements Response { ... }

// src/Backoffice/Courses/Application/BackofficeCoursesResponse.php
final readonly class BackofficeCoursesResponse implements Response { ... }
```

**Reglas:**
- Singular para una entidad (`CourseResponse`)
- Plural para una coleccion (`CoursesResponse`)
- Implementa la interfaz `Response` (marker interface en Shared Domain)
- NUNCA exponer objetos de dominio directamente en la respuesta

---

## Controller

**Convencion:** `<Modulo><Accion>Controller`

```php
// apps/mooc/backend/src/Controller/Courses/CoursesPutController.php
final class CoursesPutController extends ApiController {
    public function __invoke(Request $request, string $id): Response { ... }
}

// apps/mooc/backend/src/Controller/CoursesCounter/CoursesCounterGetController.php
final class CoursesCounterGetController extends ApiController {
    public function __invoke(Request $request): Response { ... }
}
```

**Reglas:**
- El nombre refleja el modulo (puede ser plural como en `CoursesPutController`)
- La accion indica el metodo HTTP o la operacion (`Put`, `Get`, `Post`, `Delete`)
- Agrupados por modulo en carpetas: `src/Controller/<Modulo>/`
- Son **delgados**: parsean entrada, crean Command/Query, despachan al bus, formatean respuesta

---

## Archivos de Rutas

**Convencion:** `<modulo_en_snake_case>.yaml`

```yaml
# config/routes/courses.yaml
courses_put:
    path: /courses/{id}
    controller: CoursesPutController
    methods: PUT

courses_get:
    path: /courses
    controller: CoursesGetController
    methods: GET
```

**Reglas:**
- Un archivo por modulo funcional
- Nombre en `snake_case`, coincidiendo con el modulo
- Las rutas NUNCA van como anotaciones en los controllers
- Nombres de ruta: `{modulo}_{accion}` en `snake_case`

---

## Anti-Patrones de Nomenclatura

| Anti-Patron | Por que es malo | Correcto |
|---|---|---|
| `CourseCreationRequest` | "Request" es termino HTTP, no de dominio | `CreateCourseCommand` |
| `CourseData` | No indica si es VO, DTO o entity | `CourseName` (VO), `CourseResponse` (DTO) |
| `HandleCourse` | "Handle" es generico, no describe la accion | `CreateCourseCommand` |
| `CourseService` | "Service" es ambiguo (domain service? app service?) | `CourseCreator` (app service), `CoursePricingService` (domain service) |
| `ICourseRepository` | Prefijo "I" de interfaz es estilo C#, no PHP | `CourseRepository` |
| `CourseRepo` | Abreviacion pierde claridad | `CourseRepository` |
| `GetCourseCommand` | "Get" es lectura, no escritura | `FindCourseQuery` (para lectura) |
| `CreateCourseQuery` | "Create" es escritura, no lectura | `CreateCourseCommand` (para escritura) |
