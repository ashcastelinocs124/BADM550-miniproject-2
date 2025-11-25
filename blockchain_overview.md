# Blockchain & Stablecoin Overview: Ethereum, Solana, and USDC

This short reference explains the core concepts of Ethereum and Solana, what USDC is, and how USDC connects and moves between these chains.

## Ethereum (high level)

- Purpose: A general-purpose programmable blockchain that introduced smart contracts and decentralized applications (DeFi, NFTs, DAOs).
- Consensus & architecture: As of 2022+, Ethereum uses a Proof-of-Stake (PoS) consensus mechanism ("The Merge"). It provides wide decentralization and strong security guarantees.
- Strengths:
  - Large developer ecosystem and tooling (Solidity, EVM-compatible tooling, major SDKs)
  - Deep liquidity across DeFi protocols
  - Rich on-chain data: transactions, logs/events (e.g. ERC-20 `Transfer` events), traceability
- Tradeoffs:
  - Historically higher transaction fees (gas) when the network is congested
  - Lower raw throughput (tx/sec) than many newer L1s, but heavy ecosystem benefits
- Common token standard: ERC-20 for fungible tokens. ERC-20 transfers emit `Transfer` events, which are commonly used for analytics (the `erc20_ethereum.evt_transfer` table in `code.sql` likely maps to these events).

## Solana (high level)

- Purpose: A high-performance blockchain designed for low-latency and high-throughput applications (payments, microtransactions, gaming).
- Consensus & architecture: Uses a combination of Proof-of-History (PoH) for ordering + Proof-of-Stake for security. Optimized for speed and low fees.
- Strengths:
  - Extremely low fees and high throughput (thousands of tx/sec in practice)
  - Good for applications requiring many small payments or fast confirmation times
- Tradeoffs:
  - Different programming model and toolchain (Rust-based programs called "programs" rather than EVM smart contracts)
  - Smaller developer ecosystem compared with Ethereum (but rapidly growing)
- Token standard: SPL tokens (Solana Program Library) — the SPL equivalent of ERC-20. SPL tokens can represent USDC on Solana.

## USDC (what it is)

- USDC is a fiat-collateralized stablecoin issued by Circle and other partners; it aims to keep a 1:1 peg with the US dollar.
- Implementations:
  - USDC exists on many blockchains (Ethereum, Solana, Avalanche, Algorand, Stellar, and more).
  - On Ethereum, USDC is an ERC-20 token (contract address: `0xA0b86991c6218b36c1d19d4a2e9eb0ce3606eb48` on mainnet). The token uses 6 decimals.
  - On Solana, USDC is an SPL token with its own mint address on the Solana network.

## How USDC connects across chains

- Bridges and wrapped assets
  - To move USDC between chains, users and services use cross-chain bridges. There are two typical patterns:
    1. Native multi-chain issuance: The issuer (Circle) mints redeemable USDC on multiple chains, so USDC on Solana can be native SPL USDC issued by Circle. This does not require "wrapping" — each chain has its own issuance backed by reserves.
    2. Wrapped / bridged tokens: A bridge locks/burns tokens on the source chain and mints a wrapped representation on the destination chain. The wrapped token can be called `wUSDC` or similar and is redeemable via the bridge.
  - Bridges vary in trust model (custodial, federated, or trust-minimized). For high-value transfers, consider the bridge's security model.

- UX & analytics implications
  - A transfer that looks like a simple `Transfer` event on Ethereum corresponds to an ERC-20 movement; the same logical transfer on Solana will be an SPL token transfer. Analytics pipelines must ingest and normalize these different event shapes.
  - Cross-chain transfers may show a token burn/lock + a mint on the other chain. To link them you typically need bridge transaction identifiers and possibly off-chain logs from the bridge operator.

## Practical differences for analysis (relating to `code.sql`)

- Event / table names:
  - Ethereum analytics often rely on `Transfer` events emitted by ERC-20 contracts. In `code.sql` queries, `erc20_ethereum.evt_transfer` likely maps to these events and the `evt_tx_hash` column joins to `ethereum.transactions`.
  - On Solana, similar analyses use SPL transfer instructions/confirmed transactions; field names and schemas differ.

- Decimals & amounts:
  - USDC uses 6 decimals on EVM chains (divide raw integer `value` by `1e6` to get USD). Confirm the token decimals on the target chain before converting.

- Fee calculations:
  - Ethereum: fees = gas_used * gas_price (result in wei); convert to ETH (divide by 1e18) then multiply by USD price to get fee in USD.
  - Solana: fees are much smaller (lamports); Solana fees are typically negligible for single transfers but still calculable if needed.

- Time windows and aggregation:
  - Because Solana has much higher throughput, daily/hourly counts may be far larger; choose aggregation windows and sampling strategies accordingly.

## Security & compliance notes

- Circle issues USDC and maintains reserves; when moving USDC cross-chain, be mindful of counterparty risk depending on the bridge or whether you are using native USDC issued on the destination chain.
- For production financial operations, ensure compliance with regulatory and KYC/AML procedures required by the relevant entities.

## Quick reference / cheat-sheet

- Ethereum USDC (mainnet ERC-20): `0xA0b86991c6218b36c1d19d4a2e9eb0ce3606eb48` (6 decimals)
- Solana USDC: SPL mint (check live Solana explorer or Circle docs for the canonical mint address)
- Token standards:
  - Ethereum: ERC-20 (Transfer event)
  - Solana: SPL token (program instructions)

## Next steps (suggestions)

- If you want, I can:
  - Add the canonical Solana USDC mint address into this file.
  - Create a small example showing how the same USDC transfer looks on Ethereum (ERC-20 Transfer event sample) and on Solana (SPL transfer instruction sample).
  - Produce a short script or SQL smoke tests that normalize ERC-20 and SPL token transfers into a single canonical analytics table.

---

If you'd like this added to the repo as a committed file, tell me and I will commit & push it for you. If you want edits (audience, length, extra technical detail), tell me which parts to expand.