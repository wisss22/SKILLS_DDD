# Controladores API

Los controladores API son **puntos de entrada delgados** que reciben solicitudes HTTP, las traducen en Commands/Queries, los despachan al bus y formatean respuestas HTTP. Contienen **cero lógica de negocio**.

## Reglas Fundamentales

### 1. Los Controladores Son Delgados

```pseudocode
// GOOD: Controller only does I/O translation
class CoursesPutController:
    property commandBus: CommandBus
    property exceptionMapper: ExceptionToHttpStatusMapper

    method handle(request: Request): Response
        try:
            // 1. Parse input
            body = JSON.parse(request.body)

            // 2. Create command
            command = new CreateCourseCommand(
                id: body.id,
                name: body.name,
                duration: body.duration
            )

            // 3. Dispatch (fire and forget)
            self.commandBus.dispatch(command)

            // 4. Return success
            return Response(status: 201)

        catch ValidationError as e:
            return Response(status: 400, body: { error: e.message })
        catch DomainError as e:
            status = self.exceptionMapper.httpStatusFor(e)
            return Response(status: status, body: { error: e.message })
```

### 2. ApiController Base

```pseudocode
abstract class ApiController:
    property commandBus: CommandBus
    property queryBus: QueryBus
    property exceptionMapper: ExceptionToHttpStatusMapper

    // Helper: Dispatch a command
    method dispatch(command: Command): void
        self.commandBus.dispatch(command)

    // Helper: Ask a query
    method ask(query: Query): Response
        data = self.queryBus.ask(query)
        return Response(status: 200, body: data.toJson())

    // Helper: Map exceptions to HTTP status codes
    method handleException(error: Error): Response
        status = self.exceptionMapper.httpStatusFor(error)
        return Response(
            status: status,
            body: { error: error.message, code: error.code }
        )
```

### 3. Mapeo de Excepciones

Mapea errores de dominio a códigos de estado HTTP. Nunca expongas errores internos:

```pseudocode
class ExceptionToHttpStatusMapper:
    property mappings: map[ErrorType, HttpStatus]

    constructor():
        self.mappings = {
            InvalidCourseName: 400,          // Bad Request
            CourseNotFound: 404,             // Not Found
            CourseAlreadyPublished: 409,     // Conflict
            InvalidAuthCredentials: 401,     // Unauthorized
            PermissionDenied: 403,           // Forbidden
        }

    method httpStatusFor(error: Error): int
        return self.mappings[error.type] ?? 500  // Default: Internal Server Error
```

### 4. Procesamiento del Cuerpo de la Solicitud

Analiza el cuerpo JSON en el command. Opcionalmente usa un middleware:

```pseudocode
// Middleware that parses JSON body and adds it to the request
class AddJsonBodyToRequestListener:
    method onRequest(request):
        if request.contentType == "application/json":
            request.body = JSON.parse(request.rawBody)
        // Continue to next middleware/controller
```

### 5. Estructura del Controlador (Ejemplo de Query)

```pseudocode
class CoursesCounterGetController:
    property queryBus: QueryBus

    method handle(request: Request): Response
        try:
            query = new FindCoursesCounterQuery()
            response = self.queryBus.ask(query)
            return Response(
                status: 200,
                body: {
                    total: response.total
                }
            )
        catch error:
            return self.handleException(error)
```

### 6. Configuración de Rutas

Las rutas se configuran por separado de los controladores:

```yaml
# routes.yaml — no annotations in controllers
courses_put:
    path: /api/courses/{id}
    controller: CoursesPutController.handle
    methods: PUT

courses_counter_get:
    path: /api/courses-counter
    controller: CoursesCounterGetController.handle
    methods: GET

health_check_get:
    path: /api/health-check
    controller: HealthCheckGetController.handle
    methods: GET
```

### 7. Flujo Completo

```
HTTP PUT /api/courses/abc-123
  { "name": "DDD Course", "duration": 120 }
    │
    ▼
AddJsonBodyToRequestListener  (middleware analiza JSON)
    │
    ▼
Router → CoursesPutController.handle(request)
    │
    ▼
Controller crea CreateCourseCommand(id, name, duration)
    │
    ▼
CommandBus.dispatch(command)
    │
    ▼
CreateCourseCommandHandler.invoke(command)
    ├── Course.create(id, name, duration)  [Capa de Dominio]
    ├── courseRepository.save(course)      [Puerto Repository]
    └── eventBus.publish(events)           [Puerto EventBus]
    │
    ▼
Controller retorna Response(201)
```

## API Controller vs Web Controller

| Característica | ApiController | WebController |
|---|---|---|
| Formato de respuesta | JSON | HTML (Twig, Blade, etc.) |
| Formato de entrada | Cuerpo JSON | Datos de formulario, params de consulta |
| Autenticación | API tokens, JWT | Basada en sesión |
| Respuesta de error | Objeto JSON de error | Página de error |

```pseudocode
// Web controller (HTML)
class CoursesGetWebController extends WebController:
    property queryBus: QueryBus

    method handle(request): Response
        query = new SearchAllCoursesQuery()
        courses = self.queryBus.ask(query)
        return self.render("courses.html.twig", {
            courses: courses.items
        })
```

## Errores Comunes

1. **Lógica de negocio en controladores**: Validación, orquestación, llamar repositories directamente
2. **Controladores sin manejo de excepciones**: Las excepciones se convierten en errores 500 con stack traces
3. **Sin controlador base**: Duplicar dispatch/ask/mapeo de excepciones en cada controlador
4. **Anotaciones de ruta en controladores**: Mezclar configuración de enrutamiento con lógica del controlador
5. **Manejar demasiados endpoints**: Un controlador con más de 10 métodos (dividir en controladores enfocados)
6. **Controladores llamando a otros controladores**: Usar el bus, no llamadas directas entre controladores
