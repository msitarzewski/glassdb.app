# Product Context

## Target User
Developers and DBAs who want native database management across Vision Pro, Mac,
iPad, and iPhone without rebuilding their SSH access in every Glass app.

## Market
Zero native visionOS database clients exist. Existing options (SQLPro Studio, TablePlus, etc.) are iPad compatibility-mode apps with no glass materials, no ornaments, no spatial UX.

## Distribution
- App Store: $10 one-time purchase
- GitHub: Open source (compile yourself)

## Brand
Part of the "glas" family alongside glas.sh. Recognizable glass-first aesthetic.

## Magic / First Class Experience

- The user-facing model is **My Connections**: an SSH connection defined in one
  Glass app is available to the other apps and supported Apple devices according
  to its sharing and credential-mobility policy.
- Canonical journey: define an eligible SSH connection in glas.sh on iPhone, open
  glassdb on Vision Pro, choose that connection as the tunnel for a database, and
  connect without re-entering endpoint or credential data.
- Normal UI describes outcomes—**Ready**, **Still Syncing**, **Sign In to iCloud**,
  **Set Up This Key**, or **Review Fingerprint**—instead of CloudKit, Keychain
  access groups, packages, records, or migrations.
- No proprietary Glass account is required. Apple iCloud/Keychain services and
  explicit consent govern eligible credential mobility.
- Security prompts remain truthful. Host trust, user presence, optional-network
  authorization, and device-bound Secure Enclave enrollment interrupt the flow
  only when their real boundary requires user action.
