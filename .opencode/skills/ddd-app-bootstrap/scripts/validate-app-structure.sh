#!/usr/bin/env bash

# =============================================================================
# validate-app-structure.sh
# Valida que la carpeta apps/ siga la convencion de un bounded context por app.
# =============================================================================

set -euo pipefail

APPS_DIR="${1:-./apps}"
ERRORS=0

echo "Validando estructura de apps en: $APPS_DIR"
echo ""

# -----------------------------------------------------------------------------
# 1. Verificar que existe apps/bootstrap.php
# -----------------------------------------------------------------------------
if [[ ! -f "$APPS_DIR/bootstrap.php" ]]; then
    echo "[ERROR] Falta archivo compartido: $APPS_DIR/bootstrap.php"
    ERRORS=$((ERRORS + 1))
else
    echo "[OK] $APPS_DIR/bootstrap.php"
fi

# -----------------------------------------------------------------------------
# 2. Verificar que cada BC tiene backend/src/<BC>BackendKernel.php
# -----------------------------------------------------------------------------
for bc_dir in "$APPS_DIR"/*/; do
    bc_name=$(basename "$bc_dir")

    # Ignorar archivos sueltos (ej. bootstrap.php)
    if [[ ! -d "$bc_dir" ]]; then
        continue
    fi

    echo ""
    echo "Bounded Context: $bc_name"

    backend_dir="$bc_dir/backend"
    if [[ ! -d "$backend_dir" ]]; then
        echo "  [ERROR] Falta carpeta backend: $backend_dir"
        ERRORS=$((ERRORS + 1))
        continue
    fi

    # Kernel
    kernel_file="$backend_dir/src/${bc_name}BackendKernel.php"
    if [[ ! -f "$kernel_file" ]]; then
        echo "  [ERROR] Falta Kernel: $kernel_file"
        ERRORS=$((ERRORS + 1))
    else
        echo "  [OK] Kernel: $kernel_file"
    fi

    # Entrypoints
    if [[ ! -f "$backend_dir/public/index.php" ]]; then
        echo "  [ERROR] Falta HTTP entrypoint: $backend_dir/public/index.php"
        ERRORS=$((ERRORS + 1))
    else
        echo "  [OK] HTTP entrypoint: $backend_dir/public/index.php"
    fi

    if [[ ! -f "$backend_dir/bin/console" ]]; then
        echo "  [ERROR] Falta CLI entrypoint: $backend_dir/bin/console"
        ERRORS=$((ERRORS + 1))
    else
        echo "  [OK] CLI entrypoint: $backend_dir/bin/console"
    fi

    # Config DI
    if [[ ! -f "$backend_dir/config/services.yaml" ]]; then
        echo "  [ERROR] Falta DI config: $backend_dir/config/services.yaml"
        ERRORS=$((ERRORS + 1))
    else
        echo "  [OK] DI config: $backend_dir/config/services.yaml"
    fi

    # Routes
    if [[ ! -d "$backend_dir/config/routes" ]]; then
        echo "  [WARN] Falta carpeta de rutas: $backend_dir/config/routes"
    else
        route_count=$(find "$backend_dir/config/routes" -type f | wc -l)
        echo "  [OK] Rutas definidas: $route_count archivo(s)"
    fi

done

echo ""
# -----------------------------------------------------------------------------
# 3. Resumen
# -----------------------------------------------------------------------------
if [[ $ERRORS -eq 0 ]]; then
    echo "========================================"
    echo "  Validacion exitosa. Sin errores."
    echo "========================================"
    exit 0
else
    echo "========================================"
    echo "  Validacion fallida. Errores: $ERRORS"
    echo "========================================"
    exit 1
fi
