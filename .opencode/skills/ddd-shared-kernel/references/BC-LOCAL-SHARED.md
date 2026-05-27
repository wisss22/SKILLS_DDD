# BC-Local Shared: Patrones y Anti-Patrones

El Shared local de un Bounded Context (`src/<BC>/Shared/`) contiene codigo que solo interesa a los modulos de ese BC. Sus patrones principales giran en torno a la configuracion de infraestructura.

## Estructura Tipica

```
src/<BC>/Shared/
├── Domain/
│   └── <Module>/                    ← Tipos compartidos entre modulos
│       └── <SharedType>.php
│
└── Infrastructure/
    ├── Doctrine/
    │   ├── <BC>EntityManagerFactory.php
    │   ├── <BC>DoctrinePrefixesSearcher.php
    │   └── <BC>DbalTypesSearcher.php
    └── Symfony/
        └── DependencyInjection/
            └── <bc>_services.yaml
```

## Patron 1: `*_services.yaml` (DI Wiring del BC)

Cada BC tiene su propio archivo de configuracion DI en `src/<BC>/Shared/Infrastructure/Symfony/DependencyInjection/<bc>_services.yaml`.

Este archivo es **importado** por el `services.yaml` de la app backend:

```yaml
# apps/<bc>/backend/config/services.yaml
imports:
  - { resource: '../../../../src/<BC>/Shared/Infrastructure/Symfony/DependencyInjection/<bc>_services.yaml' }
```

### Contenido tipico de `*_services.yaml`

```yaml
services:
  # ─── EntityManager del BC ───
  # Cada BC tiene su propio factory. NUNCA reutilizar el de otro BC.
  Doctrine\ORM\EntityManager:
    factory: [ CodelyTv\<BC>\Shared\Infrastructure\Doctrine\<BC>EntityManagerFactory, create ]
    arguments:
      - driver: '%env(<BC>_DATABASE_DRIVER)%'
        host: '%env(<BC>_DATABASE_HOST)%'
        port: '%env(<BC>_DATABASE_PORT)%'
        dbname: '%env(<BC>_DATABASE_NAME)%'
        user: '%env(<BC>_DATABASE_USER)%'
        password: '%env(<BC>_DATABASE_PASSWORD)%'
      - '%env(APP_ENV)%'
    tags:
      - { name: codely.database_connection }
    public: true

  # ─── Alias de repositorios (Implementation Selector) ───
  # Vincula la interfaz de dominio con la implementacion concreta.
  CodelyTv\<BC>\<Module>\Domain\<RepositoryInterface>:
    '@CodelyTv\<BC>\<Module>\Infrastructure\Persistence\<ConcreteRepository>'
```

### Por que existe

- Centraliza la configuracion de infraestructura del BC en un solo lugar
- Mantiene `apps/<bc>/backend/config/services.yaml` limpio y enfocado en entrypoints
- Permite que el BC sea testeable de forma aislada

## Patron 2: EntityManagerFactory del BC

Cada BC necesita su propio factory porque los modulos, prefijos Doctrine y custom types varian:

```php
// src/<BC>/Shared/Infrastructure/Doctrine/<BC>EntityManagerFactory.php
final class <BC>EntityManagerFactory
{
    private const string SCHEMA_PATH = __DIR__ . '/../../../../../../etc/databases/<bc>.sql';

    public static function create(array $parameters, string $environment): EntityManagerInterface
    {
        $isDevMode = $environment !== 'prod';

        // 1. Escanear prefijos Doctrine de ESTE BC
        $prefixes = array_merge(
            DoctrinePrefixesSearcher::inPath(
                __DIR__ . '/../../../../<BC>',
                'CodelyTv\<BC>'
            ),
            // Si el BC tambien necesita prefijos de otro BC (ej. Backoffice lee Mooc),
            // se agrega aqui. Pero lo ideal es que cada BC sea autonomo.
        );

        // 2. Escanear custom DBAL types de ESTE BC
        $dbalCustomTypesClasses = DbalTypesSearcher::inPath(
            __DIR__ . '/../../../../<BC>',
            '<BC>'
        );

        // 3. Delegar al factory generico del monorepo Shared
        return DoctrineEntityManagerFactory::create(
            $parameters,
            $prefixes,
            $isDevMode,
            self::SCHEMA_PATH,
            $dbalCustomTypesClasses
        );
    }
}
```

**Equivalente agnostico:**
- **Spring Boot:** Clase `@Configuration` con `@Bean` que crea `EntityManagerFactoryBean` + `@EnableJpaRepositories(basePackages = "...")`
- **NestJS:** `TypeOrmModule.forRoot()` con `entities: [...]` escaneando el BC
- **Laravel:** `Eloquent` models dentro del BC + `DatabaseServiceProvider` por BC

## Patron 3: DoctrinePrefixesSearcher

Escanea modulos del BC para descubrir archivos de mapeo Doctrine XML:

```php
// src/<BC>/Shared/Infrastructure/Doctrine/<BC>DoctrinePrefixesSearcher.php
final class DoctrinePrefixesSearcher
{
    public static function inPath(string $path, string $baseNamespace): array
    {
        $prefixes = [];

        // Busca recursivamente directorios de mapeo Doctrine
        // dentro de cada modulo: src/<BC>/*/Infrastructure/Persistence/Doctrine/
        foreach (glob($path . '/*', GLOB_ONLYDIR) as $moduleDir) {
            $module = basename($moduleDir);
            $possibleMappingDir = $moduleDir . '/Infrastructure/Persistence/Doctrine';

            if (is_dir($possibleMappingDir)) {
                $prefixes[$possibleMappingDir] = $baseNamespace . '\\' . $module . '\\Domain';
            }
        }

        return $prefixes;
    }
}
```

## Patron 4: DbalTypesSearcher

Escanea modulos del BC para descubrir custom DBAL types:

```php
// src/<BC>/Shared/Infrastructure/Doctrine/<BC>DbalTypesSearcher.php
final class DbalTypesSearcher
{
    public static function inPath(string $path, string $contextName): array
    {
        $types = [];

        // Busca archivos *Type.php en la carpeta de persistencia de cada modulo
        // ej: src/<BC>/Courses/Infrastructure/Persistence/Doctrine/CourseIdType.php
        foreach (glob($path . '/*/Infrastructure/Persistence/Doctrine/*Type.php') as $typeFile) {
            $typeClassName = self::classNameFromPath($typeFile, $contextName);
            $types[] = $typeClassName;
        }

        return $types;
    }

    private static function classNameFromPath(string $path, string $contextName): string
    {
        // Convierte ruta de archivo a FQCN
        // src/Backoffice/Courses/.../CourseIdType.php → CodelyTv\Backoffice\Courses\...\CourseIdType
    }
}
```

## Patron 5: Tipos de Dominio Compartidos entre Modulos

Cuando dos o mas modulos del mismo BC necesitan el mismo tipo:

```php
// src/Mooc/Shared/Domain/Courses/CourseId.php
// Usado por: src/Mooc/Courses/ y src/Mooc/Videos/
final class CourseId extends Uuid
{
    // Hereda value(), equals(), random() de Uuid (monorepo Shared)
}
```

```php
// src/Mooc/Shared/Domain/Videos/VideoUrl.php
final class VideoUrl extends StringValueObject
{
    public function __construct(string $value)
    {
        $this->ensureIsValidUrl($value);
        parent::__construct($value);
    }

    private function ensureIsValidUrl(string $url): void
    {
        if (false === filter_var($url, FILTER_VALIDATE_URL)) {
            throw new InvalidArgumentException(sprintf('<%s> is not a valid URL', $url));
        }
    }
}
```

## Anti-Patrones Comunes

### 1. BC importando Shared de otro BC

```php
// ❌ src/Backoffice/*/ usando CodelyTv\Mooc\Shared\...
use CodelyTv\Mooc\Shared\Infrastructure\Doctrine\MoocEntityManagerFactory;
```

**Solucion:** Cada BC tiene su propia factory, scanners y DI config.

### 2. Shared Domain del BC con dependencias externas

```php
// ❌ src/Mooc/Shared/Domain/*/ usando Doctrine, Symfony, etc.
use Doctrine\ORM\Mapping as ORM;
```

**Solucion:** BC-local Shared Domain solo depende de monorepo Shared Domain + stdlib.

### 3. Monorepo Shared dependiendo de un BC concreto

```php
// ❌ src/Shared/Infrastructure/Symfony/BasicHttpAuthMiddleware.php
use CodelyTv\Backoffice\Auth\Domain\InvalidAuthCredentials;

// Shared Infrastructure conoce una excepcion de Backoffice. Si Backoffice
// se elimina, Shared se rompe.
```

**Solucion:** Mover el middleware a `src/Backoffice/Shared/Infrastructure/Symfony/` o hacerlo generico (solo lanza excepciones propias de Shared).

### 4. BC-local Shared sin usar (carpeta vacia)

Si un BC solo tiene un modulo, no necesita `Shared/`. Las carpetas Shared solo se justifican cuando hay 2+ modulos.

### 5. DI config del BC sin Implementation Selector

```yaml
# ❌ services.yaml sin alias de repositorios
# Los casos de uso no pueden resolver la interfaz del repositorio.
```

**Solucion:** Siempre incluir alias de puertos a adaptadores en `*_services.yaml`.
