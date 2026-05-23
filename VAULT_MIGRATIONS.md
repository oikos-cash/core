# Vault Address Migrations

> Tracking record of vault contract redeployments and how the backend reconciles
> historical loan activity across them.

## Background

A "vault" in Oikos is a logical lending market identified by its `(token0,
token1, feeTier)` parameters. The underlying contract address changes with
each redeployment (bug fixes, ABI changes, parameter updates), but the loan
activity that users care about — borrows, paybacks, rolls — is logically
continuous across those addresses.

This document captures the migration history and explains how the API
reconciles it.

## Current chain (canonical → legacy)

Generations are ordered from earliest deployment to latest. The current
contract is always at the top of the alias list in the config, and at the
**bottom** of this table (latest generation).

| Generation | Address                                       | Role             |
| ---------- | --------------------------------------------- | ---------------- |
| 1 (first)  | `0x5EffFAD2602DCe520C09c58fa88b0e06609C52b8`  | Legacy — first  |
| 2          | `0x10229DC66ac45b6Ecd2c71ca480EDD013dE701aD`  | Legacy           |
| 3          | `0x1e9aef03ccd42c9531e404939f45d3a4e922ed9d`  | Legacy (brief)  |
| 4 (current)| `0x6D77a715d2047a69DFdf922876712c4ef17d1788`  | **Canonical**    |

The first vault (`0x5EffFAD2...`) started seeing on-chain activity on or
about **2025-06-23** (~334 days before this doc was written). The
second-generation vault (`0x10229DC...`) was deployed roughly two weeks
later, on or about **2025-07-08** (~318 days ago).

## Observed activity windows

Numbers below come from `extracted.logs` via the existing loan API
(`/api/loans/vault/:address` returns strict per-address events when
queried with any *legacy* address). The four contracts ran in partial
overlap rather than as clean handoffs — multiple were accepting loan
activity at the same time during transition windows.

| Generation | Address                  | First event          | Last event           | Events                     |
| ---------- | ------------------------ | -------------------- | -------------------- | -------------------------- |
| 1          | `0x5EffFAD2...`          | 2025-06-23 20:48 UTC | 2026-01-05 21:04 UTC |  20                        |
| 2          | `0x10229DC...`           | 2025-07-08 14:41 UTC | 2025-10-01 10:53 UTC | 204                        |
| 3          | `0x1e9aef03...`          | 2026-01-05 18:00 UTC | 2026-01-06 20:06 UTC |   9                        |
| 4          | `0x6D77a715...`          | (active)             | 2026-05-22 12:24 UTC | 10 native / 243 expanded   |

Notes:

- The gen-1 vault (`0x5EffFAD2...`) had a real active window of only
  ~2 weeks (2025-06-23 → ~2025-07-07). Ownership was transferred on or
  about **2025-07-07** (320 days ago at time of writing), which marks the
  effective end-of-life for regular operations and the handoff to gen 2.
  The Borrow event dated 2026-01-05 (137 days ago) is **not** regular
  usage — it was part of a fund recovery operation against the abandoned
  contract, so the "Last event" column above is misleading at first glance
  and should be read in that context.
- The gen-2 vault (`0x10229DC...`) carried most of the historical load
  (204 events) and is the heaviest generation by event count.
- The gen-3 vault (`0x1e9aef03...`) only lived for ~2 calendar days
  (2026-01-05 → 2026-01-06). Likely a short-lived migration intermediate
  or a hotfix deployment that was quickly rolled into gen 4 — confirm
  with whoever ran that deploy before treating this as authoritative.
- The "expanded" event count on the gen-4 row reflects what the public
  API returns today for a query against the canonical address, after the
  v0.0.9/0.0.10 alias-expansion logic landed.
