# Aggregates

Un Aggregate es un conjunto de objetos de dominio (Entities y Value Objects) tratados como una sola unidad para cambios de datos. Cada Aggregate tiene una **entidad raíz** (Aggregate Root) que es el único punto de acceso.

## ¿Por qué Aggregates?

Sin aggregates, cualquier código puede modificar cualquier entity, haciendo imposible garantizar los invariantes. Los aggregates definen **límites de consistencia** — todos los invariantes dentro del límite son aplicados por la raíz.

## Reglas Fundamentales

### 1. Un Aggregate Root por Aggregate

La raíz es la ÚNICA entity que el código externo puede referenciar. Todo acceso a las entities hijas pasa por la raíz.

```pseudocode
class Order:  // ← Aggregate Root
    property id: OrderId
    property items: Collection<OrderItem>  // Child entities
    property shippingAddress: Address      // Child value object

    // El código externo usa SOLO OrderRepository, nunca OrderItemRepository

// Entity hija - accedida solo a través de Order
class OrderItem:
    property id: OrderItemId
    property productId: ProductId
    property quantity: int
    property price: Money
```

### 2. Referencia Otros Aggregates Solo por ID

Nunca mantengas una referencia directa a otro aggregate. Usa su ID.

```pseudocode
class Order:
    property customerId: CustomerId  // POR ID, no un objeto Customer
    property items: Collection<OrderItem>
    // Cada OrderItem referencia un producto por ID:
    // orderItem.productId: ProductId  ← NO un objeto Product
```

### 3. Una Transacción por Aggregate

Modificar dos aggregates en una transacción rompe el límite del aggregate. Usa domain events para consistencia entre aggregates.

```pseudocode
// MAL: Dos aggregates en una transacción
transaction:
    orderRepository.save(order)
    inventoryRepository.save(inventory)  // ← ¡Aggregate diferente!

// BIEN: Un aggregate por transacción, evento para el otro
// En OrderCommandHandler:
transaction:
    orderRepository.save(order)
// Después de la transacción:
eventBus.publish(order.pullEvents())
// El subscriber de Inventory reacciona al evento OrderPlaced
```

### 4. Diseña Aggregates Pequeños

Los aggregates grandes causan problemas de rendimiento, contención y complejidad. Apunta a 3-5 entities por aggregate. Divide cuando te acerques a 8-10.

```pseudocode
// MAL: God aggregate con 15+ entities
class University:
    students: Collection<Student>    // Aggregate separado
    courses: Collection<Course>      // Aggregate separado
    professors: Collection<Professor>  // Aggregate separado
    departments: Collection<Department>  // Aggregate separado
    // ¡Esto deberían ser MÚLTIPLES aggregates!

// BIEN: Dividir por límite de consistencia
// Cada uno se convierte en su propio aggregate con su propio repository
// Se comunican mediante domain events
```

### 5. Elimina a Través de la Raíz

Cuando la raíz se elimina, todas las entities hijas se eliminan. Esto es natural: si eliminas un Order, sus OrderItems no tienen razón de existir.

```pseudocode
// Eliminar la raíz se propaga en cascada a las hijas
orderRepository.delete(orderId)
// Los OrderItems también se eliminan (aplicado por el adaptador de persistencia)
```

## Heurísticas de Diseño de Aggregate

### Encontrar Límites de Aggregate

| Pregunta | Si SÍ | Si NO |
|---|---|---|
| ¿Deben A y B ser consistentes en la misma transacción? | Mismo aggregate | Aggregates separados |
| ¿Puede B existir sin A? | Aggregates separados | Mismo aggregate (hijo) |
| ¿A es referenciado por muchos otros aggregates? | A es su propio aggregate | A podría ser hijo |
| ¿B cambia independientemente de A? | Aggregates separados | Mismo aggregate |

### Consistencia Eventual Entre Aggregates

```pseudocode
// Aggregate Course
class Course:
    method publish():
        self.status = CourseStatus.PUBLISHED
        self.record(new CoursePublished(self.id, self.publishedAt))

// Aggregate CoursesCounter (aggregate separado, BC diferente)
class CoursesCounter:
    method increment():
        self.total = self.total + 1
        self.record(new CoursesCounterIncremented(self.id, self.total))

// El subscriber tiende el puente
class IncrementCoursesCounterOnCoursePublished:
    subscribedTo(): [CoursePublished]
    invoke(event: CoursePublished):
        counter = self.repository.find() or CoursesCounter.initialize()
        counter.increment()
        self.repository.save(counter)
```

## Errores Comunes

1. **Demasiado grande**: God aggregates con 15+ entities dentro
2. **Demasiado pequeño**: Cada entity es su propio aggregate (pierde garantías de consistencia)
3. **Transacciones entre aggregates**: Modificar dos aggregates en una transacción de BD
4. **Referencias directas**: Mantener un objeto `Customer` dentro de un `Order`
5. **Repository por entity**: `OrderItemRepository` — no debería existir
6. **Sin domain events**: Modificar aggregates sin notificar al sistema
