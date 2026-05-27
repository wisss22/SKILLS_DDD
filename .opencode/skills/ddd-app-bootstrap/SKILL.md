---
name: ddd-app-bootstrap
description: Scaffold y estructura base para crear una nueva app backend de un Bounded Context en arquitecturas DDD + Hexagonal. Genera kernels independientes, puntos de entrada HTTP/CLI, configuracion de inyeccion de dependencias, y estructura de rutas. Basado en Symfony explicado agnosticamente. Usar cuando se necesite crear una app/punto de entrada para un BC desde cero.
license: MIT
metadata:
  version: "1.0"
  part-of: ddd-backend
  source-inspiration: codelytv/php-ddd-example
---

# App Bootstrap para DDD + Hexagonal

Este skill genera el **scaffold completo** de una nueva aplicacion backend para un Bounded Context. NO contiene reglas de implementacion de domain, application o infrastructure; solo la estructura fisica, los puntos de entrada y el cableado base de DI.

## Cuando Usar Este Skill

| Escenario | Accion |
|---|---|
| Se necesita una nueva app para un BC que aun no tiene carpeta en `apps/` | Carga este skill |
| Se necesita agregar un nuevo entorno (ej. worker, api-v2) a un BC existente | Carga este skill y adapta |
| Ya existe la app y solo faltan controllers, comandos o consumidores | Usa `ddd-entrypoints` |

## Reglas Fundamentales

1. **`apps/<bc>/backend/src/` SOLO contiene entrypoints.** Controllers, comandos CLI y consumidores. NUNCA logica de dominio, casos de uso ni repositorios.
2. **La logica de dominio vive en `src/<BC>/`.** La carpeta `src/` del proyecto (fuera de `apps/`) es el nucleo del bounded context.
3. **Un bounded context = un kernel independiente.** Cada app tiene su propio bootstrap, contenedor DI y configuracion. Nunca compartir un kernel entre BCs.
4. **Rutas separadas de controladores.** Las rutas se definen en archivos dedicados (`config/routes/`), nunca como anotaciones dentro de los controllers.
5. **`services.yaml` importa la configuracion DI del BC.** Desde `src/<BC>/Shared/Infrastructure/DependencyInjection/` (o equivalente en tu framework).
6. **`apps/bootstrap.php` es compartido.** Carga autoloader y variables de entorno. Cada app lo reusa, pero cada app tiene su propio Kernel.

## Glosario Agnostico

Este skill usa Symfony como referencia concreta, pero cada pieza tiene su equivalente en cualquier framework:

| Pieza Symfony | Nombre Agnostico | Responsabilidad |
|---|---|---|
| `Kernel` | Application Bootstrapper / App Container | Arranca el contenedor DI, carga modulos, resuelve dependencias |
| `bundles.php` | Module Registry / Plugin Manifest | Lista de modulos/framework a cargar segun entorno |
| `services.yaml` | Dependency Injection Configuration | Reglas de auto-registro, tagging y wiring de clases |
| `bin/console` | CLI Entrypoint | Script ejecutable que arranca el kernel y recibe comandos de terminal |
| `public/index.php` | HTTP Entrypoint | Script web que arranca el kernel y maneja request/response |
| `config/routes/*.yaml` | Route Definitions / URL Mapping | Mapeo de URLs a controllers, separado por modulo |
| `var/` | Cache / Logs / Temp | Archivos generados en runtime (cache de contenedor, logs) |

## Estructura de Carpetas Generada

```
apps/
├── bootstrap.php                    # Bootstrap compartido (autoloader + .env)
└── <bc>/
    └── backend/
        ├── bin/
        │   └── console              # Punto de entrada CLI
        ├── config/
        │   ├── bundles.php          # Registro de modulos
        │   ├── services.yaml        # DI principal
        │   ├── services_test.yaml   # Overrides para test
        │   ├── routes/              # Definicion de rutas
        │   │   ├── health-check.yaml
        │   │   └── <module>.yaml
        │   └── services/
        │       └── framework.yaml   # Configuracion especifica del framework
        ├── public/
        │   └── index.php            # Punto de entrada HTTP
        ├── src/
        │   ├── <BC>BackendKernel.php
        │   ├── Controller/          # Agrupados por modulo
        │   └── Command/             # Comandos de consola
        ├── tests/                   # Tests de aceptacion (Behat, Cypress, etc.)
        └── var/                     # Cache/logs
```

## Tabla de Enrutamiento Interno

| Tarea | Referencia / Template |
|---|---|
| Entender por que cada BC tiene su propio kernel y entrypoints | [references/MULTI-KERNEL.md](references/MULTI-KERNEL.md) |
| Entender el proposito de cada carpeta dentro de la app | [references/APP-STRUCTURE.md](references/APP-STRUCTURE.md) |
| Configurar inyeccion de dependencias (tagging, auto-registro, aliases) | [references/DI-WIRING.md](references/DI-WIRING.md) |
| Configurar rutas y conectarlas con controllers | [references/ROUTES-AND-ENTRYPOINTS.md](references/ROUTES-AND-ENTRYPOINTS.md) |
| Duda sobre si algo va en la app o en el BC | `ddd-backend` → [../ddd-backend/references/DECISION-TREE.md](../ddd-backend/references/DECISION-TREE.md) |

## Templates Disponibles

Copia desde [assets/templates/](assets/templates/) para scaffolding rapido:

| Template | Archivo Generado |
|---|---|
| [assets/templates/Kernel.php](assets/templates/Kernel.php) | `src/<BC>BackendKernel.php` |
| [assets/templates/bootstrap.php](assets/templates/bootstrap.php) | `apps/bootstrap.php` (compartido) |
| [assets/templates/console](assets/templates/console) | `bin/console` |
| [assets/templates/index.php](assets/templates/index.php) | `public/index.php` |
| [assets/templates/services.yaml](assets/templates/services.yaml) | `config/services.yaml` |
| [assets/templates/routes.yaml](assets/templates/routes.yaml) | `config/routes/<module>.yaml` |

## Diagrama de Arquitectura Multi-App

Consulta [assets/diagrams/multi-app-architecture.mermaid](assets/diagrams/multi-app-architecture.mermaid) para una vista visual del flujo entre `src/`, `apps/` y multiples kernels.

## Script de Validacion

Ejecuta [scripts/validate-app-structure.sh](scripts/validate-app-structure.sh) para verificar que la estructura de `apps/` siga la convencion de un bounded context por app.

## Habilidades Relacionadas

| Tarea | Cargar |
|---|---|
| Crear controllers, comandos CLI o consumidores dentro de la app ya scaffolded | `ddd-entrypoints` |
| Crear commands/queries que despacharan desde los entrypoints | `ddd-cqrs-events` |
| Crear adaptadores de persistencia/mensajeria a cablear en DI | `ddd-infrastructure` |
| Probar la app de extremo a extremo | `ddd-testing` |
| Crear entidades, value objects, aggregates del BC | `ddd-domain-patterns` |
