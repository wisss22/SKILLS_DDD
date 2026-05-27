# Patrón Criteria / Specification

El patrón Criteria proporciona una forma **componible y con seguridad de tipos para construir consultas** para repositorios. En lugar de crear docenas de métodos finder o pasar query DSL crudo, los repositorios aceptan un objeto `Criteria` que describe filtros, ordenamiento y paginación.

## ¿Por Qué el Patrón Criteria?

```pseudocode
// BAD: Method explosion
interface CourseRepository:
    method findByName(name: string): Courses
    method findByStatus(status: string): Courses
    method findByNameAndStatus(name: string, status: string): Courses
    method findByDurationGreaterThan(duration: int): Courses
    // ... 50 more methods

// BAD: Leaking infrastructure (raw SQL/query DSL)
interface CourseRepository:
    method findByQuery(sqlWhereClause: string): Courses

// GOOD: Composable Criteria pattern
interface CourseRepository:
    method matching(criteria: Criteria): Courses
```

## Componentes Principales

### Criteria

```pseudocode
class Criteria:
    property filters: Filters
    property order: Order?         // Optional
    property offset: int?          // Optional (pagination)
    property limit: int?           // Optional (pagination)

    constructor(filters, order = null, offset = null, limit = null):
        self.filters = filters
        self.order = order
        self.offset = offset
        self.limit = limit

    static withoutFilters(): Criteria
        return new Criteria(Filters.empty())

    method hasOrder(): bool
        return self.order != null

    method hasPagination(): bool
        return self.offset != null AND self.limit != null
```

### Filters

```pseudocode
class Filters:
    property filters: Filter[]

    constructor(filters: Filter[]):
        self.filters = filters

    static empty(): Filters
        return new Filters([])

    static fromValues(values: map[]): Filters
        return new Filters(values.map(v =>
            new Filter(
                field: new FilterField(v.field),
                operator: FilterOperator.fromValue(v.operator),
                value: new FilterValue(v.value)
            )
        ))

    method isEmpty(): bool
        return self.filters.length == 0
```

### Filter

```pseudocode
class Filter:
    property field: FilterField
    property operator: FilterOperator
    property value: FilterValue

    constructor(field, operator, value):
        self.field = field
        self.operator = operator
        self.value = value
```

### Filter Operators

```pseudocode
class FilterOperator:
    static EQUAL = "="
    static NOT_EQUAL = "!="
    static GT = ">"
    static GTE = ">="
    static LT = "<"
    static LTE = "<="
    static CONTAINS = "CONTAINS"
    static NOT_CONTAINS = "NOT_CONTAINS"
    static IN = "IN"

    property value: string

    constructor(value):
        self.value = value

    static fromValue(value: string): FilterOperator
        return new FilterOperator(value)

    method isEquals(): bool
        return self.value == FilterOperator.EQUAL
```

### Order

```pseudocode
class Order:
    property orderBy: OrderBy
    property orderType: OrderType

    constructor(orderBy, orderType):
        self.orderBy = orderBy
        self.orderType = orderType

    static fromValues(orderBy: string, orderType: string): Order
        return new Order(
            new OrderBy(orderBy),
            OrderType.fromValue(orderType)
        )

    static none(): Order
        // Return a default ordering or null

class OrderBy:
    property value: string
    constructor(value):
        self.value = value

class OrderType:
    static ASC = "asc"
    static DESC = "desc"
    property value: string
    constructor(value):
        self.value = value
    method isAsc(): bool
        return self.value == OrderType.ASC
```

## Ejemplo de Uso

### En un QueryHandler

```pseudocode
class SearchCoursesQueryHandler:
    property repository: CourseRepository

    method invoke(query: SearchCoursesQuery): CoursesResponse
        criteria = new Criteria(
            filters: Filters.fromValues([
                { field: "name",  operator: "CONTAINS", value: query.name },
                { field: "status", operator: "=",       value: query.status }
            ]),
            order: Order.fromValues(query.orderBy, query.order),
            offset: query.offset,
            limit: query.limit
        )

        courses = self.repository.matching(criteria)
        return CoursesResponse.fromCourses(courses)
```

### En una Query (DTO)

```pseudocode
class SearchCoursesQuery:
    property name: string?        // Optional filters
    property status: string?      // Optional filters
    property orderBy: string?     // Optional ordering
    property order: string?       // Optional ordering
    property offset: int?         // Optional pagination
    property limit: int?          // Optional pagination
```

### Conversión a Consulta Específica de Persistencia

El **adaptador** en Infrastructure convierte Criteria a la consulta específica de la base de datos:

```pseudocode
class CriteriaConverter:
    // For SQL databases
    method convert(criteria: Criteria, fieldMapping: map): SqlQuery
        where = ""
        for filter in criteria.filters.all():
            column = fieldMapping[filter.field]
            where += self.formatCondition(column, filter.operator, filter.value)

        query = "SELECT * FROM table WHERE " + where

        if criteria.hasOrder():
            query += self.formatOrder(criteria.order)

        if criteria.hasPagination():
            query += self.formatPagination(criteria.offset, criteria.limit)

        return query
```

```pseudocode
// For Elasticsearch
class ElasticsearchCriteriaConverter:
    method convert(criteria: Criteria): ElasticQuery
        query = {
            query: {
                bool: {
                    must: criteria.filters.all().map(f =>
                        self.buildFilter(f)
                    )
                }
            },
            sort: self.buildSort(criteria.order),
            from: criteria.offset,
            size: criteria.limit
        }
        return query
```

## Cuándo Usar Criteria vs Métodos Finder Específicos

| Use Case | Approach |
|---|---|
| Simple lookup by ID | `findById(id)` — dedicated method |
| Search with 1-2 filters | `findByStatus(status)` — dedicated method |
| Search with many filters, user-defined | `matching(criteria)` — Criteria pattern |
| Complex aggregations | Dedicated QueryHandler with raw adapter method |

## Errores Comunes

1. **Criteria con cadenas SQL crudas**: Valores de filtro como `"status = 'active'"` — deben ser tipados
2. **Criteria en objetos de dominio**: Criteria es una preocupación de Application/Infrastructure, no de Domain
3. **Falta de mapeo de campos**: Hardcodear nombres de columnas de base de datos en criteria
4. **Demasiados operadores de filtro**: Operadores que no se traducen a todas las bases de datos
5. **Sin paginación**: Consultas sin limit/offset en conjuntos de datos grandes
