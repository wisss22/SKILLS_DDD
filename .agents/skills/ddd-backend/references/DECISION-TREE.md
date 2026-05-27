# Árbol de Decisión: ¿A Dónde Va Este Código?

Usa este árbol de decisión cuando no estés seguro de a qué capa o módulo pertenece un nuevo fragmento de código.

## Decisión Principal: ¿Qué Capa?

```
¿Cuál es la preocupación principal del código?
│
├─ REGLAS DE NEGOCIO PURAS (sin I/O, sin frameworks)
│  ├─ ¿Tiene una identidad única que persiste en el tiempo?   → Domain Entity
│  ├─ ¿Definido completamente por sus atributos, inmutable?   → Domain Value Object
│  ├─ ¿Representa algo que ocurrió (tiempo pasado)?           → Domain Event
│  ├─ ¿Coordina múltiples objetos de dominio (sin estado)?    → Domain Service
│  ├─ ¿Crea objetos de dominio complejos?                     → Domain Factory
│  └─ ¿Define un contrato de persistencia (solo interfaz)?    → Domain Repository (Port)
│
├─ CASOS DE USO / LÓGICA DE APLICACIÓN (orquesta dominio + efectos secundarios)
│  ├─ ¿Muta estado (operación de escritura)?                  → Command + CommandHandler
│  ├─ ¿Lee datos (operación de lectura)?                      → Query + QueryHandler
│  ├─ ¿Reacciona a un domain event?                           → Domain Event Subscriber
│  └─ ¿Coordina un flujo de trabajo con transacciones?         → Application Service
│
├─ INFRASTRUCTURE (sistemas externos, frameworks, I/O)
│  ├─ ¿Implementa una interfaz Repository?                    → Persistence Adapter
│  ├─ ¿Envía/recibe mensajes de un broker?                    → Messaging Adapter
│  ├─ ¿Envuelve otro componente con lógica transversal?       → Decorator
│  ├─ ¿Expone un endpoint HTTP?                               → Controller (en apps/)
│  ├─ ¿Se ejecuta como proceso en segundo plano?              → CLI Command (en apps/)
│  └─ ¿Conecta dependencias entre sí?                         → DI Configuration
│
└─ COMPARTIDO / TRANSVERSAL
   ├─ ¿Usado por múltiples bounded contexts?                  → Shared Kernel
   ├─ ¿Clases base para value objects, UUIDs, etc.?           → Shared Domain
   └─ ¿Clases base para repositories, buses, etc.?            → Shared Infrastructure
```

## Entity vs Value Object

```
¿Este concepto necesita...
│
├─ ¿Una identidad persistente (ID) que sigue lo mismo a lo largo del tiempo?
│  └─ SÍ → Es un ENTITY
│     - Igualdad por ID (mismo ID = misma entity)
│     - Estado mutable dentro de una transacción
│     - Ejemplo: User, Order, Course
│
├─ ¿Solo los valores de sus atributos para definir lo que es?
│  └─ SÍ → Es un VALUE OBJECT
│     - Igualdad por todos los atributos (mismos valores = iguales)
│     - Inmutable (reemplazar, no modificar)
│     - Sin identidad propia
│     - Ejemplo: Money, EmailAddress, DateRange, CourseName
│
└─ ¿Aún no estás seguro?
   ├─ ¿Alguna vez necesitarías rastrear cambios a esta cosa individualmente? → Entity
   ├─ ¿Puedes reemplazarla con otra instancia del mismo valor?                → Value Object
   └─ ¿Eliminar y recrear con los mismos valores cambia el significado?       → Entity si sí, VO si no
```

## Límites del Aggregate

```
¿Cómo decidir los límites del aggregate?
│
├─ ¿Se requiere CONSISTENCIA FUERTE (deben cambiar juntos atómicamente)?
│  └─ Mismo aggregate
│
├─ ¿Es aceptable CONSISTENCIA EVENTUAL (puede estar ligeramente desincronizado)?
│  └─ Aggregates separados, se comunican mediante domain events
│
├─ ¿Referenciado solo por ID desde otros aggregates?
│  └─ Aggregate separado
│
├─ ¿Más de ~8-10 entities dentro de un aggregate?
│  └─ Considera dividir
│
├─ ¿La entity hija tiene sentido sin el padre?
│  └─ Aggregate separado
│
└─ Regla general: Un aggregate = un límite de transacción
```

## Command vs Query

```
¿Esta operación...
│
├─ ¿Cambia el estado del sistema (crear, actualizar, eliminar)?
│  └─ COMMAND
│     - Nombrado imperativamente: CreateCourse, UpdateUser, DeleteOrder
│     - No devuelve nada (void) o confirmación mínima
│     - Pasa por CommandBus
│     - Un CommandHandler por Command
│
├─ ¿Lee el estado del sistema (obtener, buscar, listar)?
│  └─ QUERY
│     - Nombrado como pregunta: FindCourse, SearchUsers, GetAllOrders
│     - Siempre devuelve datos (Response DTO)
│     - Pasa por QueryBus
│     - Puede consultar modelos optimizados para lectura directamente
│
└─ ¿Tanto lectura como escritura?
   └─ Divide en operaciones separadas de Command + Query
```

## Port vs Adapter

```
│
├─ ¿Estoy definiendo QUÉ necesita el sistema del exterior?
│  └─ PORT (interfaz / contrato)
│     - Vive en la capa Domain o Application
│     - Sin implementación, sin imports de framework
│     - Ejemplos: CourseRepository (interfaz), EventBus (interfaz)
│
├─ ¿Estoy implementando CÓMO el sistema habla con el exterior?
│  └─ ADAPTER (implementación)
│     - Vive en la capa Infrastructure
│     - Implementa una interfaz Port
│     - Ejemplos: PostgresCourseRepository, RabbitMqEventBus
│
└─ Los Ports son "conducidos" por el núcleo de aplicación. Los Adapters "conducen" sistemas externos.
```

## ¿Qué Bounded Context?

```
¿Este concepto...
│
├─ ¿Es parte de la misma capacidad de negocio?
│  └─ Mismo bounded context
│
├─ ¿La misma palabra significa cosas diferentes en diferentes contextos?
│  └─ Bounded contexts separados (cada uno tiene su propio modelo)
│     Ejemplo: "Product" en Catálogo vs "Product" en Envíos
│
├─ ¿Cambia por diferentes razones de negocio?
│  └─ Bounded contexts separados
│
├─ ¿Necesita ser desplegado/escalado independientemente?
│  └─ Bounded context separado
│
└─ ¿Comunicación entre contextos?
   ├─ Domain Events (asíncrono, consistencia eventual)
   ├─ Llamadas API (síncrono, cuando se necesita consistencia inmediata)
   └─ Shared Kernel (solo para conceptos verdaderamente comunes)
```
