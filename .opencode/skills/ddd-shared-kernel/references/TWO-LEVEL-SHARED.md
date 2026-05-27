# Arquitectura de Shared en Dos Niveles

En proyectos DDD con multiples Bounded Contexts en monorepo, el codigo compartido se organiza en **dos niveles** con reglas distintas.

## Por que Dos Niveles

Un solo nivel de Shared (monorepo) no alcanza cuando los BCs crecen y tienen modulos internos que necesitan compartir codigo entre si. Meter todo en monorepo Shared lo infla con tipos que solo interesan a un BC. Dejarlo en cada modulo duplica codigo.

Los dos niveles resuelven esto:

```
Nivel 1: src/Shared/          ← "Todos los BCs necesitan esto"
Nivel 2: src/<BC>/Shared/     ← "Solo los modulos de ESTE BC necesitan esto"
```

## Nivel 1: Monorepo Shared Kernel (`src/Shared/`)

**Proposito:** Codigo verdaderamente transversal. Todos los Bounded Contexts del monorepo dependen de el.

### Que SÍ va aqui

| Categoria | Ejemplos en este proyecto | Por que |
|---|---|---|
| Clases base abstractas | `AggregateRoot`, `Uuid`, `StringValueObject`, `IntValueObject` | Todos los BCs extienden de ellas. Sin logica de negocio. |
| Interfaces de bus (puertos) | `CommandBus`, `QueryBus`, `EventBus`, `DomainEventSubscriber` | Contratos que todo BC usa para comunicarse. |
| Interfaces de infraestructura (puertos) | `Logger`, `Monitoring`, `RandomNumberGenerator`, `UuidGenerator` | Puertos que cualquier BC puede necesitar. |
| Patron Criteria | `Criteria`, `Filter`, `Filters`, `Order`, `FilterOperator`, `FilterField`, `FilterValue` | Mecanismo de consulta usado por repos de cualquier BC. |
| Domain Event base | `DomainEvent` (abstracta) | Todos los eventos de dominio extienden de ella. |
| Utilidades sin logica de negocio | `Utils`, `Assert`, `Collection` | Herramientas tecnicas transversales. |
| Adaptadores genericos de infraestructura | `InMemorySymfonyCommandBus`, `RabbitMqEventBus`, `DoctrineRepository`, `ApiController`, `ApiExceptionListener` | Implementaciones que cualquier BC puede reusar con su config. |
| Custom Types de Doctrine | `UuidType` (abstracto) | Mapeo ORM reutilizable. |

### Que NO va aqui

| Categoria | Ejemplo INCORRECTO | Donde deberia ir |
|---|---|---|
| Tipos concretos de un BC | `CourseId`, `VideoUrl`, `BackofficeCourse` | `src/<BC>/Shared/Domain/` si lo comparten modulos, o `src/<BC>/<Module>/Domain/` si es de un solo modulo |
| Logica de negocio | `PricingService`, `FraudDetector` | Domain Service del BC correspondiente |
| Factories especificas de un BC | `MoocEntityManagerFactory` | `src/<BC>/Shared/Infrastructure/Doctrine/` |
| DI config de un BC | `mooc_services.yaml` | `src/<BC>/Shared/Infrastructure/Symfony/DependencyInjection/` |

### Estructura de Capas

```
src/Shared/
├── Domain/                  ← CERO dependencias externas
│   ├── Aggregate/           ← AggregateRoot base
│   ├── ValueObject/         ← Uuid, StringValueObject, IntValueObject
│   ├── Bus/Command/         ← CommandBus (interfaz), Command (marker)
│   ├── Bus/Query/           ← QueryBus (interfaz), Query (marker)
│   ├── Bus/Event/           ← EventBus (interfaz), DomainEvent, DomainEventSubscriber
│   ├── Criteria/            ← Criteria, Filters, Filter, Order...
│   └── *.php                ← Logger, Monitoring, Utils, Assert, Collection...
│
└── Infrastructure/          ← PUEDE usar librerias externas (Symfony, Doctrine, etc.)
    ├── Bus/Command/         ← InMemorySymfonyCommandBus
    ├── Bus/Query/           ← InMemorySymfonyQueryBus
    ├── Bus/Event/           ← InMemoryEventBus, RabbitMq*, MySql*, DomainEventMapping...
    ├── Persistence/Doctrine/ ← DoctrineRepository, DoctrineCriteriaConverter, UuidType
    ├── Symfony/             ← ApiController, WebController, ApiExceptionListener...
    ├── Logger/              ← MonologLogger
    └── Monitoring/          ← PrometheusMonitor
```

## Nivel 2: BC-Local Shared (`src/<BC>/Shared/`)

**Proposito:** Codigo compartido SOLO entre modulos del mismo Bounded Context.

### Que SÍ va aqui

| Categoria | Ejemplo real (Mooc) | Por que |
|---|---|---|
| Tipos de dominio compartidos entre modulos | `CourseId` (usado por `Courses` y `Videos`) | Ambos modulos de Mooc referencian cursos. |
| Value Objects compartidos entre modulos | `VideoUrl` (usado por varios modulos de Mooc) | Validacion de URL compartida. |
| EntityManager factory del BC | `MoocEntityManagerFactory` | Configura Doctrine para los modulos de ESTE BC. |
| Scanners de modulos del BC | `DoctrinePrefixesSearcher`, `DbalTypesSearcher` | Escanean `src/Mooc/*` para descubrir entidades y tipos. |
| DI wiring del BC | `mooc_services.yaml` | Define servicios, aliases y tags para ESTE BC. |

### Que NO va aqui

| Categoria | Ejemplo INCORRECTO | Por que |
|---|---|---|
| Codigo que otro BC necesita | Backoffice importando `MoocEntityManagerFactory` | Viola el aislamiento. Si ambos lo necesitan, va en monorepo Shared. |
| Entidades de un solo modulo | `Course` (si solo lo usa `Courses`) | Pertenece a `src/Mooc/Courses/Domain/`. |
| Casos de uso | `CreateCourseCommandHandler` | Pertenece a `src/Mooc/Courses/Application/Create/`. |

### Estructura de Capas

```
src/<BC>/Shared/
├── Domain/
│   └── <Module>/            ← Agrupado por modulo funcional
│       └── <SharedType>.php ← Tipo concreto compartido entre modulos
│
└── Infrastructure/
    ├── Doctrine/
    │   ├── <BC>EntityManagerFactory.php      ← Factory de EM especifico del BC
    │   ├── <BC>DoctrinePrefixesSearcher.php   ← Escanea prefijos Doctrine del BC
    │   └── <BC>DbalTypesSearcher.php          ← Escanea custom types del BC
    └── Symfony/
        └── DependencyInjection/
            └── <bc>_services.yaml             ← DI wiring del BC
```

## Flujo de Dependencias

```
src/Shared/Domain/              ← Nivel 1: Tipos base (AggregateRoot, Uuid, DomainEvent)
    ↑ extiende
src/<BC>/Shared/Domain/         ← Nivel 2: Tipos compartidos entre modulos (CourseId)
    ↑ usa
src/<BC>/<Module>/Domain/       ← Modulo concreto (Course, CourseRepository)
    ↑ implementa
src/<BC>/<Module>/Infrastructure/  ← Adaptador concreto (DoctrineCourseRepository)
    ↑ cablea
src/<BC>/Shared/Infrastructure/    ← DI config + EM factory del BC
```

## Comparativa: Nivel 1 vs Nivel 2

| Dimension | Monorepo Shared (`src/Shared/`) | BC-Local Shared (`src/<BC>/Shared/`) |
|---|---|---|
| Audiencia | TODOS los BCs | Solo modulos de ESTE BC |
| Domain | Abstracto, generico, sin logica de negocio | Concreto, con semantica del BC |
| Infrastructure | Adaptadores genericos reusables | Factories y DI config especificos del BC |
| Dependencias externas | Domain: CERO. Infrastructure: permitidas. | Infrastructure: permitidas (Symfony, Doctrine) |
| Tamano tipico | Grande (58 archivos en este proyecto) | Pequeno (1-7 archivos) |
| Frecuencia de cambio | Baja (cambios coordinados entre BCs) | Media (cambia cuando cambia la estructura de modulos) |
| Ejemplo | `Uuid`, `CommandBus`, `RabbitMqEventBus` | `CourseId`, `MoocEntityManagerFactory`, `mooc_services.yaml` |

## Anti-Patron Clasico: BC Importando Shared de Otro BC

```yaml
# ❌ MAL: backoffice_services.yaml usa MoocEntityManagerFactory
# Archivo: src/Backoffice/Shared/.../backoffice_services.yaml
services:
    Doctrine\ORM\EntityManager:
        factory: [ CodelyTv\Mooc\Shared\Infrastructure\Doctrine\MoocEntityManagerFactory, create ]
        # @todo this should be from backoffice, no mooc
```

**Problema:** Si Mooc se extrae a un microservicio, Backoffice se rompe. Si Mooc cambia su factory, Backoffice hereda el cambio.

**Solucion:** Cada BC tiene su propio `EntityManagerFactory` en su propio Shared:

```yaml
# ✅ BIEN: Backoffice usa su propia factory
services:
    Doctrine\ORM\EntityManager:
        factory: [ CodelyTv\Backoffice\Shared\Infrastructure\Doctrine\BackofficeEntityManagerFactory, create ]
```

## Regla de Oro

> Si 2+ BCs distintos necesitan el codigo → Monorepo Shared.
> Si 2+ modulos del MISMO BC necesitan el codigo → BC-Local Shared.
> Si solo 1 modulo lo necesita → Dentro de ese modulo, no en Shared.
