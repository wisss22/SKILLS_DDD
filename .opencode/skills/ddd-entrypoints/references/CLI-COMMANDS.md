# Comandos CLI

Los comandos CLI son **puntos de entrada basados en consola** para trabajos en segundo plano, tareas cron, migraciones de datos, utilidades administrativas y consumidores de eventos. Siguen el mismo patrón de despacho que los controladores HTTP: analizar entrada, crear Command/Query, despachar al bus.

## Reglas Fundamentales

### 1. Mismo Patrón de Despacho que los Controladores

```pseudocode
class ImportCoursesCommand:
    property commandBus: CommandBus
    property logger: Logger

    method run(input): int
        filePath = input.getArgument("file")
        self.logger.info("Starting import from: " + filePath)

        data = self.parseFile(filePath)
        for row in data:
            command = new CreateCourseCommand(
                id: Uuid.generate(),
                name: row.name,
                duration: row.duration
            )
            self.commandBus.dispatch(command)

        self.logger.info("Import complete. " + data.length + " courses imported.")
        return 0  // Exit code: success
```

### 2. Comandos Consumidores de Eventos

Procesos de larga duración que consumen eventos de brokers de mensajes:

```pseudocode
class ConsumeRabbitMqDomainEventsCommand:
    property consumer: RabbitMqDomainEventsConsumer
    property logger: Logger

    method run(): int
        self.logger.info("Starting RabbitMQ domain event consumer...")
        try:
            self.consumer.consume()  // Blocks forever, processes messages
        catch error:
            self.logger.error("Consumer crashed: " + error.message)
            return 1  // Exit code: error
```

### 3. Supervisor / Gestión de Procesos

Los consumidores CLI se gestionan mediante supervisores de procesos en producción:

```ini
[program:domain_events_consumer]
command=php bin/console app:domain-events:rabbitmq:consume
process_name=%(program_name)s_%(process_num)02d
numprocs=3                          # 3 parallel consumers
autostart=true
autorestart=true
startsecs=5
startretries=10
redirect_stderr=true
stdout_logfile=/var/log/app/consumer.log
stderr_logfile=/var/log/app/consumer_error.log

# Restart if memory exceeds 100MB
stopasgroup=true
killasgroup=true
```

### 4. Comandos de Una Sola Vez / Cron

```pseudocode
class PublishDomainEventsFromMutationsCommand:
    property cdcProcessor: DatabaseMutationCdcProcessor

    method run(): int
        // Read unprocessed database mutations and convert to domain events
        count = self.cdcProcessor.process()
        self.logger.info("Published " + count + " events from mutations.")
        return 0
```

```cron
# Run every 10 seconds to publish outbox events
*/10 * * * * * php bin/console app:domain-events:publish-from-mutations
```

### 5. Comando de Configuración de RabbitMQ

```pseudocode
class ConfigureRabbitMqCommand:
    property configurer: RabbitMqConfigurer

    method run(): int
        // Creates exchanges and queues for all domain events
        // Runs once at deployment time
        self.configurer.configure(
            exchanges: ["mooc.course.created", "mooc.course.renamed", ...],
            queues: ["backoffice.create_course", "mooc.increment_counter", ...]
        )
        self.logger.info("RabbitMQ configured successfully.")
        return 0
```

### 6. Comandos de Mantenimiento de Datos

```pseudocode
class ImportCoursesToElasticsearchCommand:
    property mysqlRepository: CourseRepository
    property elasticsearchRepository: ElasticsearchCourseRepository
    property logger: Logger

    method run(): int
        // Re-index all courses from MySQL to Elasticsearch
        courses = self.mysqlRepository.all()
        for course in courses:
            self.elasticsearchRepository.save(course)
        self.logger.info("Indexed " + courses.length + " courses.")
        return 0
```

### 7. Generar Archivos de Configuración

```pseudocode
class GenerateSupervisorRabbitMqConsumerFilesCommand:
    property subscriberLocator: DomainEventSubscriberLocator

    method run(input): int
        outputDir = input.getArgument("output-dir")

        for subscriber in self.subscriberLocator.all():
            for eventType in subscriber.subscribedTo():
                config = self.generateSupervisorConfig(subscriber, eventType)
                writeFile(outputDir + "/" + subscriber.name + ".conf", config)

        self.logger.info("Supervisor configs generated in: " + outputDir)
        return 0
```

## Entrada/Salida de Comandos

```pseudocode
class SomeCommand:
    // Define arguments and options
    static configure():
        return {
            arguments: {
                "file": { required: true, description: "Path to the import file" }
            },
            options: {
                "dry-run": { shortcut: "d", description: "Run without persisting" },
                "batch-size": { shortcut: "b", default: 100 }
            }
        }

    method run(input, output): int
        filePath = input.getArgument("file")
        isDryRun = input.getOption("dry-run")
        batchSize = input.getOption("batch-size")

        output.writeln("Starting import...")
        if isDryRun:
            output.writeln("[DRY RUN] No changes will be persisted.")

        // ... process ...

        output.writeln("Done.")
        return 0  // 0 = success, 1 = error
```

## Errores Comunes

1. **Lógica de negocio en comandos**: Comandos CLI con más de 20 líneas de lógica de dominio
2. **Sin códigos de salida**: Siempre retornar 0 (el supervisor no puede detectar fallos)
3. **Sin registro de logs**: Ejecutándose en silencio sin forma de depurar
4. **Rutas hardcodeadas**: Rutas de archivos hardcodeadas en lugar de usar argumentos/opciones
5. **Sin opción de dry-run**: Comandos destructivos sin un modo de vista previa
6. **Bloquear el hilo principal**: Solicitudes HTTP de larga duración que deberían ser comandos CLI
