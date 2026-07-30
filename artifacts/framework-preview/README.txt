FRAMEWORK PREVIEW — NOT A DEPLOYABLE PRODUCT
=============================================

This directory contains framework preview artifacts generated during
project scaffolding. These are NOT valid deployment bundles:

  - txsql-offline-8.0.30-1.0.0-all-supported-platforms.tar.gz
    → 26KB, contains 0 TXSQL platform payloads
    → payloads/ directory is empty
    → Will NOT install on any platform
    → Generated for framework validation only

Real deployment bundles will appear in dist/ when:
  1. TXSQL source is available and built
  2. Real RPMs are produced
  3. Full dependency closure is computed and verified
  4. At least one platform passes all 25 acceptance tests
  5. That platform is marked SUPPORTED in PLATFORM_MATRIX

Until then, all files in this directory are framework artifacts only.
