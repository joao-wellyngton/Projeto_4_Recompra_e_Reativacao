# Projeto 4: Quem recompra? E quem vale reativar?

**Base:** Olist (94.983 clientes, 98.199 pedidos válidos). **Consultas:** `projeto4_recompra_rfm.sql` (C1 a C11).

## Resposta curta

**Quase ninguém recompra.** 96,96% dos clientes compraram uma vez só. Os 3,04% que voltaram geram 5,6% da receita. E 30% das "segundas compras" foram **no mesmo dia** (provavelmente a mesma compra dividida em dois pedidos). O negócio vive de cliente novo.

## O que testei

| Hipótese | O que os dados mostram | Resultado |
|---|---|---|
| Existe uma base fiel | 2.887 clientes recompraram (3,04%). Só contando outro dia: 2.018 (2,12%). | Descartada |
| Quem volta, volta rápido | Da 1ª para a 2ª compra: mesmo dia 30%, 1-7 dias 7%, 8-30 dias 14%, 31-90 dias 17%, 91-180 dias 15%, mais de 180 dias 17%. | Metade volta em até 30 dias, o resto se espalha |
| Cliente satisfeito volta mais | Voltou em 180 dias, por nota da 1ª compra: nota 1 = 3,27%; nota 5 = 3,29%. | Descartada. Não há diferença |
| Atraso na 1ª compra afasta | Atrasado: 2,67%. No prazo: 3,20%. | Efeito pequeno |
| Depende da categoria | Bolsas e acessórios 5,37%, cama-mesa-banho 5,07%, decoração 4,68%. No fim: cool_stuff 1,34%. | Confirmada |
| A retenção está melhorando | Por mês de 1ª compra, a volta em 180 dias oscila de 2,4% a 4,7%, sem tendência. | Estável |

Taxa geral (clientes que compraram de jan/2017 a fev/2018, janela de 180 dias): **3,17%** voltaram (1,93% se contar só outro dia).

## Segmentos (hoje = 1/set/2018)

| Segmento | Regra | Clientes | % receita | Gasto médio |
|---|---|---|---|---|
| Fiel ativo | 2+ pedidos, último há até 6 meses | 1.243 (1,3%) | 2,5% | R$ 269 |
| Recomprador adormecido | 2+ pedidos, parou há 6+ meses | 1.644 (1,7%) | 3,1% | R$ 253 |
| Novo recente | 1 pedido, há até 3 meses | 17.640 (18,6%) | 18,0% | R$ 138 |
| Compra única antiga | 1 pedido, há 3+ meses | 74.456 (78,4%) | 76,4% | R$ 139 |

**Por que não usei o RFM "de livro":** ele divide a frequência em quartis. Aqui, 3 dos 4 quartis valem todos "1 pedido". Não separa ninguém. Troquei por regras (consulta C9 mostra o problema).

## Recomendação

1. **Trate como negócio de aquisição.** Se 97% compram uma vez, qualquer queda de clientes novos vai direto na receita. Foi o que apareceu na queda de jun/2018: os clientes novos caíram, os recorrentes ficaram estáveis.
2. **Teste uma reativação** com os **7.453 clientes** de compra única antiga que mais gastaram (R$ 274,90 ou mais). Eles já geraram R$ 4,25 milhões. Mande para metade da lista e compare com a outra metade. Só assim você sabe se a campanha funcionou.
3. **Ofereça a 2ª compra nas categorias que já recompram:** bolsas e acessórios, cama-mesa-banho e decoração. É uma hipótese a testar.
4. **Meça "recompra de verdade"** (2ª compra em outro dia) como indicador oficial: hoje 2,12%.

## O que ainda não dá para afirmar

- **Por que** o retorno é tão baixo. Não temos preço, canal de aquisição nem campanhas.
- Se a mesma pessoa tem dois cadastros e aparece como dois clientes.
- Que uma campanha de reativação funciona. Isso só um teste responde.

## Armadilhas que apareceram (aprenda com elas)

1. **Cliente é `customer_unique_id`.** O `customer_id` muda a cada pedido. Contar por ele dá 98.199 "clientes" (um por pedido) em vez de 94.983.
2. **Segunda compra no mesmo dia** (869 casos). Decida se conta como recompra e escreva a regra.
3. **Coorte precisa de tempo.** Para medir 180 dias, só serve quem comprou até fev/2018. Coortes novas parecem piores só porque não tiveram tempo de voltar.
4. **"Hoje" é uma escolha.** Os dados terminam em agosto/2018. Mudar a data muda os segmentos.
5. **Gasto médio de R$ 138 é gasto total do cliente**, não valor por pedido.
6. **Nota 5 e nota 1 voltam igual** não quer dizer que satisfação não importa. Só que a nota não prevê a volta aqui.


## Arquivos

- `projeto4_recompra_rfm.sql`: as consultas, numeradas C1, C2, ...
- `docs/apresentacao.pdf`: slides curtos do caso.
- `docs/relatorio.pdf`: relatório de 3 páginas.
- `dados/`: scripts para baixar os dados e montar o banco.

## Como reproduzir

1. `python3 dados/baixar_csvs.py` baixa os dados reais do Olist e cria 8 CSVs na pasta `dados`.
2. Rode `dados/montar_sqlserver.sql` no SQL Server e ajuste o caminho na linha `DECLARE @pasta`.
3. Rode as consultas de `projeto4_recompra_rfm.sql` na ordem.

## Aviso

Os números foram recalculados de forma independente em pandas. As consultas em T-SQL tiveram a sintaxe validada, mas não foram executadas num SQL Server real na preparação. Rode e confira os resultados.

Autor: João Wellyngton
