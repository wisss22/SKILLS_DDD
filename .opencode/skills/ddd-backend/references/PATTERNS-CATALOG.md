# Catálogo de Patrones

Catálogo completo de todos los patrones de diseño cubiertos por el ecosistema del skill `ddd-backend`. Cada patrón se asigna al sub-skill que contiene sus reglas detalladas de implementación.

## Patrones de la Capa Domain → `ddd-domain-patterns`

| Patrón | Qué Es | Cuándo Usarlo |
|---|---|---|
| **Entity** | Objeto con identidad única que persiste en el tiempo | Cuando el concepto tiene un ciclo de vida y la identidad importa |
| **Value Object** | Objeto inmutable definido por sus atributos | Cuando la igualdad se basa en todas las propiedades, sin identidad |
| **Aggregate Root** | Entity que es el punto de entrada a un límite de consistencia | Cuando un grupo de objetos debe ser consistente en conjunto |
| **Domain Event** | Registro inmutable de algo que ocurrió (tiempo pasado) | Cuando deben ocurrir efectos secundarios en otros aggregates/contextos |
| **Repository (Port)** | Interfaz que define operaciones de persistencia para un aggregate | Cuando el dominio necesita almacenar/recuperar aggregates |
| **Domain Service** | Operación sin estado que no pertenece a ninguna entity individual | Cuando la lógica involucra múltiples aggregates o conceptos externos del dominio |
| **Factory** | Crea objetos de dominio complejos | Cuando la creación de objetos tiene reglas o requiere múltiples pasos |
| **Domain Error** | Error tipado que representa una violación de regla de dominio | Cuando se violan reglas de negocio (no fallos técnicos) |
| **Specification** | Predicado que evalúa una regla de negocio | Cuando necesitas reglas de negocio componibles y reutilizables |

## Patrones de CQRS y Eventos → `ddd-cqrs-events`

| Patrón | Qué Es | Cuándo Usarlo |
|---|---|---|
| **Command** | Intención de cambiar estado (nomenclatura imperativa) | Para operaciones de escritura: Create, Update, Delete |
| **CommandHandler** | Ejecuta la lógica de negocio de un Command | Un handler por command, orquesta objetos de dominio |
| **CommandBus** | Enruta Commands a sus Handlers | Para desacoplar el despacho de commands de su ejecución |
| **Query** | Solicitud de datos (nomenclatura de pregunta) | Para operaciones de lectura: Find, Search, List |
| **QueryHandler** | Obtiene datos para un Query | Puede consultar modelos de lectura optimizados directamente |
| **QueryBus** | Enruta Queries a sus Handlers | Para desacoplar el despacho de queries de su ejecución |
| **EventBus** | Publica domain events a los suscriptores | Para notificar a otras partes del sistema sobre cambios |
| **DomainEventSubscriber** | Reacciona a un domain event específico | Para efectos secundarios entre aggregates o contextos |
| **CDC / Outbox** | Captura events desde cambios en la base de datos | Para garantizar la publicación confiable de events |
| **Criteria / Filters** | Filtros de consulta componibles + ordenación | Para búsqueda flexible sin filtrar detalles de persistencia |

## Patrones de Testing → `ddd-testing`

| Patrón | Qué Es | Cuándo Usarlo |
|---|---|---|
| **Object Mother** | Fábrica para crear datos de prueba con valores predeterminados sensatos | Siempre que necesites objetos de dominio en tests |
| **Mother Creator** | Generador central de valores aleatorios para mothers | Para tener datos de prueba aleatorios consistentes y realistas |
| **Unit Test** | Prueba una sola clase/caso de uso de forma aislada | Para lógica de dominio, servicios de aplicación, handlers |
| **Integration Test** | Prueba la interacción con infrastructure real | Para implementaciones de repository, event buses |
| **Architecture Test** | Prueba que el código sigue las reglas arquitectónicas | Para hacer cumplir la dirección de dependencias, límites de capas |
| **BDD / Acceptance Test** | Prueba el comportamiento desde fuera (caja negra) | Para escenarios de extremo a extremo, comportamiento de cara al usuario |
| **Test Comparator** | Igualdad personalizada para objetos de dominio complejos | Cuando la igualdad predeterminada no funciona para aserciones |

## Patrones de Infrastructure → `ddd-infrastructure`

| Patrón | Qué Es | Cuándo Usarlo |
|---|---|---|
| **Persistence Adapter** | Implementa un port Repository con una base de datos específica | Para almacenar/recuperar aggregates con bases de datos reales |
| **Messaging Adapter** | Implementa EventBus con un message broker específico | Para publicar/consumir events con message brokers reales |
| **Decorator** | Envuelve un componente para añadir comportamiento sin modificarlo | Para preocupaciones transversales: caché, logging, monitoreo |
| **Facade Adapter** | Implementa un puerto de grano grueso ocultando múltiples dependencias técnicas | Cuando un Caso de Uso acumula 4+ dependencias de infraestructura y la orquestación técnica es compleja |
| **Monitoring** | Recopila métricas sobre el comportamiento del sistema | Para observabilidad: conteo de events, duración de handlers |

## Patrones de Puntos de Entrada → `ddd-entrypoints`

| Patrón | Qué Es | Cuándo Usarlo |
|---|---|---|
| **API Controller** | Maneja peticiones HTTP, despacha a buses de Command/Query | Para endpoints de API REST/GraphQL |
| **Web Controller** | Maneja peticiones HTTP, renderiza respuestas HTML | Para páginas renderizadas en servidor |
| **CLI Command** | Punto de entrada para comandos de consola/terminal | Para trabajos en segundo plano, tareas cron, herramientas de administración |
| **Event Consumer** | Proceso de larga duración que consume events de un broker | Para procesamiento asíncrono de events desde RabbitMQ, Kafka, etc. |

## Patrones Transversales

| Patrón | Qué Es | Sub-Skill |
|---|---|---|
| **Dependency Injection** | Conecta ports a adapters al iniciar | `ddd-entrypoints` |
| **Shared Kernel** | Código compartido entre bounded contexts del mismo equipo: clases base, interfaces, utilidades | `ddd-backend` |
| **Module Structure** | Organiza el código por bounded context y módulos | Consulta `DECISION-TREE.md` |
| **Monorepo Structure** | Múltiples aplicaciones compartiendo código de dominio | `ddd-entrypoints` |

## Relación Entre Patrones

```
Entry Points (apps/)
    │  dispatch / ask
    ▼
CommandBus / QueryBus  ←── capa CQRS
    │  route
    ▼
CommandHandler / QueryHandler
    │  orchestrate
    ▼
Domain Objects (Entity, VO, Aggregate)  ←── capa Domain
    │  record / publish
    ▼
Domain Events  ──→  EventBus  ──→  DomainEventSubscribers
                                        │
                                        ▼
                                  Other Aggregates / Contexts
```
