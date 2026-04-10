-- =====================================================
-- ZOMATO DATA ANALYSIS - ENHANCED VERSION
-- Business Intelligence & Analytics Queries
-- =====================================================

USE project;

-- =====================================================
-- MARKET SHARE AND PENETRATION ANALYSIS
-- =====================================================

-- Global market distribution with key performance indicators
WITH market_overview AS (
    SELECT 
        COUNTRY_NAME,
        COUNT(*) AS total_restaurants,
        AVG(CAST(Rating AS FLOAT)) AS avg_rating,
        AVG(CAST(Votes AS FLOAT)) AS avg_customer_engagement,
        COUNT(CASE WHEN Has_Online_delivery = 'YES' THEN 1 END) AS online_delivery_restaurants,
        COUNT(CASE WHEN Has_Table_booking = 'YES' THEN 1 END) AS table_booking_restaurants
    FROM [dbo].[ZomatoData1]
    WHERE COUNTRY_NAME IS NOT NULL
    GROUP BY COUNTRY_NAME
),
global_totals AS (
    SELECT COUNT(*) AS global_restaurant_count
    FROM [dbo].[ZomatoData1]
)
SELECT 
    mo.COUNTRY_NAME,
    mo.total_restaurants,
    ROUND(CAST(mo.total_restaurants AS FLOAT) / gt.global_restaurant_count * 100, 2) AS market_share_percentage,
    ROUND(mo.avg_rating, 2) AS avg_rating,
    ROUND(mo.avg_customer_engagement, 0) AS avg_votes,
    ROUND(CAST(mo.online_delivery_restaurants AS FLOAT) / mo.total_restaurants * 100, 2) AS online_delivery_penetration_pct,
    ROUND(CAST(mo.table_booking_restaurants AS FLOAT) / mo.total_restaurants * 100, 2) AS table_booking_penetration_pct,
    CASE 
        WHEN CAST(mo.online_delivery_restaurants AS FLOAT) / mo.total_restaurants >= 0.5 THEN 'DIGITAL_LEADER'
        WHEN CAST(mo.online_delivery_restaurants AS FLOAT) / mo.total_restaurants >= 0.25 THEN 'DIGITAL_ADOPTER'
        ELSE 'TRADITIONAL_MARKET'
    END AS digital_maturity_level
FROM market_overview mo
CROSS JOIN global_totals gt
ORDER BY mo.total_restaurants DESC;

-- =====================================================
-- INDIA MARKET DEEP DIVE - CITY AND LOCALITY PERFORMANCE
-- =====================================================

-- Top performing localities in India with comprehensive metrics
WITH india_locality_metrics AS (
    SELECT 
        City,
        Locality,
        COUNT(*) AS restaurant_count,
        AVG(CAST(Rating AS FLOAT)) AS avg_rating,
        AVG(CAST(Votes AS FLOAT)) AS avg_votes,
        AVG(CAST(Average_Cost_for_two AS FLOAT)) AS avg_cost_for_two,
        COUNT(CASE WHEN Has_Online_delivery = 'YES' THEN 1 END) AS online_delivery_count,
        COUNT(CASE WHEN Has_Table_booking = 'YES' THEN 1 END) AS table_booking_count,
        COUNT(CASE WHEN Rating >= 4.0 THEN 1 END) AS high_rated_restaurants
    FROM [dbo].[ZomatoData1]
    WHERE COUNTRY_NAME = 'INDIA'
    GROUP BY City, Locality
    HAVING COUNT(*) >= 5
),
locality_rankings AS (
    SELECT 
        *,
        RANK() OVER (ORDER BY restaurant_count DESC) AS density_rank,
        RANK() OVER (ORDER BY avg_rating DESC) AS quality_rank,
        ROUND(CAST(online_delivery_count AS FLOAT) / restaurant_count * 100, 1) AS online_penetration_pct,
        ROUND(CAST(table_booking_count AS FLOAT) / restaurant_count * 100, 1) AS booking_penetration_pct,
        ROUND(CAST(high_rated_restaurants AS FLOAT) / restaurant_count * 100, 1) AS quality_restaurant_pct
    FROM india_locality_metrics
)
SELECT TOP 20
    City,
    Locality,
    restaurant_count,
    density_rank,
    ROUND(avg_rating, 2) AS avg_rating,
    quality_rank,
    ROUND(avg_cost_for_two, 0) AS avg_cost_for_two,
    online_penetration_pct,
    booking_penetration_pct,
    quality_restaurant_pct,
    CASE 
        WHEN density_rank <= 10 AND quality_rank <= 10 THEN 'PREMIUM_DESTINATION'
        WHEN density_rank <= 20 AND quality_restaurant_pct >= 60 THEN 'QUALITY_HUB'
        WHEN restaurant_count >= 50 THEN 'MAJOR_FOOD_ZONE'
        ELSE 'EMERGING_AREA'
    END AS market_classification
FROM locality_rankings
ORDER BY restaurant_count DESC;

-- =====================================================
-- CUISINE ANALYSIS AND MARKET OPPORTUNITIES
-- =====================================================

-- Comprehensive cuisine performance analysis
WITH cuisine_breakdown AS (
    SELECT 
        RestaurantID,
        RestaurantName,
        COUNTRY_NAME,
        City,
        Rating,
        Votes,
        Average_Cost_for_two,
        Has_Online_delivery,
        Has_Table_booking,
        TRIM(cuisine_item.value) AS individual_cuisine
    FROM [dbo].[ZomatoData1]
    CROSS APPLY STRING_SPLIT(Cuisines, ',') AS cuisine_item
    WHERE Cuisines IS NOT NULL AND COUNTRY_NAME = 'INDIA'
),
cuisine_performance AS (
    SELECT 
        individual_cuisine,
        COUNT(DISTINCT RestaurantID) AS restaurant_count,
        COUNT(DISTINCT City) AS city_presence,
        AVG(CAST(Rating AS FLOAT)) AS avg_rating,
        AVG(CAST(Votes AS FLOAT)) AS avg_customer_engagement,
        AVG(CAST(Average_Cost_for_two AS FLOAT)) AS avg_pricing,
        COUNT(CASE WHEN Has_Online_delivery = 'YES' THEN 1 END) AS online_enabled_count,
        COUNT(CASE WHEN Rating >= 4.0 THEN 1 END) AS premium_restaurant_count,
        STDEV(CAST(Rating AS FLOAT)) AS rating_consistency
    FROM cuisine_breakdown
    WHERE individual_cuisine != '' AND LEN(individual_cuisine) > 2
    GROUP BY individual_cuisine
    HAVING COUNT(DISTINCT RestaurantID) >= 20
)
SELECT TOP 25
    individual_cuisine,
    restaurant_count,
    city_presence,
    ROUND(avg_rating, 2) AS avg_rating,
    ROUND(avg_customer_engagement, 0) AS avg_votes,
    ROUND(avg_pricing, 0) AS avg_cost_for_two,
    ROUND(CAST(online_enabled_count AS FLOAT) / restaurant_count * 100, 1) AS digital_adoption_pct,
    ROUND(CAST(premium_restaurant_count AS FLOAT) / restaurant_count * 100, 1) AS premium_segment_pct,
    ROUND(rating_consistency, 2) AS rating_consistency_score,
    CASE 
        WHEN avg_rating >= 4.0 AND restaurant_count >= 100 THEN 'ESTABLISHED_PREMIUM'
        WHEN avg_rating >= 3.5 AND city_presence >= 10 THEN 'GROWING_SEGMENT'
        WHEN restaurant_count >= 200 THEN 'MASS_MARKET'
        WHEN avg_pricing >= 1000 THEN 'LUXURY_NICHE'
        ELSE 'EMERGING_CATEGORY'
    END AS market_segment
FROM cuisine_performance
ORDER BY restaurant_count DESC;

-- =====================================================
-- SERVICE ADOPTION AND REVENUE CORRELATION
-- =====================================================

-- Analysis of service features impact on business performance
WITH service_impact_analysis AS (
    SELECT 
        CASE 
            WHEN Has_Online_delivery = 'YES' AND Has_Table_booking = 'YES' THEN 'FULL_SERVICE'
            WHEN Has_Online_delivery = 'YES' THEN 'DELIVERY_ONLY'
            WHEN Has_Table_booking = 'YES' THEN 'BOOKING_ONLY'
            ELSE 'BASIC_SERVICE'
        END AS service_tier,
        RATE_CATEGORY,
        PRICE_CATEGORY,
        COUNT(*) AS restaurant_count,
        AVG(CAST(Rating AS FLOAT)) AS avg_rating,
        AVG(CAST(Votes AS FLOAT)) AS avg_customer_engagement,
        AVG(CAST(Average_Cost_for_two AS FLOAT)) AS avg_revenue_per_customer,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY CAST(Votes AS FLOAT)) AS median_votes,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY CAST(Rating AS FLOAT)) AS rating_75th_percentile
    FROM [dbo].[ZomatoData1]
    WHERE COUNTRY_NAME = 'INDIA' 
        AND RATE_CATEGORY IS NOT NULL 
        AND PRICE_CATEGORY IS NOT NULL
    GROUP BY 
        CASE 
            WHEN Has_Online_delivery = 'YES' AND Has_Table_booking = 'YES' THEN 'FULL_SERVICE'
            WHEN Has_Online_delivery = 'YES' THEN 'DELIVERY_ONLY'
            WHEN Has_Table_booking = 'YES' THEN 'BOOKING_ONLY'
            ELSE 'BASIC_SERVICE'
        END,
        RATE_CATEGORY,
        PRICE_CATEGORY
)
SELECT 
    service_tier,
    RATE_CATEGORY,
    PRICE_CATEGORY,
    restaurant_count,
    ROUND(avg_rating, 2) AS avg_rating,
    ROUND(avg_customer_engagement, 0) AS avg_customer_engagement,
    ROUND(avg_revenue_per_customer, 0) AS avg_cost_for_two,
    ROUND(median_votes, 0) AS median_customer_engagement,
    ROUND(rating_75th_percentile, 2) AS top_quartile_rating,
    ROUND(avg_revenue_per_customer * avg_customer_engagement / 100, 0) AS engagement_revenue_index
FROM service_impact_analysis
WHERE restaurant_count >= 10
ORDER BY service_tier, avg_rating DESC;

-- =====================================================
-- COMPETITIVE LANDSCAPE ANALYSIS
-- =====================================================

-- Restaurant performance benchmarking and market positioning
WITH restaurant_performance_metrics AS (
    SELECT 
        RestaurantID,
        RestaurantName,
        COUNTRY_NAME,
        City,
        Locality,
        Cuisines,
        Rating,
        Votes,
        Average_Cost_for_two,
        Has_Online_delivery,
        Has_Table_booking,
        PRICE_CATEGORY,
        RATE_CATEGORY,
        RANK() OVER (PARTITION BY City ORDER BY Rating DESC, Votes DESC) AS city_quality_rank,
        RANK() OVER (PARTITION BY City ORDER BY Votes DESC) AS city_popularity_rank,
        PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY CAST(Rating AS FLOAT)) 
            OVER (PARTITION BY City) AS city_rating_90th_percentile,
        AVG(CAST(Average_Cost_for_two AS FLOAT)) 
            OVER (PARTITION BY City) AS city_avg_cost
    FROM [dbo].[ZomatoData1]
    WHERE COUNTRY_NAME = 'INDIA' 
        AND Rating IS NOT NULL 
        AND Votes >= 50
),
top_performers AS (
    SELECT 
        *,
        CASE 
            WHEN city_quality_rank <= 5 AND city_popularity_rank <= 10 THEN 'MARKET_LEADER'
            WHEN city_quality_rank <= 10 AND Rating >= city_rating_90th_percentile THEN 'QUALITY_CHAMPION'
            WHEN city_popularity_rank <= 5 THEN 'CUSTOMER_FAVORITE'
            WHEN Rating >= 4.5 AND Average_Cost_for_two <= city_avg_cost THEN 'VALUE_LEADER'
            ELSE 'STANDARD_PERFORMER'
        END AS competitive_position
    FROM restaurant_performance_metrics
    WHERE city_quality_rank <= 20 OR city_popularity_rank <= 20
)
SELECT TOP 50
    RestaurantName,
    City,
    Locality,
    LEFT(Cuisines, 50) + '...' AS primary_cuisines,
    ROUND(Rating, 1) AS rating,
    Votes,
    ROUND(Average_Cost_for_two, 0) AS cost_for_two,
    PRICE_CATEGORY,
    city_quality_rank,
    city_popularity_rank,
    competitive_position,
    CASE 
        WHEN Has_Online_delivery = 'YES' AND Has_Table_booking = 'YES' THEN 'Both Services'
        WHEN Has_Online_delivery = 'YES' THEN 'Online Delivery'
        WHEN Has_Table_booking = 'YES' THEN 'Table Booking'
        ELSE 'Basic Service'
    END AS service_offerings
FROM top_performers
ORDER BY 
    CASE competitive_position 
        WHEN 'MARKET_LEADER' THEN 1
        WHEN 'QUALITY_CHAMPION' THEN 2
        WHEN 'CUSTOMER_FAVORITE' THEN 3
        WHEN 'VALUE_LEADER' THEN 4
        ELSE 5
    END,
    Rating DESC;

-- =====================================================
-- BUSINESS OPPORTUNITY IDENTIFICATION
-- =====================================================

-- Identify high-potential restaurants and market gaps
WITH opportunity_analysis AS (
    SELECT 
        RestaurantID,
        RestaurantName,
        City,
        Locality,
        Cuisines,
        Rating,
        Votes,
        Average_Cost_for_two,
        Has_Online_delivery,
        Has_Table_booking,
        PRICE_CATEGORY,
        CASE 
            WHEN Rating >= 4.0 AND Votes >= 100 AND Average_Cost_for_two < 1000 
                 AND Has_Online_delivery = 'YES' AND Has_Table_booking = 'YES' 
            THEN 'HIGH_VALUE_OPPORTUNITY'
            WHEN Rating >= 4.5 AND Votes < 50 
            THEN 'HIDDEN_GEM'
            WHEN Rating <= 3.5 AND Has_Online_delivery = 'NO' AND Has_Table_booking = 'NO' 
            THEN 'IMPROVEMENT_CANDIDATE'
            WHEN Average_Cost_for_two >= 2000 AND Rating >= 4.0 
            THEN 'PREMIUM_SEGMENT'
            ELSE 'STANDARD_OPERATION'
        END AS opportunity_category,
        ROW_NUMBER() OVER (
            PARTITION BY City 
            ORDER BY 
                CASE 
                    WHEN Rating >= 4.0 AND Votes >= 100 AND Average_Cost_for_two < 1000 THEN 1
                    WHEN Rating >= 4.5 AND Votes < 50 THEN 2
                    ELSE 3
                END,
                Rating DESC, 
                Votes DESC
        ) AS opportunity_rank_in_city
    FROM [dbo].[ZomatoData1]
    WHERE COUNTRY_NAME = 'INDIA' AND Rating IS NOT NULL
)
SELECT TOP 30
    RestaurantName,
    City,
    Locality,
    LEFT(Cuisines, 40) + '...' AS cuisine_offerings,
    ROUND(Rating, 1) AS rating,
    Votes AS customer_engagement,
    ROUND(Average_Cost_for_two, 0) AS cost_for_two,
    PRICE_CATEGORY,
    opportunity_category,
    opportunity_rank_in_city,
    CASE 
        WHEN Has_Online_delivery = 'NO' THEN 'Add Online Delivery'
        WHEN Has_Table_booking = 'NO' THEN 'Add Table Booking'
        WHEN Votes < 100 THEN 'Increase Marketing'
        ELSE 'Maintain Excellence'
    END AS recommended_action
FROM opportunity_analysis
WHERE opportunity_category IN ('HIGH_VALUE_OPPORTUNITY', 'HIDDEN_GEM', 'PREMIUM_SEGMENT')
    AND opportunity_rank_in_city <= 5
ORDER BY 
    CASE opportunity_category
        WHEN 'HIGH_VALUE_OPPORTUNITY' THEN 1
        WHEN 'HIDDEN_GEM' THEN 2
        WHEN 'PREMIUM_SEGMENT' THEN 3
        ELSE 4
    END,
    Rating DESC;

-- =====================================================
-- MARKET SEGMENTATION AND CUSTOMER PREFERENCES
-- =====================================================

-- Advanced customer preference analysis by price and rating segments
WITH customer_preference_matrix AS (
    SELECT 
        PRICE_CATEGORY,
        RATE_CATEGORY,
        COUNT(*) AS restaurant_count,
        AVG(CAST(Votes AS FLOAT)) AS avg_customer_engagement,
        AVG(CAST(Average_Cost_for_two AS FLOAT)) AS avg_cost,
        COUNT(CASE WHEN Has_Online_delivery = 'YES' THEN 1 END) AS online_delivery_adoption,
        COUNT(CASE WHEN Has_Table_booking = 'YES' THEN 1 END) AS table_booking_adoption,
        STRING_AGG(
            CASE WHEN ROW_NUMBER() OVER (
                PARTITION BY PRICE_CATEGORY, RATE_CATEGORY 
                ORDER BY Votes DESC
            ) <= 3 THEN LEFT(Cuisines, 20) END, 
            ', '
        ) AS top_cuisines
    FROM [dbo].[ZomatoData1]
    WHERE COUNTRY_NAME = 'INDIA' 
        AND PRICE_CATEGORY IS NOT NULL 
        AND RATE_CATEGORY IS NOT NULL
    GROUP BY PRICE_CATEGORY, RATE_CATEGORY
),
segment_analysis AS (
    SELECT 
        *,
        ROUND(CAST(online_delivery_adoption AS FLOAT) / restaurant_count * 100, 1) AS online_adoption_pct,
        ROUND(CAST(table_booking_adoption AS FLOAT) / restaurant_count * 100, 1) AS booking_adoption_pct,
        CASE 
            WHEN PRICE_CATEGORY = 'LUXURY' AND RATE_CATEGORY = 'EXCELLENT' THEN 'PREMIUM_EXCELLENCE'
            WHEN PRICE_CATEGORY = 'BUDGET' AND RATE_CATEGORY IN ('GREAT', 'EXCELLENT') THEN 'VALUE_CHAMPIONS'
            WHEN PRICE_CATEGORY = 'MODERATE' AND RATE_CATEGORY = 'GREAT' THEN 'SWEET_SPOT'
            WHEN RATE_CATEGORY = 'POOR' THEN 'REQUIRES_ATTENTION'
            ELSE 'STANDARD_SEGMENT'
        END AS market_segment_classification
    FROM customer_preference_matrix
)
SELECT 
    PRICE_CATEGORY,
    RATE_CATEGORY,
    restaurant_count,
    ROUND(avg_customer_engagement, 0) As avg_votes,
    ROUND(avg_cost, 0) AS avg_cost_for_two,
    online_adoption_pct,
    booking_adoption_pct,
    market_segment_classification,
    top_cuisines
FROM segment_analysis
ORDER BY 
    CASE PRICE_CATEGORY 
        WHEN 'LUXURY' THEN 1 
        WHEN 'EXPENSIVE' THEN 2 
        WHEN 'MODERATE' THEN 3 
        WHEN 'BUDGET' THEN 4 
        ELSE 5 
    END,
    CASE RATE_CATEGORY 
        WHEN 'EXCELLENT' THEN 1 
        WHEN 'GREAT' THEN 2 
        WHEN 'GOOD' THEN 3 
        WHEN 'POOR' THEN 4 
        ELSE 5 
    END;

-- =====================================================
-- PREDICTIVE PERFORMANCE INDICATORS
-- =====================================================

-- Restaurant success probability scoring model
WITH performance_indicators AS (
    SELECT 
        RestaurantID,
        RestaurantName,
        City,
        Locality,
        Rating,
        Votes,
        Average_Cost_for_two,
        Has_Online_delivery,
        Has_Table_booking,
        PRICE_CATEGORY,
        -- Success Score Components
        CASE WHEN Rating >= 4.0 THEN 25 ELSE CAST(Rating * 6.25 AS INT) END AS rating_score,
        CASE 
            WHEN Votes >= 1000 THEN 25
            WHEN Votes >= 500 THEN 20
            WHEN Votes >= 100 THEN 15
            WHEN Votes >= 50 THEN 10
            ELSE 5
        END AS engagement_score,
        CASE WHEN Has_Online_delivery = 'YES' THEN 15 ELSE 0 END AS digital_score,
        CASE WHEN Has_Table_booking = 'YES' THEN 10 ELSE 0 END AS service_score,
        CASE 
            WHEN PRICE_CATEGORY = 'MODERATE' THEN 25
            WHEN PRICE_CATEGORY = 'BUDGET' THEN 20
            WHEN PRICE_CATEGORY = 'EXPENSIVE' THEN 15
            WHEN PRICE_CATEGORY = 'LUXURY' THEN 10
            ELSE 5
        END AS market_positioning_score
    FROM [dbo].[ZomatoData1]
    WHERE COUNTRY_NAME = 'INDIA' AND Rating IS NOT NULL
),
success_scoring AS (
    SELECT 
        *,
        rating_score + engagement_score + digital_score + service_score + market_positioning_score AS total_success_score,
        RANK() OVER (PARTITION BY City ORDER BY 
            rating_score + engagement_score + digital_score + service_score + market_positioning_score DESC
        ) AS city_success_rank
    FROM performance_indicators
),
final_classification AS (
    SELECT 
        *,
        CASE 
            WHEN total_success_score >= 85 THEN 'HIGH_SUCCESS_PROBABILITY'
            WHEN total_success_score >= 70 THEN 'MODERATE_SUCCESS_PROBABILITY'
            WHEN total_success_score >= 55 THEN 'AVERAGE_PERFORMANCE'
            WHEN total_success_score >= 40 THEN 'IMPROVEMENT_NEEDED'
            ELSE 'HIGH_RISK_OPERATION'
        END AS success_probability_tier,
        CASE 
            WHEN city_success_rank <= 5 THEN 'TOP_TIER_IN_CITY'
            WHEN city_success_rank <= 15 THEN 'STRONG_PERFORMER'
            WHEN city_success_rank <= 30 THEN 'AVERAGE_PERFORMER'
            ELSE 'BELOW_AVERAGE'
        END AS city_competitive_position
    FROM success_scoring
)
SELECT TOP 25
    RestaurantName,
    City,
    Locality,
    ROUND(Rating, 1) AS rating,
    Votes,
    ROUND(Average_Cost_for_two, 0) AS cost_for_two,
    total_success_score,
    success_probability_tier,
    city_success_rank,
    city_competitive_position,
    rating_score,
    engagement_score,
    digital_score,
    service_score,
    market_positioning_score
FROM final_classification
WHERE success_probability_tier = 'HIGH_SUCCESS_PROBABILITY'
ORDER BY total_success_score DESC;

-- =====================================================
-- EXECUTIVE SUMMARY DASHBOARD
-- =====================================================

-- Key performance indicators for executive reporting
SELECT 
    'Total Active Restaurants' AS kpi_metric,
    FORMAT(COUNT(*), 'N0') AS value,
    'All Markets' AS segment
FROM [dbo].[ZomatoData1]

UNION ALL

SELECT 
    'India Market Share',
    FORMAT(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM [dbo].[ZomatoData1]), 'N2') + '%',
    'India Focus'
FROM [dbo].[ZomatoData1]
WHERE COUNTRY_NAME = 'INDIA'

UNION ALL

SELECT 
    'Average Rating (India)',
    FORMAT(AVG(CAST(Rating AS FLOAT)), 'N2'),
    'Quality Metric'
FROM [dbo].[ZomatoData1]
WHERE COUNTRY_NAME = 'INDIA'

UNION ALL

SELECT 
    'Digital Adoption Rate (India)',
    FORMAT(COUNT(CASE WHEN Has_Online_delivery = 'YES' THEN 1 END) * 100.0 / COUNT(*), 'N1') + '%',
    'Digital Transformation'
FROM [dbo].[ZomatoData1]
WHERE COUNTRY_NAME = 'INDIA'

UNION ALL

SELECT 
    'Premium Segment (4+ Rating)',
    FORMAT(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM [dbo].[ZomatoData1] WHERE COUNTRY_NAME = 'INDIA'), 'N1') + '%',
    'Quality Distribution'
FROM [dbo].[ZomatoData1]
WHERE COUNTRY_NAME = 'INDIA' AND Rating >= 4.0

UNION ALL

SELECT 
    'Top City - Restaurant Count',
    City + ' (' + FORMAT(COUNT(*), 'N0') + ')',
    'Market Concentration'
FROM [dbo].[ZomatoData1]
WHERE COUNTRY_NAME = 'INDIA'
GROUP BY City
HAVING COUNT(*) = (
    SELECT MAX(city_count) 
    FROM (
        SELECT COUNT(*) AS city_count 
        FROM [dbo].[ZomatoData1] 
        WHERE COUNTRY_NAME = 'INDIA' 
        GROUP BY City
    ) AS city_counts
)

UNION ALL

SELECT 
    'Service Integration Rate',
    FORMAT(COUNT(CASE WHEN Has_Online_delivery = 'YES' AND Has_Table_booking = 'YES' THEN 1 END) * 100.0 / COUNT(*), 'N1') + '%',
    'Full Service Adoption'
FROM [dbo].[ZomatoData1]
WHERE COUNTRY_NAME = 'INDIA';

-- =====================================================
-- END OF ANALYSIS SCRIPT
-- =====================================================