# Tests de Arquitectura

Los tests de arquitectura **hacen cumplir la regla de dependencia** y los límites de capa automáticamente. A diferencia de la revisión manual de código, se ejecutan en cada build y detectan violaciones de inmediato.

## ¿Por qué Tests de Arquitectura?

- Los desarrolladores olvidan las reglas con el tiempo
- Los nuevos miembros del equipo no conocen las convenciones
- El refactoring puede romper accidentalmente los límites de capa
- La revisión manual de código no escala

## Qué Verifican los Tests de Arquitectura

| Regla | Qué Verificar |
|---|---|
| **Aislamiento del dominio** | La capa de dominio no importa nada de Application, Infrastructure ni frameworks |
| **Dirección de dependencia** | Application importa de Domain (solo). Infrastructure importa de Application/Domain |
| **Convenciones de naming** | Las clases en `Domain/` no se nombran `*Service` (responsabilidad de Application) |
| **Patrón Repository** | Interfaces de Repository en Domain, implementaciones en Infrastructure |
| **Patrón Command/Query** | Commands nombrados `*Command`, Queries nombrados `*Query` |
| **Puerto/Adaptador** | Las clases de Infrastructure implementan interfaces de dominio |
| **Límites de módulo** | Los módulos no importan de otros módulos sin pasar por shared |

## Reglas de Arquitectura de Ejemplo

### Regla 1: El Dominio No Tiene Dependencias Externas

```pseudocode
// Architecture test pseudo-code
test "Domain layer depends on nothing external":
    for file in findFiles("src/**/Domain/**"):
        imports = extractImports(file)
        for import in imports:
            assert not import.contains("Infrastructure")
            assert not import.contains("framework")
            assert not import.contains("database.driver")
            assert not import.contains("http.client")
```

### Regla 2: Application Depende Solo de Domain

```pseudocode
test "Application layer depends only on Domain":
    for file in findFiles("src/**/Application/**"):
        imports = extractImports(file)
        for import in imports:
            assert import.contains("Domain") or import.contains("Shared")
            assert not import.contains("Infrastructure")
```

### Regla 3: Infrastructure Implementa los Puertos de Domain

```pseudocode
test "Repository implementations implement repository interfaces":
    for file in findFiles("src/**/Infrastructure/**/*Repository*"):
        classInfo = extractClass(file)
        interfaces = classInfo.implementedInterfaces
        assert interfaces.length > 0
        assert any(i.endsWith("Repository") for i in interfaces)
```

### Regla 4: Convención de Naming de CommandHandler

```pseudocode
test "Command handlers follow naming convention":
    for file in findFiles("src/**/Application/**/*Handler*"):
        className = extractClassName(file)
        assert className.endsWith("CommandHandler")
```

### Regla 5: Sin Dependencias Internas Entre Módulos

```pseudocode
test "Courses module does not import from Videos module directly":
    coursesFiles = findFiles("src/**/Courses/**")
    for file in coursesFiles:
        imports = extractImports(file)
        for import in imports:
            assert not import.contains("Mooc.Videos")
            // Unless it's a shared type
            if import.contains("Mooc.Shared"):
                continue  // Shared types are allowed
```

## Enfoques de Implementación

### Enfoque A: Librería de Testing de Arquitectura Específica

Usa una librería diseñada para testing de arquitectura que proporcione reglas declarativas:

```pseudocode
// Using a hypothetical architecture testing library
architectureTest("Domain rules"):
    layer("Domain").definedBy("src/**/Domain/**")
        .shouldOnlyDependOn()
        .layers("Shared/Domain")

    layer("Application").definedBy("src/**/Application/**")
        .shouldOnlyDependOn()
        .layers("Domain", "Shared")

    layer("Infrastructure").definedBy("src/**/Infrastructure/**")
        .shouldOnlyDependOn()
        .layers("Domain", "Application", "Shared")
```

### Enfoque B: Herramientas de Análisis Estático

Usa herramientas específicas del lenguaje. Ejemplos por lenguaje:
- **PHP**: PHPat, Deptrac, reglas personalizadas de PHPStan
- **Java**: ArchUnit
- **.NET**: NetArchTest
- **TypeScript**: dependency-cruiser, eslint-plugin-boundaries
- **Python**: import-linter, pytest-arch
- **Go**: go-cleanarch

## Errores Comunes

1. **Sin tests de arquitectura**: Las reglas existen solo en la documentación
2. **Demasiado estricto al principio**: Hacer cumplir cada regla desde el día 1 (empieza con reglas críticas, añade gradualmente)
3. **Tests demasiado complejos**: Tests de arquitectura difíciles de entender y mantener
4. **Permitir excepciones sin documentación**: `@SuppressWarnings("architecture")` sin explicar por qué
5. **No ejecutar en CI**: Los tests de arquitectura solo se ejecutan localmente (se olvidan)
