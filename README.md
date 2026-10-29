# BAHIANO-HUB

## Edição unificada — experimental

Interface CyberBlue preservada, com banner/avatar e créditos da biblioteca tlredz / Redz Hub.
Os seis arquivos fornecidos foram analisados estaticamente. **Não são executados juntos nem carregados por um hub externo.**

### O que está implementado

- Auto Farm Level: seleção por nível/mar, aceitar quest, atacar NPCs compatíveis, repetir e trocar de quest depois de terminar a anterior.
- Farm por alvo: NPC mais próximo, NPC/boss presente e grupos de materiais, ossos, ectoplasm e cake mobs. Não invoca boss, não aceita quest de boss e não confirma drops.
- 62 comandos simples deduplicados pela assinatura do remote: compras, estilos, crafting, time e viagem. Confirmação em dois cliques; servidor decide custos/requisitos.
- Utilitários: Anti AFK, FPS Booster reversível, iluminação/neblina, ESP de jogadores/NPCs/inimigos/frutas/localizações, Job ID e rejoin.
- Auto Stats, consulta/compra de frutas, guardar frutas com OriginalName reconhecido, Auto Store Fruit, seleção/compra de chip e pedido de despertar.
- Spectate local, sem ataques automáticos contra jogadores.

**Implementado não significa validado no Delta.** Comandos de jogo adicionais precisam da autorização “Autorizar testes experimentais” na aba Loja. Todos os toggles começam desligados. Auto Farm Level também é experimental, com status e diagnóstico próprios.

### Catálogo não é implementação

A extração identificou **1.145 controles em seis arquivos**, agrupados em **761 rótulos normalizados**. Há funções, configurações e variantes com nomes diferentes; esse número NÃO é uma contagem de automações funcionando.

A aba **Todas as funções** mostra referência/linha e situação de cada recurso. Os que ainda não foram portados/validados aparecem **INDISPONÍVEIS**, sem botão de execução. Incluem muitas automações avançadas de mastery, raids completos, eventos, puzzles/V4 e PvP, além de fast attack/magnet/bypass dependentes de lógica não confirmada ou externa.

As duplicatas executáveis usam um único serviço: comandos são agrupados pelos argumentos, e farms compartilham equipamento, movimento, ataque e cancelamento. O último farm ativado interrompe o anterior. Variantes ainda indisponíveis permanecem no catálogo para rastreabilidade, não como menus/loops concorrentes.

## Instalar no seu GitHub

1. Extraia o ZIP. Substitua os arquivos correspondentes na **raiz** do seu repositório `santosps222328-star/BAHIANO-HUB`, branch `main`.
2. Envie também as pastas **Modules/** e **Data/**. Sem elas, o loader interrompe com o nome do arquivo ausente.
3. Mantenha **Library/** e **assets/**. A pasta AUDITORIA/ é documental, não é baixada nem executada pelo loader.
4. O arquivo independente `BAHIANO-HUB/BahianoHub.lua` que já existia foi preservado; seu otimizador não foi integrado nem ativado automaticamente.
5. No Delta, execute:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/santosps222328-star/BAHIANO-HUB/main/TestarExecutor.luau"))()
```

Não foi feito push nem publicação no seu GitHub. O link acima só carregará esta edição **depois do seu upload**.

## Primeiro teste — Terceiro Mar, nível 2550

1. Fique perto do **Tiki Quest Giver 3**, com o jogo e personagem carregados.
2. Termine ou abandone manualmente uma quest diferente. O hub não abandona sua missão sem consentimento.
3. Escolha **Melee**, **Sword** ou **Equipped**. Equipped usa a ferramenta que você deixou na mão, permitindo uma arma específica.
4. Comece com **Tool + Walk**. Ative apenas Auto Farm Level.
5. Confira o status: **TikiQuest3 / 1 / Serpent Hunter**. No snapshot, a etapa 2 é Skull Slayer a partir de 2575.
6. Se não andar/alcançar NPC ou não houver redução de HP em 15s, o controlador para com erro. Teste Click ou Tween apenas conscientemente; não existe contrato de fast attack verificado.
7. Use **Gerar / copiar diagnóstico** e envie o texto ou captura. Ele também tenta salvar `RedzCyberBlue/DIAGNOSTICO.txt` no executor.
8. Depois de validar Level, teste um único módulo adicional por vez. Para comandos: autorize experimentais e confirme a ação com o segundo clique em até 15s.

## Limites técnicos e de segurança

- Quests do jogo têm prioridade. Se indisponíveis, usa-se um snapshot identificado; não cobre nível 2600+. Dados atuais do jogo não foram confirmados neste ambiente.
- Os arquivos novos discordam no limite 2550/2551 e contêm posições ambíguas de quest/NPC. Essas divergências NÃO substituíram silenciosamente a seleção de 2550. Não há coordenadas inventadas.
- NPCs e spawns precisam existir no cliente. Walk não calcula rotas interilhas; Tween é experimental e pode ser corrigido pelo servidor. Não há troca automática de mar.
- O combate usa Tool:Activate ou entrada virtual. Não há remote inventado de hit, manipulação de HP, hooks, SimulationRadius ou execução de FastAttackLoader/BringMobLoader.
- Redução observada de HP pode ter outras causas; não comprova crédito do abate. O farm só aceita a quest após reconhecê-la na interface, e não declara conclusão com base em um clique.
- Desligar/fechar/reexecutar cancela tarefas e movimento próprios. **Um pedido já enviado ao servidor não pode ser retirado**; um pedido ainda não enviado é cancelado. Não repetimos chamadas CommF_ pendentes.
- Não há webhooks, autoload koby, kick/shutdown, alteração de áudio ou execução dos inicializadores dos seis hubs.
- Não há garantia antiban ou garantia de segurança da conta. Use por sua conta e risco.

## Validação

Veja `AUDITORIA/testes.json` e `AUDITORIA/compilacao-originais.json`: compilação Luau e testes offline com mocks, **não teste dentro do Roblox/Delta**. A interface anterior foi confirmada pelo usuário; as abas e módulos desta edição ainda precisam de teste no executor.

Originais, hashes, referências e inventário estão em AUDITORIA/. Os arquivos legíveis fornecidos não vinham acompanhados de uma licença verificada; preserve as atribuições e confirme permissões antes de redistribuir.