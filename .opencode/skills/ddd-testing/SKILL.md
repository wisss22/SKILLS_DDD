---
name: ddd-testing
description: Patrones de testing para arquitecturas DDD + CQRS + Hexagonal. Patrón Object Mother para factorías de datos de prueba, tests unitarios para lógica de dominio y casos de uso, tests de integración para adaptadores de infraestructura, tests de arquitectura para hacer cumplir las reglas de dependencia, tests de aceptación BDD para escenarios end-to-end, y comparadores de test personalizados para objetos de dominio complejos. Independiente del lenguaje y del framework.
license: MIT
metadata:
  version: "1.0"
  part-of: ddd-backend
---

# Patrones de Testing para DDD

Estrategias de testing alineadas con DDD y Arquitectura Hexagonal. La separación de responsabilidades de la arquitectura hace que cada tipo de test sea claro y enfocado.

## Pirámide de Testing para DDD

```
        /\
       /BDD\           Tests de aceptación (escenarios end-to-end)
      /------\
     /  Int.  \        Tests de integración (repositorios, buses de eventos)
    /----------\
   /   Unit     \      Tests unitarios (lógica de dominio, casos de uso, handlers)
  /--------------\
 /  Arquitectura  \    Tests de arquitectura (reglas de dependencia, naming)
/__________________\
```

## Resumen de Patrones

| Tipo de Test | Prueba qué | Mockea qué | Velocidad |
|---|---|---|---|
| **Arquitectura** | Reglas de dependencia, límites de capa, naming | Nada (análisis estático) | Muy rápido |
| **Unitario** | Objetos de dominio, servicios de aplicación, handlers | Puertos de Repository, puertos de EventBus | Rápido |
| **Integración** | Implementaciones de Repository, implementaciones de Bus | Nada (infraestructura real) | Más lento |
| **BDD / Aceptación** | Caso de uso completo desde el punto de entrada hasta la persistencia | Nada (stack completo) | El más lento |

## Reglas Rápidas

1. **Object Mothers** para TODOS los datos de prueba. Nunca `new Entity(...)` en los cuerpos de los tests. Usa `EntityMother.random()`.
2. **Tests unitarios** extienden un test case específico del módulo que proporciona dependencias de puertos mockeadas.
3. **Tests de integración** extienden un test case de infraestructura que proporciona conexiones reales a base de datos/broker.
4. **Tests de arquitectura** se ejecutan primero. Detectan violaciones de capa antes de que pierdas tiempo en otros tests.
5. **Prueba el comportamiento, no la implementación.** Haz asserts sobre salidas y efectos secundarios, no sobre llamadas internas a métodos.
6. **Comparadores personalizados** para objetos de dominio. No dependas de la igualdad por defecto para aggregates con IDs/timestamps generados.
7. **Un concepto de aserción por test.** Prueba una regla de negocio por método de test.

## Archivos de Referencia

| Archivo | Contenido |
|---|---|
| [references/OBJECT-MOTHER.md](references/OBJECT-MOTHER.md) | Patrón Object Mother: estructura, MotherCreator, naming |
| [references/UNIT-TESTS.md](references/UNIT-TESTS.md) | Estructura de tests unitarios: test cases de módulo, mockeo de puertos |
| [references/INTEGRATION-TESTS.md](references/INTEGRATION-TESTS.md) | Tests de integración: adaptadores reales, setup/teardown de base de datos |
| [references/ARCHITECTURE-TESTS.md](references/ARCHITECTURE-TESTS.md) | Tests de arquitectura: reglas de dependencia, verificaciones de capa |
| [references/BDD-ACCEPTANCE.md](references/BDD-ACCEPTANCE.md) | Tests BDD / aceptación: archivos de feature, definiciones de pasos |
| [references/TEST-COMPARATORS.md](references/TEST-COMPARATORS.md) | Comparadores personalizados para aggregates, Domain Events, Value Objects |

## Skills Relacionadas

| Tarea | Cargar |
|---|---|
| Necesitas los patrones de dominio que se están probando | `ddd-domain-patterns` |
| Necesitas patrones CQRS para tests de handlers | `ddd-cqrs-events` |
| Necesitas infraestructura para tests de integración | `ddd-infrastructure` |
