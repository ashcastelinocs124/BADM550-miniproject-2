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
