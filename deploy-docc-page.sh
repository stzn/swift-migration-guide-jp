#/usr/bin/env bash -euo pipefail

DOCC_COMMAND="/usr/bin/xcrun docc"
DOCC_ARCHIVE="Guide.doccarchive"

$DOCC_COMMAND convert Guide.docc \
  --fallback-display-name MigrationGuide \
  --fallback-bundle-identifier org.swift.MigrationGuide \
  --fallback-bundle-version 1 \
  --output-dir $DOCC_ARCHIVE

$DOCC_COMMAND process-archive transform-for-static-hosting \
  --output-path ./docs \
  --hosting-base-path swift-migration-guide-jp \
  $DOCC_ARCHIVE
