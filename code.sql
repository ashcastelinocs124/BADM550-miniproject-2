-- understand attributes in the transfer table on the ethereum blockahin 
SELECT *
FROM erc20_ethereum.evt_transfer
LIMIT 100;


-- graph a bar chart about daily USDC transaction volume in the last 6 months group by transfer bucket size
SELECT
    -- trunc evt_block_time to the unit of day
    date_trunc('day', evt_block_time) AS day,
    -- bucket sizes for USDC transaction volume (used ChatGPT for correcting some of the bucket sizes)
    CASE
        WHEN value / 1e6 < 100 THEN '1:$0–$100'
        WHEN value / 1e6 < 1000 THEN '2:$100–$1k'
        WHEN value / 1e6 < 10000 THEN '3:$1k–$10k'
        WHEN value / 1e6 < 100000 THEN '4:$10k–$100k'
        WHEN value / 1e6 < 1000000 THEN '5:$100k–$1M'
        WHEN value / 1e6 < 10000000 THEN '6:$1M–$10M'
        ELSE '7:>$10M'
    END AS size_bucket,
    -- sum up the total USDC transaction volume 
    SUM(value / 1e6) AS total_usd
FROM erc20_ethereum.evt_transfer
-- specialize getting information from USDC in the last 6 months (used ChatGPT to correct stablecoin type and time period specialization)
WHERE contract_address = 0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48
  AND evt_block_time >= now() - interval '6' month
-- group and order by day then transaction volume
GROUP BY 1, 2
ORDER BY 1, 2;


-- graph a line chart about daily median USDC transaction size (retail/overall) in the last 6 months 
-- create CTEs to store "base" with information about time and amount, "daily_overall" with information about time and daily median overall transaction size, and "daily_retail" with information about time and daily median retail transaction size
WITH base AS (
    SELECT
        evt.evt_block_time AS block_time,
        evt.value / 1e6 AS amount_usdc
    FROM erc20_ethereum.evt_transfer evt
    -- specify USDC and time period 
    WHERE evt.contract_address = 0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48
      AND evt.evt_block_time >= now() - interval '6' month
),

-- find daily median overall transaction size (used ChatGPT to correctly calculate daily median USDC transaction size)
daily_overall AS (
    SELECT
        date_trunc('day', block_time) AS day,
        approx_percentile(amount_usdc, 0.5) AS median_overall
    FROM base
    GROUP BY 1
),

-- find daily median retail transaction size
daily_retail AS (
    SELECT
        date_trunc('day', block_time) AS day,
        approx_percentile(amount_usdc, 0.5) AS median_retail
    FROM base
    WHERE amount_usdc < 1000
    GROUP BY 1
)

-- find day, daily median USDC overall transaction size, and daily median USDC retail transaction size from the joined table daily_overall and daily_retail 
SELECT
    o.day,
    o.median_overall,
    r.median_retail
FROM daily_overall o
LEFT JOIN daily_retail r
    ON o.day = r.day
ORDER BY o.day;


-- graph a line chart about daily median USDC transaction size in the last 6 months group by stress level
-- create CTEs to store "daily" with information about time and daily median USDC transaction size, "rolling" with information about rolling mean and rolling standard deviation for daily median USDC transaction size in the 7-days window, and "scores" with information about z-scores 
WITH daily AS (
    SELECT
        date_trunc('day', evt_block_time) AS day,
        -- calculate daily median USDC transaction size 
        approx_percentile(value / 1e6, 0.5) AS median_usdc
    FROM erc20_ethereum.evt_transfer
    -- specify USDC and the last 6 months
    WHERE contract_address = 0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48
      AND evt_block_time >= now() - interval '6' month
    GROUP BY 1
),

-- find rolling mean, rolling standard deviation for daily median USDC transaction size in the 7-days window (used ChatGPT to correctly calculate the rolling mean and the rolling standard deviation in the 7-days window)
rolling AS (
    SELECT
        day,
        median_usdc,
        AVG(median_usdc) OVER (
            ORDER BY day
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS med_ma7,
        STDDEV(median_usdc) OVER (
            ORDER BY day
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS med_std7
    FROM daily
),

-- calculate z_scores using the rolling mean of daily median USDC transaction size and the rolling standard deviation of daily median USDC transaction size  
scores AS (
    SELECT
        day,
        median_usdc,
        med_ma7,
        med_std7,
        (median_usdc - med_ma7) / NULLIF(med_std7, 0) AS zscore
    FROM rolling
)

-- find daily median USDC transaction size group by stress level 
SELECT
    day,
    median_usdc,
    zscore,
    -- use z_scores to find stress levels
    CASE
        WHEN zscore > 2 THEN '3: High Stress'
        WHEN zscore > 1 THEN '2: Mild Stress'
        ELSE '1: Normal'
    END AS stress_segment
FROM scores
ORDER BY day;



-- ============================================================================
-- USDC RETAIL TRANSACTION ANALYSIS - SQL APPENDIX
-- ============================================================================
-- Persona: Emerging Markets Analyst
-- Key Question: Do we see many smaller (retail-sized) transfers in USDC?
-- Stablecoin: USDC (Circle)
-- Time Period: Last 6 months
-- ============================================================================

-- ----------------------------------------------------------------------------
-- QUERY 1: Percentile Analysis
-- ----------------------------------------------------------------------------
-- Business Question: What are the natural breakpoints in USDC transaction sizes?
-- Purpose: Identify key percentiles to understand the distribution and inform
--          bucket definitions for retail vs institutional categorization
-- Output: Single row with summary statistics and percentile values
-- Used for: Understanding data distribution before creating visualizations
-- ----------------------------------------------------------------------------

WITH usdc_transfers AS (
  SELECT
    value / 1e6 AS amount_usd  -- USDC has 6 decimals
  FROM erc20_ethereum.evt_Transfer
  WHERE contract_address = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48  -- USDC contract
    AND evt_block_time >= NOW() - INTERVAL '6' MONTH
    AND value > 0  -- Exclude zero-value transfers
)

SELECT
  COUNT(*) AS total_transactions,
  ROUND(APPROX_PERCENTILE(amount_usd, 0.25), 2) AS p25_amount,
  ROUND(AVG(amount_usd), 2) AS mean_amount,
  ROUND(APPROX_PERCENTILE(amount_usd, 0.50), 2) AS median_amount,
  ROUND(APPROX_PERCENTILE(amount_usd, 0.75), 2) AS p75_amount,
  ROUND(APPROX_PERCENTILE(amount_usd, 0.90), 2) AS p90_amount,
  ROUND(APPROX_PERCENTILE(amount_usd, 0.95), 2) AS p95_amount,
  ROUND(APPROX_PERCENTILE(amount_usd, 0.99), 2) AS p99_amount,
  ROUND(MIN(amount_usd), 2) AS min_amount,
  ROUND(MAX(amount_usd), 2) AS max_amount
FROM usdc_transfers;


-- ----------------------------------------------------------------------------
-- QUERY 2: Granular Transaction Size Distribution
-- ----------------------------------------------------------------------------
-- Business Question: How are USDC transactions distributed across fine-grained
--                    size buckets?
-- Purpose: Create a detailed histogram showing transaction concentration across
--          13 size categories from micro (<$10) to very large (>$100K)
-- Visualization: Histogram
-- Key Insight: Reveals if there's clustering around specific transaction sizes
-- ----------------------------------------------------------------------------

WITH usdc_transfers AS (
  SELECT
    value / 1e6 AS amount_usd
  FROM erc20_ethereum.evt_Transfer
  WHERE contract_address = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
    AND evt_block_time >= NOW() - INTERVAL '6' MONTH
    AND value > 0
),

bucketed AS (
  SELECT
    CASE
      WHEN amount_usd < 10 THEN '01. $0-$10'
      WHEN amount_usd < 25 THEN '02. $10-$25'
      WHEN amount_usd < 50 THEN '03. $25-$50'
      WHEN amount_usd < 100 THEN '04. $50-$100'
      WHEN amount_usd < 250 THEN '05. $100-$250'
      WHEN amount_usd < 500 THEN '06. $250-$500'
      WHEN amount_usd < 1000 THEN '07. $500-$1K'
      WHEN amount_usd < 2500 THEN '08. $1K-$2.5K'
      WHEN amount_usd < 5000 THEN '09. $2.5K-$5K'
      WHEN amount_usd < 10000 THEN '10. $5K-$10K'
      WHEN amount_usd < 50000 THEN '11. $10K-$50K'
      WHEN amount_usd < 100000 THEN '12. $50K-$100K'
      ELSE '13. $100K+'
    END AS bucket
  FROM usdc_transfers
)

SELECT
  bucket,
  COUNT(*) AS transaction_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_transactions
FROM bucketed
GROUP BY bucket
ORDER BY bucket;

-- ----------------------------------------------------------------------------
-- QUERY 3: Retail vs Institutional Transaction Distribution
-- ----------------------------------------------------------------------------
-- Business Question: What percentage of USDC transactions are retail-sized
--                    vs institutional-sized?
-- Purpose: Categorize all transactions into 5 meaningful buckets aligned with
--          remittance use cases to directly answer the key question
-- Visualization: Primary bar chart for dashboard
-- Key Finding: Shows whether USDC is primarily used for retail/remittance
--              (transactions <$2K) or institutional purposes (>$2K)
-- ----------------------------------------------------------------------------

WITH usdc_transfers AS (
  SELECT
    evt_block_time,
    value / 1e6 AS amount_usd  -- USDC has 6 decimals
  FROM erc20_ethereum.evt_Transfer
  WHERE contract_address = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48  -- USDC contract
    AND evt_block_time >= NOW() - INTERVAL '6' MONTH
    AND value > 0  -- Exclude zero-value transfers
),

bucketed_transactions AS (
  SELECT
    CASE
      WHEN amount_usd < 100 THEN '1. Micro (<$100)'
      WHEN amount_usd >= 100 AND amount_usd < 500 THEN '2. Small Retail ($100-$500)'
      WHEN amount_usd >= 500 AND amount_usd < 2000 THEN '3. Medium Retail ($500-$2K)'
      WHEN amount_usd >= 2000 AND amount_usd < 10000 THEN '4. Small Institutional ($2K-$10K)'
      ELSE '5. Large Institutional (>$10K)'
    END AS size_category
  FROM usdc_transfers
)

SELECT
  size_category,
  COUNT(*) AS transaction_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM bucketed_transactions
GROUP BY size_category
ORDER BY size_category;
