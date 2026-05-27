# Monitoreo

El monitoreo proporciona **observabilidad** del comportamiento de tu aplicación. En la arquitectura DDD + Hexagonal, el monitoreo se implementa como un **decorador** que envuelve puertos (EventBus, Repository, etc.) para recolectar métricas sin acoplar el código de dominio a la infraestructura de monitoreo.

## Qué Monitorear

| Qué | Tipo de Métrica | Por Qué |
|---|---|---|
| Conteo de publicaciones del EventBus | Counter | Seguir el rendimiento de eventos |
| Duración de publicación del EventBus | Histogram | Detectar publicación lenta de eventos |
| Conteo de ejecución de CommandHandler | Counter | Seguir la frecuencia de casos de uso |
| Duración de ejecución de CommandHandler | Histogram | Detectar casos de uso lentos |
| Errores de CommandHandler | Counter | Alertar sobre fallos |
| Conteo de consultas de Repository | Counter | Seguir la carga de base de datos |
| Duración de consultas de Repository | Histogram | Detectar consultas lentas |
| Conteo de solicitudes HTTP | Counter | Seguir el tráfico de API |
| Duración de solicitudes HTTP | Histogram | Detectar endpoints lentos |
| Profundidad de cola (consumidores de eventos) | Gauge | Detectar acumulación de procesamiento |

## Puerto de Monitoreo (Capa de Dominio)

Define una interfaz de monitoreo como un puerto en la capa de Dominio:

```pseudocode
interface Monitor:
    method incrementCounter(name: string, labels: map): void
    method recordGauge(name: string, value: float, labels: map): void
    method recordDuration(name: string, duration: Duration, labels: map): void
```

## Adaptador de Monitoreo (Capa de Infraestructura)

Implementa el puerto de monitoreo con un sistema de monitoreo específico:

```pseudocode
// Prometheus adapter
class PrometheusMonitor implements Monitor:
    property registry: CollectorRegistry
    property counters: map[string, Counter]
    property histograms: map[string, Histogram]

    method incrementCounter(name, labels = {}):
        counter = self.getOrCreateCounter(name)
        counter.inc(labels)

    method recordGauge(name, value, labels = {}):
        gauge = self.getOrCreateGauge(name)
        gauge.set(value, labels)

    method recordDuration(name, duration, labels = {}):
        histogram = self.getOrCreateHistogram(name)
        histogram.observe(duration.toSeconds(), labels)
```

## Decoradores Monitoreados

### EventBus Monitoreado

```pseudocode
class MonitoredEventBus implements EventBus:
    property wrapped: EventBus
    property monitor: Monitor

    method publish(events): void
        if events.isEmpty():
            return

        start = now()
        try:
            self.wrapped.publish(events)
            duration = now() - start

            // Record success metrics
            for event in events:
                self.monitor.incrementCounter("event_published_total", {
                    event_type: event.eventName()
                })

            self.monitor.recordDuration("event_publish_duration_seconds", duration, {
                event_count: events.length.toString()
            })
        catch error:
            self.monitor.incrementCounter("event_publish_errors_total", {
                error_type: error.type
            })
            throw error
```

### CommandBus Monitoreado

```pseudocode
class MonitoredCommandBus implements CommandBus:
    property wrapped: CommandBus
    property monitor: Monitor

    method dispatch(command): void
        commandType = command.constructor.name
        start = now()

        try:
            self.wrapped.dispatch(command)
            duration = now() - start

            self.monitor.incrementCounter("command_dispatched_total", {
                command: commandType
            })
            self.monitor.recordDuration("command_dispatch_duration_seconds", duration, {
                command: commandType
            })
        catch error:
            self.monitor.incrementCounter("command_dispatch_errors_total", {
                command: commandType,
                error: error.type
            })
            throw error
```

### Repository Monitoreado

```pseudocode
class MonitoredCourseRepository implements CourseRepository:
    property wrapped: CourseRepository
    property monitor: Monitor

    method findById(id): Course?
        start = now()
        result = self.wrapped.findById(id)
        duration = now() - start
        self.monitor.recordDuration("repository_find_by_id_duration_seconds", duration, {
            repository: "course",
            found: result != null ? "true" : "false"
        })
        return result

    method save(course): void
        start = now()
        self.wrapped.save(course)
        duration = now() - start
        self.monitor.recordDuration("repository_save_duration_seconds", duration, {
            repository: "course"
        })
```

## Endpoint de Métricas

Expón las métricas para su recolección por Prometheus o similar:

```pseudocode
class MetricsController:
    property monitor: PrometheusMonitor

    method getMetrics(): Response
        metrics = self.monitor.registry.render()
        return Response(
            status: 200,
            body: metrics,
            contentType: "text/plain"
        )
```

```yaml
# Route configuration
metrics:
    path: /metrics
    controller: MetricsController.getMetrics
    methods: GET
```

## Dashboard de Grafana (Paneles Clave)

```
Dashboard: Event-Driven Architecture

Panel 1: Event Publishing Rate
  - Graph: rate(event_published_total[5m]) by event_type
  - Alert if rate drops to 0

Panel 2: Event Publishing Duration
  - Graph: histogram_quantile(0.95, event_publish_duration_seconds)
  - Alert if p95 > 1 second

Panel 3: Command Dispatch Rate
  - Graph: rate(command_dispatched_total[5m]) by command

Panel 4: Command Errors
  - Graph: rate(command_dispatch_errors_total[5m]) by command, error
  - Alert if any error rate > 0

Panel 5: Queue Depth (event consumers)
  - Graph: rabbitmq_queue_messages by queue
  - Alert if depth > 1000

Panel 6: Repository Performance
  - Graph: histogram_quantile(0.99, repository_save_duration_seconds)
```

## Errores Comunes

1. **Sin monitoreo**: ejecutar en producción con cero observabilidad
2. **Monitoreo en código de dominio**: entidades de dominio llamando al monitor directamente (usa decoradores)
3. **Etiquetas de alta cardinalidad**: usar IDs de eventos o IDs de usuario como etiquetas de métricas (sobrecarga la base de datos de series temporales)
4. **Sin seguimiento de errores**: solo monitorear rutas de éxito, faltan métricas de fallo
5. **Monitorear demasiado**: registrar cada llamada a método como métrica (costoso, ruidoso)
6. **Sin alertas**: las métricas existen pero no hay reglas de alerta configuradas
