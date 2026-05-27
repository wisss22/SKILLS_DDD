#!/usr/bin/env bash

# =============================================================================
# validate-shared-structure.sh
# Valida que la estructura de carpetas Shared siga las convenciones DDD:
# - Monorepo Shared Domain sin dependencias externas
# - BC-local Shared sin imports cruzados entre BCs
# - Cada BC tiene su propio *_services.yaml y EntityManager factory
# =============================================================================

set -euo pipefail

SRC_DIR="${1:-./src}"
ERRORS=0
WARNINGS=0

echo "Validando estructura Shared en: $SRC_DIR"
echo ""

# -----------------------------------------------------------------------------
# 1. Monorepo Shared: verificar existencia
# -----------------------------------------------------------------------------
MONOREPO_SHARED="$SRC_DIR/Shared"
if [[ ! -d "$MONOREPO_SHARED" ]]; then
    echo "[ERROR] Falta monorepo Shared: $MONOREPO_SHARED"
    ERRORS=$((ERRORS + 1))
else
    echo "[OK] Monorepo Shared: $MONOREPO_SHARED"

    # Verificar capas minimas
    if [[ ! -d "$MONOREPO_SHARED/Domain" ]]; then
        echo "  [WARN] Falta Shared/Domain/"
        WARNINGS=$((WARNINGS + 1))
    else
        echo "  [OK] Shared/Domain/"
    fi

    if [[ ! -d "$MONOREPO_SHARED/Infrastructure" ]]; then
        echo "  [WARN] Falta Shared/Infrastructure/"
        WARNINGS=$((WARNINGS + 1))
    else
        echo "  [OK] Shared/Infrastructure/"
    fi
fi

# -----------------------------------------------------------------------------
# 2. BC-local Shared: verificar que cada BC tiene su carpeta Shared autonoma
# -----------------------------------------------------------------------------
echo ""

for bc_dir in "$SRC_DIR"/*/; do
    bc_name=$(basename "$bc_dir")

    # Ignorar monorepo Shared
    if [[ "$bc_name" == "Shared" ]]; then
        continue
    fi

    # Ignorar archivos sueltos
    if [[ ! -d "$bc_dir" ]]; then
        continue
    fi

    # Ignorar si no es un BC (no tiene modulos)
    module_count=$(find "$bc_dir" -maxdepth 1 -mindepth 1 -type d | grep -v Shared | wc -l || true)
    if [[ $module_count -eq 0 ]]; then
        continue
    fi

    echo "Bounded Context: $bc_name"

    bc_shared="$bc_dir/Shared"
    if [[ ! -d "$bc_shared" ]]; then
        echo "  [INFO] Sin carpeta Shared (puede ser valido si solo tiene 1 modulo)"
        continue
    fi

    # Verificar servicios.yaml del BC
    services_yaml="$bc_shared/Infrastructure/Symfony/DependencyInjection/${bc_name,,}_services.yaml"
    # Tambien buscar con el nombre en minusculas (mooc_services.yaml, backoffice_services.yaml)
    found_services=$(find "$bc_shared" -name "*_services.yaml" 2>/dev/null | head -1 || echo "")

    if [[ -z "$found_services" ]]; then
        echo "  [WARN] Falta DI config: se esperaba *_services.yaml en Shared/Infrastructure/"
        WARNINGS=$((WARNINGS + 1))
    else
        echo "  [OK] DI config: $found_services"
    fi

    # Verificar EntityManager factory del BC
    em_factory=$(find "$bc_shared" -name "*EntityManagerFactory.php" 2>/dev/null | head -1 || echo "")
    if [[ -z "$em_factory" ]]; then
        echo "  [WARN] Falta EntityManagerFactory en Shared/Infrastructure/Doctrine/"
        WARNINGS=$((WARNINGS + 1))
    else
        echo "  [OK] EntityManager factory: $em_factory"
    fi

    # Verificar que BC-local Shared no es importado por otro BC
    bc_namespace=$(echo "$bc_name" | sed 's/.*/\u&/')
    for other_bc_dir in "$SRC_DIR"/*/; do
        other_bc_name=$(basename "$other_bc_dir")
        if [[ "$other_bc_name" == "$bc_name" ]] || [[ "$other_bc_name" == "Shared" ]]; then
            continue
        fi

        # Buscar imports cruzados del Shared de este BC en otro BC
        cross_imports=$(grep -r "\\${bc_namespace}\\\Shared\\" "$other_bc_dir" 2>/dev/null || echo "")
        if [[ -n "$cross_imports" ]]; then
            echo "  [ERROR] Anti-patron detectado: $other_bc_name importa Shared de $bc_name"
            echo "    $cross_imports"
            ERRORS=$((ERRORS + 1))
        fi
    done

    echo ""
done

# -----------------------------------------------------------------------------
# 3. Monorepo Shared Domain: verificar cero dependencias externas
# -----------------------------------------------------------------------------
echo "Verificando dependencias externas en Shared/Domain/..."

if [[ -d "$MONOREPO_SHARED/Domain" ]]; then
    # Buscar imports de frameworks/librerias en Shared/Domain
    # (permitimos ramsey/uuid porque Uuid.php lo usa)
    external_imports=$(grep -rn "use Symfony\\|use Doctrine\\|use Monolog\\|use Ramsey" "$MONOREPO_SHARED/Domain" 2>/dev/null | grep -v "Ramsey" || echo "")

    if [[ -n "$external_imports" ]]; then
        echo "  [WARN] Shared/Domain/ tiene dependencias externas (no-Ramsey):"
        echo "$external_imports"
        WARNINGS=$((WARNINGS + 1))
    else
        echo "  [OK] Shared/Domain/ sin dependencias externas problematicas"
    fi
fi

# -----------------------------------------------------------------------------
# 4. Resumen
# -----------------------------------------------------------------------------
echo ""
echo "========================================"
echo "  Resultado: Errores=$ERRORS, Warnings=$WARNINGS"
echo "========================================"

if [[ $ERRORS -gt 0 ]]; then
    echo "  FALLIDO — Se encontraron anti-patrones."
    exit 1
else
    echo "  OK — Estructura Shared valida."
    exit 0
fi
