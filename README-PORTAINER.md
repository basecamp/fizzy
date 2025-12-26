# Deploy do Fizzy no Portainer

Este guia explica como fazer o deploy do Fizzy usando Portainer com Traefik como proxy reverso.

## Pré-requisitos

- Portainer instalado e configurado
- Traefik configurado com as networks:
  - `traefik_public` (proxy reverso)
  - `digital_network` (overlay network)
- Docker Swarm inicializado (para networks overlay)
- Domínio apontando para seu servidor

## Arquivos Necessários

- `docker-compose.portainer.yml` - Stack do Portainer
- `.env.portainer.example` - Template de variáveis de ambiente

## Passo a Passo

### 1. Gerar Secrets (SUPER FÁCIL!)

Execute o script gerador (não precisa do container rodando!):

```bash
./scripts/generate-secrets.sh
```

O script vai:
- ✅ Gerar SECRET_KEY_BASE automaticamente
- ✅ Gerar chaves VAPID para notificações push
- ✅ Exibir os valores para você copiar
- ✅ Opcionalmente criar arquivo `.env.portainer` pronto para usar

**Alternativa manual** (sem script):

```bash
# SECRET_KEY_BASE (qualquer string aleatória de 128 chars)
openssl rand -hex 64

# Se preferir usar o container do Fizzy:
docker run --rm ghcr.io/basecamp/fizzy:latest bin/rails secret
docker run --rm ghcr.io/basecamp/fizzy:latest bin/rails runner "puts WebPush.generate_key.to_json"
```

### 2. Preparar o Arquivo .env

Se não usou o script acima, copie o arquivo de exemplo:

```bash
cp .env.portainer.example .env.portainer
```

Edite `.env.portainer` e configure **apenas**:

```env
# Host do seu domínio (OBRIGATÓRIO!)
FIZZY_HOST=fizzy.seudominio.com

# Configuração de Email (OBRIGATÓRIO para magic links funcionarem!)
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=seu-email@gmail.com
SMTP_PASSWORD=sua-senha-de-app-do-gmail
MAILER_FROM_ADDRESS=noreply@fizzy.seudominio.com
```

**Nota:** Se usou o script `generate-secrets.sh`, os valores SECRET_KEY_BASE e VAPID já estão preenchidos automaticamente! ✨

### 3. Deploy no Portainer

#### Opção A: Via Interface Web

1. Acesse o Portainer
2. Vá em **Stacks** → **Add stack**
3. Nomeie a stack: `fizzy`
4. Cole o conteúdo de `docker-compose.portainer.yml`
5. Em **Environment variables**, adicione as variáveis do seu `.env`
6. Clique em **Deploy the stack**

#### Opção B: Via CLI (docker stack)

```bash
# Carregue as variáveis de ambiente
export $(cat .env | xargs)

# Deploy da stack
docker stack deploy -c docker-compose.portainer.yml fizzy
```

### 4. Configuração do DNS

Aponte seu domínio para o servidor:

```
fizzy.seudominio.com  →  IP_DO_SERVIDOR
```

### 5. Verificar o Deploy

Aguarde alguns minutos para:
- Download da imagem Docker
- Inicialização do MySQL
- Migração do banco de dados
- Inicialização do Fizzy

Verifique os logs:

```bash
# Via Portainer: Stacks → fizzy → Logs

# Via CLI:
docker service logs fizzy_fizzy
docker service logs fizzy_db
```

### 6. Acessar o Fizzy

Acesse: `https://fizzy.seudominio.com`

O Traefik deve gerar automaticamente o certificado SSL via Let's Encrypt.

## Configuração de Email (Gmail)

Para usar Gmail como SMTP:

1. Acesse sua conta Google
2. Vá em **Segurança** → **Verificação em duas etapas**
3. Em **Senhas de app**, gere uma senha específica
4. Use essa senha no `SMTP_PASSWORD`

## Troubleshooting

### Container não inicia

Verifique os logs:

```bash
docker service logs fizzy_fizzy --tail 100
```

### Erro de conexão com o banco

Verifique se o MySQL está saudável:

```bash
docker service ps fizzy_db
```

### Traefik não roteia

Verifique se o container está na network correta:

```bash
docker network inspect traefik_public
```

Deve listar o serviço `fizzy_fizzy`.

### Erro 502 Bad Gateway

- Aguarde a migração do banco de dados terminar
- Verifique o healthcheck: `docker service ps fizzy_fizzy`

### Regenerar o Banco de Dados

Se precisar resetar:

```bash
# Pare a stack
docker stack rm fizzy

# Remova o volume do banco
docker volume rm fizzy_fizzy_db_data

# Faça o deploy novamente
docker stack deploy -c docker-compose.portainer.yml fizzy
```

## Segurança

### Senhas

A senha do MySQL está definida como `Slay159753` no `docker-compose.portainer.yml`. Para produção:

1. Altere a senha no arquivo compose:
   ```yaml
   - MYSQL_ROOT_PASSWORD=sua-senha-forte
   - MYSQL_PASSWORD=sua-senha-forte
   ```
2. Atualize a variável no serviço fizzy:
   ```yaml
   - MYSQL_PASSWORD=sua-senha-forte
   ```

### Firewall

Certifique-se de que apenas as portas 80 e 443 estejam abertas publicamente.

## Backup

### Banco de Dados

```bash
# Export do banco
docker exec fizzy_db mysqldump -u root -pSlay159753 fizzy_production > backup.sql

# Import do banco
docker exec -i fizzy_db mysql -u root -pSlay159753 fizzy_production < backup.sql
```

### Storage (uploads/arquivos)

```bash
# Backup do volume
docker run --rm -v fizzy_fizzy_storage:/data -v $(pwd):/backup ubuntu tar czf /backup/fizzy-storage.tar.gz /data

# Restore do volume
docker run --rm -v fizzy_fizzy_storage:/data -v $(pwd):/backup ubuntu tar xzf /backup/fizzy-storage.tar.gz -C /
```

## Atualização

Para atualizar para uma nova versão:

```bash
# Pull da nova imagem
docker pull ghcr.io/basecamp/fizzy:latest

# Atualizar o serviço
docker service update --image ghcr.io/basecamp/fizzy:latest fizzy_fizzy
```

Ou simplesmente atualize a stack no Portainer.

## Monitoramento

### Verificar status dos serviços

```bash
docker stack services fizzy
```

### Verificar réplicas

```bash
docker service ps fizzy_fizzy
docker service ps fizzy_db
```

### Logs em tempo real

```bash
docker service logs -f fizzy_fizzy
```

## Recursos

- **Documentação oficial**: https://github.com/basecamp/fizzy
- **Issues**: https://github.com/basecamp/fizzy/issues
- **Imagem Docker**: https://github.com/basecamp/fizzy/pkgs/container/fizzy

## Suporte

Se encontrar problemas:

1. Verifique os logs dos serviços
2. Consulte a seção de Troubleshooting
3. Abra uma issue no repositório oficial
