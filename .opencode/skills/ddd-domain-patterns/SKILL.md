---
name: ddd-domain-patterns
description: Patrones tácticos de Domain-Driven Design para construir modelos de dominio ricos. Usar al crear o modificar Entity, Value Object, Aggregate Root, Domain Event, interfaz Repository (puerto), Domain Service, Factory o Domain Error. Independiente del lenguaje y del framework.
license: MIT
metadata:
  version: "1.0"
  part-of: ddd-backend
---

# Patrones de Dominio DDD

Bloques de construcción tácticos de DDD para modelar dominios de negocio complejos. Estos patrones forman el **núcleo interno** de tu aplicación — la capa de Dominio no tiene dependencias externas.

## Recordatorio de la Regla de Dependencia

```
Infrastructure → Application → Domain
                              ↑
                         CERO dependencias externas
```

El código del dominio NO debe importar: librerías de base de datos, clientes HTTP, anotaciones de framework, formatos de serialización. Solo la biblioteca estándar de tu lenguaje y otros tipos del Dominio.

## Resumen de Patrones

| Pattern | Identity | Equality | Mutability | Repository |
|---|---|---|---|---|
| **Entity** | Tiene ID único | Por ID | Mutable dentro de TX | Parte del aggregate |
| **Value Object** | Sin identidad | Por todos los atributos | **Inmutable** | Ninguno |
| **Aggregate Root** | Tiene ID único | Por ID | Mutable dentro de TX | Uno por aggregate |
| **Domain Event** | Tiene ID de evento | N/A | **Inmutable** | Almacenado por el event bus |
| **Domain Service** | Ninguna | N/A | Sin estado | Ninguno |
| **Factory** | Ninguna | N/A | Sin estado | Ninguno |

## Reglas Rápidas

1. Los **Entities** tienen identidad y ciclo de vida. Usa constructores privados + métodos factory con nombre (ej., `Course.create()`, no `new Course()`).
2. Los **Value Objects** son inmutables. Reemplaza, no modifiques. `entity.name = new Name("x")`, no `entity.name.setValue("x")`.
3. Los **Aggregates** son límites de consistencia. Un aggregate por transacción. Referencia otros aggregates solo por ID.
4. Los **Domain Events** se nombran en tiempo pasado. Regístralos en el aggregate, publícalos después de la persistencia en el handler.
5. Las interfaces de **Repository** son puertos en la capa de Dominio. Una por aggregate root. Nunca por entity.
6. Los **Domain Services** son para lógica que no encaja en una sola entity (sin estado, involucrando múltiples aggregates o conceptos externos del dominio).
7. Las **Factories** encapsulan lógica de creación compleja. Usa métodos factory estáticos en las entities para casos simples.
8. Los **Domain Errors** son excepciones tipadas para violaciones de reglas de negocio. No para fallos técnicos.

## Archivos de Referencia

| Archivo | Contenido |
|---|---|
| [references/ENTITIES.md](references/ENTITIES.md) | Patrón Entity: identidad, ciclo de vida, comportamiento |
| [references/VALUE-OBJECTS.md](references/VALUE-OBJECTS.md) | Patrón Value Object: inmutabilidad, autovalidación, igualdad estructural |
| [references/AGGREGATES.md](references/AGGREGATES.md) | Diseño de Aggregate: límites de consistencia, límites de tamaño, referencias por ID |
| [references/DOMAIN-EVENTS.md](references/DOMAIN-EVENTS.md) | Domain Events: nomenclatura, registro, diseño de payload |
| [references/REPOSITORIES.md](references/REPOSITORIES.md) | Patrón Repository (puerto): interfaces por aggregate, métodos de consulta |
| [references/DOMAIN-SERVICES.md](references/DOMAIN-SERVICES.md) | Domain Services: lógica sin estado, cuándo usar vs métodos de entity |
| [references/FACTORIES.md](references/FACTORIES.md) | Patrón Factory: encapsulando creación compleja de objetos |
| [references/NAMING-CONVENTIONS.md](references/NAMING-CONVENTIONS.md) | Convenciones de nomenclatura: como nombrar modulos, aggregates, VOs, Commands, Queries, Controllers |

## Plantillas

Carga primero la skill `ddd-backend` para las plantillas base: [entity.pseudo](../ddd-backend/assets/templates/entity.pseudo), [value-object.pseudo](../ddd-backend/assets/templates/value-object.pseudo), [aggregate-root.pseudo](../ddd-backend/assets/templates/aggregate-root.pseudo), [domain-event.pseudo](../ddd-backend/assets/templates/domain-event.pseudo).

## Skills Relacionadas

| Tarea | Cargar |
|---|---|
| Necesitas patrones Command/Query para la capa de aplicación | `ddd-cqrs-events` |
| Necesitas probar objetos de dominio | `ddd-testing` |
| Necesitas organizar Shared Domain en dos niveles | `ddd-shared-kernel` |
| ¿No sabes dónde va el código? | Carga `ddd-backend` y usa su árbol de decisión |
