# Clareza — Finanças da família

Aplicativo estático para controle financeiro familiar, conectado ao Supabase.

## Publicação

O `index.html` é a aplicação. O GitHub Pages pode publicá-lo diretamente a partir da raiz do repositório. O arquivo `supabase.sql` registra o esquema, as permissões e o compartilhamento por código de convite.

## Primeiro acesso

1. A primeira pessoa cria uma conta no app e confirma o e-mail.
2. No primeiro acesso, o app cria o orçamento familiar compartilhado.
3. Em **Configurações**, copie o código de convite.
4. A segunda pessoa cria sua própria conta e informa o código durante o cadastro.

O app usa a chave publicável do Supabase no navegador. Os dados financeiros ficam no banco e o acesso é controlado pelas políticas RLS para membros do orçamento. Nunca inclua uma chave `service_role` neste app.

## Projeto Supabase

- Projeto: Clareza Finanças
- Região: São Paulo
- URL: `https://thkziqyytdobxmvobguz.supabase.co`

As configurações de URL de redirecionamento da autenticação devem apontar para o endereço final do GitHub Pages após a publicação.
