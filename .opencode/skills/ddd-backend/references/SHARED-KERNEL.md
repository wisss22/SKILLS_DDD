# Shared Kernel / Carpeta Shared

El **Shared Kernel** es un concepto de DDD Estratégico: un subconjunto de código y modelo compartido deliberadamente entre dos o más Bounded Contexts. En la práctica de Arquitectura Hexagonal, se materializa en la carpeta `src/Shared/` (o `shared/`) que contiene tipos base, utilidades e interfaces reutilizables.

## Por Qué Existe Shared

Sin Shared, cada Bounded Context duplica clases base idénticas (`Uuid`, `AggregateRoot`, `CommandBus`) o — peor — un BC importa directamente del código interno de otro BC, violando los límites.

Shared proporciona un **punto de acoplamiento controlado**: ambos BCs dependen de Shared, no entre sí.

```
// MAL: Acoplamiento directo entre BCs
Mooc/Courses/ → importa de → Backoffice/Courses/
// Si Backoffice cambia, Mooc se rompe.

// BIEN: Acoplamiento a través de Shared
Mooc/Courses/   → importa de → Shared/Domain/
Backoffice/     → importa de → Shared/Domain/
// Shared cambia bajo control de ambos equipos.
```

## Las Tres Capas de Shared

Cada capa de Shared refleja las reglas de dependencia de su capa correspondiente en la arquitectura:

| Capa | Carpeta | Contiene | Regla de Dependencia | Ejemplos |
|---|---|---|---|---|
| **Shared Domain** | `src/Shared/Domain/` | Tipos base de dominio, interfaces de dominio | **CERO dependencias externas.** Solo librería estándar del lenguaje. | `AggregateRoot`, `ValueObject`, `Uuid`, `DomainEvent`, `StringValueObject`, `IntValueObject`, `EnumValueObject`, `Identifier` |
| **Shared Application** | `src/Shared/Application/` | Interfaces base y DTOs para la capa de aplicación | Solo depende de Shared/Domain. | `CommandBus` (interfaz), `QueryBus` (interfaz), `Criteria`, `Filters`, `Order`, `Query`, `Command` |
| **Shared Infrastructure** | `src/Shared/Infrastructure/` | Clases base de infraestructura, adaptadores reutilizables | Depende de Shared/Domain y Shared/Application. Puede usar librerías externas. | `BaseRepository`, `BaseDoctrineRepository`, `BaseElasticsearchRepository`, `InMemoryEventBus`, `UuidGenerator`, `Logger` |

### Shared Domain — Tipos Base de Dominio

```pseudocode
// ─── src/Shared/Domain/ ───

// Clase base para todos los aggregates
abstract class AggregateRoot:
    property events: DomainEvent[]

    method record(event: DomainEvent): void
        self.events.append(event)

    method pullEvents(): DomainEvent[]
        events = self.events.copy()
        self.events.clear()
        return events

// Clase base para Value Objects inmutables
abstract class ValueObject:
    abstract method equals(other: ValueObject): bool

// Value Object base para strings con validación
abstract class StringValueObject extends ValueObject:
    property value: string

    constructor(value: string):
        self.ensureIsString(value)
        self.value = value

    method value(): string
        return self.value

    method equals(other: StringValueObject): bool
        return self.value == other.value

// Value Object base para identificadores (UUID)
abstract class Uuid extends ValueObject:
    property value: string

    constructor(value: string):
        self.ensureIsValidUuid(value)
        self.value = value

    static generate(): Uuid
        return new static(uuid_v4())

    method equals(other: Uuid): bool
        return self.value == other.value

// Value Object base para enumerados
abstract class EnumValueObject extends ValueObject:
    property value: string

    constructor(value: string):
        self.ensureIsValidValue(value)
        self.value = value

    abstract static validValues(): array

    method ensureIsValidValue(value: string): void
        if value not in self.validValues():
            throw InvalidEnumValue(value, self.validValues())

// Clase base para domain events
abstract class DomainEvent:
    property eventId: Uuid
    property aggregateId: Uuid
    property occurredOn: DateTime

    abstract static eventName(): string
    abstract method toPrimitives(): map
    abstract static fromPrimitives(aggregateId, body, eventId, occurredOn): DomainEvent
```

### Shared Application — Interfaces de Bus y Criteria

```pseudocode
// ─── src/Shared/Application/ ───

// Interfaz base para todos los commands
interface Command:  // Marker interface — sin métodos

// Interfaz base para el bus de commands
interface CommandBus:
    method dispatch(command: Command): void

// Interfaz base para todos los queries
interface Query:  // Marker interface

// Interfaz base para el bus de queries
interface QueryBus:
    method ask(query: Query): Response

// Criteria pattern — objetos de consulta componibles
class Criteria:
    property filters: Filters
    property order: Order?
    property offset: int?
    property limit: int?

class Filters:
    property filters: Filter[]

class Filter:
    property field: FilterField
    property operator: FilterOperator
    property value: FilterValue

class Order:
    property orderBy: OrderBy
    property orderType: OrderType
```

### Shared Infrastructure — Clases Base de Persistencia

```pseudocode
// ─── src/Shared/Infrastructure/ ───

// Clase base para repositories que usan ORM/DB
abstract class BaseRepository:
    property connection: DatabaseConnection

    abstract method tableName(): string
    abstract method toDomain(row: map): AggregateRoot
    abstract method toPersistence(aggregate: AggregateRoot): map

    method save(aggregate: AggregateRoot): void
        primitives = self.toPersistence(aggregate)
        self.connection.upsert(self.tableName(), primitives)

    method findById(id: Uuid): AggregateRoot?
        row = self.connection.query(
            "SELECT * FROM " + self.tableName() + " WHERE id = ?",
            id.value()
        )
        return self.toDomain(row) if row else null

    method delete(id: Uuid): void
        self.connection.execute(
            "DELETE FROM " + self.tableName() + " WHERE id = ?",
            id.value()
        )

// Implementación in-memory del EventBus (para desarrollo/testing)
class InMemoryEventBus implements EventBus:
    property subscribers: map[string, DomainEventSubscriber[]]

    method register(subscriber: DomainEventSubscriber, eventType: string): void
        self.subscribers[eventType].append(subscriber)

    method publish(events: DomainEvent[]): void
        for event in events:
            subs = self.subscribers[event.eventName()] ?? []
            for subscriber in subs:
                subscriber.invoke(event)

// Generador de UUIDs reutilizable
class UuidGenerator:
    method generate(): string
        return uuid_v4()
```

## Qué SÍ Va en Shared

| Tipo | Ejemplos | Razón |
|---|---|---|
| Clases base abstractas sin lógica de negocio | `AggregateRoot`, `ValueObject`, `StringValueObject`, `EnumValueObject` | Todos los BCs necesitan la misma base. No contienen reglas específicas. |
| Interfaces de bus y mensajería | `CommandBus`, `QueryBus`, `EventBus` | La definición del contrato es compartida. Las implementaciones son por BC o globales. |
| Value Objects genéricos reutilizables | `Uuid`, `Identifier`, `DateTimeValueObject`, `Email` (si es exactamente igual en todos los BCs) | Conceptos atómicos sin variación semántica entre contextos. |
| Utilidades transversales sin lógica de negocio | `UuidGenerator`, `Logger` (interfaz), `Criteria`, `Filters` | Herramientas técnicas, no reglas de dominio. |
| Tipos de colección | `CourseCollection`, `AggregateCollection` (genéricos) | Wrappers de colección con métodos de consulta comunes. |
| Interfaces de puerto sin implementación | `Repository` (interfaz base), `EventBus` (interfaz) | Los contratos se definen en Shared. Las implementaciones concretas viven en cada BC o en Infrastructure. |

## Qué NO Va en Shared

| Tipo | Ejemplo INCORRECTO | Por Qué | Dónde Debería Ir |
|---|---|---|---|
| **Entidades de dominio específicas** | `Course`, `User`, `Order` | Son específicas de un BC. Shared NO debe conocer entidades concretas. | En el BC correspondiente: `src/Mooc/Courses/Domain/Course` |
| **Lógica de negocio** | `PricingService`, `FraudDetector`, `ShippingCalculator` | Las reglas de negocio pertenecen al BC que las define. | En el Domain Service del BC correspondiente |
| **Handlers de casos de uso** | `CreateCourseCommandHandler` | Los casos de uso son específicos de cada BC. | En el Application del BC: `src/Mooc/Courses/Application/Create/` |
| **Repositorios concretos** | `PostgresCourseRepository` | La implementación concreta pertenece al BC o a Infrastructure. | En el BC o en Infrastructure |
| **Value Objects con semántica de BC** | `CourseName` (si solo existe en un BC) | Si el concepto solo existe en un BC, no hay razón para compartirlo. | En el Domain del BC |
| **Value Objects con distinto significado entre BCs** | `Product` en Catálogo (nombre, precio) vs `Product` en Envío (peso, dimensiones) | Mismo nombre, distinto modelo. Forzarlos a compartir rompe el ubiquitous language. | Cada BC define su propio `Product` |

## Regla de Oro para Decidir: ¿Esto va en Shared?

```
¿Este código...
│
├─ ¿Es idéntico en TODOS los BCs que lo usarían?
│  └─ SÍ → ¿Cambia por las mismas razones en todos los BCs?
│     ├─ SÍ → Va en Shared
│     └─ NO → NO va en Shared (cada BC tendrá su propia versión)
│
├─ ¿Contiene lógica de negocio específica de un BC?
│  └─ SÍ → NO va en Shared. Pertenece a ese BC.
│
├─ ¿Es una clase base abstracta o interfaz sin implementación?
│  └─ SÍ → Probablemente va en Shared Domain o Shared Application
│
├─ ¿Es una implementación concreta reutilizable (ej. InMemoryEventBus)?
│  └─ SÍ → Va en Shared Infrastructure
│
└─ ¿Tiene sentido como concepto fuera de cualquier BC específico?
   └─ SÍ → Candidato a Shared
   └─ NO → Déjalo en el BC
```

## Shared Kernel vs Anti-Corruption Layer

Ambos son patrones de DDD Estratégico para comunicación entre BCs, pero resuelven problemas opuestos:

| Criterio | Shared Kernel | Anti-Corruption Layer (ACL) |
|---|---|---|
| **Acoplamiento** | Alto — los BCs comparten código y modelo | Bajo — los BCs traducen entre sí |
| **Cuándo usarlo** | BCs del mismo equipo, mismo repositorio, mismo ritmo de cambio | BCs de equipos distintos, integración con sistemas legacy, third-party |
| **Mantenimiento** | Cambios en Shared requieren coordinar ambos BCs | Cambios en un BC no afectan al otro (la ACL absorbe el cambio) |
| **Código compartido** | Carpeta `Shared/` en el monorepo | Capa de traducción en el BC consumidor |
| **Velocidad de desarrollo** | Más rápida (sin traducción) | Más lenta (requiere mapeo) |
| **Riesgo** | Un cambio en Shared puede romper múltiples BCs | La ACL puede convertirse en cuello de botella si es muy compleja |
| **Ejemplo** | `Mooc` y `Backoffice` del mismo producto comparten `Uuid`, `AggregateRoot` | `Ecommerce` (nuevo) integrándose con `ERP` (legacy) mediante ACL |

```pseudocode
// Shared Kernel: ambos BCs importan del mismo Shared
// Mooc/Courses/Domain/Course.ts
import { AggregateRoot, Uuid, DomainEvent } from '@/Shared/Domain'

// Backoffice/Courses/Domain/BackofficeCourse.ts
import { AggregateRoot, Uuid, DomainEvent } from '@/Shared/Domain'
// ↑ Mismo código. Cambios coordinados por el mismo equipo.


// Anti-Corruption Layer: un BC traduce el modelo del otro
// Ecommerce/Payment/Infrastructure/Acl/LegacyErpTranslator.ts
class LegacyErpTranslator:
    method toDomain(erpResponse: LegacyXmlResponse): Payment
        // Convierte el modelo legacy del ERP al modelo de Ecommerce
        return new Payment(
            id: PaymentId.fromValue(erpResponse.transactionRef),
            amount: Money.fromCents(erpResponse.valueInCents),
            status: self.translateStatus(erpResponse.stateCode)
        )
    // ↑ El ERP legacy no se modifica. Ecommerce define su propio modelo.
```

## Reglas de Oro

1. **Shared Domain tiene CERO dependencias externas.** Misma regla que la capa Domain de cualquier BC. Solo librería estándar del lenguaje.
2. **Shared Kernel solo entre BCs del mismo equipo.** Si los BCs pertenecen a equipos distintos, usa ACL o eventos en su lugar.
3. **Si dos BCs necesitan el mismo concepto con distinto significado → NO compartir.** `Product` en Catálogo no es `Product` en Envío. Cada BC define el suyo.
4. **Shared NO contiene lógica de negocio específica de ningún BC.** Si encuentras un `if` que depende de un contexto concreto, no pertenece a Shared.
5. **Minimizar el Shared Kernel.** Cada clase en Shared es un punto de acoplamiento. Ante la duda, no la compartas.
6. **Shared Application depende solo de Shared Domain.** No puede depender de infraestructura ni de BCs concretos.
7. **Shared Infrastructure puede usar librerías externas** (ORM, message brokers, etc.) pero NO debe contener lógica de negocio.
8. **Los cambios en Shared deben ser coordinados.** Si modificas una clase base, asegúrate de que todos los BCs que la usan sigan funcionando.

## Organización de Carpetas

```
src/
├── Shared/
│   ├── Domain/
│   │   ├── AggregateRoot.pseudo            // Clase base para aggregates
│   │   ├── ValueObject.pseudo              // Clase base para value objects
│   │   ├── DomainEvent.pseudo              // Clase base para domain events
│   │   ├── Uuid.pseudo                     // Value Object para UUIDs
│   │   ├── StringValueObject.pseudo        // Value Object base para strings
│   │   ├── IntValueObject.pseudo           // Value Object base para enteros
│   │   ├── EnumValueObject.pseudo          // Value Object base para enumerados
│   │   ├── Identifier.pseudo               // Value Object base para IDs
│   │   └── DateTimeValueObject.pseudo      // Value Object base para fechas
│   │
│   ├── Application/
│   │   ├── Command.pseudo                  // Interfaz marker para commands
│   │   ├── CommandBus.pseudo               // Interfaz del bus de commands
│   │   ├── Query.pseudo                    // Interfaz marker para queries
│   │   ├── QueryBus.pseudo                 // Interfaz del bus de queries
│   │   └── Criteria/
│   │       ├── Criteria.pseudo
│   │       ├── Filters.pseudo
│   │       ├── Filter.pseudo
│   │       ├── Order.pseudo
│   │       └── FilterOperator.pseudo
│   │
│   └── Infrastructure/
│       ├── Persistence/
│       │   ├── BaseRepository.pseudo       // Clase base para repositories
│       │   ├── BaseDoctrineRepository.pseudo
│       │   └── BaseElasticsearchRepository.pseudo
│       ├── Bus/
│       │   ├── InMemoryCommandBus.pseudo
│       │   ├── InMemoryQueryBus.pseudo
│       │   └── InMemoryEventBus.pseudo
│       └── UuidGenerator.pseudo
│
├── Mooc/                                   // Bounded Context: Mooc
│   ├── Courses/
│   │   ├── Domain/
│   │   │   ├── Course.pseudo              // Extiende AggregateRoot (Shared)
│   │   │   ├── CourseId.pseudo            // Extiende Uuid (Shared)
│   │   │   ├── CourseName.pseudo          // Extiende StringValueObject (Shared)
│   │   │   ├── CourseDuration.pseudo      // Extiende IntValueObject (Shared)
│   │   │   └── CourseRepository.pseudo    // Interfaz específica de Mooc
│   │   ├── Application/
│   │   │   ├── Create/
│   │   │   │   ├── CreateCourseCommand.pseudo
│   │   │   │   └── CreateCourseCommandHandler.pseudo
│   │   │   └── Find/
│   │   │       ├── FindCourseQuery.pseudo
│   │   │       └── FindCourseQueryHandler.pseudo
│   │   └── Infrastructure/
│   │       └── PostgresCourseRepository.pseudo  // Extiende BaseRepository (Shared)
│   │
│   └── Videos/
│       └── ...
│
├── Backoffice/                             // Bounded Context: Backoffice
│   └── Courses/
│       ├── Domain/
│       │   ├── BackofficeCourse.pseudo     // Extiende AggregateRoot (Shared)
│       │   └── BackofficeCourseId.pseudo   // Extiende Uuid (Shared)
│       └── ...
│
└── apps/                                   // Puntos de entrada
    ├── mooc/
    │   └── ...
    └── backoffice/
        └── ...
```

## Cómo un BC Usa Shared

```pseudocode
// ─── src/Mooc/Courses/Domain/Course.pseudo ───
// Una entidad concreta extiende clases base de Shared

import { AggregateRoot } from '@/Shared/Domain/AggregateRoot'
import { CourseId } from './CourseId'
import { CourseName } from './CourseName'
import { CourseDuration } from './CourseDuration'
import { CourseCreated } from './CourseCreated'

class Course extends AggregateRoot:
    property id: CourseId
    property name: CourseName
    property duration: CourseDuration
    property status: CourseStatus

    private constructor(id: CourseId, name: CourseName, duration: CourseDuration):
        self.id = id
        self.name = name
        self.duration = duration
        self.status = CourseStatus.DRAFT

    static create(id: CourseId, name: CourseName, duration: CourseDuration): Course
        course = new Course(id, name, duration)

        // Usa record() heredado de AggregateRoot (Shared)
        course.record(new CourseCreated(
            id.value(),
            name.value(),
            duration.value()
        ))

        return course

    method rename(newName: CourseName): void
        self.name = newName
        self.record(new CourseRenamed(self.id.value(), newName.value()))

    method publish(): void
        ensure self.status == CourseStatus.DRAFT
        self.status = CourseStatus.PUBLISHED
        self.record(new CoursePublished(self.id.value()))


// ─── src/Mooc/Courses/Domain/CourseId.pseudo ───
// Un Value Object concreto extiende Uuid de Shared

import { Uuid } from '@/Shared/Domain/Uuid'

class CourseId extends Uuid:
    // Hereda equals(), value(), generate() de Uuid (Shared)
    // No necesita implementar nada adicional
```

## Errores Comunes

1. **Shared como cajón de sastre:** Todo termina en `Shared/` sin criterio. La carpeta crece sin control, el acoplamiento se dispara y Shared se convierte en un "god module". Solución: aplica la regla de oro antes de mover algo a Shared.

2. **Lógica de negocio en Shared Domain:** `PricingService`, `FraudDetector` o reglas de validación específicas de un BC dentro de `Shared/Domain/`. Viola el bounded context y hace que Shared dependa de conceptos de negocio que no le corresponden.

3. **Dependencias de framework en Shared Domain:** `import { Column, Entity } from 'orm-lib'` en una clase base de Shared Domain. Shared Domain debe tener CERO dependencias externas, igual que la capa Domain de cualquier BC.

4. **Shared Kernel entre equipos distintos:** Dos equipos comparten código en Shared pero tienen ritmos de desarrollo y prioridades diferentes. Un cambio de un equipo rompe al otro. Solución: separar en BCs independientes con ACL o eventos.

5. **Demasiados tipos en Shared:** Shared crece hasta contener 50+ clases base, value objects y utilidades. Cada una es un punto de acoplamiento. Solución: revisar periódicamente qué clases de Shared realmente se usan en 2+ BCs. Si una clase solo se usa en 1 BC, muévela allí.

6. **Shared sin versionado ni contrato claro:** Los BCs importan de Shared sin saber qué versión esperan. Un cambio en Shared rompe builds en silencio. Solución: si los BCs están en repos separados, versiona Shared como paquete. En monorepo, los tests de arquitectura deben verificar que los BCs dependen de Shared correctamente.

7. **Value Objects de BC en Shared:** `CourseName` en `Shared/Domain/` cuando solo existe en el BC de Mooc. Si el concepto no es verdaderamente compartido, no pertenece a Shared.

8. **Implementaciones concretas en Shared Application:** `InMemoryCommandBus` en `Shared/Application/` en lugar de `Shared/Infrastructure/`. Las implementaciones van en Infrastructure, las interfaces en Application o Domain.

---

# Shared en Dos Niveles: Monorepo vs BC-Local

Ademas del Shared Kernel de monorepo (`src/Shared/`), los proyectos con multiples modulos dentro de un Bounded Context necesitan un **segundo nivel** de Shared local al BC (`src/<BC>/Shared/`).

## Por Que Dos Niveles

```
src/
├── Shared/                 ← Nivel 1: TODOS los BCs usan esto
│   ├── Domain/             ← AggregateRoot, Uuid, CommandBus...
│   └── Infrastructure/     ← Buses, Doctrine, Symfony base...
│
├── Mooc/
│   ├── Shared/             ← Nivel 2: SOLO modulos de Mooc usan esto
│   │   ├── Domain/         ← CourseId (usado por Courses y Videos)
│   │   └── Infrastructure/ ← MoocEntityManagerFactory, mooc_services.yaml
│   ├── Courses/
│   └── Videos/
│
└── Backoffice/
    ├── Shared/             ← Nivel 2: SOLO modulos de Backoffice usan esto
    └── Courses/
```

## Que Va en BC-Local Shared (`src/<BC>/Shared/`)

| Categoria | Ejemplo | Proposito |
|---|---|---|
| **Domain:** Tipos concretos compartidos entre modulos del BC | `CourseId` (usado por `Courses` y `Videos` en Mooc) | Evitar duplicar el tipo en cada modulo |
| **Infrastructure:** EntityManager factory del BC | `MoocEntityManagerFactory` | Escanear modulos del BC para Doctrine |
| **Infrastructure:** Scanners de modulos | `DoctrinePrefixesSearcher`, `DbalTypesSearcher` | Descubrir entidades y tipos por convencion |
| **Infrastructure:** DI config del BC | `mooc_services.yaml` | Centralizar wiring de infraestructura |

## Que NO Va en BC-Local Shared

- **Codigo usado por otro BC** — Si Backoffice necesita algo de `Mooc\Shared\`, ese codigo debe moverse a monorepo `Shared\`. Importar `Mooc\Shared\` desde Backoffice es un anti-patron.
- **Entidades de un solo modulo** — Si `Course` solo lo usa `Courses/`, vive en `Courses/Domain/`, no en `Shared/`.
- **Casos de uso** — Los handlers pertenecen a cada modulo (`Courses/Application/`).

## Regla de Decision: ¿Monorepo Shared o BC-Local Shared?

```
¿Este codigo lo necesitan 2+ Bounded Contexts DISTINTOS?
├─ SI → Monorepo Shared (src/Shared/)
└─ NO → ¿Lo necesitan 2+ modulos del MISMO BC?
         ├─ SI → BC-Local Shared (src/<BC>/Shared/)
         └─ NO → Dentro del modulo que lo usa
```

## Anti-Patron: BC Importando Shared de Otro BC

```yaml
# ❌ MAL: backoffice_services.yaml importando MoocEntityManagerFactory
services:
    Doctrine\ORM\EntityManager:
        factory: [ CodelyTv\Mooc\Shared\Infrastructure\Doctrine\MoocEntityManagerFactory, create ]
```

Si Backoffice necesita su propio EntityManager, debe tener su propio `BackofficeEntityManagerFactory` en `src/Backoffice/Shared/Infrastructure/Doctrine/`. Si el codigo es identico y ambos BCs lo necesitan, promover a monorepo `src/Shared/Infrastructure/Doctrine/`.

Para scaffolding y validacion de la estructura Shared en dos niveles, consulta la skill `ddd-shared-kernel`.
