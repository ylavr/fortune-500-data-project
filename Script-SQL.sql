--Let's check % of newcomers in each year:
CREATE VIEW prep_newcomers AS
SELECT
	g.year, (SELECT count (newcomer) AS number_of_new_comers
	FROM global_500
	WHERE newcomer = 'yes'AND YEAR = g.year) AS count_newcomers,
	count (newcomer) AS total
FROM global_500 AS g
GROUP BY g.year
ORDER BY 1

SELECT year,CAST(((count_newcomers * 1.0 / total)* 100) AS DECIMAL(10,2)) AS perc_newcomers
FROM prep_newcomers
GROUP BY year
ORDER BY 1;


--Let's check CEO Woman % by total:
CREATE VIEW prep_ceo_woman AS
SELECT
	g.year,(SELECT Count (ceowoman) AS number_of_ceo_woman
	FROM global_500
	WHERE ceowoman = 'yes'AND year = g.year) AS count_ceowoman,
	Count (ceowoman) AS total
FROM global_500 AS g
GROUP BY g.year
ORDER BY 1

SELECT year, CAST(((count_ceowoman * 1.0 / total)* 100) AS DECIMAL(10,2)) AS perc_ceowoman
FROM prep_ceo_woman
GROUP BY year
ORDER BY 1;

--Let's fill empty cells in profit revchange, prftchange where it's possible.
--We already have the list of companies from pandas analysis, 
--so it's posssible to calculate values if we have 2020 and 2021 years:

CREATE VIEW rev_prep_table AS
SELECT  name, YEAR, revenues,
lAG(revenues ,1) OVER (PARTITION BY name ORDER BY YEAR ) AS prev_revenues,
revchange, profits, prftchange
FROM global_500
GROUP BY name , YEAR

SELECT * , ROUND((((revenues - prev_revenues)/prev_revenues) * 100),5) AS rev_change_calculated
FROM rev_prep_table
WHERE revchange = 0 AND rev_change_calculated IS NOT NULL

UPDATE global_500 
SET revchange = ( SELECT 
ROUND((((revenues - prev_revenues)/prev_revenues) * 100),5) AS rev_change_calculated
					FROM rev_prep_table
					 WHERE rev_prep_table.name = global_500.name
					 	AND YEAR = global_500.YEAR
					 	)
WHERE revchange = 0

UPDATE global_500 
SET revchange = ( SELECT 
CASE WHEN ROUND((((revenues - prev_revenues)/prev_revenues) * 100),5) IS NOT null THEN ROUND((((revenues - prev_revenues)/prev_revenues) * 100),5)
    ELSE global_500.revchange 
END AS  rev_change_calculated
		FROM rev_prep_table
		WHERE rev_prep_table.name = global_500.name
		AND YEAR = global_500.YEAR)
WHERE revchange = 0

--Check:
SELECT * FROM global_500 --WHERE name = 'Sanofi'

--The same for prftchange:

CREATE VIEW prft_prep_table AS
SELECT  name, YEAR, revenues, revchange, profits, 
lAG(profits ,1) OVER (PARTITION BY name ORDER BY YEAR ) AS prev_profits, prftchange
FROM global_500
GROUP BY name , YEAR


SELECT * , ROUND((((profits - prev_profits)/ prev_profits) * 100),5) AS profits_change_calculated
FROM prft_prep_table
WHERE prftchange = 0 AND profits_change_calculated IS NOT NULL 

UPDATE global_500 
SET prftchange = ( SELECT 
CASE
WHEN ROUND((((profits - prev_profits)/ prev_profits) * 100),5) IS NOT null THEN ROUND((((profits - prev_profits)/ prev_profits) * 100),5)  
ELSE global_500.prftchange 
END AS  profits_change_calculated
					FROM prft_prep_table
					 WHERE prft_prep_table.name = global_500.name
					 	AND YEAR = global_500.year)
WHERE prftchange = 0

--Check:
SELECT * FROM global_500 WHERE name = 'Ansteel Group'



--Find top 5 revchange growth in each year and top 5 outsiders;
WITH top_rated_table AS(
SELECT t.*,
ROW_NUMBER () OVER (PARTITION BY YEAR
ORDER BY revchange DESC) AS rate
FROM (SELECT YEAR, name, sector, revenues, revchange
FROM global_500
GROUP BY YEAR, name
ORDER BY YEAR, revchange DESC) t)
SELECT *
FROM top_rated_table
WHERE rate <= 5;

WITH outsiders_rated_table AS(
SELECT t.*, 
ROW_NUMBER () OVER (PARTITION BY YEAR ORDER BY revchange ASC) AS rate
FROM (
SELECT  YEAR, name,sector, revenues, revchange
FROM global_500
GROUP BY YEAR, name
ORDER BY YEAR, revchange ASC) t)
SELECT * FROM outsiders_rated_table WHERE rate <=5;


--#Where are most headquarters located , top-5 ? 

WITH rated_table AS(
SELECT t.*, 
ROW_NUMBER () OVER (PARTITION BY YEAR ORDER BY total DESC) AS rate
FROM 
(SELECT year, country, COUNT(name) AS total,
  CAST((COUNT(name) * 1.0 / 500) * 100 AS DECIMAL(10, 2)) AS perc_of_total
FROM global_500
GROUP BY year, country
ORDER  BY year, total DESC) t)
SELECT * FROM rated_table WHERE rate <=5;

--Revenues Compared to Workforce

SELECT
	sector, YEAR,
	ROUND(SUM(revenues), 2) AS revenue,
	SUM(employees) AS headcount,
	Round((SUM(revenues)/ SUM(employees)), 3) AS revenue_per_employee
FROM global_500
GROUP BY sector, YEAR


-- Rating changes through the years:

WITH prep_table AS(
SELECT YEAR, name , rating , 
lAG(rating , 1) OVER (PARTITION BY name
ORDER BY YEAR ) AS prev_rank
FROM global_500
GROUP BY name, YEAR)
SELECT * ,
	(rating - prev_rank) AS rating_changes
FROM prep_table

-- Who has max growth?
WITH prep_table AS(
SELECT YEAR, name , rating , 
lAG(rating , 1) OVER (PARTITION BY name ORDER BY YEAR ) AS prev_rank
FROM global_500
GROUP BY name, YEAR)
SELECT * ,
	MAX((rating - prev_rank)) AS rating_changes
FROM prep_table

--Drop:
WITH prep_table AS(
SELECT YEAR, name , rating ,
	lAG(rating ,1) OVER (PARTITION BY name ORDER BY YEAR ) AS prev_rank
FROM global_500
GROUP BY name, YEAR)
SELECT * , MIN((rating - prev_rank)) AS rating_changes
FROM prep_table

	
--Show rating and year as pivot table:
CREATE VIEW rating_pivot_2 AS
SELECT name,
       MAX(CASE WHEN year = 2019 THEN rating END) AS '2019',
       MAX(CASE WHEN year = 2020 THEN rating END) AS '2020',
       MAX(CASE WHEN year = 2021 THEN rating END) AS '2021'
FROM global_500
GROUP BY name;
 
SELECT *
FROM rating_pivot_2;


--Create view with names where Tickers are available:
CREATE VIEW prep_table_ticker AS
SELECT distinct(name), sector, revenues,profits,employees, ticker
FROM global_500
WHERE ticker != 'N/A'

SELECT *
FROM prep_table_ticker
