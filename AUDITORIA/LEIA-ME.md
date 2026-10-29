# Auditoria da edição unificada

## Cobertura real

- 6 arquivos fornecidos, 2.384.419 bytes, preservados byte a byte em Fontes/.
- 1.145 controles de interface identificados estaticamente por tokenização (não execução dos hubs).
- 761 rótulos normalizados. Configurações e nomes traduzidos/variantes também entram nessa contagem.
- 148 rótulos/aliases apontam para comandos ou módulos portados nesta edição.
- 613 rótulos permanecem **indisponíveis**, não como botões/toggles fictícios.
- 62 comandos simples agrupados por assinatura de argumentos. Não se escolhe uma versão arbitrária por nome quando os argumentos diferem.

`inventario.json` contém rótulo, origem, linha, categoria e implementação, quando houver. `compilacao-originais.json` registra somente compilação dos originais: nenhum deles foi executado durante esta revisão.

## Critérios de integração

Não foi usada concatenação de hubs ou adaptação por sandbox/global compartilhado: os inicializadores criam loops, menus, carregadores externos e alterações de estado diferentes. Foram criados serviços próprios e uma única arbitragem para movimento/farm.

Callbacks de compra/comando automaticamente aproveitados precisam ser exatamente uma chamada CommF_ com argumentos literais. Essa extração não executa o callback. A implementação própria exige autorização experimental, debounce/pendência e confirmação em dois cliques.

Farm Level prefere o módulo Quests do jogo e usa fallback identificado. Os fontes Eclipse/Skibidi colocam Serpent Hunter após 2550, divergindo do snapshot fornecido (LevelReq 2550). Não adotamos esse off-by-one nem coordenadas potencialmente de mobs como posições confirmadas de quest giver.

Materiais/ossos/ectoplasm reutilizam ações normais e nomes de NPCs; falta de alvo, falta de dano ou ausência de dependências produz status/erro, não sucesso fictício. Não garante drops ou crédito de kills.

Não há execução de autoload koby, Fluent/Paste, BringMobLoader/FastAttackLoader, webhooks, hooks, propriedades ocultas, kick/shutdown, áudio ou troca de time automática da abertura dos originais. Bibliotecas/scripts independentes previamente existentes foram preservados, não ativados.

## Testes

Veja `testes.json`: compilação dos arquivos de produção e testes em Luau Web/WASM com mocks de scheduler, clock, mundo, remotes e UI. Cobrem seleção 2550/2575, limites de mares, exclusão de bosses, configuração OFF, cancelamento, ausência de dano, missão não confirmada, quest diferente, mudança de nível, timeout e pendência de remote, confirmação de compras, arbitragem e construção das seis abas adicionais.

**Não há Roblox nem Delta neste ambiente.** Os testes não confirmam o protocolo atual de combate, os schemas de todas as quests, os custos/requisitos das compras ou a execução destas novas abas no Android.

Para reproduzir os testes, em um ambiente Node.js 26 com internet para instalar a dependência de teste:

```bash
# Dentro da pasta AUDITORIA do pacote extraído:
npm install --ignore-scripts
node validar.mjs ..
```

Essa dependência npm é apenas para os testes offline, não para o loader do executor. `extrair-inventario.reference.py` é a referência do extrator usado, com caminhos do ambiente de revisão; não é executado pelo hub.

## Créditos e permissões

Biblioteca visual: tlredz / Redz Hub. Arquivos fornecidos identificam Eclipse/Luan, Fai Fao, Kakah Menu/Souza/Skinny e outros nomes nos cabeçalhos, Skibidi/Haidepzai e Xester/HuySimp. Os originais preservam esses cabeçalhos sem reivindicação de autoria.

Código legível, ausência de chave ou comentários “cracked” não comprovam licença nem titularidade. Nenhuma licença de redistribuição desses seis arquivos foi verificada. Confirme permissões antes de redistribuir/publicar; os originais no ZIP servem à rastreabilidade do material que você forneceu.