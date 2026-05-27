# Domain Services

Un Domain Service es una **operación sin estado** que representa lógica de dominio que no pertenece naturalmente a ningún Entity o Value Object individual.

## Cuándo Usar un Domain Service

Usa un Domain Service cuando:
- La operación involucra **múltiples aggregates** del mismo tipo
- La lógica es un **concepto de dominio independiente** no ligado a un entity específico
- Colocar la lógica en un solo entity violaría su responsabilidad única
- La operación accede a un **concepto de dominio externo** (¡no infraestructura!)

NO uses un Domain Service cuando:
- La lógica claramente pertenece a un entity → Ponla allí
- La operación orquesta infraestructura → Eso es un Application Service
- La operación es puramente técnica (formateo, conversión) → Utilidad, no Domain Service

## Domain Service vs Application Service

| Criterio | Domain Service | Application Service |
|---|---|---|
| ¿Sin estado? | Sí | Sí |
| ¿Orquesta infraestructura? | No | Sí |
| ¿Contiene reglas de negocio? | Sí | No |
| ¿Llama a repositories? | No (recibe aggregates) | Sí |
| ¿Dónde vive? | Capa de Dominio | Capa de Aplicación |

## Estructura

```pseudocode
// Domain Service: Lógica de negocio pura, sin I/O
class CourseAvailabilityChecker:
    // Verifica si un curso puede aceptar más estudiantes
    method isFull(course: Course, currentEnrollments: int): bool
        return currentEnrollments >= course.maxCapacity()

    method canEnroll(course: Course, student: Student, currentEnrollments: int): bool
        if course.isArchived():
            return false
        if self.isFull(course, currentEnrollments):
            return false
        if student.hasCompletedPrerequisites(course.prerequisites()):
            return false
        return true
```

## Cuándo la Lógica Pertenece a un Entity vs Domain Service

```pseudocode
// PERTENECE AL ENTITY: Operación sobre el propio estado del entity
class Course:
    method rename(newName: string): void
        self.name = CourseName.fromValue(newName)
        self.record(new CourseRenamed(self.id, newName))

// PERTENECE AL DOMAIN SERVICE: Operación que involucra múltiples entities o reglas externas
class CoursePricingService:
    method calculateDiscountedPrice(course: Course, user: User): Money
        basePrice = course.basePrice()
        discount = 0

        // Regla 1: Descuento por fidelidad
        if user.isLoyal():
            discount += basePrice * 0.10

        // Regla 2: Descuento estacional
        if self.isSeasonalDiscountActive():
            discount += basePrice * 0.05

        return basePrice.subtract(discount)
```

## Domain Service con Conceptos de Dominio Externos

A veces una regla de dominio requiere un concepto externo que no debería inyectarse como infraestructura:

```pseudocode
// Domain Service con un puerto hacia un concepto de dominio externo
interface ExchangeRateProvider:    // ← Esto es un PUERTO en la capa de Dominio
    method getRate(from: Currency, to: Currency): ExchangeRate

class CurrencyConverter:
    // Lógica de dominio pura usando el puerto
    method convert(amount: Money, toCurrency: Currency, rateProvider: ExchangeRateProvider): Money
        rate = rateProvider.getRate(amount.currency, toCurrency)
        return amount.multiply(rate.value)
```

## Errores Comunes

1. **Domain Service anémico**: El service hace todo el trabajo mientras los entities son bolsas de datos → Mueve la lógica a los entities
2. **Lógica de aplicación en Domain Service**: Domain Service llamando a repositories o event bus → Esto es un Application Service
3. **Clase de utilidad etiquetada como Domain Service**: `StringFormatter`, `DateHelper` → Estas son utilidades, no conceptos de dominio
4. **Entity haciendo trabajo de Domain Service**: Entity con 20+ métodos manejando conceptos no relacionados → Divide en Domain Service
5. **Demasiados Domain Services**: Si cada operación es un Domain Service, tus entities son anémicos
