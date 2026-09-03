# Shared SSH Key Picker

**Status:** To do — filed 2026-08-14 during SSH-credential-slice review
**Scope:** The connection form's "Use a glas.sh credential" menu covers password credentials only. Key-auth glas.sh connections (e.g. a favorited bastion using an Ed25519 key) are correctly absent from the password picker — but the shared App Group `StoredSSHKey` catalog already exists, dual-written by both apps, so an equivalent picker on the SSH-Key auth path is buildable with existing plumbing.

## Direction

When Authentication is "SSH Key," offer the shared key catalog (names + algorithm, never key material) alongside glassdb's own keys. Respect storage-kind constraints: Secure Enclave-wrapped keys are device-bound and app-private by design — list only keys whose storage kind is eligible for cross-app use.

## Related gap (endpoint-index dependency)

Password credentials stored only under canonical `ssh:<uuid>` accounts cannot be listed with an identity (the account string carries none) — connection names live in the owning app's private store. The complete fix for both naming ("which machine is this?") and UUID-account coverage is the approved My Connections / GlassConnectionKit neutral endpoint index; this picker is its concrete consumer.
