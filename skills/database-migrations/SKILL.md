---
name: database-migrations
description: Reversible schema migrations, zero-downtime patterns, locking awareness and safe backfills. Use when writing, reviewing or deploying a schema or data migration, or planning a column, index or table change on a live database.
tags: [database, migrations]
---

# Database migrations

## Principles
- Every schema change is a versioned, reviewed migration file in the repo; never hand-edit a shared database.
- One logical change per migration. Never edit a migration that has already been applied anywhere shared; add a new one.
- Migrations are tested: apply on an empty database and on a copy with realistic data; apply twice must be safe or refused by the tool.
- Have a rollback story for each: either a down migration or a documented forward-fix. Data-destroying steps cannot be rolled back, so they are separated and delayed.
- Never run migrations against production without explicit approval, and never as part of an unreviewed automatic step.

## Expand / contract (zero downtime)
Application and schema deploy at different times, so old and new code must both work against the intermediate schema.
1. **Expand:** add the new structure (nullable column, new table, new index) without breaking old code.
2. **Migrate:** deploy code that writes to both old and new (or reads new with fallback). Backfill existing rows in batches.
3. **Switch:** read from the new structure only. Verify.
4. **Contract:** in a later release, remove the old column, table or code path.

### Recipes
- **Add a column:** add nullable (or with a cheap constant default where the engine supports it without rewrite), backfill, then add NOT NULL via a validated constraint.
- **Rename a column:** do not rename in place. Add new, dual-write, backfill, switch reads, drop old.
- **Change a type:** add a new column of the new type, copy and convert, switch, drop.
- **Drop a column or table:** first stop all reads and writes in code and deploy; wait a release; then drop.
- **Add a unique or foreign key constraint:** clean duplicates and orphans first; add as not-validated/concurrent where supported, then validate.
- **Split or merge tables:** treat as expand/contract with dual-writes and a verification query comparing both sides.

## Locking and performance
- Know what lock each statement takes in your engine and version (check its documentation). Table rewrites and full-table locks block traffic.
- Create indexes with the non-blocking or concurrent option when available; do it outside a transaction if the engine requires.
- Set lock and statement timeouts for migrations so they fail fast instead of queueing behind long transactions and blocking everyone.
- Avoid long transactions mixing schema and data changes.
- Large tables: schedule off-peak, estimate duration on production-sized data, and keep a kill switch.

## Backfills
- Run as a separate, resumable job, not inside the schema migration.
- Process in small batches by primary-key range; commit per batch; sleep or throttle to protect replicas and the primary.
- Make it idempotent (safe to rerun) and log progress counts, not row content.
- Verify with a count or checksum query before the switch step.
- Do not backfill with application logic that may change; use plain SQL or a pinned script.

## Data safety
- Back up or confirm point-in-time recovery exists before destructive steps.
- Never put personal data or secrets in migration files or logs.
- Seed or reference data changes are migrations too, and must be idempotent.
- Default values, NOT NULL and check constraints should reflect real invariants; test them against existing data first.

## Review checklist
- Does old code still work after this migration alone? Does new code work before it?
- Which locks are taken, for how long, on which tables?
- Is there a down path or forward-fix plan? Is the destructive part separate?
- Are indexes added for new query paths, and are unused ones removed deliberately?
- Tested on realistic data volume? Idempotent? Timeouts set?

## Reporting
List each migration, its risk (locking, data loss, ordering), the rollout order relative to code deploys, and the verification queries.
