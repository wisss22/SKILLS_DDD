# Patrón Fachada (Facade Adapter)

El **Patrón Fachada** resuelve el problema de **Constructor Over-Injection** en los Casos de Uso: cuando un handler acumula demasiadas dependencias técnicas de bajo nivel, se vuelve ilegible, difícil de testear y frágil ante cambios de infraestructura.

## El Problema: Constructor Over-Injection

```pseudocode
// MAL: Caso de Uso con sobreinyección de dependencias técnicas
class GenerateDigitalCloneUseCase:
    constructor(
        textExtractor: TextExtractorPort,           // OCR
        layoutDetector: LayoutDetectorPort,         // Detección de contenedores
        imageEnhancer: ImageEnhancerPort,           // Mejora de imagen
        fontMatcher: FontMatcherPort,               // Matching tipográfico
        documentRepository: DocumentRepositoryPort,
        eventBus: EventBus
    )
    // ↑ 6 dependencias. 4 son técnicas, no de negocio.
    // El Caso de Uso pierde expresividad: ¿qué hace realmente?
    // Tests requieren 4 mocks de infraestructura. Frágiles.

    method invoke(command):
        // El handler se llena de orquestación técnica
        enhancedImage = self.imageEnhancer.enhance(command.image)
        rawText = self.textExtractor.extract(enhancedImage)
        layouts = self.layoutDetector.detect(enhancedImage)
        fonts = self.fontMatcher.match(enhancedImage)
        // ... finalmente, aplicar lógica de negocio
```

**Síntomas:**
- El Caso de Uso supera las 4-5 dependencias.
- El constructor mezcla puertos de dominio con herramientas técnicas.
- Las pruebas unitarias requieren simular (mockear) demasiadas librerías externas.
- Cambiar una librería técnica obliga a modificar el Caso de Uso.

## La Solución: Puerto de Grano Grueso + Adaptador Fachada

El patrón se divide en dos conceptos que trabajan en conjunto a través de las capas:

### A. El Puerto de Grano Grueso (Capa de Aplicación)

En lugar de crear múltiples interfaces pequeñas (grano fino) para cada herramienta técnica, la capa de Aplicación define **un único contrato de alto nivel** (grano grueso).

```pseudocode
// Puerto de grano grueso: un solo contrato expresivo
interface DocumentAnalyzerPort:
    method analyze(image: Image): RawDocumentData
```

| Enfoque | Ejemplo | Dependencias en el Caso de Uso |
|---|---|---|
| **Puertos de grano fino** | `TextExtractorPort` + `LayoutDetectorPort` + `ImageEnhancerPort` + `FontMatcherPort` | 4 puertos técnicos |
| **Puerto de grano grueso** | `DocumentAnalyzerPort` | 1 puerto expresivo |

### B. El Adaptador Fachada (Capa de Infraestructura)

Es la implementación real del puerto. En su propio constructor inyecta todas las librerías de bajo nivel y oculta el flujo técnico de cómo interactúan entre sí.

```pseudocode
// El Adaptador Fachada: implementa el puerto, oculta la complejidad técnica
class ComprehensiveDocumentAnalyzer implements DocumentAnalyzerPort:
    property imageEnhancer: ImageEnhancer        // Librería externa
    property textExtractor: TextExtractor        // Librería externa
    property layoutDetector: LayoutDetector      // Librería externa
    property fontMatcher: FontMatcher            // Librería externa
    property logger: Logger

    constructor(imageEnhancer, textExtractor, layoutDetector, fontMatcher, logger):
        self.imageEnhancer = imageEnhancer
        self.textExtractor = textExtractor
        self.layoutDetector = layoutDetector
        self.fontMatcher = fontMatcher
        self.logger = logger

    method analyze(image: Image): RawDocumentData
        self.logger.info("Iniciando análisis de documento...")

        // Orquestación técnica: coordinar cómo las herramientas interactúan
        enhancedImage = self.imageEnhancer.enhance(image)
        rawText = self.textExtractor.extract(enhancedImage)
        layouts = self.layoutDetector.detect(enhancedImage)
        fonts = self.fontMatcher.match(enhancedImage)

        return new RawDocumentData(
            text: rawText,
            layouts: layouts,
            fonts: fonts,
            enhancedImage: enhancedImage
        )
```

### El Caso de Uso limpio (3 dependencias)

```pseudocode
class GenerateDigitalCloneUseCase:
    constructor(
        analyzer: DocumentAnalyzerPort,            // ← Fachada (1 puerto en vez de 4)
        repository: DocumentRepositoryPort,        // ← Puerto de dominio
        eventBus: EventBus                         // ← Puerto de dominio
    )
    // 3 dependencias. La intención es clara: analizar, persistir, notificar.

    method invoke(command: GenerateDigitalCloneCommand): void
        // 1. Obtener datos crudos del adaptador fachada
        rawData = self.analyzer.analyze(command.image)

        // 2. Aplicar reglas de dominio (Servicio de Dominio o Aggregate)
        document = DocumentAssembler.fromRawData(rawData, command.userId)
        document.validate()

        // 3. Persistir
        self.repository.save(document)

        // 4. Publicar events
        self.eventBus.publish(document.pullEvents())
```

## Las Dos Orquestaciones

El patrón establece una separación clara de responsabilidades entre dos tipos de orquestación:

| Tipo de Orquestación | Dónde Ocurre | Responsabilidad | Ejemplo |
|---|---|---|---|
| **Orquestación de Negocio** | Caso de Uso (Aplicación) | Coordina las fases lógicas para cumplir el objetivo del usuario. | 1. Analizar documento. 2. Aplicar reglas de dominio. 3. Guardar en BD. 4. Publicar events. |
| **Orquestación Técnica** | Adaptador Fachada (Infraestructura) | Coordina cómo las herramientas técnicas interactúan para generar un dato. | 1. Pasar por OpenCV. 2. Pasar por OCR. 3. Ejecutar detector de layouts. 4. Unir resultados en un DTO. |

> **Analogía:** El Caso de Uso es el gerente general (qué hay que hacer). El Adaptador Fachada es el supervisor técnico (cómo se hace).

## Cuándo USAR el Patrón Fachada

- El Caso de Uso requiere 4+ dependencias de infraestructura o librerías externas.
- Existe un flujo técnico multi-paso que no tiene significado de dominio por sí mismo.
- Necesitas poder cambiar librerías externas sin tocar el Caso de Uso (cumplimiento DIP).
- Las pruebas unitarias del Caso de Uso requieren simular demasiadas herramientas externas.

## Cuándo NO USAR el Patrón Fachada

| Situación | Solución Correcta | Por Qué |
|---|---|---|
| **Múltiples dependencias técnicas** (librerías, APIs, SDKs) | Adaptador Fachada con puerto de grano grueso | Son detalles de implementación. El Caso de Uso no necesita saber cómo se analiza un documento, solo que se analiza. |
| **Múltiples servicios de dominio inyectados** (PricingService, FraudDetector, AvailabilityChecker) | Servicio de Dominio compuesto o mover lógica a entidades/aggregates | Son reglas de negocio explícitas. Ocultarlas oscurece qué reglas está aplicando el Caso de Uso. Si un aggregate tiene demasiados servicios, probablemente el modelo de dominio está anémico. |
| **Lógica que involucra múltiples aggregates del mismo tipo** | Domain Service (Dominio) | Es orquestación de dominio, no técnica. La Fachada vive en Infraestructura y no debe contener lógica de negocio. |
| **Caso de Uso con 2-3 dependencias simples** | Inyectar los puertos directamente | La Fachada añade una capa innecesaria si no hay complejidad técnica que ocultar. |

### Regla de oro

> **La Fachada oculta orquestación técnica, no lógica de negocio.** Si al leer el constructor del Caso de Uso no entiendes qué reglas de negocio se aplican, hay un problema. La Fachada solo debe encapsular librerías externas que no tienen significado de dominio por sí mismas.

```pseudocode
// CORRECTO: Fachada para dependencias técnicas
class GenerateContractUseCase:
    constructor(
        analyzer: DocumentAnalyzerPort,      // ← Fachada (técnica: OCR, layouts)
        pricing: PricingService,             // ← Dominio (explícito)
        validator: ContractRulesValidator,   // ← Dominio (explícito)
        repository: ContractRepositoryPort,
        eventBus: EventBus
    )
    // Se entienden las reglas de negocio: pricing + validación de contrato

// INCORRECTO: Fachada ocultando servicios de dominio
class GenerateContractUseCase:
    constructor(
        facade: ContractProcessingPort,  // ← ¿Qué reglas de negocio aplica? Imposible saber
        repository: ContractRepositoryPort,
        eventBus: EventBus
    )
    // La fachada internamente llama PricingService y ContractRulesValidator.
    // El dominio se volvió opaco. Anti-patrón.
```

## Fachada vs Decorator vs Domain Service

| Criterio | Fachada (Facade Adapter) | Decorator | Domain Service |
|---|---|---|---|
| **Propósito** | Ocultar complejidad de un subsistema técnico | Añadir comportamiento sin modificar el original | Lógica de dominio sin dueño natural |
| **Capa** | Infraestructura | Infraestructura | Dominio |
| **Implementa mismo puerto?** | Sí (puerto de grano grueso definido en Aplicación) | Sí (mismo puerto que envuelve) | No (métodos propios de dominio) |
| **Inyecta múltiples dependencias?** | Sí (varias librerías/APIs) | Normalmente 1 (el objeto envuelto + comportamiento extra) | No (recibe aggregates, no dependencias externas) |
| **Contiene lógica de negocio?** | No — solo orquestación técnica | No — solo preocupaciones transversales | Sí — reglas de dominio puras |
| **Ejemplo** | `ComprehensiveDocumentAnalyzer` (OpenCV + OCR + Layout) | `CachedCourseRepository` (repo + caché) | `CourseAvailabilityChecker` (cupo + prerrequisitos) |

## Estructura Completa en el Código

```pseudocode
// ─── CAPA DE APLICACIÓN ───
// Puerto de grano grueso: define QUÉ se necesita
interface DocumentAnalyzerPort:
    method analyze(image: Image): RawDocumentData

// Caso de Uso: orquestación de negocio
class GenerateDigitalCloneUseCase:
    constructor(
        analyzer: DocumentAnalyzerPort,
        repository: DocumentRepositoryPort,
        eventBus: EventBus
    )

    method invoke(command): void
        rawData = self.analyzer.analyze(command.image)
        document = DocumentAssembler.fromRawData(rawData, command.userId)
        document.validate()
        self.repository.save(document)
        self.eventBus.publish(document.pullEvents())


// ─── CAPA DE DOMINIO ───
// Servicio de Dominio: recibe datos crudos, aplica reglas, retorna entidad válida
class DocumentAssembler:
    static method fromRawData(rawData: RawDocumentData, userId: UserId): Document
        // Reglas de dominio puras en RAM
        ensure rawData.text.isNotEmpty()
        ensure rawData.layouts.hasAtLeastOneContainer()

        document = new Document(
            DocumentId.generate(),
            DocumentText.fromRaw(rawData.text),
            DocumentLayouts.fromRaw(rawData.layouts),
            userId
        )
        document.record(new DocumentClonedFromImage(document.id, rawData.sourceHash))
        return document


// ─── CAPA DE INFRAESTRUCTURA ───
// Adaptador Fachada: orquestación técnica, oculta librerías externas
class ComprehensiveDocumentAnalyzer implements DocumentAnalyzerPort:
    property imageEnhancer: OpenCVImageEnhancer
    property textExtractor: AwsTextractClient
    property layoutDetector: YoloLayoutDetector
    property fontMatcher: CustomFontMatcher
    property logger: Logger

    constructor(imageEnhancer, textExtractor, layoutDetector, fontMatcher, logger):
        self.imageEnhancer = imageEnhancer
        self.textExtractor = textExtractor
        self.layoutDetector = layoutDetector
        self.fontMatcher = fontMatcher
        self.logger = logger

    method analyze(image: Image): RawDocumentData
        self.logger.info("Iniciando pipeline de análisis...")

        enhancedImage = self.imageEnhancer.enhance(
            image,
            options: { denoise: true, sharpen: true }
        )

        textTask = async: self.textExtractor.extract(enhancedImage)
        layoutTask = async: self.layoutDetector.detect(enhancedImage)

        rawText = await textTask
        layouts = await layoutTask
        fonts = self.fontMatcher.match(enhancedImage)

        return new RawDocumentData(
            text: rawText,
            layouts: layouts,
            fonts: fonts,
            enhancedImage: enhancedImage
        )


// ─── COMPOSICIÓN EN DI ───
// La inyección de dependencias conecta las piezas
container.register(DocumentAnalyzerPort, () =>
    new ComprehensiveDocumentAnalyzer(
        new OpenCVImageEnhancer(),
        new AwsTextractClient(config.aws),
        new YoloLayoutDetector("model/v8"),
        new CustomFontMatcher(),
        new Logger("document-analyzer")
    )
)

container.register(GenerateDigitalCloneUseCase, (c) =>
    new GenerateDigitalCloneUseCase(
        c.get(DocumentAnalyzerPort),
        c.get(DocumentRepositoryPort),
        c.get(EventBus)
    )
)
```

## Beneficios Arquitectónicos

| Beneficio | Descripción |
|---|---|
| **Cumplimiento del DIP** | La infraestructura técnica se amolda a la interfaz simple que dictó el Caso de Uso, no al revés. |
| **Aislamiento del Framework** | Cambiar Tesseract por un modelo propietario no toca el Caso de Uso. Solo se crea un nuevo Adaptador Fachada. |
| **Tests Unitarios Triviales** | Para testear el Caso de Uso solo se simula la respuesta de la Fachada (un DTO prefabricado), ignorando la complejidad de las IAs subyacentes. |
| **Lectura Lineal** | El código del Caso de Uso se lee como un índice claro de pasos de negocio. |
| **Principio de Responsabilidad Única** | El Caso de Uso tiene una razón para cambiar (reglas de negocio). La Fachada tiene otra (cambio de librerías). |

## Errores Comunes

1. **Fachada ocultando servicios de dominio**: el constructor del Caso de Uso pierde expresividad de negocio. Las reglas de dominio deben ser explícitas.
2. **Fachada con lógica de negocio**: la Fachada vive en Infraestructura. Si contiene `if user.isPremium() then...`, se debe extraer a un Domain Service.
3. **Puerto demasiado genérico**: `ProcessingPort.process(data: any): any` no expresa intención de dominio. Usa nombres como `DocumentAnalyzerPort`, `PaymentGatewayPort`.
4. **Una fachada por cada dependencia**: volver a puertos de grano fino anula el propósito del patrón. Agrupa dependencias relacionadas.
5. **Fachada para dependencias que no son técnicas**: si el puerto de grano grueso envuelve otros puertos de dominio, estás creando una capa innecesaria. Usa un Domain Service compuesto en su lugar.
6. **Fachada sin contrato explícito**: el puerto de grano grueso debe tener un método con nombre de dominio claro y retornar un DTO bien definido, no genéricos.
