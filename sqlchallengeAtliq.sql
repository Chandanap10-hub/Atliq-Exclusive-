/*Analyzing the data*/
show tables;
select *from dim_customer;
select *from dim_product;
select *from fact_gross_price;
select *from fact_manufacturing_cost;
select *from fact_pre_invoice_deductions;
select *from fact_sales_monthly;
/*list of markets in which customer  "Atliq  Exclusive"  operates its business in the  APAC  region.*/ 
select market from dim_customer where customer='Atliq Exclusive' and region='APAC';

/*percentage of unique product increase in 2021 vs. 2020*/

select gross_price from fact_gross_price group by fiscal_year;
CREATE TABLE output (
    unique_product_2020 VARCHAR(25),
    unique_product_2021 VARCHAR(25),
    percentage_chg DECIMAL(10, 2) 
);
INSERT INTO output (unique_product_2020, unique_product_2021, percentage_chg)
SELECT 
    gp_2020.product_code AS unique_product_2020,
    gp_2021.product_code AS unique_product_2021,
    ROUND(ABS(CAST(gp_2021.gross_price AS SIGNED) - CAST(gp_2020.gross_price AS SIGNED)) / gp_2020.gross_price * 100, 2) AS percentage_chg
FROM 
    (SELECT product_code, gross_price FROM fact_gross_price WHERE fiscal_year = 2020) AS gp_2020
INNER JOIN 
    (SELECT product_code, gross_price FROM fact_gross_price WHERE fiscal_year = 2021) AS gp_2021 
ON 
    gp_2020.product_code = gp_2021.product_code;
    
select *from output;
/* all the unique product counts for each  segment */
SELECT segment, COUNT(DISTINCT product_code) AS product_count
FROM dim_product
GROUP BY segment
ORDER BY product_count DESC;

select segment,count(distinct product_code)  from dim_product group by segment;
WITH product_counts AS (
    SELECT 
        segment,
        COUNT(DISTINCT CASE WHEN YEAR(fiscal_year) = 2020 THEN product_code END) AS product_count_2020,
        COUNT(DISTINCT CASE WHEN YEAR(fiscal_year) = 2021 THEN product_code END) AS product_count_2021
    FROM dim_product
    WHERE YEAR(fiscal_year) IN (2020, 2021)
    GROUP BY segment
    )

/*segment had the most increase in unique products in 
2021 vs 2020*/

SELECT 
    segment,
    product_count_2020,
    product_count_2021,
    product_count_2021 - product_count_2020 AS difference
FROM 
    (SELECT 
        d.segment,
        COUNT(DISTINCT CASE WHEN f.fiscal_year = 2020 THEN f.product_code END) AS product_count_2020,
        COUNT(DISTINCT CASE WHEN f.fiscal_year = 2021 THEN f.product_code END) AS product_count_2021
    FROM 
        dim_product d
    INNER JOIN 
        fact_sales_monthly f ON d.product_code = f.product_code
    GROUP BY 
        d.segment) AS counts
ORDER BY 
    difference DESC
LIMIT 1;
/* products that have the highest and lowest manufacturing costs.*/
SELECT 
    dp.product_code,
    dp.product,
    fmc.manufacturing_cost
FROM 
    (SELECT product_code, product FROM dim_product) AS dp
INNER JOIN 
    (SELECT product_code, manufacturing_cost FROM fact_manufacturing_cost ORDER BY manufacturing_cost DESC LIMIT 1) AS fmc
ON 
    dp.product_code = fmc.product_code

UNION

SELECT 
    dp.product_code,
    dp.product,
    fmc.manufacturing_cost
FROM 
    (SELECT product_code, product FROM dim_product) AS dp
INNER JOIN 
    (SELECT product_code, manufacturing_cost FROM fact_manufacturing_cost ORDER BY manufacturing_cost ASC LIMIT 1) AS fmc
ON 
    dp.product_code = fmc.product_code;
select customer_market.customer_code,customer_market.customer,average_discount_percentage from
  (select market,customer from dim_customer where market='India') as customer_market
  inner join (select avg(pre_invoice_discount)from fact_pre_invoice_deductions where fiscal_year=2021) as avergae_discount_percentage order by average_discount_percentage
on customer_market.customer_code=averagelimit 5;
/* the top 5 customers who received an 
average high  pre_invoice_discount_pct  for the  fiscal  year 2021  and in the 
Indian  market.*/
SELECT 
    customer_market.customer_code,
    customer_market.customer,
    AVG(fpid.pre_invoice_discount_pct) AS average_discount_percentage
FROM 
    (SELECT customer_code, customer FROM dim_customer WHERE market = 'India') AS customer_market
INNER JOIN 
    fact_pre_invoice_deductions AS fpid ON customer_market.customer_code = fpid.customer_code
WHERE 
    fpid.fiscal_year = 2021
GROUP BY 
    customer_market.customer_code, customer_market.customer
ORDER BY 
    average_discount_percentage DESC
LIMIT 5;
/*the Gross sales amount for the customer  “Atliq 
Exclusive”  for each month*/


   SELECT 
    DATE_FORMAT(fsm.date, '%Y-%m') AS Month,
    fsm.fiscal_year AS Year,
    ROUND(SUM(fsm.sold_quantity * fgp.gross_price), 2) AS Gross_sales_Amount
FROM 
    fact_sales_monthly fsm
INNER JOIN 
    dim_customer dc ON fsm.customer_code = dc.customer_code
INNER JOIN 
    fact_gross_price fgp ON fsm.product_code = fgp.product_code
WHERE 
    dc.customer = 'Atliq Exclusive'
GROUP BY 
    DATE_FORMAT(fsm.date, '%Y-%m'), fsm.fiscal_year, fsm.date
ORDER BY 
    fsm.fiscal_year, MONTH(fsm.date);
/* which quarter of 2020, got the maximum total_sold_quantity?*/
SELECT
    CASE
        WHEN MONTH(date) IN (9, 10, 11) THEN 'Q1'
        WHEN MONTH(date) IN (12, 1, 2) THEN 'Q2'
        WHEN MONTH(date) IN (3, 4, 5) THEN 'Q3'
        WHEN MONTH(date) IN (6, 7, 8) THEN 'Q4'
    END AS Quarter,
    SUM(sold_quantity) AS total_sold_quantity
FROM
    fact_sales_monthly
WHERE
    YEAR(date) = 2020 AND MONTH(date) >= 9
    OR YEAR(date) = 2021 AND MONTH(date) < 9
GROUP BY
    Quarter
ORDER BY
    total_sold_quantity DESC
LIMIT 1;
/*Which channel helped to bring more gross sales in the fiscal year 2021 
and the percentage of contribution?*/ 
SELECT 
    dc.channel,
    SUM(fp.gross_price * fs.sold_quantity) AS gross_sales_mln,
    (SUM(fp.gross_price * fs.sold_quantity) / (SELECT SUM(fp.gross_price * fs.sold_quantity) 
                                                FROM dim_customer AS dc
                                                INNER JOIN fact_sales_monthly AS fs ON dc.customer_code = fs.customer_code
                                                INNER JOIN fact_gross_price AS fp ON fp.product_code = fs.product_code
                                                WHERE fp.fiscal_year = 2021 AND fs.fiscal_year = 2021) * 100) AS percentage
FROM
    dim_customer AS dc
INNER JOIN fact_sales_monthly AS fs ON fs.customer_code = dc.customer_code
INNER JOIN fact_gross_price AS fp ON fp.product_code = fs.product_code
WHERE
    fp.fiscal_year = 2021 AND fs.fiscal_year = 2021
GROUP BY
    dc.channel
ORDER BY
    gross_sales_mln DESC
LIMIT 1;
/*Top 3 products in each division that have a high 
total_sold_quantity in the fiscal_year 2021*/
SELECT 
    division,
    product_code,
    product,
    total_sold_quantity,
    rank_order
FROM (
    SELECT 
        division,
        product_code,
        product,
        total_sold_quantity,
        RANK() OVER (PARTITION BY division ORDER BY total_sold_quantity DESC) AS rank_order
    FROM (
        SELECT 
            dc.division,
            fs.product_code,
            p.product,
            SUM(fs.sold_quantity) AS total_sold_quantity
        FROM
            dim_product AS dc
        INNER JOIN fact_sales_monthly AS fs ON fs.product_code = dc.product_code
        INNER JOIN dim_product AS p ON fs.product_code = p.product_code
        WHERE
            fs.fiscal_year = 2021
        GROUP BY
            dc.division, fs.product_code, p.product
    ) AS ranked_sales
) AS top_ranked_products
WHERE
    rank_order <= 3;
