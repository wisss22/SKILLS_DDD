# Multi-Kernel: Por que Cada BC Tiene su Propio Kernel

En arquitecturas DDD con multiples Bounded Contexts, la pregunta fundamental es: **¿por que no una sola app con un solo kernel?**

La respuesta es que cada Bounded Context es una **aplicacion autonoma** con sus propias necesidades de configuracion, escalado, despliegue y ciclos de vida.

## Comparativa: Monolitico vs Multi-Kernel

| Caracteristica | App Unica (Monolitico) | Multi-Kernel (Un BC = Un Kernel) |
|---|---|---|
| **Despliegue** | Todo junto; un cambio en un BC redepliega todo | Independiente; solo se redepliega el BC modificado |
| **Escalado** | Escalar todo o nada | Escalar solo el BC con alta carga (ej. solo Mooc, no Backoffice) |
| **Configuracion DI** | Unica; conflictos entre adaptadores de BCs distintos | Cada BC define sus adaptadores sin afectar a otros |
| **Arranque en test** | Carga TODOS los bundles de TODOS los BCs | Carga solo los bundles del BC que se esta probando |
| **Tiempo de boot** | Lento (mas bundles, mas rutas, mas servicios) | Rapido (solo lo necesario para ese BC) |
| **Aislamiento de fallos** | Un error en un BC puede afectar a otros | Un BC caido no afecta a los demas |
| **Complejidad inicial** | Menor | Mayor (se repite estructura por BC) |

## Diagrama de Dependencias Multi-App

```
+----------------------------------------------------------+
|                       Monorepo                           |
|                                                          |
|   src/                                                   |
|   ├── Shared/          ← Tipos base, interfaces de bus   |
|   ├── Mooc/            ← Logica de dominio y aplicacion  |
|   └── Backoffice/      ← Logica de dominio y aplicacion  |
|                                                          |
|   apps/                                                  |
|   ├── mooc/backend/    ← Kernel + Controllers + CLI      |
|   │      │                                               |
|   │      ▼                                               |
|   │   Carga: src/Shared + src/Mooc                       |
|   │   Adaptadores: RabbitMQ, MySQL, Prometheus           |
|   │                                                      |
|   └── backoffice/backend/  ← Kernel + Controllers + CLI  |
|          │                                               |
|          ▼                                               |
|       Carga: src/Shared + src/Backoffice                 |
|       Adaptadores: Elasticsearch, MySQL, Prometheus      |
|                                                          |
+----------------------------------------------------------+
```

Observa que:
- **Shared es el unico punto de acoplamiento intencional.** Ambos BCs dependen de `src/Shared/`, pero NUNCA uno del otro.
- **Cada app elige sus propios adaptadores.** Mooc publica eventos a RabbitMQ; Backoffice indexa cursos en Elasticsearch. Si ambos usaran el mismo kernel, la configuracion DI se volveria un espagueti de condicionales.
- **Cada app tiene sus propios entrypoints.** Mooc expone `PUT /courses/{id}`; Backoffice expone `GET /courses`. Pueden coexistir en el mismo servidor o en servidores separados.

## Flujo de una Peticion HTTP

```
Navegador / Cliente HTTP
    │
    ▼
public/index.php  (front controller del BC)
    │
    ├── Requiere apps/bootstrap.php (autoloader + .env)
    │
    ▼
Instancia <BC>BackendKernel(env, debug)
    │
    ├── Carga config/bundles.php
    ├── Compila contenedor DI desde config/services.yaml
    └── Carga rutas desde config/routes/
    │
    ▼
Router empareja URL → Controller
    │
    ▼
Controller crea Command/Query DTO
    │
    ▼
Despacha al CommandBus / pregunta al QueryBus
    │
    ▼
Bus resuelve Handler via DI
    │
    ▼
Handler ejecuta caso de uso (capa Application)
    │
    ▼
Controller formatea Response HTTP
    │
    ▼
Kernel termina request/response
```

## Flujo de un Comando CLI

```
Terminal
    │
    ▼
bin/console <command-name> [args]
    │
    ├── Requiere apps/bootstrap.php
    │
    ▼
Instancia <BC>BackendKernel
    │
    ▼
Aplicacion de consola resuelve comando
    │
    ▼
Comando crea Command/Query DTO
    │
    ▼
Despacha al Bus
    │
    ▼
Handler ejecuta caso de uso
    │
    ▼
Salida a stdout
```

## Por que un `bootstrap.php` Compartido

Aunque cada BC tiene su propio kernel, existe un `apps/bootstrap.php` compartido que:

1. **Carga el autoloader** (`vendor/autoload.php`) — es identico para todos los BCs.
2. **Lee variables de entorno** (`.env`) — el mismo archivo de configuracion de entorno aplica a todo el monorepo.
3. **Establece `APP_ENV` y `APP_DEBUG`** — valores por defecto consistentes.

**Equivalentes en otros frameworks:**
- Laravel: `bootstrap/app.php` compartido entre HTTP y CLI
- Spring Boot: `application.properties` compartido, pero multiples clases `@SpringBootApplication`
- Node.js: Un `dotenv.config()` compartido, pero multiples archivos `server.js` o `worker.js`

## Cuando NO Usar Multi-Kernel

- **Proyecto con un solo BC:** Si solo hay un bounded context, un unico kernel es suficiente y reduce complejidad.
- **Microservicios independientes:** Si cada BC ya vive en su propio repositorio y se despliega como servicio independiente, no necesitas multi-kernel; cada servicio es su propia app.
- **Equipos muy pequenos:** La sobrecarga de mantener N configuraciones de DI puede no valer la pena si el equipo no tiene capacidad.

## Regla de Oro

> Si tienes 2+ bounded contexts en el mismo repositorio (monorepo) y cada uno necesita adaptadores, rutas o configuracion distinta, usa multi-kernel. Si no, mantenlo simple con un solo kernel.
