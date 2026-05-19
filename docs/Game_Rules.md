O JOGO
Um círculo com uma bola que se move na sua linha. Nessa linha existe:

Safe Zone — se o jogador parar a bola nesta zona, avança de nível.
Target — posição especial na linha; parar a bola sobre ele também faz passar de nível.


O jogador perde se parar a bola fora da Safe Zone e também fora do Target ou exceder o tempo limite para acabar uma run que é 1 hora.
Após 1 hora desde o início, a run acaba e o jogador fica com a pontuação que tinha no final, mesmo que esteja em pause.

O jogador passa de nível se qualquer parte da bola tocar a Safe Zone. 
Para o Target: considera acerto se qualquer parte da bola tocar o Target.

O último nível que o jogador pode jogar é o nível 60.

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


MENU ENTRE NÍVEIS
Após cada nível deve ser mostrado quanto o jogador ganhou de PP, bem como o novo total de PP acumulado.
Se o jogador acertou no target deve mostrar o valor máximo de PP do próximo tier.
Deve ser mostrado um único botão a dizer Next Level.
Next level — sobe dificuldade numa variável aleatória,


PRECISION POINTS (PP) — Pontuação de Competição

A pontuação máxima vai aumentando à medida que vamos acertando no target durante a run.
No primeiro nível a pontuação máxima é 100. 
Sempre que o jogador acerta no target, avança de nível e no nível seguinte vai ter um novo tier de valor de pontuação máxima de PP.
Se o jogador passar de nível por ter acertado na safe zone sem ter acertado no target, vai manter o tier de valor máximo de pontuação de PP no nível seguinte.

PP_Tier_1 - 100 PP
PP_Tier_2 - 200 PP
PP_Tier_3 - 300 PP
PP_Tier_4 - 500 PP
PP_Tier_5 - 750 PP
PP_Tier_6 - 1000 PP
PP_Tier_7 - 1250 PP
PP_Tier_8 - 1500 PP
PP_Tier_9 - 1750 PP
PP_Tier_10 - 2000 PP
PP_Tier_11 - 2300 PP
PP_Tier_12 - 2600 PP
PP_Tier_13 - 2900 PP
PP_Tier_14 - 3200 PP
PP_Tier_15 - 3500 PP
PP_Tier_16 - 3800 PP
PP_Tier_17 - 4100 PP
PP_Tier_18 - 4400 PP
PP_Tier_19 - 4700 PP
PP_Tier_20 - 5000 PP
PP_Tier_21 - 5500 PP
PP_Tier_22 - 6000 PP
PP_Tier_23 - 6500 PP
PP_Tier_24 - 7000 PP
PP_Tier_25 - 7500 PP
PP_Tier_26 - 8000 PP
PP_Tier_27 - 8500 PP
PP_Tier_28 - 9000 PP
PP_Tier_29 - 9500 PP
PP_Tier_30 - 10000 PP
PP_Tier_31 - 11000 PP
PP_Tier_32 - 12000 PP
PP_Tier_33 - 13000 PP
PP_Tier_34 - 14000 PP
PP_Tier_35 - 15000 PP
PP_Tier_36 - 16000 PP
PP_Tier_37 - 17000 PP
PP_Tier_38 - 18000 PP
PP_Tier_39 - 19000 PP
PP_Tier_40 - 20000 PP
PP_Tier_41 - 23000 PP
PP_Tier_42 - 26000 PP
PP_Tier_43 - 29000 PP
PP_Tier_44 - 32000 PP
PP_Tier_45 - 35000 PP
PP_Tier_46 - 38000 PP
PP_Tier_47 - 41000 PP
PP_Tier_48 - 44000 PP
PP_Tier_49 - 47000 PP
PP_Tier_50 - 50000 PP
PP_Tier_51 - 55000 PP
PP_Tier_52 - 60000 PP
PP_Tier_53 - 65000 PP
PP_Tier_54 - 70000 PP
PP_Tier_55 - 75000 PP
PP_Tier_56 - 80000 PP
PP_Tier_57 - 85000 PP
PP_Tier_58 - 90000 PP
PP_Tier_59 - 95000 PP
PP_Tier_60 - 100000 PP

Pontuação máxima: é ganha quando o centro da bola coincide exatamente com o Target
Quando acerta na Safe Zone ou acerta no target independentemente de onde ele estiver: PP calculados pela
distância do centro da bola ao Target tendo como referência para calcular o valor máximo do tier em que o jogador está.
PP acumulam durante toda a run e são sempre visíveis no ecrã
PP ganhos num nível são o total PP base (distância do centro da bola ao Target)
Se parar fora da Safe Zone e fora do Target: perde, PP=0 para esse nível
Pontuação final da Run são o total de PP ganhos

Pontuação semanal:

1-5 jogadas: melhor jogada
6-10 jogadas: média das 2 melhores
11-15 jogadas: média das 3 melhores
(incrementa 1 jogada por cada 5 adicionais)
Fórmula:
média das   /*  floor((jogadas+4)/5) */   melhores jogadas do jogador na liga semanal

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
Jogador não pagante aparece na classificação como "inactive" até pagar os 10 GP para entrar na liga
Ao pagar: pontuação passa a 0 e pode começar a jogar

Classificação da divisão:
Os jogadores em cada divisão ficam classificados de acordo com as seguintes regras:
Primeiro os jogadores activos, depois os jogadores que não pagaram.

Para os jogadores activos aplicam-se as seguintes regras de desempate(por ordem):
Score da semana
Maior nº de dias com atividade na semana
Maior nº de jogadas feitas na semana
Média de pontuação por jogada na semana
Melhor jogada individual da semana
Mais jogadas feitas desde sempre
Melhor média de pontuação por jogada desde sempre
Registo mais antigo na app

Para os jogadores não pagantes dos 10 GP aplicam-se as seguintes regras de desempate(por ordem):
Mais jogadas feitas desde sempre
Melhor média de pontuação por jogada desde sempre
Registo mais antigo na app


Regras de descida (todas as divisões exceto penúltima e última):

Descem sempre os últimos 40% dos jogadores de acordo com a classificação da divisão


Jogadores que descem para a última divisão perdem a slot reservada

Regras de subida (todas as divisões excepto a última:

Sobem sempre os primeiros 20% de jogadores de acordo com a classificação da divisão

Nº de jogadores que sobe = nº de jogadores que desceu da divisão acima


Regras especiais penúltima ↔ última divisão:
Os jogadores inativos da penúltima divisão descem todos para última
Todos os jogadores inativos que desçam da penúltima divisão deixam de estar na liga e têm que se inscrever novamente para começar da última divisão
Se 20% melhores da última divisão e activos > nº de inativos que descem: descem os inativos + piores ativos até igualar o nº de jogadores que vai subir da última divisão
Se 20% melhores da última divisão e activos < nº de inativos que descem: sobem os melhores classificados activos da última e fecha-se a última divisão
Ativos que descem para a última ficam com slot reservada 
Ativos que se mantêm na última ficam com slot reservada
Só inativos que ficam ou descem para a última perdem reserva


Fecho semanal: Domingo às 23:59 hora de Portugal (Europe/Lisbon)

Visualização do ranking:

Posição atual do jogador na sua divisão
5 jogadores acima e 5 abaixo com pontuações semanais
Pontuação mínima para subir
Pontuação mínima para não descer
Nº de dias jogados e multiplicador atual de cada jogador visível
Jogadores inativos mostram "inactive" em vez de pontuação





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