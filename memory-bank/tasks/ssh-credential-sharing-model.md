# SSH Credential Sharing Model in the Connection Form

**Status:** To do — specced and human-confirmed 2026-08-13; not started
**Discovered by:** Human review of the Add/Edit Connection form
**Scope:** Invert the sharing surface: database passwords are never shared with glas.sh; SSH credentials are the shareable class, selectable from the glas.sh catalog or entered manually with an explicit share opt-in.

## Problem

The connection form currently offers "Shared with glas.sh" as a **database** Password-storage option, while **SSH password storage** reads "glassdb only". This is backwards: glas.sh has no use for database credentials, and the SSH tunnel identity is exactly what the two apps can hold in common.

## Confirmed direction (2026-08-13)

1. **Database password storage** drops "Shared with glas.sh" entirely; remaining options are the glassdb-private policies ("glassdb only", "Require authentication").
2. **SSH credentials** gain two paths in the form:
   - **Choose from glas.sh** — a menu of existing shared glas.sh SSH credentials from the shared Keychain/App Group catalog, so a tunnel reuses an identity glas.sh already owns;
   - **Enter manually** — with a "Share with glas.sh" checkbox at creation that publishes the glas.sh-compatible record through the existing atomic dual-write/rollback contract.
3. **No migration required** — no users exist; existing saved data may be normalized freely and any orphaned shared database-password records cleaned up.

## Reuse analysis

No new sharing plumbing: GlasSecretStore's canonical UUID accounts, the App Group SSH metadata catalog, and the atomic dual-write with rollback already exist and are regression-tested. The work re-points the UI and policy surface (ConnectionFormView storage pickers, credential-policy plumbing) at the correct credential class, and adds catalog *read* for the picker — aligned with the approved My Connections program's GlasSecretStore credential-catalog direction.

## Acceptance sketch

- The database Password-storage picker never offers cross-app sharing; SSH offers catalog selection and share-on-create.
- Selecting a glas.sh catalog credential creates no duplicate secret; manual entry with the checkbox publishes both records atomically with rollback on partial failure.
- Existing SSH isolation regressions (no DB-password fallback into SSH, separate authentication domains) stay green; add focused coverage for the picker and the opt-in path.
