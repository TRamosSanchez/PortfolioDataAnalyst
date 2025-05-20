-- 1. Data import

SET GLOBAL local_infile = 1;

CREATE TABLE occupancy (
	Touristic_concept VARCHAR(250),
    National_total VARCHAR(250),
    Autonomous_communities_and_cities VARCHAR(250),
    Traveller_residence VARCHAR(250),
    Period VARCHAR(50),
    Total VARCHAR(250));

LOAD DATA LOCAL INFILE 'C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\occupancy.csv'
INTO TABLE occupancy
FIELDS TERMINATED BY ';'
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;

CREATE TABLE dwellings (
	National_total VARCHAR(250),
    Autonomous_communities_and_cities VARCHAR(250),
    Province VARCHAR(250),
    Homes_and_places VARCHAR(250),
    Period VARCHAR(50),
    Total VARCHAR(250));
    
LOAD DATA LOCAL INFILE 'C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\dwellings.csv'
INTO TABLE dwellings
FIELDS TERMINATED BY ';'
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;

-- Backup tables creation

CREATE TABLE dwellings_raw AS
SELECT * FROM dwellings;

CREATE TABLE occupancy_raw AS
SELECT * FROM occupancy;

-- Remark :
-- The 'occupancy' table covers all the months of the year.
-- However, we only have data for february and august of each year in the 'dwellings' table.
-- In order to be able to calculate occupancy rates by month and by year, we will use the August's number of dwellings as basis for the corresponding year.
-- Even though this is not the most precise solution, this should provide a close approximation of reality.



-- 2. Data cleaning

-- 2.1. Dwellings table

-- 2.1.1. NULLs and blanks

-- Checklist

SELECT DISTINCT National_total FROM dwellings;
SELECT DISTINCT Autonomous_communities_and_cities FROM dwellings;
SELECT DISTINCT Province FROM dwellings;
SELECT DISTINCT Homes_and_places FROM dwellings;
SELECT DISTINCT Period FROM dwellings;
SELECT *
FROM dwellings
WHERE Total = '' OR Total IS NULL;

-- Let's delete the total/sub-total lines (no values in 'Province')

SELECT *
FROM dwellings
WHERE province = '';

DELETE FROM dwellings
WHERE province = '';

-- 2.1.2. National_total

SELECT DISTINCT National_total FROM dwellings; 			
-- There is only one value in this column, thus it doesn't bring any information and can be deleted.

ALTER TABLE dwellings
DROP COLUMN National_total;

-- 2.1.3. Autonomous_communities_and_cities

SELECT DISTINCT Autonomous_communities_and_cities FROM dwellings;		
-- The naming isn't optimal for the automated recognition in Tableau. Let's thus standardize it with a mapping table.

CREATE TABLE region_mapping (
    original_name VARCHAR(100),
    standardized_name VARCHAR(100)
);

INSERT INTO region_mapping (original_name, standardized_name) VALUES
('01 Andalucía', 'Andalucía'),
('02 Aragón', 'Aragón'),
('03 Asturias, Principado de', 'Asturias'),
('04 Balears, Illes', 'Islas Baleares'),
('05 Canarias', 'Canarias'),
('06 Cantabria', 'Cantabria'),
('07 Castilla y León', 'Castilla y León'),
('08 Castilla - La Mancha', 'Castilla-La Mancha'),
('09 Cataluña', 'Cataluña'),
('10 Comunitat Valenciana', 'Comunidad Valenciana'),
('11 Extremadura', 'Extremadura'),
('12 Galicia', 'Galicia'),
('13 Madrid, Comunidad de', 'Comunidad de Madrid'),
('14 Murcia, Región de', 'Región de Murcia'),
('15 Navarra, Comunidad Foral de', 'Navarra'),
('16 País Vasco', 'País Vasco'),
('17 Rioja, La', 'La Rioja'),
('18 Ceuta', 'Ceuta'),
('19 Melilla', 'Melilla');

SELECT DISTINCT d.Autonomous_communities_and_cities, r.standardized_name
FROM dwellings d
JOIN region_mapping r
	ON d.Autonomous_communities_and_cities = r.original_name;			

UPDATE dwellings d
JOIN region_mapping r
	ON d.Autonomous_communities_and_cities = r.original_name
SET d.Autonomous_communities_and_cities = r.standardized_name;

-- Let's rename this column 'Region'
ALTER TABLE dwellings
CHANGE COLUMN Autonomous_communities_and_cities Region VARCHAR(250);

-- 2.1.4. Province

SELECT DISTINCT Province FROM dwellings ORDER BY Province;			
-- Let's delete the unnecessary numbers and spaces.

SELECT DISTINCT Province, TRIM(SUBSTRING(Province,4))
FROM dwellings;

UPDATE dwellings
SET Province = TRIM(SUBSTRING(Province,4));

-- 2.1.5. Homes_and_places

SELECT DISTINCT Homes_and_places FROM dwellings;			
-- Let's translate the values in this column.

SELECT DISTINCT Homes_and_places, 
CASE 
	WHEN Homes_and_places = 'Viviendas turísticas' THEN 'Tourist dwellings'
    WHEN Homes_and_places = 'Plazas' THEN 'Bed places'
    WHEN Homes_and_places = 'Plazas por vivienda turística' THEN 'Bed places per tourist dwelling'
END AS new_name
FROM dwellings;

UPDATE dwellings
SET Homes_and_places = 'Tourist dwellings'
WHERE Homes_and_places = 'Viviendas turísticas';

UPDATE dwellings
SET Homes_and_places = 'Bed places'
WHERE Homes_and_places = 'Plazas';

UPDATE dwellings
SET Homes_and_places = 'Bed places per tourist dwelling'
WHERE Homes_and_places = 'Plazas por vivienda turística';

-- 2.1.6. Period

SELECT DISTINCT Period FROM dwellings;						
-- Let's format this column as date to facilitate the temporal analysis. Note : the first day of each month will be used as a convention.

SELECT DISTINCT Period, STR_TO_DATE(CONCAT(SUBSTRING(Period, 1, 4), '-', SUBSTRING(Period, 6, 2), '-01'), '%Y-%m-%d') as new_date
FROM dwellings;

UPDATE dwellings
SET Period = STR_TO_DATE(CONCAT(SUBSTRING(Period, 1, 4), '-', SUBSTRING(Period, 6, 2), '-01'), '%Y-%m-%d');

ALTER TABLE dwellings MODIFY COLUMN Period DATE;

-- 2.1.7. Total

SELECT * FROM dwellings;									
-- Let's clean the data in order to be able to format this column as FLOAT.

SELECT Total, REPLACE(Total, '.', '') as new_total
FROM dwellings;

UPDATE dwellings
SET Total = REPLACE(Total, '.', '');

SELECT Total, REPLACE(Total, ',', '.') as new_total
FROM dwellings;

UPDATE dwellings
SET Total = REPLACE(Total, ',', '.');

ALTER TABLE dwellings
MODIFY COLUMN Total FLOAT;

-- 2.1.8. Final check of NULLs and blanks

SELECT DISTINCT National_total FROM dwellings;
SELECT DISTINCT Autonomous_communities_and_cities FROM dwellings;
SELECT DISTINCT Province FROM dwellings;
SELECT DISTINCT Homes_and_places FROM dwellings;
SELECT DISTINCT Period FROM dwellings;
SELECT *
FROM dwellings
WHERE Total = '' OR Total IS NULL;
-- Everything seems good

-- 2.1.9. Duplicates

SELECT Region, Province, Homes_and_places, Period, COUNT(*) as nb
FROM dwellings
GROUP BY Region, Province, Homes_and_places, Period
HAVING nb > 1;
-- No duplicates found

-- The 'dwellings' table is now cleaned. Let's look at the 'occupancy' table.




-- 2.2. Occupancy table 

SELECT * FROM occupancy;

-- 2.2.1. NULLs and blanks

-- Checklist

SELECT DISTINCT Touristic_concept FROM occupancy;
SELECT DISTINCT National_total FROM occupancy;
SELECT DISTINCT Autonomous_communities_and_cities FROM occupancy;
SELECT DISTINCT Traveller_residence FROM occupancy;
SELECT DISTINCT Period FROM occupancy;
SELECT *
FROM occupancy
WHERE Total = '' OR Total IS NULL;

-- There are blanks values for periods 2024M07, 2024M08 and 2024M09.

SELECT *
FROM occupancy
WHERE (Period = '2024M09' OR Period = '2024M08' OR Period = '2024M07') AND Total <> '';
-- It seems that we only have total values for those periods without the split per region.
-- As we want to make our analysis on basis of regional data, this data isn't relevant for our analysis and can therefore be removed.

SELECT *
FROM occupancy
WHERE Period = '2024M09' OR Period = '2024M08' OR Period = '2024M07';

DELETE FROM occupancy
WHERE Period = '2024M09' OR Period = '2024M08' OR Period = '2024M07';

-- Let's delete the total/sub-total lines (no values in 'Autonomous_communities_and_cities').

SELECT *
FROM occupancy_raw
WHERE Autonomous_communities_and_cities = '';

DELETE FROM occupancy
WHERE Autonomous_communities_and_cities = '';

-- 2.2.2. Touristic_concept

SELECT DISTINCT Touristic_concept FROM occupancy;
-- Data is clean

-- 2.2.3. National_total

SELECT DISTINCT National_total FROM occupancy;
-- There is only one value in this column, thus it doesn't bring any information and can be deleted.

ALTER TABLE occupancy
DROP COLUMN National_total;

-- 2.2.4. Autonomous_communities_and_cities

SELECT DISTINCT Autonomous_communities_and_cities FROM occupancy;
-- Similarly to the 'dwellings' table, the naming isn't optimal for an automatic recognition in Tableau. Let's thus standardize it with a mapping table.
-- As the names used are the same as the ones of the 'dwellings' table, we can use the same mapping table.

SELECT DISTINCT o.Autonomous_communities_and_cities, r.standardized_name
FROM occupancy o
JOIN region_mapping r
	ON o.Autonomous_communities_and_cities = r.original_name;	

UPDATE occupancy o
JOIN region_mapping r
ON o.Autonomous_communities_and_cities = r.original_name
SET o.Autonomous_communities_and_cities = r.standardized_name;

-- Let's rename this column 'Region'
ALTER TABLE occupancy
CHANGE COLUMN Autonomous_communities_and_cities Region VARCHAR(250);

-- 2.2.5. Traveller_residence

SELECT DISTINCT Traveller_residence FROM occupancy;
-- Let's delete the 'Total' lines

SELECT *
FROM occupancy
WHERE Traveller_residence = 'Total';

DELETE FROM occupancy
WHERE Traveller_residence = 'Total';

-- 2.2.6. Period

SELECT DISTINCT Period FROM occupancy;						
-- Let's format this column as date to facilitate the temporal analysis.

SELECT DISTINCT Period, STR_TO_DATE(CONCAT(SUBSTRING(Period, 1, 4), '-', SUBSTRING(Period, 6, 2), '-01'), '%Y-%m-%d') as new_date
FROM occupancy;

UPDATE occupancy
SET Period = STR_TO_DATE(CONCAT(SUBSTRING(Period, 1, 4), '-', SUBSTRING(Period, 6, 2), '-01'), '%Y-%m-%d');

ALTER TABLE occupancy MODIFY COLUMN Period DATE;

-- 2.2.7. Total

SELECT * FROM occupancy;									
-- Let's clean the data in order to be able to format this column as FLOAT.

SELECT Total, REPLACE(Total, '.', '') as new_total
FROM occupancy;

UPDATE occupancy
SET Total = REPLACE(Total, '.', '');

SELECT Total, REPLACE(Total, ',', '.') as new_total
FROM occupancy;

UPDATE occupancy
SET Total = REPLACE(Total, ',', '.');

ALTER TABLE occupancy
MODIFY COLUMN Total FLOAT;

-- 2.2.8. Final check of NULLs and blanks

SELECT DISTINCT National_total FROM occupancy;
SELECT DISTINCT Autonomous_communities_and_cities FROM occupancy;
SELECT DISTINCT Province FROM occupancy;
SELECT DISTINCT Homes_and_places FROM occupancy;
SELECT DISTINCT Period FROM occupancy;
SELECT *
FROM occupancy
WHERE Total = '' OR Total IS NULL;
-- Blank values have appeared in the 'Total' column. Let's check the original value of one of those lines in the backup table.

SELECT *
FROM occupancy_raw
WHERE Autonomous_communities_and_cities LIKE '%Asturias%' AND Period = '2021M03';
-- It seems that the months for which there was no data collected were marked with '..'. As a result of the data cleaning steps above, those values became blank values.

SELECT COUNT(*)
FROM occupancy_raw
WHERE Total = '..';

SELECT COUNT(*)
FROM occupancy
WHERE Total = '';
-- Confirmation that there is the same number of blank values in 'occupancy' than '..' values in the backup table.
-- Let's replace the blank values by NULLs to keep track of months for which we didn't have data while avoiding any problem with statistical operations and visualisations.

UPDATE occupancy
SET Total = NULL
WHERE Total = '';

-- 2.2.9. Duplicates

SELECT Touristic_concept, Region, Traveller_residence, Period, COUNT(*) as nb
FROM occupancy
GROUP BY Touristic_concept, Region, Traveller_residence, Period
HAVING nb > 1;
-- No duplicates found

-- The 'occupancy' table is now cleaned. 



-- 3. Indexations

CREATE INDEX idx_occupancy_region_period ON occupancy(Region, Period);
CREATE INDEX idx_dwellings_region_period ON dwellings(Region, Period);




-- 4. Views creations for the data export.

-- As mentioned before, we will use the month of August's total dwellings as reference for the corresponding year. 

CREATE VIEW dwellings_per_region_per_year AS
	WITH dwellings_per_regions_per_month AS
		(
		SELECT Region, Period, SUM(Total) AS Dwellings
		FROM dwellings
		WHERE Homes_and_places = 'Tourist dwellings'
		GROUP BY Region, Period
		)
	SELECT Region, YEAR(Period) AS Year, Dwellings
	FROM dwellings_per_regions_per_month
	WHERE MONTH(Period) = 8;

CREATE VIEW occupancy_per_region_per_year AS
	WITH nights_per_region_per_month AS
		(
		SELECT Region, Period, SUM(Total) AS Total_nights
		FROM occupancy
		WHERE Touristic_concept = 'Number of nights'
		GROUP BY Region, Period
		),
		occupancy_per_region_per_month AS
		(
		SELECT n.Region, n.Period, (n.Total_nights/d.Dwellings)/DAY(LAST_DAY(n.Period)) AS Monthly_occupancy
		FROM nights_per_region_per_month n
		JOIN dwellings_per_region_per_year d
			ON n.Region = d.Region AND YEAR(n.Period) = d.Year
		)
	SELECT Region, YEAR(Period) as Year, ROUND(AVG(Monthly_occupancy),4) as Yearly_occupancy
    FROM occupancy_per_region_per_month
    GROUP BY Region, YEAR(Period);
-- Note : 2024 occupancy rate only takes into account January to June as we do not yet have data for the rest of the year. This will be clarified again in the visualization to avoid any misinterpretation.

-- Extracts from these views will be used for the analysis in Tableau (2nd part of the project)