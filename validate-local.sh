#!/bin/bash
# Validaciones locales antes de pushear

set -e

echo "🔍 Ejecutando validaciones locales..."

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0

# Función para verificar sintaxis
check_syntax() {
    local file="$1"
    echo -n "Verificando sintaxis: $file ... "
    if bash -n "$file" 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
        bash -n "$file"
        ((ERRORS++))
    fi
}

# Verificar archivos principales
echo -e "\n${YELLOW}Verificando sintaxis de scripts...${NC}"
check_syntax "ywai/tests/test-e2e-simple.sh"
check_syntax "ywai/setup/setup.sh"
check_syntax "ywai/setup/lib/config.sh"
check_syntax "ywai/setup/lib/ui.sh"
check_syntax "ywai/setup/lib/detector.sh"
check_syntax "ywai/setup/lib/installer.sh"
check_syntax "ywai/extensions/install-steps/shared-skills/install.sh"

# Verificar que los archivos ejecutables tengan permisos
echo -e "\n${YELLOW}Verificando permisos de ejecución...${NC}"
for file in ywai/setup/setup.sh ywai/tests/test-e2e-simple.sh ywai/extensions/install-steps/shared-skills/install.sh; do
    echo -n "Verificando permisos: $file ... "
    if [[ -x "$file" ]]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}⚠${NC} (sin permisos de ejecución)"
        chmod +x "$file"
        echo "   → Permisos agregados"
    fi
done

# Resumen
echo -e "\n${YELLOW}============================================${NC}"
if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}✅ Todas las validaciones pasaron${NC}"
    echo -e "${GREEN}🚀 Listo para pushear${NC}"
    exit 0
else
    echo -e "${RED}❌ $ERRORS errores encontrados${NC}"
    echo -e "${RED}🛑 Corrige los errores antes de pushear${NC}"
    exit 1
fi
