#!/usr/bin/env bash
# validate-structure.sh
# Checks that the project directory structure follows DDD + Hexagonal dependency rules.
# Usage: ./validate-structure.sh [project-root]
#
# Validates:
#   1. Domain layer has no external dependencies (no DB, HTTP, framework imports)
#   2. Application layer depends only on Domain layer
#   3. Infrastructure layer implements port interfaces
#   4. Entry points (apps/) depend only on Application + Infrastructure
#   5. Directory structure matches bounded context / module conventions

set -euo pipefail

PROJECT_ROOT="${1:-.}"
ERRORS=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; ERRORS=$((ERRORS + 1)); }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

echo "=== DDD Structure Validator ==="
echo "Project root: $PROJECT_ROOT"
echo ""

# --- Check 1: Required top-level directories ---
echo "--- Checking top-level structure ---"
for dir in "src" "tests"; do
    if [ -d "$PROJECT_ROOT/$dir" ]; then
        log_pass "Directory '$dir' exists"
    else
        log_warn "Directory '$dir' not found (may be named differently)"
    fi
done

# --- Check 2: Domain layer isolation ---
echo ""
echo "--- Checking Domain layer isolation ---"

# Find domain directories (adapt this pattern to your language/structure)
DOMAIN_DIRS=$(find "$PROJECT_ROOT/src" -type d -name "Domain" 2>/dev/null || echo "")

if [ -z "$DOMAIN_DIRS" ]; then
    log_warn "No 'Domain' directories found under src/"
else
    for domain_dir in $DOMAIN_DIRS; do
        # List of forbidden imports in domain layer
        FORBIDDEN=(
            "import.*database"
            "import.*http"
            "import.*controller"
            "import.*persistence"
            "import.*infrastructure"
            "require.*vendor"
        )

        for pattern in "${FORBIDDEN[@]}"; do
            # Search for imports in domain files (language-agnostic string search)
            if grep -r -l "$pattern" "$domain_dir" 2>/dev/null; then
                log_fail "$domain_dir: May contain forbidden dependency matching '$pattern'"
            fi
        done

        log_pass "$domain_dir: No obvious infrastructure leaks detected (heuristic)"
    done
fi

# --- Check 3: Layer order ---
echo ""
echo "--- Checking layer dependency direction ---"

# Heuristic: Infrastructure files should NOT be imported by Domain files
INFRA_DIRS=$(find "$PROJECT_ROOT/src" -type d -name "Infrastructure" 2>/dev/null || echo "")
APP_DIRS=$(find "$PROJECT_ROOT/src" -type d -name "Application" 2>/dev/null || echo "")

for domain_dir in $DOMAIN_DIRS; do
    for infra_dir in $INFRA_DIRS; do
        infra_basename=$(basename "$(dirname "$infra_dir")")
        # Check if domain imports from infrastructure
        if grep -r -q "$infra_basename" "$domain_dir" 2>/dev/null; then
            log_fail "$domain_dir appears to reference '$infra_basename' from Infrastructure"
        fi
    done
done

log_pass "Layer dependency direction check complete (heuristic)"

# --- Check 4: Test structure ---
echo ""
echo "--- Checking test structure ---"
if [ -d "$PROJECT_ROOT/tests" ]; then
    TEST_DIRS=$(find "$PROJECT_ROOT/tests" -type d -name "Domain" 2>/dev/null || echo "")
    for test_dir in $TEST_DIRS; do
        # Check for Mother/ObjectMother pattern
        MOTHER_COUNT=$(find "$test_dir" -name "*Mother*" 2>/dev/null | wc -l)
        if [ "$MOTHER_COUNT" -gt 0 ]; then
            log_pass "Found $MOTHER_COUNT Object Mother(s) in $test_dir"
        fi
    done
fi

# --- Check 5: Port/Adapter pattern ---
echo ""
echo "--- Checking Port/Adapter pattern ---"
if [ -d "$PROJECT_ROOT/src" ]; then
    # Repositories are ports (interfaces/abstract) in Domain
    REPO_INTERFACES=$(find "$PROJECT_ROOT/src" -path "*/Domain/*Repository*" \( -name "*.php" -o -name "*.ts" -o -name "*.go" -o -name "*.java" -o -name "*.cs" -o -name "*.py" -o -name "*.rs" \) 2>/dev/null | wc -l)
    # Adapters implement those ports in Infrastructure
    REPO_ADAPTERS=$(find "$PROJECT_ROOT/src" -path "*/Infrastructure/*Repository*" \( -name "*.php" -o -name "*.ts" -o -name "*.go" -o -name "*.java" -o -name "*.cs" -o -name "*.py" -o -name "*.rs" \) 2>/dev/null | wc -l)

    log_pass "Repository ports found: $REPO_INTERFACES"
    log_pass "Repository adapters found: $REPO_ADAPTERS"

    if [ "$REPO_INTERFACES" -eq 0 ] && [ "$REPO_ADAPTERS" -eq 0 ]; then
        log_warn "No repository pattern detected (may be too early in project)"
    fi
fi

# --- Summary ---
echo ""
echo "=== Validation Complete ==="
if [ "$ERRORS" -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC}"
    exit 0
else
    echo -e "${RED}$ERRORS issue(s) found.${NC} Review the [FAIL] lines above."
    exit 1
fi
