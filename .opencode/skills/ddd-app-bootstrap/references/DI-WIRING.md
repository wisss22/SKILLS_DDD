# Cableado de Dependencias (DI Wiring)

El archivo `config/services.yaml` es el corazon de la aplicacion. Define como se instancian y conectan los objetos. En DDD + Hexagonal, su responsabilidad principal es:

1. **Auto-registrar** entrypoints (controllers, comandos CLI)
2. **Taggear** handlers y subscribers para que el bus los descubra
3. **Cargar** todo el codigo del BC desde `src/<BC>/`
4. **Seleccionar implementaciones** de puertos (alias de interfaces a adaptadores concretos)

## Estructura Base

```yaml
imports:
  # Carga configuracion DI compartida del BC (desde src/)
  - { resource: '../../../../src/<BC>/Shared/Infrastructure/DependencyInjection/<bc>_services.yaml' }

services:
  _defaults:
    autoconfigure: true   # El framework aplica tags automaticamente
    autowire: true        # El framework inyecta dependencias por tipo

  # ============================================================
  # TAGGING AUTOMATICO (descubre handlers y subscribers)
  # ============================================================
  _instanceof:
    App\Shared\Domain\Bus\Event\DomainEventSubscriber:
      tags: ['app.domain_event_subscriber']

    App\Shared\Domain\Bus\Command\CommandHandler:
      tags: ['app.command_handler']

    App\Shared\Domain\Bus\Query\QueryHandler:
      tags: ['app.query_handler']

  # ============================================================
  # AUTO-REGISTRO DE ENTRYPOINTS
  # ============================================================
  App\Apps\<BC>\Backend\Controller\:
    resource: '../src/Controller'
    tags: ['controller.service_arguments']

  App\Apps\<BC>\Backend\Command\:
    resource: '../src/Command'
    tags: ['console.command']

  # ============================================================
  # WIRING DE DOMINIO Y APLICACION
  # ============================================================
  App\Shared\:
    resource: '../../../../src/Shared'

  App\<BC>\:
    resource: '../../../../src/<BC>'

  # ============================================================
  # CONFIGURACION MANUAL DE INFRAESTRUCTURA
  # ============================================================
  # Aqui se definen adaptadores concretos que necesitan parametros
  # (host, puerto, credenciales) y no pueden auto-registrarse.

  App\Shared\Infrastructure\Bus\Event\RabbitMq\RabbitMqConnection:
    arguments:
      - host: '%env(RABBITMQ_HOST)%'
        port: '%env(RABBITMQ_PORT)%'
        login: '%env(RABBITMQ_LOGIN)%'
        password: '%env(RABBITMQ_PASSWORD)%'

  # ============================================================
  # IMPLEMENTATION SELECTOR (alias de puertos a adaptadores)
  # ============================================================
  # Esto permite cambiar toda la infraestructura cambiando una linea.

  App\Shared\Domain\Bus\Event\EventBus:
    '@App\Shared\Infrastructure\Bus\Event\RabbitMq\RabbitMqEventBus'
```

## Secciones Explicadas

### `_defaults`

```yaml
services:
  _defaults:
    autoconfigure: true
    autowire: true
```

- **`autoconfigure`**: El framework escanea interfaces implementadas y aplica tags automaticamente. Por ejemplo, si una clase implementa `CommandHandler`, se taggea sin anotaciones YAML.
- **`autowire`**: El framework lee los tipos de los constructores e inyecta las dependencias automaticamente. No necesitas definir `arguments:` para cada servicio.

**Equivalentes en otros frameworks:**
- Laravel: `app->singleton()`, `app->bind()`, auto-discovery de providers
- Spring Boot: `@ComponentScan`, `@Autowired`, `@Service`
- Node.js/NestJS: `@Injectable()`, `@Module()` providers/controllers

### `_instanceof` Tagging

```yaml
  _instanceof:
    App\Shared\Domain\Bus\Command\CommandHandler:
      tags: ['app.command_handler']
```

Esta regla dice: *"Toda clase que implemente `CommandHandler`, automaticamente recibe el tag `app.command_handler`"*.

Esto permite que el `CommandBus` reciba TODOS los handlers mediante un **tagged iterator**:

```yaml
  App\Shared\Infrastructure\Bus\Command\InMemoryCommandBus:
    arguments: [!tagged app.command_handler]
```

**Por que es importante:** Si creas un nuevo `CreateCourseCommandHandler`, no necesitas tocar `services.yaml`. El framework lo descubre y lo conecta al bus automaticamente.

**Equivalentes en otros frameworks:**
- Laravel: Tagging de bindings (`$app->tag([...], 'command_handlers')`)
- Spring Boot: `@Component` + `@Qualifier` o `Map<String, CommandHandler>`
- NestJS: `@Injectable()` + modulo que exporta providers

### Auto-registro de Controllers y Commands

```yaml
  App\Apps\<BC>\Backend\Controller\:
    resource: '../src/Controller'
    tags: ['controller.service_arguments']
```

Esto escanea toda la carpeta `src/Controller/` y registra cada clase como un servicio. El tag `controller.service_arguments` habilita la inyeccion de dependencias en los controllers.

**Regla:** Los controllers deben vivir en `src/Controller/` y estar organizados por modulo (`Courses/`, `HealthCheck/`).

### Wiring de `src/Shared` y `src/<BC>`

```yaml
  App\Shared\:
    resource: '../../../../src/Shared'

  App\<BC>\:
    resource: '../../../../src/<BC>'
```

Estas dos lineas cargan TODO el codigo del nucleo:
- `src/Shared/` — Tipos base, buses (interfaces), utilidades
- `src/<BC>/` — Entidades, casos de uso, repositorios (interfaces), subscribers del bounded context

**Importante:** El framework auto-registra cada clase como servicio. Gracias a `autowire`, las dependencias se resuelven por tipo. Las interfaces (puertos) se resuelven mediante el **Implementation Selector**.

### Implementation Selector

La parte mas critica del DI es decidir **que adaptador concreto** implementa cada **puerto** (interfaz del dominio):

```yaml
  # Puerto (interfaz en Domain / Shared Application)
  App\Shared\Domain\Bus\Event\EventBus:
    # Adaptador concreto (implementacion en Infrastructure)
    '@App\Shared\Infrastructure\Bus\Event\RabbitMq\RabbitMqEventBus'
```

Esto permite cambiar toda la infraestructura de mensajeria cambiando una sola linea:

```yaml
  # Para tests:
  App\Shared\Domain\Bus\Event\EventBus:
    '@App\Shared\Infrastructure\Bus\Event\InMemory\InMemoryEventBus'

  # Para produccion con monitoring:
  App\Shared\Domain\Bus\Event\EventBus:
    '@App\Shared\Infrastructure\Bus\Event\WithMonitoring\WithPrometheusMonitoringEventBus'
```

**Equivalentes en otros frameworks:**
- Laravel: `App::bind(EventBus::class, RabbitMqEventBus::class)` en `AppServiceProvider`
- Spring Boot: `@Bean` que retorna la implementacion concreta, o `@Primary`
- NestJS: `providers: [{ provide: EVENT_BUS, useClass: RabbitMqEventBus }]`

## Overrides para Test (`services_test.yaml`)

En entorno de test se reemplazan adaptadores externos por implementaciones in-memory para aislar los tests:

```yaml
services:
  _defaults:
    autoconfigure: true
    autowire: true

  framework:
    test: true   # Activa modo test del framework

  # Carga helpers de test
  App\Tests\:
    resource: '../../../../tests'

  # Override: EventBus in-memory para tests
  App\Shared\Domain\Bus\Event\EventBus:
    '@App\Shared\Infrastructure\Bus\Event\InMemory\InMemoryEventBus'

  # Override: Generador de numeros aleatorios con valor fijo
  App\Shared\Domain\RandomNumberGenerator:
    class: App\Tests\Shared\Infrastructure\ConstantRandomNumberGenerator
```

**Regla:** `services_test.yaml` se carga DESPUES de `services.yaml`, por lo que cualquier definicion aqui sobreescribe la anterior.

## Errores Comunes

1. **Olvidar el tag en `_instanceof`**: Si creas un `CommandHandler` pero no lo taggeas, el `CommandBus` no lo descubre y lanza `CommandNotRegisteredError`.

2. **Ciclo de dependencias**: Si `HandlerA` depende de `ServiceB` y `ServiceB` depende de `HandlerA`, el contenedor falla. Solucion: usar el bus (eventos) en lugar de inyeccion directa.

3. **Alias de puerto a adaptador inexistente**: `EventBus` apunta a una clase que no existe o que no implementa la interfaz. El contenedor compila pero falla en runtime.

4. **Cargar `src/<OtroBC>/` en la app**: `services.yaml` de Mooc NUNCA debe cargar `src/Backoffice/`. Eso rompe el aislamiento del bounded context.

5. **Definir servicios con parametros secretos en YAML**: Credenciales de base de datos, API keys, etc. deben usar variables de entorno (`%env(...)%`), nunca valores hardcodeados.
