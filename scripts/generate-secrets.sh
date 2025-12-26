#!/bin/bash
# Script para gerar secrets necessários para o Fizzy
# Não precisa do container rodando!

set -e

echo "=========================================="
echo "  Gerador de Secrets do Fizzy"
echo "=========================================="
echo ""

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Gerar SECRET_KEY_BASE
echo -e "${YELLOW}1. Gerando SECRET_KEY_BASE...${NC}"
SECRET_KEY_BASE=$(openssl rand -hex 64)
echo -e "${GREEN}✓ Gerado!${NC}"
echo ""

# 2. Gerar VAPID keys
echo -e "${YELLOW}2. Gerando VAPID keys (Web Push)...${NC}"

# VAPID keys são chaves ECDSA P-256
# Gerar chave privada
VAPID_PRIVATE_KEY_PEM=$(openssl ecparam -name prime256v1 -genkey -noout)

# Extrair chave privada em formato base64url (Rails WebPush espera isso)
VAPID_PRIVATE_KEY=$(echo "$VAPID_PRIVATE_KEY_PEM" | openssl ec -outform DER 2>/dev/null | tail -c +8 | head -c 32 | base64 | tr '+/' '-_' | tr -d '=')

# Gerar chave pública a partir da privada
VAPID_PUBLIC_KEY=$(echo "$VAPID_PRIVATE_KEY_PEM" | openssl ec -pubout -outform DER 2>/dev/null | tail -c 65 | base64 | tr '+/' '-_' | tr -d '=')

echo -e "${GREEN}✓ Gerado!${NC}"
echo ""

# 3. Exibir resultados
echo "=========================================="
echo "  SECRETS GERADOS COM SUCESSO!"
echo "=========================================="
echo ""
echo "Copie estes valores para o seu arquivo .env:"
echo ""
echo "-------------------------------------------"
echo "SECRET_KEY_BASE=$SECRET_KEY_BASE"
echo ""
echo "VAPID_PUBLIC_KEY=$VAPID_PUBLIC_KEY"
echo "VAPID_PRIVATE_KEY=$VAPID_PRIVATE_KEY"
echo "-------------------------------------------"
echo ""

# 4. Opcionalmente criar arquivo .env
read -p "Deseja criar um arquivo .env automaticamente? (s/N): " CREATE_ENV

if [[ "$CREATE_ENV" =~ ^[Ss]$ ]]; then
    ENV_FILE=".env.portainer"

    if [ -f "$ENV_FILE" ]; then
        read -p "Arquivo $ENV_FILE já existe. Sobrescrever? (s/N): " OVERWRITE
        if [[ ! "$OVERWRITE" =~ ^[Ss]$ ]]; then
            echo "Operação cancelada."
            exit 0
        fi
    fi

    cat > "$ENV_FILE" << EOF
# Fizzy Portainer Stack - Environment Variables
# Gerado automaticamente em $(date)

# ============================================
# CONFIGURAÇÃO OBRIGATÓRIA
# ============================================

# Host do Fizzy (ALTERE PARA SEU DOMÍNIO!)
FIZZY_HOST=fizzy.localhost

# Rails Secret Key Base
SECRET_KEY_BASE=$SECRET_KEY_BASE

# ============================================
# CONFIGURAÇÃO DE EMAIL (SMTP)
# ============================================

# Servidor SMTP (CONFIGURE COM SEUS DADOS!)
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_DOMAIN=gmail.com

# Credenciais SMTP (ALTERE!)
SMTP_USERNAME=seu-email@gmail.com
SMTP_PASSWORD=sua-senha-de-app

# Email remetente
MAILER_FROM_ADDRESS=noreply@fizzy.localhost

# ============================================
# WEB PUSH NOTIFICATIONS (VAPID)
# ============================================

VAPID_PUBLIC_KEY=$VAPID_PUBLIC_KEY
VAPID_PRIVATE_KEY=$VAPID_PRIVATE_KEY

# ============================================
# CONFIGURAÇÕES OPCIONAIS
# ============================================

# Multi-tenancy (permitir múltiplas organizações)
# MULTI_TENANT=true

# Adapter de storage (local, s3)
# ACTIVE_STORAGE_SERVICE=local
EOF

    echo -e "${GREEN}✓ Arquivo $ENV_FILE criado com sucesso!${NC}"
    echo ""
    echo "Próximos passos:"
    echo "1. Edite $ENV_FILE e configure:"
    echo "   - FIZZY_HOST (seu domínio)"
    echo "   - SMTP_USERNAME e SMTP_PASSWORD (configuração de email)"
    echo "2. Use este arquivo no Portainer ou carregue com: export \$(cat $ENV_FILE | xargs)"
else
    echo ""
    echo "Copie os valores acima manualmente para seu arquivo .env"
fi

echo ""
echo -e "${GREEN}Concluído!${NC}"
