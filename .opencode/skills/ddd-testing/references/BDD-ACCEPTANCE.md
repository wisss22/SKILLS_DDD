# Tests BDD / Aceptación

Los tests de aceptación BDD (Behavior-Driven Development) verifican el sistema **desde fuera** — simulando interacciones reales de usuario a través del stack completo. Usan escenarios en lenguaje natural que los stakeholders no técnicos pueden leer.

## Dónde Encajan los Tests de Aceptación

```
        /\
       /BDD\           ← Prueba el ciclo completo HTTP request → response
      /------\
     /  Int.  \        ← Prueba adaptadores con infraestructura real
    /----------\
   /   Unit     \      ← Prueba lógica de negocio aislada
  /--------------\
 /  Arquitectura  \    ← Prueba reglas de dependencia
/__________________\
```

## Estructura de Tests (Gherkin / Archivos Feature)

```gherkin
Feature: Create a course

  Scenario: Create a valid course
    Given I send a POST request to "/api/courses" with body:
      """
      {
        "id": "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d",
        "name": "DDD in Practice",
        "duration": 120
      }
      """
    Then the response status code should be 201
    And the response should be empty

  Scenario: Reject a course with an empty name
    Given I send a POST request to "/api/courses" with body:
      """
      {
        "id": "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d",
        "name": "",
        "duration": 120
      }
      """
    Then the response status code should be 400
    And the response should contain "Course name cannot be empty"

  Scenario: Reject a duplicate course
    Given there is a course with ID "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d"
    When I send a POST request to "/api/courses" with body:
      """
      {
        "id": "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d",
        "name": "Another Course",
        "duration": 60
      }
      """
    Then the response status code should be 409
```

## Definiciones de Pasos / Contexto

El contexto de test traduce los pasos en lenguaje natural a llamadas API y aserciones:

```pseudocode
class ApiContext:
    property client: HttpClient
    property response: Response
    property baseUrl: string

    method setUp():
        # Bootstrap the real application (test environment)
        self.client = new HttpClient(self.baseUrl)
        # Clean database before each scenario
        databaseCleaner.truncateAll()

    # Given steps — set up preconditions
    method givenThereIsACourse(id: string):
        # Can use the API itself or direct DB insertion for setup
        self.sendRequest("POST", "/api/courses", {
            id: id,
            name: "Existing Course",
            duration: 60
        })

    # When steps — execute the action
    method iSendAPostRequestTo(path: string, body: string):
        self.response = self.client.post(
            self.baseUrl + path,
            json: JSON.parse(body)
        )

    # Then steps — assert the outcome
    method theResponseStatusCodeShouldBe(status: int):
        assert self.response.statusCode == status

    method theResponseShouldBeEmpty():
        assert self.response.body == "" or self.response.body is null

    method theResponseShouldContain(expected: string):
        assert self.response.body.contains(expected)
```

## Configuración de Tests

Los tests de aceptación necesitan su propia configuración de aplicación:

```yaml
# Test environment configuration
database:
  driver: test_database    # In-memory or dedicated test DB
  name: app_test

event_bus:
  driver: in_memory        # No real message broker in tests

logging:
  level: error              # Minimal logging
```

## Cuándo Escribir Tests BDD

| Escribe BDD para | No escribas BDD para |
|---|---|
| Flujos de trabajo principales de cara al usuario | Cada caso límite (los tests unitarios los cubren) |
| Verificación de contrato de API | Detalles internos de implementación |
| Integración entre módulos | Consultas de repositorio (los tests de integración las cubren) |
| Happy path + errores críticos | Errores de validación menores |

## Errores Comunes

1. **Demasiados tests BDD**: BDD para cada acción de controlador (lento, difícil de mantener)
2. **Sin aislamiento de base de datos**: Los tests dependen de datos de tests anteriores
3. **Testear todo a través de la UI**: Los tests de UI son frágiles; prefiere BDD a nivel de API
4. **Definiciones de pasos con lógica de negocio**: Los pasos solo deben enviar requests y verificar responses
5. **Falta de limpieza**: El estado de la base de datos se filtra entre escenarios
6. **Escribir escenarios BDD después del código**: Derrota el propósito de BDD (debería guiar el desarrollo)
