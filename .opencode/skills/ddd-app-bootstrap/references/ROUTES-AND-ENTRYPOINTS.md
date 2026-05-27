# Rutas y Puntos de Entrada

Las rutas definen que URLs exponen los controllers. En arquitectura DDD + Hexagonal, las rutas son **configuracion**, no logica de negocio. Por eso se separan en archivos dedicados.

## Convenciones de Nombrado

### Archivos de Rutas

Cada modulo del dominio tiene su propio archivo en `config/routes/`:

```
config/routes/
├── courses.yaml
├── courses_counter.yaml
├── health-check.yaml
└── metrics.yaml
```

**Reglas:**
- Un archivo por modulo funcional (no un archivo gigante con todas las rutas)
- Nombre en `snake_case`, coincidiendo con el modulo
- Extension `.yaml` (o `.xml` / `.json` segun el framework)

### Nombres de Rutas

Cada ruta tiene un **nombre unico** usado para generar URLs y para referenciar en tests:

```yaml
courses_put:
    path: /courses/{id}
    controller: CoursesPutController
    methods: PUT
```

**Convencion:** `{modulo}_{accion}` en `snake_case`.
- `courses_put`
- `courses_counter_get`
- `health_check_get`

### Nombres de Controllers

Los controllers se nombran describiendo la accion que realizan:

```
CoursesPutController       → PUT /courses/{id}
CoursesCounterGetController → GET /courses-counter
HealthCheckGetController    → GET /health-check
```

**Convencion:** `{Recurso}{Accion}{Metodo}Controller` en `PascalCase`.
- Accion: `Put`, `Get`, `Post`, `Patch`, `Delete`
- Metodo HTTP opcional si hay ambiguedad

### Agrupacion en Carpetas

Los controllers se agrupan por modulo dentro de `src/Controller/`:

```
src/Controller/
├── Courses/
│   └── CoursesPutController.php
├── CoursesCounter/
│   └── CoursesCounterGetController.php
├── HealthCheck/
│   └── HealthCheckGetController.php
└── Metrics/
    └── MetricsController.php
```

Esto refleja la estructura del dominio y facilita la navegacion.

## Ejemplo de Archivo de Rutas

```yaml
# config/routes/courses.yaml
courses_put:
    path: /courses/{id}
    controller: App\Apps\Mooc\Backend\Controller\Courses\CoursesPutController
    methods: PUT

courses_get:
    path: /courses
    controller: App\Apps\Mooc\Backend\Controller\Courses\CoursesGetController
    methods: GET
    defaults:
        _format: json
```

```yaml
# config/routes/health-check.yaml
health_check_get:
    path: /health-check
    controller: App\Apps\Mooc\Backend\Controller\HealthCheck\HealthCheckGetController
    methods: GET
```

## Separacion de Rutas y Controllers

**MAL — Anotaciones en el controller (acoplamiento):**
```php
// ❌ Mezcla configuracion de URL con logica de entrada
#[Route('/courses/{id}', methods: ['PUT'])]
class CoursesPutController { ... }
```

**BIEN — Rutas en YAML separado (desacoplamiento):**
```yaml
# ✅ La URL puede cambiar sin tocar PHP
courses_put:
    path: /api/v1/courses/{id}
    controller: CoursesPutController
```

**Por que importa:**
- Un cambio de URL no requiere modificar codigo fuente
- Facil ver TODAS las URLs del BC de un vistazo
- Posible versionar APIs cambiando solo archivos YAML
- Los tests pueden referenciar rutas por nombre sin conocer la URL exacta

## Entrypoints HTTP vs CLI

| Caracteristica | HTTP (`public/index.php`) | CLI (`bin/console`) |
|---|---|---|
| Entrada | Request HTTP (URL, headers, body JSON) | Argumentos de terminal |
| Salida | Response HTTP (status code, JSON/HTML) | Texto en stdout/stderr |
| Ciclo de vida | Request/Response corta | Comando que puede durar horas (workers) |
| Concurrencia | Alta (miles de requests paralelos) | Baja (uno o pocos procesos) |
| Proposito | APIs, paginas web | Tareas administrativas, workers de eventos, cron jobs |

### Cuando Crear un Controller HTTP

- El usuario/cliente necesita obtener datos (Query)
- El usuario/cliente necesita mutar datos (Command)
- Se necesita un health check o endpoint de monitoreo

### Cuando Crear un Comando CLI

- Consumir eventos de una cola (RabbitMQ, SQS, Kafka)
- Reindexar datos en Elasticsearch
- Ejecutar tareas programadas (cron)
- Configurar infraestructura (crear exchanges/queues)
- Generar archivos de configuracion (supervisor, nginx)

## Estructura del Controller (Recordatorio)

Los controllers son **delgados**. Solo traducen I/O:

```php
class CoursesPutController extends ApiController
{
    public function __invoke(Request $request, string $id): Response
    {
        // 1. Parsear entrada
        $body = json_decode($request->getContent(), true);

        // 2. Crear Command DTO
        $command = new CreateCourseCommand(
            $id,
            $body['name'],
            $body['duration']
        );

        // 3. Despachar (fire and forget)
        $this->dispatch($command);

        // 4. Responder
        return new Response(status: Response::HTTP_CREATED);
    }
}
```

**Prohibido en controllers:**
- Validacion de reglas de negocio (eso es dominio)
- Llamar repositories directamente
- Logica de orquestacion compleja (eso es Application Service / Handler)
- Crear entidades de dominio

## Estructura del Comando CLI

```php
class ConsumeRabbitMqDomainEventsCommand extends Command
{
    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        // 1. Obtener parametros (opcional)
        $queueName = $input->getArgument('queue');

        // 2. Crear DTO o usar servicio directamente (solo para infraestructura pura)
        $consumer = $this->getContainer()->get(RabbitMqDomainEventsConsumer::class);

        // 3. Ejecutar
        $consumer->consume($queueName);

        return Command::SUCCESS;
    }
}
```

**Regla para comandos CLI:** Si el comando ejecuta un caso de uso de negocio, debe crear un Command/Query DTO y despacharlo al bus, igual que un controller. Solo los comandos de infraestructura pura (configurar RabbitMQ, consumir colas) pueden interactuar directamente con adaptadores.

## Errores Comunes

1. **Rutas duplicadas**: Dos archivos YAML definen la misma URL. El framework suele silenciar uno sin avisar.

2. **Controllers con multiples metodos**: Un controller con 10 metodos (`list`, `create`, `update`, `delete`, `search`, etc.) viola el principio de responsabilidad unica. Dividir en `CoursesGetController`, `CoursesPutController`, etc.

3. **Rutas sin nombre**: Rutas anonimas dificitan generar URLs en tests y en respuestas (ej. HATEOAS).

4. **Mezclar rutas de API y Web en el mismo archivo**: Si la app tiene tanto API JSON como paginas HTML, separar en `routes/api_*.yaml` y `routes/web_*.yaml`.

5. **Controllers que llaman a otros controllers**: Un controller NUNCA debe hacer una sub-request a otro controller. Usar el CommandBus/QueryBus.
