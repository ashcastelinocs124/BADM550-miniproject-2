


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


"""
Query 4 : Cost for USDC Transfer on Ethereum
1. Business Question

How much does it cost, in USD, to execute USDC transfers on the Ethereum network, and how does this cost vary over time?

This helps businesses or analysts understand the transaction costs associated with using USDC on Ethereum.
2. Purpose
Analyze on-chain transfer fees for USDC transactions and Evaluate efficiency and cost of using USDC for payments, remittances, or DeFi activities.

3. Output
Column	Description
block_time	Timestamp when the transaction occurred
fee_usd	Transaction fee in USD, calculated as gas_used * gas_price / 1e18

Example output (first 10 rows):

block_time	fee_usd
2025-11-22 12:00:01	0.45
2025-11-22 12:03:45	0.52
...	...
4. Used For

Evaluate how expensive USDC transfers are for users or businesses and optimize strategies for sending large volumes of USDC on Ethereum.


"""
select
    block_time
    , (CAST(gas_used as DOUBLE) * CAST(gas_price as DOUBLE)) / 1e18 as fee_usd
from ethereum.transactions tr
    inner join erc20_ethereum.evt_transfer tt on tr.hash = tt.evt_tx_hash
where tt.contract_address = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
limit 10;


"""
1)Business Question
"How does Ethereum network congestion (measured by gas prices) affect USDC stablecoin transaction activity on an hourly basis, and when are the optimal times to execute transfers?"
Purpose
To provide granular, hour-by-hour visibility into real-time correlation between gas prices and USDC transaction volume
This analysis enables users and businesses to make data-driven decisions about when to execute USDC transfers to minimize costs while maximizing transaction success probability.

Output
The query produces an hourly time-series dataset containing:
Transaction Metrics:

hour: Timestamp (hourly granularity)
usdc_tx_count: Number of USDC transfers per hour
usdc_volume: Total USD value transferred per hour

Gas/Congestion Metrics:

avg_gas_gwei: Average gas price in Gwei
max_gas_gwei: Peak gas price for the hour
min_gas_gwei: Lowest gas price for the hour
network_condition: Categorical classification (HIGH_CONGESTION > 100 Gwei, MODERATE > 50 Gwei, LOW_CONGESTION ≤ 50 Gwei)

Time Range: Last 7 days of hourly data

4)Used For

Transaction Scheduling: Identify specific hours when gas prices are lowest to schedule large USDC transfers, potentially saving thousands in fees
Batch Processing: Consolidate multiple transfers during low-congestion windows
Cost Forecasting: Predict hourly gas costs for budgeting purposes

"""
WITH hourly_usdc AS (
    SELECT
        DATE_TRUNC('hour', evt_block_time) AS hour,
        COUNT(evt_tx_hash) AS usdc_tx_count,
        SUM(value / 1e6) AS usdc_volume
    FROM erc20_ethereum.evt_Transfer
    WHERE contract_address = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
        AND evt_block_time >= NOW() - INTERVAL '7' DAY
    GROUP BY 1
),
gas_metrics AS (
    SELECT
        DATE_TRUNC('hour', block_time) AS hour,
        AVG(gas_price / 1e9) AS avg_gas_gwei,
        MAX(gas_price / 1e9) AS max_gas_gwei,
        MIN(gas_price / 1e9) AS min_gas_gwei
    FROM ethereum.transactions
    WHERE block_time >= NOW() - INTERVAL '7' DAY
    GROUP BY 1
)
SELECT
    u.hour,
    u.usdc_tx_count,
    u.usdc_volume,
    g.avg_gas_gwei,
    g.max_gas_gwei,
    g.min_gas_gwei,
    CASE
        WHEN g.avg_gas_gwei > 100 THEN 'HIGH_CONGESTION'
        WHEN g.avg_gas_gwei > 50 THEN 'MODERATE'
        ELSE 'LOW_CONGESTION'
    END AS network_condition
FROM hourly_usdc u
LEFT JOIN gas_metrics g ON u.hour = g.hour
WHERE g.hour IS NOT NULL
ORDER BY u.hour ASC;  
