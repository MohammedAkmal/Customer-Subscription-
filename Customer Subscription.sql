USE customer_subscription;

-- Q1: What are the Seasonal Trends in subscription sign-ups over time, 
-- and identify the GROWTH_RATE from one month to the next ?

-- Answer):-
-- 1- Seasonal Trends in subscription signups:
SELECT 	
	YEAR(signup_date_time) AS SignUp_Year,
    MONTHNAME(signup_date_time) AS SignUp_Month,
    -- DAY(signup_date_time) As SignUp_Day,
    COUNT(*) AS SignUps -- To determine how many signups per Month?
FROM 
	customer_product
GROUP BY 
	1, 2 
ORDER BY 
	1, MIN(MONTH(signup_date_time));


-- 2- Identify the GROWTH_RATE from one month to the next: 

WITH MonthlySignUps AS(
    SELECT 	
        YEAR(signup_date_time) AS SignUp_Year,
        MONTHNAME(signup_date_time) AS SignUp_Month,
        MONTH(signup_date_time) AS SignUp_MonthNumber,
        COUNT(*) AS SignUps -- To determine how many signups per month
    FROM 
        customer_product
    GROUP BY
        SignUp_Year, SignUp_Month, SignUp_MonthNumber
)
SELECT 
    SignUp_Year,
    SignUp_Month,
    SignUps,
    LAG(SignUps) OVER (ORDER BY SignUp_Year, SignUp_MonthNumber) AS PreviousMonthSignUps, -- To retrieve the sign-ups from the previous month
    ROUND(((SignUps - LAG(SignUps) OVER (ORDER BY SignUp_Year, SignUp_MonthNumber)) / 
           LAG(SignUps) OVER (ORDER BY SignUp_Year, SignUp_MonthNumber)) * 100, 2) AS GrowthRate
FROM 
    MonthlySignUps
ORDER BY 
    SignUp_Year, SignUp_MonthNumber;
    
    

-- Q2: How do cancellation patterns change over time?
-- When customers are most likely to cancel their subscriptions?

SELECT 
	YEAR(cancel_date_time) As Cancel_Year,
    MONTHNAME(cancel_date_time) As Cancel_Month,
    COUNT(*) AS Cancelations 
    
FROM 
	customer_product
WHERE 
	cancel_date_time IS NOT NULL 
GROUP BY 
	1,2
ORDER BY 
	1, MIN(MONTH(cancel_date_time));
    
    

-- Q3: What is the long-term trend in customer sign-ups and cancellations over the years?
-- Determine whether the business is growing or if there are periods of decline (Net Growth Rate) ?

WITH AnnualTrends AS (
    SELECT
        YEAR(signup_date_time) AS Year,
        COUNT(*) AS SignUps,
        SUM(CASE WHEN cancel_date_time IS NOT NULL THEN 1 ELSE 0 END) AS Cancellations -- counting the number of cancellations for each year 
    FROM
        customer_product
    GROUP BY
        Year
)
SELECT 
    Year,
    SignUps,
    Cancellations,
    LAG(SignUps) OVER (ORDER BY Year) AS PreviousYearSignUps,
    LAG(Cancellations) OVER (ORDER BY Year) AS PreviousYearCancellations,
    ROUND(((SignUps - LAG(SignUps) OVER (ORDER BY Year)) / LAG(SignUps) OVER (ORDER BY Year)) * 100, 2) AS SignUpGrowthRate,
    ROUND(((Cancellations - LAG(Cancellations) OVER (ORDER BY Year)) / LAG(Cancellations) OVER (ORDER BY Year)) * 100, 2) AS Cancellation_Rate,
    ROUND(((SignUps - Cancellations) - (LAG(SignUps) OVER (ORDER BY Year) - LAG(Cancellations) OVER (ORDER BY Year))) / 
          (LAG(SignUps) OVER (ORDER BY Year) - LAG(Cancellations) OVER (ORDER BY Year)) * 100, 2) AS NetGrowthRate
FROM 
    AnnualTrends
ORDER BY 
    Year;
    
    
    
-- Q4: Which customer demographics (age & gender) are most likely to cancel their subscriptions?

WITH Cancellations AS ( -- Counts the number of cancellations by age and gender.
    SELECT
        ci.age,
        ci.gender,
        COUNT(c.case_id) AS Cancellation_Count
    FROM
        customer_cases c
    JOIN
        customer_info ci 
			ON c.customer_id = ci.customer_id
    WHERE
        c.reason = 'Support'
    GROUP BY
        1, 2
),
TotalCustomers AS ( -- Counts the total number of customers by age and gender.
    SELECT
        ci.age,
        ci.gender,
        COUNT(*) AS TotalCustomers
    FROM
        customer_info ci
    GROUP BY
        1, 2
),
CancellationRates AS (
    SELECT
        tc.age,
        tc.gender,
        COALESCE(c.Cancellation_Count, 0) AS CancellationCount,
        COALESCE(tc.TotalCustomers, 1) AS TotalCustomers,
        ROUND((COALESCE(c.Cancellation_Count, 0) / COALESCE(tc.TotalCustomers, 1)) * 100, 2) AS CancellationRate -- computing the cancellation rate for each demographic group.
    FROM
        TotalCustomers tc
    LEFT JOIN
        Cancellations c
    ON
        tc.age = c.age AND tc.gender = c.gender
)
SELECT 
    age,
    gender,
    CancellationCount,
    TotalCustomers,
    CancellationRate
FROM 
    CancellationRates
ORDER BY 
   age, CancellationRate DESC;
    
    

-- Q5: How do customer engagement levels differ by channel?

WITH ChannelCases AS (
    SELECT channel, COUNT(*) AS case_count
    FROM customer_cases
    GROUP BY channel
),
TotalCases AS (
    SELECT COUNT(*) AS total_count
    FROM customer_cases
)
SELECT
    channel,
    case_count,
    ROUND((case_count / total_count) * 100.0, 2) AS engagement_rate
FROM
    ChannelCases,
    TotalCases 
ORDER BY
    engagement_rate DESC;
    
    
-- Q6: What are the most common reasons for customer cases, 
-- and how do they correlate with subscription cancellations?

-- Counts cases and cancellations for each reason by demographic details.
WITH CaseReasons AS (
    SELECT
        ci.age,
        ci.gender,
        c.reason,
        COUNT(c.case_id) AS CaseCount,
        SUM(CASE WHEN cp.cancel_date_time IS NOT NULL THEN 1 ELSE 0 END) AS Cancellations
    FROM
        customer_cases c
    JOIN
        customer_info ci ON c.customer_id = ci.customer_id
    LEFT JOIN
        customer_product cp ON c.customer_id = cp.customer_id AND cp.cancel_date_time IS NOT NULL
    GROUP BY
        ci.age, ci.gender, c.reason
),

-- Aggregates total cases and cancellations by reason.

ReasonSummary AS (
    SELECT
        reason,
        SUM(CaseCount) AS TotalCases,
        SUM(Cancellations) AS TotalCancellations
    FROM
        CaseReasons
    GROUP BY
        reason
),

-- Calculates the cancellation rate for each reason

CancellationRates AS (
    SELECT
        reason,
        TotalCases,
        TotalCancellations,
        ROUND((TotalCancellations / TotalCases) * 100, 2) AS CancellationRate
    FROM
        ReasonSummary
)
SELECT 
    reason,
    TotalCases,
    TotalCancellations,
    CancellationRate
FROM 
    CancellationRates
ORDER BY 
    CancellationRate DESC;




-- Q7: How does the billing cycle impact customer retention?


WITH BillingCycleData AS ( -- The total number of customers and the number of cancellations for each billing cycle.
    SELECT
        pi.billing_cycle,
        COUNT(DISTINCT cp.customer_id) AS TotalCustomers,
        SUM(CASE WHEN cp.cancel_date_time IS NOT NULL THEN 1 ELSE 0 END) AS Cancellations
    FROM
        customer_product cp
    JOIN
        product_info pi ON cp.product = pi.product_id
    GROUP BY
        pi.billing_cycle
),
RetentionRates AS ( -- The number of retained customers (those who did not cancel).
    SELECT
        billing_cycle,
        TotalCustomers,
        Cancellations,
        (TotalCustomers - Cancellations) AS RetainedCustomers,
        ROUND(((TotalCustomers - Cancellations) / TotalCustomers) * 100, 2) AS RetentionRate
    FROM
        BillingCycleData
)
SELECT 
    billing_cycle,
    TotalCustomers,
    Cancellations,
    RetainedCustomers,
    RetentionRate
FROM 
    RetentionRates
ORDER BY 
    RetentionRate DESC;


