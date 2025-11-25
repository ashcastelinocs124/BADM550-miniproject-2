# USDC Retail Transaction Analysis (SQL)

This repository contains `code.sql`, a collection of SQL queries and analysis snippets used to analyze USDC (Circle) transfers on Ethereum. The queries examine transaction-size distributions, daily volumes, median transaction size, stress-levels (z-scores), percentile summaries, gas-fee linkage, and hourly congestion analysis.

## Files

- `code.sql` — Primary SQL file containing all queries, CTEs, and commentary used for the analysis.

## Purpose

The SQL in `code.sql` answers questions such as:

- Are USDC transfers predominantly retail-sized (small transfers) or institutional-sized?
- What are the natural breakpoints in USDC transaction sizes (percentiles)?
- How does daily USDC volume and median transaction size evolve (last 6 months)?
- When is the network congested (by gas price) and how does that relate to USDC activity (hourly, last 7 days)?
- What are the typical transaction fees (USD) for USDC transfers on Ethereum?

## Key tables referenced

- `erc20_ethereum.evt_transfer` (or `evt_Transfer`) — ERC-20 transfer events (used for USDC transfer records)
- `ethereum.transactions` — Ethereum transaction table (used to calculate gas fees and gas price metrics)

Note: Table names and schema may vary by environment. If your environment uses different naming or schema, update the queries accordingly.

## Main queries (high level)

1. Basic exploration: SELECT * FROM `erc20_ethereum.evt_transfer` LIMIT 100
2. Daily USDC transaction volume grouped into size buckets (last 6 months)
3. Daily median USDC transaction size — daily overall vs retail (< $1k)
4. Daily median USDC transaction size with 7-day rolling mean/stddev and z-score-based stress levels
5. Percentile analysis (P25, median, mean, P75, P90, P95, P99) — distribution overview
6. Granular transaction size distribution across 13 size buckets (histogram)
7. Retail vs institutional buckets (5 categories) and percentage of transactions
8. Fee analysis: join `ethereum.transactions` to compute fee in USD for USDC transfers
9. Hourly correlation between gas prices (Gwei) and USDC activity (last 7 days)

## Assumptions & environment notes

- USDC contract address (mainnet): `0xA0b86991c6218b36c1d19d4a2e9eb0ce3606eb48`. In `code.sql` the address may appear without quotes — depending on your SQL engine you may need to surround it with single quotes, e.g. `'0xA0b8...eb48'`.
- USDC uses 6 decimals. The queries divide token `value` by `1e6` to convert to USD-equivalent amounts.
- The queries use functions which must be supported by your SQL engine (commonly found in engines like Trino/Presto, Snowflake, or similar analytical engines):
  - `date_trunc()`
  - `now()` and `INTERVAL` arithmetic
  - `approx_percentile()` (approximate percentiles)
  - Window functions (`AVG() OVER (...)`, `STDDEV() OVER (...)`)
  - `ROUND()` and `SUM()` aggregations
- The sample design expects a data lake or analytic database with separate schemas (e.g. `erc20_ethereum`, `ethereum`). Adjust fully-qualified table names if your environment differs.

## How to run

1. Open your SQL client or the query editor for your analytic engine (Trino/Presto, Snowflake, Databricks, etc.).
2. If you want to run the full file, split it into logical sections (the file already contains section comments) and execute sections one at a time.

Example (run percentile summary only):

- Copy the "Percentile Analysis" CTE and final SELECT into your SQL editor and execute.

Notes for Windows PowerShell users running a CLI tool:
- If your engine provides a CLI (e.g., `trino`, `snowflake`, or a local `psql`/`sqlite3` wrapper), you can pass the file to it. Confirm the command syntax with your engine and adapt.

## Suggested edits before running

- Quote hex contract addresses if your SQL dialect requires strings: `WHERE contract_address = '0xA0b8...eb48'`.
- Verify the decimal scaling for the token: `value / 1e6` assumes 6 decimals for USDC.
- If `approx_percentile` is not supported in your engine, substitute with the appropriate percentile function (for exact percentile you might use `percentile_cont` or `percentile_disc`, depending on support and performance requirements).
- If your environment uses different column names (for example, `evt_tx_hash` vs `tx_hash`), update joins accordingly.

## Examples & quick checks

- Quick sample to preview 10 USDC transfers (modify quoting as needed):

  SELECT *
  FROM erc20_ethereum.evt_transfer
  WHERE contract_address = '0xA0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'
  LIMIT 10;

- Example: compute fee in USD for the first 10 USDC transfers (ensure correct join keys and quoting):

  SELECT
    tr.block_time,
    (CAST(tr.gas_used AS DOUBLE) * CAST(tr.gas_price AS DOUBLE)) / 1e18 AS fee_eth,
    ((CAST(tr.gas_used AS DOUBLE) * CAST(tr.gas_price AS DOUBLE)) / 1e18) * eth_usd_price AS fee_usd
  FROM ethereum.transactions tr
  JOIN erc20_ethereum.evt_transfer tt ON tr.hash = tt.evt_tx_hash
  WHERE tt.contract_address = '0xA0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'
  LIMIT 10;

(Above assumes you have a way to obtain `eth_usd_price`; if not, remove the USD conversion or join a price table.)

## Author / License

- Author: Generated from `code.sql` (repository: BADM550-miniproject-2)
- License: Use as you see fit — add a license file if required for your project.

## Next steps / improvements

- Add a small sample dataset or unit tests (SQL-based smoke tests) to validate query assumptions.
- Add an example notebook (Jupyter or SQL worksheet) that runs these queries and produces charts.

---

If you'd like, I can also:
- Adjust the README to target a specific SQL engine (Trino/Presto, Snowflake, BigQuery) and update the exact syntax.
- Create a short SQL smoke test that verifies table presence and the USDC contract address formatting.
