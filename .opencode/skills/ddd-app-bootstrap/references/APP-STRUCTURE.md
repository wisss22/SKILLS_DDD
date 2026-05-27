# Estructura de la App Backend

Cada app backend de un Bounded Context sigue una estructura estandarizada para garantizar aislamiento, consistencia y escalabilidad independiente.

## Arbol Completo

```
apps/<bc>/backend/
├── bin/
│   └── console              # Punto de entrada CLI
├── config/
│   ├── bundles.php          # Registro de modulos/frameworks
│   ├── services.yaml        # Configuracion DI principal
│   ├── services_test.yaml   # Overrides para entorno de test
│   ├── routes/              # Definicion de rutas (una por modulo)
│   │   ├── health-check.yaml
│   │   └── <module>.yaml
│   └── services/            # Configuracion especifica del framework
│       └── framework.yaml
├── public/
│   └── index.php            # Punto de entrada HTTP
├── src/
│   ├── <BC>BackendKernel.php   # Kernel propio del BC
│   ├── Controller/          # Controladores agrupados por modulo
│   │   ├── <Module>/
│   │   │   └── <Action>Controller.php
│   │   └── HealthCheck/
│   │       └── HealthCheckGetController.php
│   └── Command/             # Comandos de consola
│       └── DomainEvents/
│           └── ConsumeDomainEventsCommand.php
├── tests/                   # Tests de aceptacion / BDD
│   └── features/
│       └── <module>/
│           └── <feature>.feature
└── var/                     # Cache, logs, archivos temporales
    └── .gitkeep
```

## Descripcion por Carpeta

### `bin/console`

Script ejecutable de linea de comandos. Arranca el bootstrap compartido, instancia el Kernel del BC y ejecuta la aplicacion de consola.

**Por que existe:** Cada BC necesita sus propios comandos administrativos, workers de eventos, y tareas cron. Al tener un `console` independiente, se evitan conflictos de configuracion y se permite desplegar solo el binario necesario.

**Equivalentes en otros frameworks:**
- Laravel: `artisan`
- Spring Boot: `Application` con `CommandLineRunner`
- Node.js/Express: `cli.js` con `commander` o `yargs`

### `config/`

Contiene toda la configuracion del framework y del contenedor DI para este BC.

**Por que existe:** La configuracion de un BC no debe mezclarse con la de otro. El backoffice puede usar Elasticsearch mientras que Mooc usa RabbitMQ. Separar `config/` permite definir adaptadores distintos sin afectar al otro BC.

#### `config/bundles.php`
Registra que modulos del framework estan activos. Permite cargar modulos de test (ej. BehatExtension) solo en el entorno `test`.

#### `config/services.yaml`
Configuracion principal de DI. Define:
- `_defaults`: auto-registro y auto-configuracion
- `_instanceof`: tagging automatico de handlers y subscribers
- Auto-registro de `Controller/` y `Command/`
- Wiring de `src/Shared/` y `src/<BC>/`
- Definicion manual de adaptadores (RabbitMQ, Elasticsearch, Prometheus)
- **Implementation Selector**: alias de puertos (interfaces) a adaptadores concretos

#### `config/services_test.yaml`
Overrides que solo aplican en entorno de test. Tipicamente:
- Activa modo test del framework
- Sustituye adaptadores externos por implementaciones in-memory
- Carga clases de test desde la carpeta central `tests/`

#### `config/routes/`
Archivos YAML dedicados por modulo. Cada archivo define rutas para un dominio funcional.

**Regla:** Las rutas NUNCA van como anotaciones en los controllers. Esto desacopla la URL del codigo PHP y permite cambiar rutas sin tocar la logica de entrada.

#### `config/services/`
Configuracion adicional del framework (secretos, sesiones, manejo de errores). Se carga mediante glob para mantener `services.yaml` limpio.

### `public/index.php`

Unico archivo accesible desde la web. Actua como **front controller**.

**Flujo:**
1. Requiere `apps/bootstrap.php`
2. Habilita debug si el entorno lo indica
3. Configura proxies y hosts confiables (seguridad)
4. Instancia el Kernel del BC
5. Crea la Request desde globals
6. El Kernel procesa la Request y devuelve una Response
7. Envía la Response al cliente

**Equivalentes en otros frameworks:**
- Laravel: `public/index.php`
- Spring Boot: `ServletInitializer` o `main` embebido
- Node.js: `server.js` o `app.js` que escucha un puerto

### `src/`

Codigo fuente de la **capa de entrypoints** para este BC.

**Contenido permitido:**
- `<BC>BackendKernel.php` — Bootstrapper del contenedor
- `Controller/` — Puntos de entrada HTTP (API y/o Web)
- `Command/` — Puntos de entrada CLI

**Contenido PROHIBIDO:**
- Entidades de dominio
- Value objects
- Casos de uso (CommandHandlers, QueryHandlers)
- Repositorios (ni interfaces ni implementaciones)
- Logica de negocio de ningun tipo

**Por que existe `src/` dentro de la app:** Aunque parece redundante con `src/` del proyecto, mantiene la convencion de que cada aplicacion tiene su propio codigo fuente. En Symfony, `src/` es donde el framework espera encontrar clases PHP propias de la aplicacion.

### `tests/`

Tests de aceptacion end-to-end que ejecutan la app real con su kernel.

En el proyecto Codely se usa **Behat** con la extension de Symfony. Cada `.feature` describe un escenario de usuario que atraviesa capa HTTP → Controller → Bus → Handler → Dominio.

**Nota:** No es obligatorio que cada app tenga `tests/`. Pueden centralizarse en `tests/Apps/<BC>/` o usarse frameworks de testing distintos.

### `var/`

Archivos generados en runtime que no deben versionarse.

- Cache del contenedor DI compilado
- Logs de la aplicacion
- Sesiones (si aplica)

Siempre debe contener un `.gitkeep` y estar en `.gitignore`.

## Reglas de Dependencia en la App

```
Entrypoints (apps/<bc>/backend/src/)
  → Application (src/<BC>/Application/)
  → Domain (src/<BC>/Domain/)
  → Infrastructure (src/<BC>/Infrastructure/ y src/Shared/Infrastructure/)
```

Los controllers y comandos de la app dependen de las **interfaces** de Application (`CommandBus`, `QueryBus`, `EventBus`) que son resueltas por el contenedor DI. Nunca instancian infraestructura directamente.

## Errores Comunes

1. **Meter logica de dominio en `apps/`**: Un `CourseCreatorService` dentro de `apps/moc/backend/src/Service/`. Esto viola la regla de dependencia. Los casos de uso van en `src/Mooc/Courses/Application/Create/`.

2. **Compartir configuracion DI entre BCs**: Importar el `services.yaml` de otro BC genera acoplamiento. Cada BC debe tener su propio archivo de configuracion.

3. **Poner rutas como anotaciones en controllers**: Dificulta cambiar URLs sin modificar codigo PHP y mezcla configuracion con logica de entrada.

4. **Olvidar `services_test.yaml`**: Sin overrides de test, los tests de aceptacion intentan conectarse a RabbitMQ/Elasticsearch reales, haciendolos lentos y fragiles.

5. **No agrupar controllers por modulo**: Tener 50 controllers sueltos en `src/Controller/` dificulta la navegacion. Agrupar por modulo (`Courses/`, `Users/`) refleja la estructura del dominio.
