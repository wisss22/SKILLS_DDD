# Anti-Patrones

Errores comunes al aplicar DDD, CQRS y Arquitectura Hexagonal. Cada anti-patrón incluye el problema, por qué duele y la solución.

## Anti-Patrones de la Capa Domain

### Modelo de Dominio Anémico
| Aspecto | Descripción |
|---|---|
| **Problema** | Las entities son bolsas de datos con getters/setters. Toda la lógica de negocio vive en servicios. |
| **Por qué duele** | Las reglas de negocio se dispersan entre servicios, se duplican, son difíciles de encontrar. El modelo no expresa el dominio. |
| **Solución** | Mueve el comportamiento DENTRO de las entities. Métodos como `course.start()`, `order.addItem()`, no `course.setStatus(STARTED)`. |
| **Detección** | Clases Entity con solo propiedades + getters/setters + sin métodos con nombres de negocio. |

### Repository por Entity
| Aspecto | Descripción |
|---|---|
| **Problema** | Crear un repository para cada entity, incluso entities hijas dentro de aggregates. |
| **Por qué duele** | Rompe los límites del aggregate. Las entities hijas son accedidas sin pasar por el aggregate root. Las reglas de consistencia se evaden. |
| **Solución** | Un repository solo por AGGREGATE ROOT. Accede a las entities hijas a través del root. |
| **Detección** | `LineItemRepository`, `OrderItemRepository` — no deberían existir si son parte de un aggregate Order. |

### Fuga de Infrastructure hacia Domain
| Aspecto | Descripción |
|---|---|
| **Problema** | El código de Domain importa librerías de base de datos, clientes HTTP, anotaciones de framework o formatos de serialización. |
| **Por qué duele** | Domain se acopla a infrastructure. Difícil de probar. No se puede cambiar de base de datos. Viola la regla de dependencia. |
| **Solución** | Domain tiene CERO dependencias externas. Solo la librería estándar del lenguaje y otros tipos de domain. Crea interfaces (ports) en domain, implementa en infrastructure. |
| **Detección** | `import { Entity, Column } from 'orm-lib'` dentro de una entity de domain. |

### Aggregate Dios
| Aspecto | Descripción |
|---|---|
| **Problema** | Un aggregate contiene demasiadas entities (10+, a veces 20+). Carga grafos de objetos masivos para operaciones simples. |
| **Por qué duele** | Degradación de rendimiento. Alta contención en escrituras. Difícil de razonar. Las transacciones se vuelven demasiado grandes. |
| **Solución** | Divide en aggregates más pequeños. Referencia otros aggregates solo por ID. Usa domain events para consistencia entre aggregates. |
| **Detección** | Aggregate con >10 entities hijas directas. Métodos que tocan solo una pequeña parte del aggregate. |

### Omitir Value Objects
| Aspecto | Descripción |
|---|---|
| **Problema** | Usar primitivos (string, int, float) para conceptos de dominio que tienen reglas. |
| **Por qué duele** | Validación dispersa por todas partes. Sin seguridad de tipos para conceptos de dominio. Un string "email" puede pasarse donde se espera un "name". |
| **Solución** | Envuelve primitivos con reglas en Value Objects. `EmailAddress`, `PositiveMoney`, `CourseName`, `PhoneNumber`. |
| **Detección** | Métodos que aceptan `string` para conceptos como email, teléfono, dinero, referencias de ID. |

### Value Objects Mutables
| Aspecto | Descripción |
|---|---|
| **Problema** | Value Objects con setters o métodos de mutación. |
| **Por qué duele** | Los Value Objects pierden su previsibilidad. Las referencias compartidas causan cambios inesperados. |
| **Solución** | Haz los Value Objects INMUTABLES. Crea una nueva instancia cuando se necesite un cambio. Sin setters. |
| **Detección** | Value Object con métodos `setX()` o propiedades públicas mutables. |

### Domain Events como Idea Tardía
| Aspecto | Descripción |
|---|---|
| **Problema** | Añadir domain events después de los hechos, o events que no representan ocurrencias reales de negocio. |
| **Por qué duele** | Otras partes del sistema no pueden reaccionar a los cambios. Oportunidades perdidas de comunicación entre contextos. |
| **Solución** | Registra domain events a medida que el aggregate cambia de estado. Nómbralos en tiempo pasado: `CourseCreated`, `PaymentReceived`, `OrderShipped`. |
| **Detección** | Aggregates que cambian de estado pero nunca registran domain events. Events nombrados como `DataChanged`. |

## Anti-Patrones de la Capa Application

### Omitir Casos de Uso
| Aspecto | Descripción |
|---|---|
| **Problema** | Los controladores llaman a repositories directamente en lugar de pasar por los handlers de Command/Query. |
| **Por qué duele** | La lógica de negocio se filtra en los controladores. Lógica duplicada entre controladores. Difícil de probar y reutilizar. |
| **Solución** | Siempre enruta a través de los handlers de Command/Query. Los controladores solo despachan al bus. |
| **Detección** | Controlador con llamadas a `$repository->save()` o `$repository->find()`. |

### CommandHandler Haciendo Trabajo de Query
| Aspecto | Descripción |
|---|---|
| **Problema** | Un CommandHandler devuelve datos (modelo de lectura) después de ejecutar el command. |
| **Por qué duele** | Difumina la separación CQRS. Los commands deben cambiar estado, no devolver vistas. Difícil optimizar lecturas por separado. |
| **Solución** | Los commands devuelven void (o ID mínimo). Los queries manejan todas las lecturas. Si necesitas datos después de un command, emite un query separado. |
| **Detección** | CommandHandler con un tipo de retorno no void. |

### Scripting Transaccional en Handlers
| Aspecto | Descripción |
|---|---|
| **Problema** | El CommandHandler contiene lógica paso a paso en lugar de delegar en objetos de dominio. |
| **Por qué duele** | La lógica de dominio se filtra en la capa de aplicación. Validación duplicada. Modelo de dominio anémico. |
| **Solución** | Los handlers orquestan: validar entrada, cargar aggregate, llamar método de dominio, guardar. El paso "llamar método de dominio" debería ser una línea. |
| **Detección** | Handler con >15 líneas de lógica de negocio (sin contar validación/plomería). |

### Constructor Over-Injection
| Aspecto | Descripción |
|---|---|
| **Problema** | Un Caso de Uso recibe 5+ dependencias en su constructor, muchas de ellas técnicas y de bajo nivel (librerías externas, SDKs, clientes HTTP). |
| **Por qué duele** | El Caso de Uso se vuelve ilegible, difícil de testear (hay que mockear demasiadas librerías) y frágil ante cambios de infraestructura. La intención de negocio se pierde entre dependencias técnicas. |
| **Solución** | Agrupa dependencias técnicas relacionadas tras un puerto de grano grueso usando el Patrón Fachada. Las dependencias de dominio (servicios de dominio, repositories) permanecen explícitas en el constructor. |
| **Detección** | Constructor de handler con >5 parámetros, donde más de 3 son librerías o herramientas técnicas (no puertos de dominio). |

### Fachada Ocultando Lógica de Negocio
| Aspecto | Descripción |
|---|---|
| **Problema** | Un puerto de grano grueso o Adaptador Fachada encapsula servicios de dominio en su interior, haciendo invisible qué reglas de negocio se están aplicando. |
| **Por qué duele** | Al leer el constructor del Caso de Uso no se entiende qué reglas de dominio se ejecutan. El modelo de dominio se vuelve opaco. La Fachada mezcla orquestación técnica con lógica de negocio. |
| **Solución** | La Fachada solo encapsula orquestación técnica (librerías externas, APIs, SDKs). Los servicios de dominio se inyectan explícitamente en el Caso de Uso o se invocan directamente. Si el Caso de Uso necesita demasiados servicios de dominio, revisa si el modelo de dominio está anémico. |
| **Detección** | Fachada cuyo método internamente invoca servicios de dominio (ej. `PricingService`, `FraudDetector`, `InventoryValidator`). El constructor del Caso de Uso oculta reglas de negocio tras un nombre genérico. |

## Anti-Patrones de Infrastructure

### Fuga de Detalles de Persistencia hacia Arriba
| Aspecto | Descripción |
|---|---|
| **Problema** | La capa Application o Domain depende de tipos específicos de base de datos, clases ORM o query builders. |
| **Por qué duele** | Acopla la lógica de negocio a una base de datos específica. No se puede cambiar de base de datos sin cambiar el código de domain. |
| **Solución** | Las interfaces Repository devuelven objetos de dominio. Los adapters convierten entre objetos de dominio y modelos de persistencia. |
| **Detección** | Servicio de aplicación importando clases entity de ORM o query builders. |

### Falta de Abstracciones de Adapter
| Aspecto | Descripción |
|---|---|
| **Problema** | El código instancia o llama directamente a infrastructure sin pasar por una interfaz port. |
| **Por qué duele** | No se puede probar sin infrastructure. No se pueden intercambiar implementaciones. Acoplamiento fuerte. |
| **Solución** | Define una interfaz (port) en Domain/Application. Implementa en Infrastructure. Inyecta mediante DI. |
| **Detección** | `new HttpClient()` o `new DatabaseConnection()` directo en código de aplicación. |

### Adapter Dios
| Aspecto | Descripción |
|---|---|
| **Problema** | Una clase adapter implementa múltiples interfaces port o conoce demasiadas preocupaciones. |
| **Por qué duele** | Difícil reemplazar comportamientos individuales. Viola responsabilidad única. |
| **Solución** | Una clase adapter por interfaz port. Compón adapters con decorators para preocupaciones transversales. |
| **Detección** | Clase adapter que `implements RepositoryInterface, EventBusInterface, CacheInterface`. |

## Anti-Patrones de Testing

### Probar Implementación, No Comportamiento
| Aspecto | Descripción |
|---|---|
| **Problema** | Los tests verifican llamadas a métodos internos, estado privado o detalles específicos de implementación. |
| **Por qué duele** | Los tests se rompen en refactors. No se puede mejorar el código sin reescribir tests. Los tests no prueban que el sistema funciona. |
| **Solución** | Prueba entradas → salidas (o efectos secundarios). Usa Object Mothers para la configuración. Prueba en los límites de los casos de uso. |
| **Detección** | Tests con mocking de métodos privados. Tests que hacen assert sobre campos de estado interno. |

### Probar Sin Mothers
| Aspecto | Descripción |
|---|---|
| **Problema** | Cada test construye manualmente objetos de dominio con valores hardcodeados. |
| **Por qué duele** | La configuración de tests es verbosa y repetitiva. Cambiar un constructor significa actualizar docenas de tests. Los tests son difíciles de leer. |
| **Solución** | Usa Object Mothers con valores predeterminados sensatos. Sobrescribe solo lo que le importa al test. |
| **Detección** | Bloques largos de configuración de test con `new Entity("hardcoded", "values", ...)`. |

### Sin Tests de Arquitectura
| Aspecto | Descripción |
|---|---|
| **Problema** | Las reglas de dependencia y los límites de capas existen solo en documentación, no se hacen cumplir. |
| **Por qué duele** | Las reglas se degradan con el tiempo. Nuevos desarrolladores violan límites sin saberlo. |
| **Solución** | Escribe tests de arquitectura que verifiquen: domain no tiene dependencias externas, infrastructure implementa ports, se siguen las convenciones de nomenclatura. |
| **Detección** | No hay test que verifique que `domain/` no importa de `infrastructure/`. |

## Anti-Patrones Generales

### Pensamiento CRUD
| Aspecto | Descripción |
|---|---|
| **Problema** | Modelar el sistema como Crear-Leer-Actualizar-Eliminar en lugar de operaciones de negocio. |
| **Por qué duele** | Se pierde el lenguaje del dominio. Las reglas de negocio son implícitas. Las operaciones no reflejan la intención del usuario. |
| **Solución** | Modela operaciones de negocio: `enrollInCourse()`, `publishArticle()`, `approveLoan()`, no `updateStatus()`. |
| **Detección** | Casos de uso nombrados `UpdateX`, `DeleteX`. Entities con campo genérico `status` cambiado desde múltiples lugares. |

### CQRS / Event Sourcing Prematuro
| Aspecto | Descripción |
|---|---|
| **Problema** | Añadir CQRS o Event Sourcing antes de que la complejidad del dominio lo justifique. |
| **Por qué duele** | Complejidad innecesaria. Un CRUD simple se convierte en una arquitectura multi-servicio. Mayor costo de mantenimiento. |
| **Solución** | Empieza simple. Añade CQRS solo cuando los modelos de lectura/escritura divergen significativamente. Añade Event Sourcing solo cuando se requiera auditoría o consultas temporales. |
| **Detección** | Un sistema con 3 entities y 0 queries que difieran de las escrituras, pero infraestructura completa de CQRS + Event Sourcing. |

### Transacciones Entre Aggregates
| Aspecto | Descripción |
|---|---|
| **Problema** | Una transacción modificando múltiples aggregates. |
| **Por qué duele** | Acopla aggregates. Crea contención. Viola los límites del aggregate. Puede causar deadlocks. |
| **Solución** | Una transacción por modificación de aggregate. Usa domain events para consistencia eventual entre aggregates. |
| **Detección** | Método de repository que guarda dos tipos diferentes de aggregate. Transacción que abarca múltiples llamadas a `repository.save()`. |
