# Value Objects

Los Value Objects son objetos de dominio definidos **completamente por sus atributos**. No tienen identidad y son **inmutables**. Dos Value Objects con los mismos atributos se consideran iguales.

## Cuándo Modelar como un Value Object

Usa un Value Object cuando:
- El concepto se define por su valor, no por su identidad
- Nunca rastrearías cambios en esta cosa individualmente
- Dos instancias con el mismo valor son intercambiables
- El concepto tiene reglas de validación

Ejemplos: `EmailAddress`, `Money`, `DateRange`, `CourseName`, `PhoneNumber`, `Address`, `GeoCoordinate`

## Reglas Fundamentales

### 1. Inmutable — Sin Setters, Sin Mutación

```pseudocode
class Money:
    property amount: decimal
    property currency: Currency

    constructor(amount, currency):
        self.ensurePositive(amount)
        self.amount = amount
        self.currency = currency

    // SIN setters. Para "cambiar" un valor, crea una NUEVA instancia.
    // MAL:  money.setAmount(100)     ← NUNCA hagas esto
    // BIEN: money = new Money(100, money.currency)  ← Reemplazar
```

### 2. Autovalidación

El constructor valida. Un Value Object nunca debe existir en un estado inválido.

```pseudocode
class CourseName:
    property value: string

    constructor(value):
        if value is empty:
            throw InvalidCourseName("Name cannot be empty")
        if len(value) < 3:
            throw InvalidCourseName("Name must be at least 3 characters")
        if len(value) > 100:
            throw InvalidCourseName("Name must be at most 100 characters")
        self.value = value
```

### 3. Igualdad Estructural

```pseudocode
class Money:
    method equals(other: Money): bool
        return self.amount == other.amount AND self.currency == other.currency

// $5 USD == $5 USD (true — mismo valor)
// $5 USD == $5 EUR (false — diferente moneda)
```

### 4. Métodos Sin Efectos Secundarios

Los métodos que "modifican" un Value Object devuelven una NUEVA instancia.

```pseudocode
class Money:
    method add(other: Money): Money
        ensure self.currency == other.currency
        return new Money(self.amount + other.amount, self.currency)

    method multiply(factor: decimal): Money
        return new Money(self.amount * factor, self.currency)
```

## Patrones Comunes de Value Object

### Value Object de ID (Envolviendo un UUID o ID numérico)

```pseudocode
class CourseId:
    property value: string  // UUID

    constructor(value):
        ensure value is a valid UUID
        self.value = value

    static generate(): CourseId
        return new CourseId(uuid_v4())

    method value(): string
        return self.value

    method equals(other: CourseId): bool
        return self.value == other.value
```

### Value Object Tipo Enum

```pseudocode
class OrderStatus:
    static DRAFT = new OrderStatus("draft")
    static CONFIRMED = new OrderStatus("confirmed")
    static SHIPPED = new OrderStatus("shipped")
    static CANCELLED = new OrderStatus("cancelled")

    property value: string

    private constructor(value):
        self.value = value

    // Todos los valores posibles
    static validValues(): array
        return [self.DRAFT, self.CONFIRMED, self.SHIPPED, self.CANCELLED]

    static fromValue(value: string): OrderStatus
        for status in self.validValues():
            if status.value == value:
                return status
        throw InvalidOrderStatus(value)
```

### Value Object Compuesto

```pseudocode
class Address:
    property street: string
    property city: string
    property postalCode: PostalCode  // Otro Value Object
    property country: Country        // Otro Value Object

    constructor(street, city, postalCode, country):
        self.street = street
        self.city = city
        self.postalCode = postalCode
        self.country = country
```

## Errores Comunes

1. **Value Objects mutables**: Agregar setters o métodos de mutación
2. **Obsesión por primitivos**: Usar `string` en lugar de `EmailAddress`, `int` en lugar de `PositiveInteger`
3. **Validación ausente**: Confiar en que el llamante proporcione valores válidos
4. **Value Objects con identidad**: Agregar un campo `id` a un Value Object
5. **Demasiado delgados**: Solo envolver un primitivo sin agregar comportamiento o validación
