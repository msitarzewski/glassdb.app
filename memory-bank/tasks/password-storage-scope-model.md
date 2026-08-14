# Password Storage Scope Model (local / cloud / both)

**Status:** To do — needs semantics decision; raised 2026-08-14 during SSH-credential-slice review
**Scope:** Reframe the database password storage picker from app-sharing policies to storage *scope*.

## The ask (verbatim intent)

Michael: the database password storage picker "should simply be local/cloud/both" — no glas.sh prompt (that part shipped in the SSH credential slice; DB pickers now offer only private policies).

## Open questions before build

1. **Semantics of the three states.** Keychain-technically a synchronized item always also exists locally, so "cloud" and "both" collapse into one state unless "cloud" means something beyond iCloud Keychain (e.g. a future server-side vault). Proposed mapping: **Local** = device-only (today's behavior); **Cloud** = `kSecAttrSynchronizable` iCloud Keychain sync — which pulls the C3 eligible-secret cross-device program into scope.
2. **"Require authentication" placement** — it is a protection level orthogonal to storage scope. Options: independent toggle (user-presence secrets cannot sync, so checking it would force Local), a third picker entry, or dropped.
3. **Does the model extend to SSH manual storage** alongside the share-with-glas.sh toggle?

## Constraints already known

- Device-bound policies (user-presence, Secure Enclave) are intentionally non-synchronizable — any cloud scope excludes them by construction.
- C3 cross-device synchronization is an open Memory Bank program (same-device sharing only today); this task is likely its UI face.
- No users exist — no migration constraints.
