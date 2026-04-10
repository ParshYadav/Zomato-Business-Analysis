-- =====================================================
-- ZOMATO DATA EXPLORATION - ENHANCED VERSION
-- =====================================================

USE [project];

-- =====================================================
-- DATA SCHEMA VALIDATION
-- =====================================================

-- Examine table structure and data types
SELECT 
    col.COLUMN_NAME AS column_name,
    col.DATA_TYPE AS data_type,
    col.IS_NULLABLE AS nullable,
    col.CHARACTER_MAXIMUM_LENGTH AS max_length
FROM INFORMATION_SCHEMA.COLUMNS col
WHERE col.TABLE_NAME = 'ZomatoData1'
ORDER BY col.ORDINAL_POSITION;

-- =====================================================
-- DATA QUALITY ASSESSMENT
-- =====================================================

-- Check for duplicate restaurant records
WITH duplicate_check AS (
    SELECT 
        RestaurantID,
        COUNT(*) AS duplicate_count
    FROM [dbo].[ZomatoData1]
    GROUP BY RestaurantID
    HAVING COUNT(*) > 1
)
SELECT 
    COUNT(*) AS total_duplicates,
    SUM(duplicate_count) AS total_duplicate_records
FROM duplicate_check;

-- Identify data quality issues across key columns
SELECT 
    'RestaurantID' AS column_name,
    COUNT(*) AS total_records,
    COUNT(RestaurantID) AS non_null_count,
    COUNT(*) - COUNT(RestaurantID) AS null_count,
    ROUND(CAST(COUNT(RestaurantID) AS FLOAT) / COUNT(*) * 100, 2) AS completeness_percentage
FROM [dbo].[ZomatoData1]

UNION ALL

SELECT 
    'RestaurantName',
    COUNT(*),
    COUNT(RestaurantName),
    COUNT(*) - COUNT(RestaurantName),
    ROUND(CAST(COUNT(RestaurantName) AS FLOAT) / COUNT(*) * 100, 2)
FROM [dbo].[ZomatoData1]

UNION ALL

SELECT 
    'Cuisines',
    COUNT(*),
    COUNT(Cuisines),
    COUNT(*) - COUNT(Cuisines),
    ROUND(CAST(COUNT(Cuisines) AS FLOAT) / COUNT(*) * 100, 2)
FROM [dbo].[ZomatoData1];

-- =====================================================
-- DATA CLEANING OPERATIONS
-- =====================================================

-- Remove invalid records with malformed country codes
DELETE FROM [dbo].[ZomatoData1] 
WHERE CountryCode IN (
    ' Bar', ' Grill', ' Bakers & More"', 
    ' Chowringhee Lane"', ' Grill & Bar"', ' Chinese'
);

-- Remove specific problematic record
DELETE FROM [dbo].[ZomatoData1] 
WHERE RestaurantID = '18306543';

-- Add country name column and populate from lookup table
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_NAME = 'ZomatoData1' AND COLUMN_NAME = 'COUNTRY_NAME'
)
ALTER TABLE [dbo].[ZomatoData1] ADD COUNTRY_NAME VARCHAR(50);

UPDATE zd 
SET COUNTRY_NAME = zc.COUNTRY
FROM [dbo].[ZomatoData1] zd
INNER JOIN [dbo].[ZOMATO_COUNTRY] zc ON zd.CountryCode = zc.COUNTRYCODE;

-- Fix encoding issues in city names
UPDATE [dbo].[ZomatoData1] 
SET City = REPLACE(City, '?', 'i') 
WHERE City LIKE '%?%';

-- Standardize data types for numeric columns
ALTER TABLE [dbo].[ZomatoData1] ALTER COLUMN Votes INT;
ALTER TABLE [dbo].[ZomatoData1] ALTER COLUMN Average_Cost_for_two FLOAT;
ALTER TABLE [dbo].[ZomatoData1] ALTER COLUMN Rating DECIMAL(3,1);

-- =====================================================
-- ENHANCED DATA CATEGORIZATION
-- =====================================================

-- Create rating categories
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_NAME = 'ZomatoData1' AND COLUMN_NAME = 'RATE_CATEGORY'
)
ALTER TABLE [dbo].[ZomatoData1] ADD RATE_CATEGORY VARCHAR(20);

UPDATE [dbo].[ZomatoData1] 
SET RATE_CATEGORY = 
    CASE 
        WHEN Rating >= 4.5 THEN 'EXCELLENT'
        WHEN Rating >= 3.5 THEN 'GREAT'
        WHEN Rating >= 2.5 THEN 'GOOD'
        WHEN Rating >= 1.0 THEN 'POOR'
        ELSE 'UNRATED'
    END;

-- Create price category for better analysis
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_NAME = 'ZomatoData1' AND COLUMN_NAME = 'PRICE_CATEGORY'
)
ALTER TABLE [dbo].[ZomatoData1] ADD PRICE_CATEGORY VARCHAR(20);

UPDATE [dbo].[ZomatoData1] 
SET PRICE_CATEGORY = 
    CASE 
        WHEN Price_range = 1 THEN 'BUDGET'
        WHEN Price_range = 2 THEN 'MODERATE'
        WHEN Price_range = 3 THEN 'EXPENSIVE'
        WHEN Price_range = 4 THEN 'LUXURY'
        ELSE 'UNKNOWN'
    END;

-- =====================================================
-- ADVANCED DATA EXPLORATION QUERIES
-- =====================================================

-- 1. COMPREHENSIVE MARKET PENETRATION ANALYSIS
WITH country_metrics AS (
    SELECT 
        COUNTRY_NAME,
        COUNT(*) AS total_restaurants,
        AVG(CAST(Rating AS FLOAT)) AS avg_rating,
        AVG(CAST(Average_Cost_for_two AS FLOAT)) AS avg_cost,
        COUNT(CASE WHEN Has_Online_delivery = 'YES' THEN 1 END) AS online_delivery_count,
        COUNT(CASE WHEN Has_Table_booking = 'YES' THEN 1 END) AS table_booking_count
    FROM [dbo].[ZomatoData1]
    GROUP BY COUNTRY_NAME
),
total_restaurants AS (
    SELECT COUNT(*) AS global_total
    FROM [dbo].[ZomatoData1]
)
SELECT 
    cm.COUNTRY_NAME,
    cm.total_restaurants,
    ROUND(CAST(cm.total_restaurants AS FLOAT) / tr.global_total * 100, 2) AS market_share_percentage,
    ROUND(cm.avg_rating, 2) AS avg_rating,
    ROUND(cm.avg_cost, 0) AS avg_cost_for_two,
    ROUND(CAST(cm.online_delivery_count AS FLOAT) / cm.total_restaurants * 100, 2) AS online_delivery_penetration,
    ROUND(CAST(cm.table_booking_count AS FLOAT) / cm.total_restaurants * 100, 2) AS table_booking_penetration
FROM country_metrics cm
CROSS JOIN total_restaurants tr
ORDER BY cm.total_restaurants DESC;

-- 2. CUISINE POPULARITY AND PERFORMANCE MATRIX
WITH cuisine_split AS (
    SELECT 
        RestaurantID,
        RestaurantName,
        COUNTRY_NAME,
        City,
        Rating,
        Votes,
        Average_Cost_for_two,
        TRIM(cuisine.value) AS individual_cuisine
    FROM [dbo].[ZomatoData1]
    CROSS APPLY STRING_SPLIT(Cuisines, ',') AS cuisine
    WHERE Cuisines IS NOT NULL
),
cuisine_metrics AS (
    SELECT 
        individual_cuisine,
        COUNT(*) AS restaurant_count,
        AVG(CAST(Rating AS FLOAT)) AS avg_rating,
        AVG(CAST(Votes AS FLOAT)) AS avg_votes,
        AVG(CAST(Average_Cost_for_two AS FLOAT)) AS avg_cost,
        RANK() OVER (ORDER BY COUNT(*) DESC) AS popularity_rank,
        RANK() OVER (ORDER BY AVG(CAST(Rating AS FLOAT)) DESC) AS quality_rank
    FROM cuisine_split
    WHERE individual_cuisine != ''
    GROUP BY individual_cuisine
    HAVING COUNT(*) >= 10
)
SELECT TOP 20
    individual_cuisine,
    restaurant_count,
    popularity_rank,
    ROUND(avg_rating, 2) AS avg_rating,
    quality_rank,
    ROUND(avg_votes, 0) AS avg_votes,
    ROUND(avg_cost, 0) AS avg_cost_for_two,
    CASE 
        WHEN popularity_rank <= 10 AND quality_rank <= 10 THEN 'HIGH_DEMAND_HIGH_QUALITY'
        WHEN popularity_rank <= 10 AND quality_rank > 10 THEN 'HIGH_DEMAND_MODERATE_QUALITY'
        WHEN popularity_rank > 10 AND quality_rank <= 10 THEN 'NICHE_HIGH_QUALITY'
        ELSE 'EMERGING_SEGMENT'
    END AS market_segment
FROM cuisine_metrics
ORDER BY restaurant_count DESC;

-- 3. GEOGRAPHIC HOTSPOT ANALYSIS WITH DENSITY METRICS
WITH location_performance AS (
    SELECT 
        COUNTRY_NAME,
        City,
        Locality,
        COUNT(*) AS restaurant_density,
        AVG(CAST(Rating AS FLOAT)) AS avg_rating,
        AVG(CAST(Votes AS FLOAT)) AS avg_votes,
        AVG(CAST(Average_Cost_for_two AS FLOAT)) AS avg_cost,
        COUNT(CASE WHEN Has_Online_delivery = 'YES' THEN 1 END) AS online_enabled,
        COUNT(CASE WHEN Has_Table_booking = 'YES' THEN 1 END) AS booking_enabled,
        STDEV(CAST(Rating AS FLOAT)) AS rating_variance
    FROM [dbo].[ZomatoData1]
    WHERE COUNTRY_NAME IS NOT NULL AND City IS NOT NULL
    GROUP BY COUNTRY_NAME, City, Locality
    HAVING COUNT(*) >= 5
),
city_rankings AS (
    SELECT 
        *,
        RANK() OVER (PARTITION BY COUNTRY_NAME ORDER BY restaurant_density DESC) AS density_rank_in_country,
        RANK() OVER (PARTITION BY COUNTRY_NAME ORDER BY avg_rating DESC) AS quality_rank_in_country,
        CASE 
            WHEN avg_rating >= 4.0 AND restaurant_density >= 20 THEN 'PREMIUM_HOTSPOT'
            WHEN avg_rating >= 3.5 AND restaurant_density >= 15 THEN 'QUALITY_CLUSTER'
            WHEN restaurant_density >= 25 THEN 'HIGH_DENSITY_ZONE'
            ELSE 'STANDARD_AREA'
        END AS zone_classification
    FROM location_performance
)
SELECT TOP 25
    COUNTRY_NAME,
    City,
    Locality,
    restaurant_density,
    density_rank_in_country,
    ROUND(avg_rating, 2) AS avg_rating,
    quality_rank_in_country,
    ROUND(avg_cost, 0) AS avg_cost_for_two,
    ROUND(CAST(online_enabled AS FLOAT) / restaurant_density * 100, 1) AS online_penetration_pct,
    ROUND(CAST(booking_enabled AS FLOAT) / restaurant_density * 100, 1) AS booking_penetration_pct,
    ROUND(rating_variance, 2) AS rating_consistency,
    zone_classification
FROM city_rankings
ORDER BY restaurant_density DESC, avg_rating DESC;

-- 4. SERVICE FEATURE CORRELATION ANALYSIS
WITH service_correlation AS (
    SELECT 
        RATE_CATEGORY,
        PRICE_CATEGORY,
        COUNT(*) AS restaurant_count,
        AVG(CAST(Votes AS FLOAT)) AS avg_votes,
        COUNT(CASE WHEN Has_Online_delivery = 'YES' THEN 1 END) AS has_online_delivery,
        COUNT(CASE WHEN Has_Table_booking = 'YES' THEN 1 END) AS has_table_booking,
        COUNT(CASE WHEN Has_Online_delivery = 'YES' AND Has_Table_booking = 'YES' THEN 1 END) AS has_both_services
    FROM [dbo].[ZomatoData1]
    WHERE RATE_CATEGORY IS NOT NULL AND PRICE_CATEGORY IS NOT NULL
    GROUP BY RATE_CATEGORY, PRICE_CATEGORY
)
SELECT 
    RATE_CATEGORY,
    PRICE_CATEGORY,
    restaurant_count,
    ROUND(avg_votes, 0) AS avg_customer_engagement,
    ROUND(CAST(has_online_delivery AS FLOAT) / restaurant_count * 100, 1) AS online_delivery_adoption_pct,
    ROUND(CAST(has_table_booking AS FLOAT) / restaurant_count * 100, 1) AS table_booking_adoption_pct,
    ROUND(CAST(has_both_services AS FLOAT) / restaurant_count * 100, 1) AS full_service_adoption_pct,
    CASE 
        WHEN CAST(has_both_services AS FLOAT) / restaurant_count >= 0.7 THEN 'SERVICE_LEADERS'
        WHEN CAST(has_both_services AS FLOAT) / restaurant_count >= 0.4 THEN 'SERVICE_ADOPTERS'
        WHEN CAST(has_both_services AS FLOAT) / restaurant_count >= 0.2 THEN 'SELECTIVE_ADOPTERS'
        ELSE 'TRADITIONAL_MODEL'
    END AS service_adoption_tier
FROM service_correlation
ORDER BY 
    CASE RATE_CATEGORY 
        WHEN 'EXCELLENT' THEN 1 
        WHEN 'GREAT' THEN 2 
        WHEN 'GOOD' THEN 3 
        WHEN 'POOR' THEN 4 
        ELSE 5 
    END,
    CASE PRICE_CATEGORY 
        WHEN 'LUXURY' THEN 1 
        WHEN 'EXPENSIVE' THEN 2 
        WHEN 'MODERATE' THEN 3 
        WHEN 'BUDGET' THEN 4 
        ELSE 5 
    END;

-- 5. ROLLING TREND ANALYSIS WITH CUMULATIVE METRICS
WITH restaurant_metrics AS (
    SELECT 
        COUNTRY_NAME,
        City,
        Locality,
        COUNT(*) AS locality_restaurant_count,
        AVG(CAST(Rating AS FLOAT)) AS locality_avg_rating,
        AVG(CAST(Average_Cost_for_two AS FLOAT)) AS locality_avg_cost
    FROM [dbo].[ZomatoData1]
    WHERE COUNTRY_NAME = 'INDIA'
    GROUP BY COUNTRY_NAME, City, Locality
),
rolling_analysis AS (
    SELECT 
        COUNTRY_NAME,
        City,
        Locality,
        locality_restaurant_count,
        ROUND(locality_avg_rating, 2) AS locality_avg_rating,
        ROUND(locality_avg_cost, 0) AS locality_avg_cost,
        SUM(locality_restaurant_count) OVER (
            PARTITION BY City 
            ORDER BY locality_restaurant_count DESC 
            ROWS UNBOUNDED PRECEDING
        ) AS cumulative_restaurants_in_city,
        RANK() OVER (
            PARTITION BY City 
            ORDER BY locality_restaurant_count DESC
        ) AS locality_rank_in_city,
        ROUND(
            AVG(locality_avg_rating) OVER (
                PARTITION BY City 
                ORDER BY locality_restaurant_count DESC 
                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            ), 2
        ) AS rolling_avg_rating_3period
    FROM restaurant_metrics
)
SELECT TOP 30
    City,
    Locality,
    locality_restaurant_count,
    locality_rank_in_city,
    locality_avg_rating,
    rolling_avg_rating_3period,
    locality_avg_cost,
    cumulative_restaurants_in_city,
    ROUND(
        CAST(locality_restaurant_count AS FLOAT) / cumulative_restaurants_in_city * 100, 2
    ) AS contribution_to_city_pct
FROM rolling_analysis
WHERE locality_rank_in_city <= 5
ORDER BY City, locality_rank_in_city;

-- =====================================================
-- DATA SUMMARY STATISTICS
-- =====================================================

-- Final data overview after cleaning
SELECT 
    'Total Restaurants' AS metric,
    COUNT(*) AS value
FROM [dbo].[ZomatoData1]

UNION ALL

SELECT 
    'Countries Covered',
    COUNT(DISTINCT COUNTRY_NAME)
FROM [dbo].[ZomatoData1]

UNION ALL

SELECT 
    'Cities Covered',
    COUNT(DISTINCT City)
FROM [dbo].[ZomatoData1]

UNION ALL

SELECT 
    'Average Rating',
    ROUND(AVG(CAST(Rating AS FLOAT)), 2)
FROM [dbo].[ZomatoData1];

-- =====================================================
-- END OF EXPLORATION SCRIPT
-- =====================================================