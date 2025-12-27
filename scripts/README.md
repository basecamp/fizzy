# Scripts do Fizzy

Esta pasta contém scripts utilitários para facilitar o deploy e configuração do Fizzy.

## generate-secrets.sh

Gera automaticamente todos os secrets necessários para o Fizzy **sem precisar do container rodando**.

### Uso

```bash
./scripts/generate-secrets.sh
```

### O que faz

1. **Gera SECRET_KEY_BASE**: String aleatória de 128 caracteres (hex) usando OpenSSL
2. **Gera chaves VAPID**: Par de chaves ECDSA P-256 para Web Push Notifications
3. **Exibe os valores**: Mostra todos os secrets gerados no terminal
4. **Cria arquivo .env (opcional)**: Pergunta se você quer criar `.env.portainer` automaticamente

### Requisitos

- `openssl` (geralmente já instalado no Linux/Mac)
- `base64` (geralmente já instalado)

### Exemplo de saída

```
==========================================
  Gerador de Secrets do Fizzy
==========================================

1. Gerando SECRET_KEY_BASE...
✓ Gerado!

2. Gerando VAPID keys (Web Push)...
✓ Gerado!

==========================================
  SECRETS GERADOS COM SUCESSO!
==========================================

Copie estes valores para o seu arquivo .env:

-------------------------------------------
SECRET_KEY_BASE=a1b2c3d4e5f6...

VAPID_PUBLIC_KEY=BPx1y2z3...
VAPID_PRIVATE_KEY=a9b8c7d6...
-------------------------------------------

Deseja criar um arquivo .env automaticamente? (s/N):
```

### Por que usar?

Antes você precisava:
```bash
# Baixar a imagem Docker (pode ser grande)
docker pull ghcr.io/basecamp/fizzy:latest

# Rodar comando dentro do container
docker run --rm ghcr.io/basecamp/fizzy:latest bin/rails secret
```

Agora é só:
```bash
./scripts/generate-secrets.sh
```

**Muito mais rápido e simples!** ⚡
