# Application Services: La Capa de Orquestacion CQRS

En la arquitectura CQRS del proyecto Codely, existe una **separacion de responsabilidades en 3 capas** entre el punto de entrada y el dominio. Esta separacion es clave para mantener el codigo limpio, testeable y reutilizable.

## El Flujo de 3 Capas

### Para Commands (Escritura)

```
┌─────────────────────────────────────────────────────────────────┐
│  Controller (apps/<bc>/backend/src/Controller/)                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ 1. Parsea entrada HTTP (JSON body, path params)           │  │
│  │ 2. Crea Command DTO (datos primitivos: strings, ints)     │  │
│  │ 3. Despacha al CommandBus                                 │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                   │
│                              ▼                                   │
│  CommandBus (Shared/Infrastructure/Bus/Command/)                │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ 1. Resuelve el Handler por tipo de Command                │  │
│  │ 2. Invoca el Handler                                      │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                   │
│                              ▼                                   │
│  CommandHandler (src/<BC>/<Module>/Application/<Verb>/)         │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ 1. Recibe Command DTO (primitivos: string, int)           │  │
│  │ 2. TRADUCE primitivos → Value Objects del dominio         │  │
│  │ 3. DELEGA al Application Service                          │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                   │
│                              ▼                                   │
│  Application Service (src/<BC>/<Module>/Application/<Verb>/)    │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ 1. Crea/modifica el Aggregate (llama a metodo de dominio) │  │
│  │ 2. Persiste via Repository (puerto)                       │  │
│  │ 3. Publica Domain Events via EventBus (puerto)            │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                   │
│                              ▼                                   │
│  Domain (src/<BC>/<Module>/Domain/)                             │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ Aggregate::create(), aggregate.doSomething()              │  │
│  │ Registra Domain Events internamente                       │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Para Queries (Lectura)

```
┌─────────────────────────────────────────────────────────────────┐
│  Controller (apps/<bc>/backend/src/Controller/)                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ 1. Parsea entrada HTTP (query params, path params)        │  │
│  │ 2. Crea Query DTO (parametros de filtro)                  │  │
│  │ 3. Pregunta al QueryBus                                   │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                   │
│                              ▼                                   │
│  QueryBus (Shared/Infrastructure/Bus/Query/)                    │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ 1. Resuelve el Handler por tipo de Query                  │  │
│  │ 2. Invoca el Handler                                      │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                   │
│                              ▼                                   │
│  QueryHandler (src/<BC>/<Module>/Application/<Verb>/)           │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ 1. Recibe Query DTO                                       │  │
│  │ 2. DELEGA al Application Service (Finder, Searcher)       │  │
│  │ 3. Retorna Response DTO                                   │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                   │
│                              ▼                                   │
│  Application Service (src/<BC>/<Module>/Application/<Verb>/)    │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ 1. Consulta via Repository (puerto)                       │  │
│  │ 2. Valida resultados (ej: throw si no existe)             │  │
│  │ 3. Construye y retorna Response DTO                       │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Ejemplo Real: Command Completo

### Capa 1: Command DTO

```php
// src/Mooc/Courses/Application/Create/CreateCourseCommand.php
// Responsabilidad: llevar datos primitivos desde el controller al handler
// Es un DTO: solo datos, sin comportamiento, sin validacion
final readonly class CreateCourseCommand implements Command
{
    public function __construct(
        private string $id,       // ← primitivo (string)
        private string $name,     // ← primitivo (string)
        private string $duration  // ← primitivo (string)
    ) {}

    public function id(): string { return $this->id; }
    public function name(): string { return $this->name; }
    public function duration(): string { return $this->duration; }
}
```

### Capa 2: CommandHandler (Traductor)

```php
// src/Mooc/Courses/Application/Create/CreateCourseCommandHandler.php
// Responsabilidad: TRADUCIR primitivos → Value Objects del dominio
// Delegar en el Application Service
// NO orquestar, NO crear aggregates, NO persistir
final readonly class CreateCourseCommandHandler implements CommandHandler
{
    public function __construct(private CourseCreator $creator) {}

    public function __invoke(CreateCourseCommand $command): void
    {
        // ─── TRADUCCION ───
        // Convierte datos primitivos del DTO en tipos fuertes del dominio
        $id       = new CourseId($command->id());
        $name     = new CourseName($command->name());
        $duration = new CourseDuration($command->duration());

        // ─── DELEGACION ───
        // El Application Service es el orquestador real
        $this->creator->__invoke($id, $name, $duration);
    }
}
```

### Capa 3: Application Service (Orquestador)

```php
// src/Mooc/Courses/Application/Create/CourseCreator.php
// Responsabilidad: ORQUESTAR el caso de uso completo
// - Crear/modificar el aggregate
// - Persistir via repository
// - Publicar domain events
final readonly class CourseCreator
{
    public function __construct(
        private CourseRepository $repository,  // ← puerto de dominio
        private EventBus $bus                  // ← puerto de dominio
    ) {}

    public function __invoke(
        CourseId $id,
        CourseName $name,
        CourseDuration $duration
    ): void {
        // ─── DOMINIO ───
        // El aggregate se crea a si mismo (factory method)
        // Registra internamente los domain events que genera
        $course = Course::create($id, $name, $duration);

        // ─── PERSISTENCIA ───
        // Guarda el aggregate via el puerto Repository
        $this->repository->save($course);

        // ─── EVENTOS ───
        // Publica los eventos que el aggregate registro
        $this->bus->publish(...$course->pullDomainEvents());
    }
}
```

## Ejemplo Real: Query Completa

### Capa 1: Query DTO

```php
// src/Mooc/CoursesCounter/Application/Find/FindCoursesCounterQuery.php
// Responsabilidad: llevar parametros de consulta
// Es un DTO: sin comportamiento
final class FindCoursesCounterQuery implements Query {}
```

### Capa 2: QueryHandler (Delegador)

```php
// src/Mooc/CoursesCounter/Application/Find/FindCoursesCounterQueryHandler.php
// Responsabilidad: DELEGAR al Finder y retornar la respuesta
final readonly class FindCoursesCounterQueryHandler implements QueryHandler
{
    public function __construct(private CoursesCounterFinder $finder) {}

    public function __invoke(FindCoursesCounterQuery $query): CoursesCounterResponse
    {
        // Delega directamente (no hay datos que traducir en este caso simple)
        return $this->finder->__invoke();
    }
}
```

### Capa 3: Application Service (Finder)

```php
// src/Mooc/CoursesCounter/Application/Find/CoursesCounterFinder.php
// Responsabilidad: ORQUESTAR la consulta completa
final readonly class CoursesCounterFinder
{
    public function __construct(private CoursesCounterRepository $repository) {}

    public function __invoke(): CoursesCounterResponse
    {
        // ─── CONSULTA ───
        $counter = $this->repository->search();

        // ─── VALIDACION ───
        if ($counter === null) {
            throw new CoursesCounterNotExist();
        }

        // ─── RESPUESTA ───
        // Construye el Response DTO con datos del aggregate
        return new CoursesCounterResponse($counter->total()->value());
    }
}
```

## Por Que Separar Handler de Application Service?

### 1. Principio de Responsabilidad Unica

| Capa | Responsabilidad | Cambia cuando... |
|---|---|---|
| **Handler** | Traducir DTO → tipos del dominio | Cambia el formato de entrada del DTO |
| **Application Service** | Orquestar el caso de uso | Cambia la logica de negocio o los pasos del flujo |

### 2. Testabilidad

```php
// Test del Handler: solo verifica la traduccion
function test_handler_translates_dto_to_domain_objects(): void
{
    $creator = Mock::of(CourseCreator::class);
    $creator->expects('__invoke')
        ->with(new CourseId('abc'), new CourseName('DDD'), new CourseDuration('120'));

    $handler = new CreateCourseCommandHandler($creator);
    $handler->__invoke(new CreateCourseCommand('abc', 'DDD', '120'));
}

// Test del Application Service: verifica la orquestacion
function test_service_creates_course_and_publishes_events(): void
{
    $repository = Mock::of(CourseRepository::class);
    $bus = Mock::of(EventBus::class);
    $bus->expects('publish')
        ->with(new CourseCreatedDomainEvent('abc', 'DDD', '120'));

    $service = new CourseCreator($repository, $bus);
    $service->__invoke(new CourseId('abc'), new CourseName('DDD'), new CourseDuration('120'));
}
```

### 3. Reutilizacion

Un Application Service puede ser invocado desde multiples fuentes:

```php
// Desde un Command (via HTTP)
$handler = new CreateCourseCommandHandler($creator);
$handler->__invoke(new CreateCourseCommand($id, $name, $duration));

// Desde un Domain Event Subscriber (via RabbitMQ)
$subscriber = new CreateCourseOnVideoCreated($creator);
$subscriber->__invoke(new VideoCreatedDomainEvent(...));

// Desde un CLI Command (via consola)
$command = new CreateCourseCliCommand($creator);
$command->execute($input, $output);
```

Todos usan el mismo `CourseCreator`. Si la logica cambia, se modifica en un solo lugar.

## Cuando NO Separar (Handler = Orquestador)

En casos muy simples donde no hay traduccion compleja, el Handler PUEDE orquestar directamente:

```php
// Aceptable para casos triviales sin traduccion
final readonly class HealthCheckQueryHandler implements QueryHandler
{
    public function __invoke(HealthCheckQuery $query): HealthCheckResponse
    {
        // No hay dominio que consultar, no hay traduccion
        return new HealthCheckResponse('ok', random_int(1, 5));
    }
}
```

**Regla:** Si el Handler tiene mas de 3 lineas de logica (traduccion + delegacion), separa en Application Service.

## Anti-Patrones

### 1. Handler sin Application Service (Logica en el Handler)

```php
// ❌ MAL: El Handler orquesta directamente
final readonly class CreateCourseCommandHandler implements CommandHandler
{
    public function __construct(
        private CourseRepository $repository,
        private EventBus $bus
    ) {}

    public function __invoke(CreateCourseCommand $command): void
    {
        $course = Course::create(
            new CourseId($command->id()),
            new CourseName($command->name()),
            new CourseDuration($command->duration())
        );
        $this->repository->save($course);
        $this->bus->publish(...$course->pullDomainEvents());
    }
}
```

**Problema:** El Handler tiene dos responsabilidades (traduccion + orquestacion). No se puede reutilizar desde un Subscriber o CLI sin duplicar codigo.

### 2. Application Service sin Handler (Saltarse el Bus)

```php
// ❌ MAL: El Controller llama al Application Service directamente
final class CoursesPutController extends ApiController
{
    public function __construct(private CourseCreator $creator) {}

    public function __invoke(Request $request, string $id): Response
    {
        $body = json_decode($request->getContent(), true);
        $this->creator->__invoke(
            new CourseId($id),
            new CourseName($body['name']),
            new CourseDuration($body['duration'])
        );
        return new Response(status: 201);
    }
}
```

**Problema:** El Controller conoce los tipos del dominio (CourseId, CourseName). Esto acopla la capa de entrypoint al dominio. El Controller solo debe conocer primitivos y Commands/Queries.

### 3. Command con Comportamiento

```php
// ❌ MAL: El Command valida o tiene logica
final readonly class CreateCourseCommand implements Command
{
    public function __construct(private string $name)
    {
        if (empty($name)) {
            throw new InvalidArgumentException('Name is required');
        }
    }
}
```

**Problema:** Los Commands son DTOs puros. La validacion pertenece al dominio (Value Objects) o al controller (validacion de formato HTTP).

### 4. Application Service que Devuelve Datos en un Command

```php
// ❌ MAL: Un Command que retorna datos
final readonly class CreateCourseCommandHandler implements CommandHandler
{
    public function __invoke(CreateCourseCommand $command): CourseResponse
    {
        $course = Course::create(...);
        $this->repository->save($course);
        return new CourseResponse($course->id()->value());  // ← NO
    }
}
```

**Problema:** Los Commands devuelven void. Si se necesitan datos despues de una operacion de escritura, emite una Query separada.

## Resumen Visual

```
┌──────────────┐     ┌──────────────┐     ┌───────────────────┐     ┌──────────┐
│   Command    │────▶│   Handler    │────▶│  Application Svc  │────▶│  Domain  │
│   (DTO)      │     │ (Traductor)  │     │  (Orquestador)    │     │          │
│              │     │              │     │                   │     │          │
│ Solo datos   │     │ Primitivos   │     │ Crea aggregate    │     │ Factory  │
│ Sin logica   │     │ → VOs        │     │ Persiste          │     │ methods  │
│              │     │ Delega       │     │ Publica eventos   │     │          │
└──────────────┘     └──────────────┘     └───────────────────┘     └──────────┘

┌──────────────┐     ┌──────────────┐     ┌───────────────────┐
│    Query     │────▶│   Handler    │────▶│  Application Svc  │
│   (DTO)      │     │ (Delegador)  │     │  (Finder/Searcher)│
│              │     │              │     │                   │
│ Solo params  │     │ Delega al    │     │ Consulta repo     │
│ Sin logica   │     │ Finder       │     │ Valida resultado  │
│              │     │              │     │ Retorna Response  │
└──────────────┘     └──────────────┘     └───────────────────┘
```
