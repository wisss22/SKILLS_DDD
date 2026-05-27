---
name: ddd-shared-kernel
description: Scaffold y estructura para carpetas Shared en dos niveles de arquitectura DDD + Hexagonal. Shared Kernel de monorepo (src/Shared/) para codigo compartido entre todos los Bounded Contexts, y Shared local de BC (src/<BC>/Shared/) para codigo compartido entre modulos de un mismo BC. Incluye patrones de DI wiring por BC, EntityManager factories, doctypes scanners y validacion de estructura Shared. Usar al organizar codigo compartido entre bounded contexts o entre modulos de un mismo BC.
license: MIT
metadata:
  version: "1.0"
  part-of: ddd-backend
  source-inspiration: codelytv/php-ddd-example
---

# Shared Kernel para DDD + Hexagonal (Dos Niveles)

Este skill organiza el codigo compartido en **dos niveles** de la arquitectura. NO contiene reglas de implementacion de dominio; solo la estructura fisica, criterios de decision y patrones de infraestructura para carpetas Shared.

## El Problema: Dos Niveles de Shared

En monorepos DDD con multiples Bounded Contexts, aparece una necesidad recurrente: compartir codigo. Pero no todo lo compartido es igual:

```
src/
├── Shared/                 ← Nivel 1: Monorepo Shared Kernel (58 archivos en este proyecto)
│   └── Usado por TODOS los BCs (Mooc, Backoffice, Analytics, Retention...)
│
├── Mooc/
│   ├── Shared/             ← Nivel 2: BC-Local Shared (7 archivos en este proyecto)
│   │   └── Usado SOLO por modulos DENTRO de Mooc (Courses, Videos...)
│   ├── Courses/
│   └── Videos/
│
└── Backoffice/
    ├── Shared/             ← Nivel 2: BC-Local Shared (1 archivo en este proyecto)
    └── Courses/
```

**Cada nivel tiene reglas distintas.** Confundirlos lleva a anti-patrones como que Backoffice use `MoocEntityManagerFactory` (problema real en este proyecto).

## Cuando Usar Este Skill

| Escenario | Accion |
|---|---|
| Se necesita decidir si un tipo va en monorepo Shared o BC-local Shared | Carga este skill |
| Se necesita crear/scaffoldear la carpeta Shared de un BC nuevo | Carga este skill |
| Se necesita agregar un tipo compartido entre modulos de un BC | Carga este skill |
| El Shared existente tiene acoplamientos entre BCs (deuda tecnica) | Usa `references/BC-LOCAL-SHARED.md` |
| Crear el EntityManager factory, scanners y DI config de un BC | Copia desde `assets/templates/` |

## Reglas Fundamentales

1. **Monorepo Shared Domain = CERO dependencias externas.** Misma regla que la capa Domain de cualquier BC. Solo stdlib del lenguaje.
2. **BC-local Shared NUNCA debe ser importado por otro BC.** `Mooc\Shared\` solo se importa desde `Mooc\*`. Si Backoffice lo necesita, sube a monorepo Shared.
3. **Cada BC tiene su propio `*_services.yaml` y EntityManager factory.** No reutilizar factories entre BCs.
4. **Tipos concretos con semantica de BC van en BC-local Shared Domain** (ej: `CourseId` usado por `Courses` y `Videos`).
5. **Shared Infrastructure (monorepo) contiene adaptadores genericos** que cualquier BC puede instanciar con su propia configuracion.
6. **Los scanners/prefixers viven en BC-local Shared Infrastructure** porque escanean rutas especificas del BC (`src/<BC>/*`).

## Tabla de Decision: ¿A Donde Va Este Codigo?

```
¿Este codigo...
│
├─ ¿Es usado por 2+ Bounded Contexts DISTINTOS?
│  ├─ ¿Es abstracto/interfaz sin logica de negocio?  → src/Shared/Domain/
│  ├─ ¿Es implementacion concreta reutilizable?       → src/Shared/Infrastructure/
│  └─ ¿Tiene semantica de un solo BC?                 → NO compartir (va en ese BC)
│
├─ ¿Es usado por 2+ MODULOS dentro del MISMO BC?
│  ├─ ¿Es un tipo de dominio concreto (VO, ID)?       → src/<BC>/Shared/Domain/
│  ├─ ¿Es infraestructura/wiring del BC?              → src/<BC>/Shared/Infrastructure/
│  └─ ¿Es un puerto/interfaz del BC?                  → src/<BC>/Shared/Domain/ (o Application)
│
└─ ¿Es usado por UN solo modulo?
   └─ Vive dentro de ese modulo, no en Shared
```

## Estructura de Carpetas

```
src/
├── Shared/                              ← Nivel 1: Monorepo Shared
│   ├── Domain/
│   │   ├── Aggregate/AggregateRoot.php  ← Base de todos los aggregates
│   │   ├── ValueObject/Uuid.php         ← Base de UUIDs
│   │   ├── ValueObject/StringValueObject.php
│   │   ├── Bus/Command/CommandBus.php   ← Interfaz del bus de comandos
│   │   ├── Bus/Query/QueryBus.php       ← Interfaz del bus de queries
│   │   ├── Bus/Event/EventBus.php       ← Interfaz del bus de eventos
│   │   ├── Criteria/Criteria.php        ← Patron Criteria para queries
│   │   └── Logger.php                   ← Puerto de logging
│   └── Infrastructure/
│       ├── Bus/Command/InMemory*.php    ← Implementaciones de buses
│       ├── Bus/Event/RabbitMq/*.php     ← Adaptador RabbitMQ
│       ├── Persistence/Doctrine/*.php   ← Base repositorios Doctrine
│       ├── Symfony/ApiController.php    ← Base controllers HTTP
│       └── Logger/MonologLogger.php     ← Adaptador Monolog
│
└── <BC>/                                ← Nivel 2: BC-local Shared
    └── Shared/
        ├── Domain/
        │   └── <Module>/                 ← Tipos compartidos entre modulos del BC
        │       └── <SharedType>.php      ← ej: CourseId, VideoUrl
        └── Infrastructure/
            ├── Doctrine/
            │   ├── <BC>EntityManagerFactory.php
            │   ├── <BC>DoctrinePrefixesSearcher.php
            │   └── <BC>DbalTypesSearcher.php
            └── Symfony/
                └── DependencyInjection/
                    └── <bc>_services.yaml
```

## Archivos de Referencia

| Archivo | Contenido |
|---|---|
| [references/TWO-LEVEL-SHARED.md](references/TWO-LEVEL-SHARED.md) | Arquitectura de dos niveles explicada en detalle, comparativa, ejemplos concretos del proyecto |
| [references/BC-LOCAL-SHARED.md](references/BC-LOCAL-SHARED.md) | Patrones de BC-local Shared: DI wiring, EntityManager factories, scanners, anti-patrones |

## Templates Disponibles

| Template | Archivo Generado |
|---|---|
| [assets/templates/bc-services.yaml](assets/templates/bc-services.yaml) | `src/<BC>/Shared/Infrastructure/Symfony/DependencyInjection/<bc>_services.yaml` |
| [assets/templates/EntityManagerFactory.php](assets/templates/EntityManagerFactory.php) | `src/<BC>/Shared/Infrastructure/Doctrine/<BC>EntityManagerFactory.php` |
| [assets/templates/DoctrinePrefixesSearcher.php](assets/templates/DoctrinePrefixesSearcher.php) | `src/<BC>/Shared/Infrastructure/Doctrine/<BC>DoctrinePrefixesSearcher.php` |

## Diagrama de Arquitectura

Consulta [assets/diagrams/two-level-shared.mermaid](assets/diagrams/two-level-shared.mermaid) para vista visual de los dos niveles de Shared.

## Script de Validacion

Ejecuta [scripts/validate-shared-structure.sh](scripts/validate-shared-structure.sh) para detectar anti-patrones (ej: BC importando Shared de otro BC, Shared Domain con dependencias externas).

## Habilidades Relacionadas

| Tarea | Cargar |
|---|---|
| Crear entidades, VOs, aggregates que extienden de Shared Domain | `ddd-domain-patterns` |
| Crear adaptadores en Shared Infrastructure | `ddd-infrastructure` |
| Crear la app/entrypoint para un BC nuevo (que necesita su Shared) | `ddd-app-bootstrap` |
| Necesitas el decision tree completo de arquitectura | `ddd-backend` |
