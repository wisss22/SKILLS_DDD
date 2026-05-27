---
name: ddd-infrastructure
description: Patrones de adaptadores de infraestructura para DDD + Arquitectura Hexagonal. Los adaptadores de persistencia implementan los puertos de repositorio con bases de datos específicas. Los adaptadores de mensajería implementan los puertos de EventBus con brokers de mensajería específicos. Patrón Decorator para preocupaciones transversales como caché y monitoreo. Independiente del lenguaje y del framework.
license: MIT
metadata:
  version: "1.0"
  part-of: ddd-backend
---

# Patrones de Infraestructura DDD

La capa de infraestructura contiene **adaptadores** que implementan los **puertos** definidos en las capas de Dominio y Aplicación. Los adaptadores manejan preocupaciones externas: bases de datos, brokers de mensajería, caché, monitoreo — todo lo que toca el mundo exterior.

## Recordatorio de la Regla de Dependencia

```
Infrastructure → Application → Domain
```

La infraestructura depende DE las capas internas (implementa sus puertos). Las capas internas NO dependen de la infraestructura.

## Resumen de Patrones

| Patrón | Qué Implementa | Ubicación del Puerto |
|---|---|---|
| **Adaptador de Persistencia** | Interfaz Repository | Capa de Dominio |
| **Adaptador de Mensajería** | Interfaz EventBus | Capa de Dominio |
| **Adaptador Fachada** | Puerto de grano grueso que oculta múltiples dependencias técnicas | Capa de Aplicación |
| **Decorator** | Misma interfaz que envuelve | Capa de Dominio (puerto) |
| **Monitoreo** | Transversal (envuelve otros adaptadores) | Infraestructura |

## Reglas Rápidas

1. **Un adaptador por puerto.** Una interfaz de repositorio recibe una (o más) implementaciones concretas.
2. **Los adaptadores son dueños del mapeo.** Convierten entre objetos de dominio y formatos de persistencia. Los objetos de dominio no conocen las tablas ni los esquemas.
3. **Clases base para comportamiento común.** Crea clases base de Repository compartidas con lógica común (ej., `BaseDoctrineRepository`, `BaseElasticsearchRepository`).
4. **Los decoradores envuelven puertos de forma transparente.** Un decorador de caché o de monitoreo implementa el mismo puerto y delega en el adaptador real.
5. **Múltiples adaptadores por puerto.** Puedes tener implementaciones MySQL, Elasticsearch e InMemory de la misma interfaz Repository. Intercámbialas mediante configuración de DI.
6. **Prueba cada adaptador de forma aislada.** Cada implementación de adaptador tiene su propia prueba de integración.
7. **Usa puertos de grano grueso cuando un handler acumula 4+ dependencias técnicas.** Un solo puerto (ej. `DocumentAnalyzerPort`) reemplaza múltiples puertos de grano fino. El Adaptador Fachada oculta la orquestación técnica en Infraestructura. NUNCA ocultes servicios de dominio tras una fachada — deben ser explícitos en el constructor del Caso de Uso.

## Archivos de Referencia

| Archivo | Contenido |
|---|---|
| [references/PERSISTENCE.md](references/PERSISTENCE.md) | Adaptadores de persistencia: mapeo ORM, tipos personalizados, repositorio base |
| [references/MESSAGING.md](references/MESSAGING.md) | Adaptadores de mensajería: configuración de broker, serialización de eventos, consumidores |
| [references/DECORATOR-PATTERN.md](references/DECORATOR-PATTERN.md) | Patrón Decorator: caché, monitoreo, composición de adaptadores |
| [references/MONITORING.md](references/MONITORING.md) | Monitoreo: recolección de métricas, integración con Prometheus |
| [references/FACADE-PATTERN.md](references/FACADE-PATTERN.md) | Patrón Fachada: puertos de grano grueso, adaptadores compuestos, orquestación técnica vs de negocio |

## Skills Relacionadas

| Tarea | Cargar |
|---|---|
| Necesitas definir interfaces de repositorio (puertos) | `ddd-domain-patterns` |
| Necesitas la definición del EventBus | `ddd-cqrs-events` |
| Necesitas probar estos adaptadores | `ddd-testing` |
| Necesitas diseñar puertos de aplicación (grano grueso) | `ddd-domain-patterns` |
| Necesitas cablear adaptadores en la aplicación | `ddd-entrypoints` |
