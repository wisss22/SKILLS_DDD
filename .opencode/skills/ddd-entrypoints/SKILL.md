---
name: ddd-entrypoints
description: Patrones de punto de entrada para DDD + Arquitectura Hexagonal. Controladores HTTP (API y web), comandos CLI, consumidores de eventos, arranque de aplicación, cableado de inyección de dependencias y configuración de rutas. Independiente del lenguaje y del framework.
license: MIT
metadata:
  version: "1.0"
  part-of: ddd-backend
---

# Puntos de Entrada DDD

Los puntos de entrada son la **capa más externa** de la aplicación. Reciben solicitudes externas (HTTP, CLI, colas de mensajes) y las traducen en Commands y Queries que se despachan a la capa de Aplicación. Los puntos de entrada NO contienen lógica de negocio — son traductores delgados.

## Recordatorio de la Regla de Dependencia

```
Entry Points (apps/) → Application → Domain
```

Los puntos de entrada dependen DE la Aplicación (despachar commands, preguntar queries). Nunca llames repositories u objetos de dominio directamente desde los puntos de entrada.

## Descripción General de Patrones

| Punto de Entrada | Recibe | Despacha | Retorna |
|---|---|---|---|
| **API Controller** | Solicitud HTTP (JSON) | Command/Query al Bus | Respuesta HTTP (JSON) |
| **Web Controller** | Solicitud HTTP (formulario) | Command/Query al Bus | Respuesta HTML |
| **CLI Command** | Argumentos de consola/terminal | Command/Query al Bus | Salida de consola |
| **Event Consumer** | Mensaje del broker | Publica eventos al Bus | (Proceso en segundo plano) |

## Reglas Rápidas

1. **Los controladores son DELGADOS.** Analizar entrada, crear Command/Query, despachar al bus, formatear respuesta. Nunca lógica de negocio.
2. **Los API Controllers** extienden un `ApiController` base que proporciona métodos auxiliares `dispatch(command)` y `ask(query)`.
3. **Los Web Controllers** extienden un `WebController` base que añade renderizado de plantillas.
4. **Los CLI Commands** son para trabajos en segundo plano, tareas cron, utilidades administrativas. Mismo patrón de despacho que los controladores.
5. **Los Event Consumers** son procesos de larga duración que consumen eventos de RabbitMQ/Kafka y los publican al EventBus interno.
6. **Un bounded context = un kernel de aplicación.** Cada BC tiene su propio punto de entrada con su propia configuración de DI.
7. **La configuración de rutas** está separada de los controladores. Usar archivos de rutas, no anotaciones en controladores.

## Flujo del Punto de Entrada

```
HTTP Request
  → public/index.php
  → Application Kernel (arranca DI, carga rutas)
  → Router empareja Controller
  → Controller crea Command/Query DTO
  → Controller despacha al CommandBus o pregunta al QueryBus
  → Bus enruta al Handler (cableado vía DI)
  → Handler ejecuta el caso de uso
  → Controller formatea Response
```

## Archivos de Referencia

| Archivo | Contenido |
|---|---|
| [references/API-CONTROLLERS.md](references/API-CONTROLLERS.md) | Controladores API: clase base, enrutamiento, análisis de solicitudes, formateo de respuestas |
| [references/CLI-COMMANDS.md](references/CLI-COMMANDS.md) | Comandos CLI: puntos de entrada de consola, trabajos en segundo plano |
| [references/EVENT-CONSUMERS.md](references/EVENT-CONSUMERS.md) | Consumidores de eventos: configuración de broker, procesos de larga duración, configuración de supervisor |

## Habilidades Relacionadas

| Tarea | Cargar |
|---|---|
| Necesitas los commands/queries que se despachan | `ddd-cqrs-events` |
| Necesitas infraestructura para cablear en DI | `ddd-infrastructure` |
| Necesitas probar estos controladores de extremo a extremo | `ddd-testing` |
