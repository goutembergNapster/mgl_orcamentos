# Aplicativo Orçamento — Flutter MVP

MVP para gerar orçamentos em PDF e disparar um webhook para o n8n (para envio no WhatsApp, por exemplo).

## Como usar

1. **Pré-requisitos**: Flutter 3.19.x instalado (`flutter --version`).
2. Dentro da pasta do projeto, rode:
   ```bash
   flutter pub get
   flutter run
   ```
3. Copie o arquivo `.env.sample` para `.env` e ajuste:
   - `WEBHOOK_URL` → URL do **Webhook** do seu n8n.

## Estrutura
- `lib/models.dart` — modelos de dados (Profissional, Cliente, Item, Orcamento);
- `lib/services/pdf_service.dart` — geração do PDF (bytes e salvar arquivo);
- `lib/services/n8n_client.dart` — POST para Webhook n8n com JSON + PDF base64;
- `lib/pages/home_page.dart` — tela única (form + itens + ações);
- `lib/main.dart` — bootstrap, dotenv e MaterialApp.

## n8n (exemplo)
Importe `n8n_workflow_example.json` no n8n. Esse fluxo:
- Recebe o JSON do app (com `pdf.base64`);
- Monta um texto de resposta;
- Envia via **WhatsApp Cloud API** (ajuste `PHONE_ID` e token).

> Compatibilidade: este pacote usa `printing:^5.12.0` para rodar no Flutter 3.19.x. 
> Se atualizar o Flutter para >=3.22, você pode subir para `printing:^5.13.x`.
# mgl_orcamentos



MGL Orçamentos (Flutter)

App Flutter para criação e gestão de orçamentos com cadastro de clientes e perfil profissional, geração de PDF, e (opcionalmente) envio para n8n via webhook.

✨ Principais recursos

Autenticação local com migração automática do formato legado

Hash + salt (sha256) em SharedPreferences

Suporte a login, cadastro e redefinição de senha

Lembrar e-mail / sessão (armazenamento local)

Perfil Profissional (com logo) usado no PDF

Clientes

Busca visível (texto escuro), paginação (10 em 10), edição e exclusão

Deduplicação por telefone ou CPF/CNPJ

Orçamentos

Iniciar rapidamente pela Home (“+ Novo Orçamento”)

Itens com descrição, quantidade, unidade, valor unitário, desconto/acréscimos

Gerar PDF (compartilhar/imprimir) usando printing

Reimprimir e Editar pela página de Orçamentos (por cliente)

Após gerar PDF, a Home volta para o estado inicial (formulário fechado e campos limpos)

n8n (futuro)

Botão “Envio Auto” aparece desabilitado (visual de placeholder)

Quando ativar, o envio usará WEBHOOK_URL do .env

ViaCEP: preenchimento automático do endereço do cliente pelo CEP

Tema com gradiente e tipografia consistente
