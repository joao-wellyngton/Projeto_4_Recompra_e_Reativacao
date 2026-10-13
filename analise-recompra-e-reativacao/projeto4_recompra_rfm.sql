/*
  PROJETO 4: Quem recompra? (SQL Server 2025, banco "olist")

  Regras que valem para o arquivo todo:
   - Cliente = customer_unique_id (customer_id muda a cada pedido, não serve para contar pessoas).
   - Pedido válido = tem item e não está 'canceled' nem 'unavailable'. Valor = soma de items.price.
   - "Hoje" = 2018-09-01 (os dados vão até agosto/2018). Mude em @hoje se quiser testar outra data.
   - Dias são contados por DATA (a hora não conta): DATEDIFF(day, CAST(a AS date), CAST(b AS date)).
   - Rode o bloco "PREPARAÇÃO" primeiro. As tabelas #temporárias somem quando você fecha a janela.
*/
USE olist;
GO

/* ===================== PREPARAÇÃO ===================== */

-- Um pedido por linha, com o cliente de verdade
DROP TABLE IF EXISTS #pedidos;
SELECT o.order_id,
       c.customer_unique_id          AS cliente,
       o.order_purchase_timestamp    AS compra,
       SUM(i.price)                  AS valor,
       ROW_NUMBER() OVER (PARTITION BY c.customer_unique_id
                          ORDER BY o.order_purchase_timestamp, o.order_id) AS n   -- 1ª, 2ª, 3ª compra...
INTO   #pedidos
FROM   dbo.orders o
JOIN   dbo.customers c ON c.customer_id = o.customer_id
JOIN   dbo.items     i ON i.order_id    = o.order_id
WHERE  o.order_status NOT IN ('canceled', 'unavailable')
GROUP  BY o.order_id, c.customer_unique_id, o.order_purchase_timestamp;

-- Um cliente por linha
DROP TABLE IF EXISTS #clientes;
DECLARE @hoje date = '2018-09-01';
SELECT cliente,
       COUNT(*)                                                    AS pedidos,
       SUM(valor)                                                  AS gasto,
       MIN(compra)                                                 AS primeira,
       MAX(compra)                                                 AS ultima,
       DATEDIFF(day, CAST(MAX(compra) AS date), @hoje)             AS recencia_dias
INTO   #clientes
FROM   #pedidos
GROUP  BY cliente;

-- 1 avaliação por pedido (a mais recente)
DROP TABLE IF EXISTS #aval;
SELECT order_id, nota
INTO   #aval
FROM  (SELECT order_id, review_score AS nota,
              ROW_NUMBER() OVER (PARTITION BY order_id
                                 ORDER BY review_answer_timestamp DESC, review_id) AS rn
       FROM dbo.reviews) r
WHERE  rn = 1;

-- Primeira e segunda compra lado a lado (dias entre elas)
DROP TABLE IF EXISTS #voltas;
SELECT p1.cliente,
       p1.order_id                                   AS pedido_1,
       p1.compra                                     AS compra_1,
       p1.valor                                      AS valor_1,
       FORMAT(p1.compra, 'yyyy-MM')                  AS coorte,
       DATEDIFF(day, CAST(p1.compra AS date), CAST(p2.compra AS date)) AS dias_ate_2a   -- NULL = nunca voltou
INTO   #voltas
FROM   #pedidos p1
LEFT JOIN #pedidos p2 ON p2.cliente = p1.cliente AND p2.n = 2
WHERE  p1.n = 1;
GO

/* ===================== ANÁLISE ===================== */

-- C1. Quantos pedidos cada cliente fez?
SELECT pedidos, COUNT(*) AS clientes,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_dos_clientes
FROM   #clientes
GROUP  BY pedidos
ORDER  BY pedidos;

-- C2. Quanto os recompradores (2+ pedidos) pesam?
SELECT COUNT(*)                                                                          AS clientes,
       SUM(CASE WHEN pedidos >= 2 THEN 1 ELSE 0 END)                                     AS recompradores,
       ROUND(100.0 * SUM(CASE WHEN pedidos >= 2 THEN 1 ELSE 0 END) / COUNT(*), 2)        AS pct_recompradores,
       ROUND(100.0 * SUM(CASE WHEN pedidos >= 2 THEN gasto ELSE 0 END) / SUM(gasto), 1)  AS pct_da_receita,
       ROUND(AVG(CASE WHEN pedidos = 1  THEN gasto END), 1)                              AS gasto_medio_compra_unica,
       ROUND(AVG(CASE WHEN pedidos >= 2 THEN gasto END), 1)                              AS gasto_medio_recomprador
FROM   #clientes;

-- C3. Quanto tempo leva da 1ª para a 2ª compra?
SELECT faixa, COUNT(*) AS clientes,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM (
    SELECT CASE WHEN dias_ate_2a =   0 THEN 'a) mesmo dia'
                WHEN dias_ate_2a <=  7 THEN 'b) 1-7 dias'
                WHEN dias_ate_2a <= 30 THEN 'c) 8-30 dias'
                WHEN dias_ate_2a <= 90 THEN 'd) 31-90 dias'
                WHEN dias_ate_2a <= 180 THEN 'e) 91-180 dias'
                WHEN dias_ate_2a <= 365 THEN 'f) 181-365 dias'
                ELSE                         'g) mais de 365 dias' END AS faixa
    FROM #voltas
    WHERE dias_ate_2a IS NOT NULL) f
GROUP  BY faixa
ORDER  BY faixa;

-- C4. Recompra "de verdade": a 2ª compra foi em outro dia?
SELECT COUNT(*)                                                                     AS clientes,
       SUM(CASE WHEN dias_ate_2a IS NOT NULL THEN 1 ELSE 0 END)                     AS com_2a_compra,
       SUM(CASE WHEN dias_ate_2a >= 1        THEN 1 ELSE 0 END)                     AS com_2a_compra_outro_dia,
       ROUND(100.0 * SUM(CASE WHEN dias_ate_2a >= 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_recompra_de_verdade
FROM   #voltas;

-- C5. Coortes: dos clientes que compraram pela 1ª vez em cada mês, quantos voltaram em até 180 dias?
--     (só coortes de jan/2017 a fev/2018: precisam de 180 dias de histórico completos)
SELECT coorte,
       COUNT(*)                                                                         AS clientes,
       SUM(CASE WHEN dias_ate_2a <= 30  THEN 1 ELSE 0 END)                              AS voltaram_30d,
       SUM(CASE WHEN dias_ate_2a <= 180 THEN 1 ELSE 0 END)                              AS voltaram_180d,
       ROUND(100.0 * SUM(CASE WHEN dias_ate_2a <= 180 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_180d
FROM   #voltas
WHERE  compra_1 >= '2017-01-01' AND compra_1 < '2018-03-01'
GROUP  BY coorte
ORDER  BY coorte;

-- C5b. Total das coortes (180 dias), contando o mesmo dia e só "outro dia"
SELECT COUNT(*)                                                                         AS clientes,
       ROUND(100.0 * SUM(CASE WHEN dias_ate_2a <= 180 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_180d_com_mesmo_dia,
       ROUND(100.0 * SUM(CASE WHEN dias_ate_2a BETWEEN 1 AND 180 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_180d_outro_dia
FROM   #voltas
WHERE  compra_1 >= '2017-01-01' AND compra_1 < '2018-03-01';

-- C6. Cliente satisfeito volta mais? (nota da 1ª compra x voltou em 180 dias)
SELECT a.nota,
       COUNT(*)                                                                         AS clientes,
       ROUND(100.0 * SUM(CASE WHEN v.dias_ate_2a <= 180 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_voltou_180d
FROM   #voltas v
JOIN   #aval a ON a.order_id = v.pedido_1
WHERE  v.compra_1 >= '2017-01-01' AND v.compra_1 < '2018-03-01'
GROUP  BY a.nota
ORDER  BY a.nota;

-- C7. Entrega atrasada na 1ª compra reduz a volta?
SELECT CASE WHEN o.order_delivered_customer_date IS NULL THEN 'sem_entrega'
            WHEN CAST(o.order_delivered_customer_date AS date) > CAST(o.order_estimated_delivery_date AS date)
                 THEN 'atrasado' ELSE 'no_prazo' END                                      AS entrega_1a_compra,
       COUNT(*)                                                                           AS clientes,
       ROUND(100.0 * SUM(CASE WHEN v.dias_ate_2a <= 180 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_voltou_180d
FROM   #voltas v
JOIN   dbo.orders o ON o.order_id = v.pedido_1
WHERE  v.compra_1 >= '2017-01-01' AND v.compra_1 < '2018-03-01'
GROUP  BY CASE WHEN o.order_delivered_customer_date IS NULL THEN 'sem_entrega'
               WHEN CAST(o.order_delivered_customer_date AS date) > CAST(o.order_estimated_delivery_date AS date)
                    THEN 'atrasado' ELSE 'no_prazo' END;

-- C8. Categoria da 1ª compra x volta em 180 dias (categorias com pelo menos 800 clientes)
WITH cat1 AS (
    SELECT i.order_id,
           ISNULL(t.product_category_name_english, 'sem_categoria') AS categoria,
           ROW_NUMBER() OVER (PARTITION BY i.order_id ORDER BY i.price DESC, i.order_item_id) AS rn
    FROM   dbo.items i
    LEFT JOIN dbo.products   p ON p.product_id = i.product_id
    LEFT JOIN dbo.categories t ON t.product_category_name = p.product_category_name
)
SELECT categoria, clientes, pct_voltou_180d
FROM (
    SELECT c.categoria,
           COUNT(*)                                                                           AS clientes,
           ROUND(100.0 * SUM(CASE WHEN v.dias_ate_2a <= 180 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_voltou_180d
    FROM   #voltas v
    JOIN   cat1 c ON c.order_id = v.pedido_1 AND c.rn = 1
    WHERE  v.compra_1 >= '2017-01-01' AND v.compra_1 < '2018-03-01'
    GROUP  BY c.categoria
    HAVING COUNT(*) >= 800) x
ORDER  BY pct_voltou_180d DESC;

-- C9. Por que o RFM "de livro" falha aqui? (quase todo mundo tem frequência 1)
SELECT quartil, MIN(pedidos) AS freq_min, MAX(pedidos) AS freq_max, COUNT(*) AS clientes
FROM  (SELECT pedidos, NTILE(4) OVER (ORDER BY pedidos) AS quartil FROM #clientes) q
GROUP  BY quartil
ORDER  BY quartil;

-- C10. Segmentos por regras (R = recência, F = frequência, M = gasto)
SELECT segmento,
       COUNT(*)                                                    AS clientes,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)          AS pct_clientes,
       ROUND(SUM(gasto), 0)                                        AS receita,
       ROUND(100.0 * SUM(gasto) / SUM(SUM(gasto)) OVER (), 1)      AS pct_receita,
       ROUND(AVG(gasto), 1)                                        AS gasto_medio
FROM (
    SELECT gasto,
           CASE WHEN pedidos >= 2 AND recencia_dias <= 180 THEN '1) Fiel ativo (2+ pedidos, comprou ate 6 meses atras)'
                WHEN pedidos >= 2                          THEN '2) Recomprador adormecido (2+ pedidos, parou ha 6+ meses)'
                WHEN recencia_dias <= 90                   THEN '3) Novo recente (1 pedido, ate 3 meses atras)'
                ELSE                                            '4) Compra unica antiga (1 pedido, 3+ meses atras)' END AS segmento
    FROM #clientes) s
GROUP  BY segmento
ORDER  BY segmento;

-- C11. Lista de reativação: compra única antiga entre os 10% que mais gastaram
WITH antigos AS (
    SELECT cliente, gasto, ultima, recencia_dias,
           PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY gasto) OVER () AS corte_p90
    FROM   #clientes
    WHERE  pedidos = 1 AND recencia_dias > 90
)
SELECT COUNT(*)                AS clientes_na_lista,
       MAX(corte_p90)          AS gasto_minimo_para_entrar,
       ROUND(SUM(gasto), 0)    AS receita_que_ja_geraram
FROM   antigos
WHERE  gasto >= corte_p90;
