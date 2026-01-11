PROJETO CARTIO - Common Authorized Resilient Tactical Identity Operations
AUTORIA: Wagner Philippe Calazans
ANO: 2025
INSTITUIÇÃO: Instituto Militar de Engenharia (IME)

DESCRIÇÃO DO CONTEÚDO:
Contém a implementação de referência do protocolo CARTIO e os utilitários de
automação tática desenvolvidos durante o mestrado.

ESTRUTURA:
- src/scripts/  : Scripts de sincronização (.sh) e motores de carga (.py).
- src/schema/   : Definições de atributos LDAP (cartio-schema.ldif).
- scim_server/  : Implementação do servidor SCIM em Flask para fins comparativos.
- certs/        : Infraestrutura de chaves para testes com SSL/TLS.

OBSERVAÇÃO:
As pastas de ambiente virtual (venv) foram omitidas. Utilize 'pip install -r 
requirements.txt' para reconstruir as dependências.