O JOGO
Um círculo com uma bola que se move na sua linha. Nessa linha existe:

Safe Zone — se o jogador parar a bola nesta zona, avança de nível.
Target — posição especial na linha; parar a bola sobre ele faz passar de nível. Se o target estiver
fora da safe zone, o jogador passa de nível sem aumentar nenhum nível de dificuldade em nenhuma 
variável para compensar o risco de tentar parar a bola no target fora da safe zone.

O jogador perde se parar a bola fora da Safe Zone e também fora do Target ou exceder o tempo limite para acabar uma run que é 1 hora.
Após 1 hora desde o início, a run acaba e o jogador fica com a pontuação que tinha no final, mesmo que esteja em pause.
Safe Zone dividida em zonas (por percentagem da safe zone):

Gold: primeiros 10% + últimos 10%
Silver: seguintes 15% + anteriores 15%
Bronze: 50% centrais

Cada zona vale Run Points (RP): Gold=3, Silver=2, Bronze=1
O centro da bola determina os RP ganhos. Mas o jogador passa de nível se qualquer parte da bola tocar a Safe Zone. Se o centro estiver fora da Safe Zone mas a bola tocar nela, o jogador passa mas não ganha RP — mostrar mensagem e fazer zoom para mostrar posição exata.
Para o Target: considera acerto se qualquer parte da bola tocar o Target.

SISTEMA DE DIFICULDADE
6 variáveis, cada uma com 11 níveis (0 a 10). A cada nível passado, apenas 1 variável aumenta aleatoriamente.
1. Velocidade da bola

Nível 0: velocidade base fácil
Nível 10: muito rápida
A velocidade da bola nível N corresponde à velocidade do Target nível N+1
A velocidade da bola nível 10 é ligeiramente superior à velocidade do Target nível 10

2. Tamanho da bola

Nível 0: grande
Nível 10: pequena

3. Tempo para parar a bola

Nível 0: 30s | Nível 1: 27s | Nível 2: 24s | Nível 3: 21s | Nível 4: 18s
Nível 5: 15s | Nível 6: 13s | Nível 7: 11s | Nível 8: 9s | Nível 9: 7s | Nível 10: 5s

4. Tamanho da Safe Zone

Nível 0: 55% da linha do círculo
Cada nível reduz 5%
Nível 10: 5% da linha

5. Velocidade da Safe Zone

Nível 0: parada
Aumenta progressivamente até nível 10: muito rápida

6. Velocidade do Target

Nível 0: parado
A velocidade do Target nível N deve estar entre a velocidade da Safe Zone nível N e N+1
A velocidade do Target nível 10 é superior à velocidade da Safe Zone nível 10
O objetivo é que a velocidade do Target nunca seja igual à da Safe Zone em nenhum nível


RUN POINTS (RP) e MENU ENTRE NÍVEIS
RP acumulam durante a run e podem ser gastos no menu que aparece após cada nível:

Next level — sobe dificuldade numa variável aleatória, mantém RP (grátis)
Aumentar dificuldade numa variável específica escolhida pelo jogador — 2 RP cada (6 opções)
Não aumentar dificuldade — 5 RP
Diminuir dificuldade numa variável aleatória — 10 RP
Diminuir dificuldade numa variável à escolha — 15 RP (mostra nível atual de cada variável)
Comprar uma vida — 20 RP (permite repetir o nível se perder; sem limite de vidas)


PRECISION POINTS (PP) — Pontuação de Competição

Pontuação máxima: 1000 PP quando o centro da bola coincide exatamente com o Target
Quando para na Safe Zone: PP calculados pela distância do centro da bola ao Target
PP acumulam durante toda a run e são sempre visíveis no ecrã
PP ganhos ganhos num nível são o total PP base (distância do centro da bola ao 
    Target) * ( 1 + (nível * 0.01) )
Se parar fora da Safe Zone e fora do Target: perde, PP=0 para esse nível
Pontuação final da Run são o total de PP ganhos + Pontos Bónus de níveis (nível atingido * 100)

Pontuação semanal:

1-5 jogadas: melhor jogada
6-10 jogadas: média das 2 melhores
11-15 jogadas: média das 3 melhores
(incrementa 1 jogada por cada 5 adicionais)

Multiplicador bónus por dias de atividade na semana:

1 dia: ×1.0 | 2 dias: ×1.1 | 3 dias: ×1.2 | 4 dias: ×1.4
5 dias: ×1.6 | 6 dias: ×1.8 | 7 dias: ×2.0


Ads

A Estratégia de Ads

Fim do jogo:

Exemplo prático de fim do jogo:
1. O jogador termina a run.
2. Tu ofereces: "Queres uma continuar do mesmo nível?” (Vídeo Recompensado).
3. Cenário A (Ele clica): Vê o vídeo, recomeça do mesmo nível e não vê mais nada.
4. Cenário B (Ele recusa): Ele clica em "Sair". Ele vê um Intersticial rápido (5 segundos).

Fim da run: O jogador clica em “Sair”.
Ecrã de Transição (1.5 segundos): Fundo desfocado do jogo com a mensagem: "A calcular a tua pontuação... 🚀".
Disparo do Anúncio: O Intersticial aparece.
Fecho: O jogador volta diretamente para o ecrã de resultados finais.

Durante o jogo (banners):

Como o jogo depende de precisão absoluta e milissegundos, o "refresh" automático de banners pode ser um problema. O processo de descarregar e renderizar um novo anúncio consome CPU e pode causar um frame drop (aquele pequeno "salto") exatamente no momento de um clique decisivo.
Para garantir zero stutter, aqui está a estratégia técnica que deves seguir:

1. Desativar o "Auto-Refresh" Totalmente
   Devemos assumir o controlo manual do refresh de banners:

* Carregamento inicial: Carrega o primeiro banner quando o jogador está no Menu Principal.

* Refresh a cada 10 níveis: Só pedes um novo banner na primeira vez que o jogador parar a bola na safe zone após pelo menos 10 níveis depois do banner actual ter sido carregado. Quando a "run" terminar, se o jogador escolher ter uma vida extra é carregado novo banner e a regra de refresh a cada 10 níveis mantém até o jogador acabar a run (game over).

Resumo da Implementação Técnica:

1.1. Se o jogador está a jogar: Banner estático (sem refresh).
1.2. Se o jogador pára a bola na safe zone:
    * Verifica: nº de níveis passados desde o último load/refresh >= 10 ?
    * Se sim: Executa refreshBanner().
    * Se não: Mantém o atual.
1.3. Antes de voltar a jogar: Garante que o pedido do anúncio já terminou ou está em segundo plano antes de recomeçar a run.


2. Pré-carregamento (Caching)
   Configura o código para fazer o fetch (pedido) do próximo Intersticial ou Vídeo Recompensado logo no início da run.
   Assim, quando o jogador perder, o anúncio já está na memória do telemóvel e aparece instantaneamente, sem precisar de usar a internet ou o processador naquele momento crítico.
   A mesma coisa deve ser feita para o primeiro banner: o fetch(pedido) deve ser feito antes do início da run.

3. Usar Banners Estáticos (Não-Animados)
   Evita banners que contenham vídeos ou animações pesadas. No painel da rede de anúncios (ex: AdMob), podes filtrar os tipos de anúncios:

* Bloqueia: Anúncios de vídeo e GIFs complexos em banners.
* Permite: Apenas imagens estáticas e texto. São muito mais leves e não causam picos de processamento após o carregamento inicial.


4. Prioridade de Processamento (Thread Handling)
   Garantir que a SDK de anúncios corre numa thread secundária e nunca na thread principal (Main/UI Thread), onde o jogo processa a física e os inputs.
   Mesmo assim, possivelmente, em telemóveis mais fracos, a simples gestão de rede pode causar picos de latência.


SISTEMA DE LIGA
Estrutura de divisões:

Divisão 1: 10 jogadores
Divisão 2: 20 jogadores
Divisão 3: 40 jogadores
Cada divisão seguinte tem o dobro da anterior
Nova divisão criada automaticamente quando a última enche

GP (Game Points):

Custo semanal: 10 GP para participar
Jogador sem GP mantém slot reservado (exceto última divisão) mas aparece como "inactive" com pontuação 0
Se terminar a semana sem pagar: desce de divisão
Ao pagar: pontuação passa a 0 e pode começar a jogar

Regras de descida (todas as divisões exceto última):

Mínimo 40% dos jogadores desce
Descem sempre os que não pagaram os 10 GP
Se os não-pagantes não chegarem aos 40%, completam-se com os de menor pontuação
Se os não-pagantes ultrapassarem 40%, descem todos na mesma
Jogadores que descem para a última divisão perdem a slot reservada

Regras de subida:

Nº de jogadores que sobe = nº que desceu da divisão acima
Mínimo 20% de jogadores sobe de cada divisão

Regras especiais penúltima ↔ última divisão:

Todos os inativos da penúltima descem e perdem reserva
Se 20% melhores da última divisão > nº de inativos que descem: descem os inativos + piores ativos até igualar o nº que vai subir
Se 20% melhores da última divisão < nº de inativos que descem: sobem os melhores classificados da última até igualar o nº de inativos
Ativos que descem para a última ficam com slot reservada
Ativos que se mantêm na última ficam com slot reservada
Só inativos que ficam ou descem para a última perdem reserva

Visualização do ranking:

Posição atual do jogador na sua divisão
5 jogadores acima e 5 abaixo com pontuações semanais
Pontuação mínima para subir
Pontuação mínima para não descer
Nº de dias jogados e multiplicador atual de cada jogador visível
Jogadores inativos mostram "inactive" em vez de pontuação

Desempates (por ordem):

Maior nº de dias com atividade na semana
Maior nº de jogadas feitas na semana
Melhor jogada individual da semana
Segunda melhor jogada individual
Terceira melhor jogada individual
Registo mais antigo na app

Fecho semanal: Domingo às 23:59 hora de Portugal (Europe/Lisbon)

JOGADOR
Registo:

Campos: Username (único), Email e País (Escolha de uma lista pré-definida com todos os países do mundo)
Recebe 5 GP ao registar

GP — Como ganhar:

1 GP por cada run feita (liga, torneio ou warmup(no warmup só ganha 1 GP se fizer pelo menos 10000 PP na run))
2 GP por cada dia com pelo menos 1 jogada (conta hora de fim da primeira run do dia)
Compra direta: 10GP=1€, 25GP=2€

Warmup:
É uma run como outra qualquer, mas só está disponível quando GP < 10
Permite fazer runs e ganhar GP sem custo de entrada


Torneios:

Todos os meses há um torneio knockout sendo que a inscrição para o torneio de um determinado mês é aberta desde o dia seguinte
ao final do torneio do mês anterior até ao último dia do mês anterior. 

Cada duelo tem a duração de 1 dia em que cada jogador pode fazer o nº de jogadas que quiser e o sistema de pontuação é igual 
ao da liga: 1 a 5 jogadas conta a melhor pontuação dessas jogadas. De 6 a 10 jogadas conta a média das duas melhores jogadas 
e assim consecutivamente.
Nas competições knockout não há pontos bónus.
No final do dia às 23h59 hora PT acaba o duelo e é feito o sorteio para a próxima ronda e começa mais um duelo de 1 dia com 
as mesmas regras. Dependendo do nº de inscritos pode muito provavelmente haver jogadores que têm passagem direta para a próxima 
ronda pois não têm adversário para acertar o emparelhamento. Exemplo:
Final - 2 jogadores
Semi Finais - 4 jogadores
Quartos de Final - 8 jogadores
Oitavos de Final - 16 jogadores
Ronda anterior - 32 jogadores e assim consecutivamente
Se no torneio se inscreveram por exemplo 35 jogadores, o primeiro dia do torneio vai emparelhar o nº de duelos suficiente 
para conseguirmos eliminar o nº de jogadores suficiente para no dia seguinte termos o nº de jogadores certo para que todos 
tenham adversário nos dias seguintes até ser determinado o vencedor. Neste exemplo só teríamos de fazer 3 duelos no primeiro 
dia (emparelhando aleatoriamente 6 jogadores) para termos no dia seguinte 32 jogadores, depois 16, depois 8 e assim sucessivamente 
até encontrarmos o vencedor. Se houver um duelo em que nenhum jogador faz uma run, tem de se ir repescar o jogador com melhor 
pontuação nos duelos desse dia que não tenha sido apurado para a ronda seguinte. Caso não haja jogadores suficientes com pontuação 
para serem repescados, repesca-se o jogador com mais runs feitas na aplicação, caso haja empate vai-se buscar o jogador com 
registo há mais tempo na aplicação.


Histórico do jogador:

Por semana e por liga: divisão, pontuação, dias jogados, nº runs, pontuações individuais contabilizadas, multiplicador, pontos bónus, total
Sumário final de todas as divisões de cada semana
Para cada torneio knockout guarda o mês de competição, a ronda a que chegou, nº de rondas do torneio
Guarda também desde sempre o nº total de runs, nº total de PP, média de PP por run e o record de PP ganho numa run 

Ranking global:

Pontuação total acumulada
Nº total de jogadas
Média de PP por jogada


MONETIZAÇÃO
Publicidade (AdMob):

Anúncio no início de cada run
A cada 5 níveis durante uma run
No final de cada run
Removida permanentemente após compra da app

Compra para remover anúncios: valor a definir, via RevenueCat (abstrai App Store + Google Play)




## Competitive Principles

- No pay-to-win mechanics.
- Skill and precision must determine competitive performance.
- All critical scoring logic must eventually be validated by the backend.

## Status

Rules are still being defined and will be expanded during Game Engine development.