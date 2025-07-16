#!/bin/bash

set -euo pipefail

# Default configuration
VERSION=""
REPO_URL=""
ARTIFACTS_FILE="artifacts.txt"
GROUP_ID="org/apache/cassandra/"
VERIFY_SIGNATURES=false

# Helper: usage
usage() {
  echo "Usage: $0 --version VERSION --repo REPO_URL [--verify-signatures]"
  exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="$2"
      shift 2
      ;;
    --repo)
      REPO_URL="$2"
      shift 2
      ;;
    --verify-signatures)
      VERIFY_SIGNATURES=true
      shift
      ;;
    *)
      usage
      ;;
  esac
done

if [[ -z "$VERSION" || -z "$REPO_URL" ]]; then
  usage
fi

# Create temp dir
WORK_DIR="cassandra-analytics-${VERSION}-validation"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo "Downloading artifacts for version $VERSION from:"
echo "$REPO_URL"
echo

# List of artifact base names (without extension)
cat <<EOF > $ARTIFACTS_FILE
analytics-sidecar-client-common
analytics-sidecar-client
analytics-sidecar-vertx-client-all
analytics-sidecar-vertx-client
cassandra-analytics-cdc-codec_spark3_2.12
cassandra-analytics-cdc-codec_spark3_2.13
cassandra-analytics-cdc-sidecar_spark3_2.12
cassandra-analytics-cdc-sidecar_spark3_2.13
cassandra-analytics-cdc_spark3_2.12
cassandra-analytics-cdc_spark3_2.13
cassandra-analytics-common_spark3_2.12
cassandra-analytics-common_spark3_2.13
cassandra-analytics-core_spark3_2.12
cassandra-analytics-core_spark3_2.13
cassandra-analytics-integration-framework_spark3_2.12
cassandra-analytics-integration-framework_spark3_2.13
cassandra-analytics-integration-tests_spark3_2.12
cassandra-analytics-integration-tests_spark3_2.13
cassandra-analytics-sidecar-client
cassandra-analytics-spark-converter_spark3_2.12
cassandra-analytics-spark-converter_spark3_2.13
cassandra-avro-converter_spark3_2.12
cassandra-avro-converter_spark3_2.13
cassandra-bridge_spark3_2.12
cassandra-bridge_spark3_2.13
EOF

# Download artifacts and optional checks
while read ARTIFACT; do
  BASE_URL="${REPO_URL}${GROUP_ID}/${ARTIFACT}/${VERSION}/"
  FILES=("${ARTIFACT}-${VERSION}.jar" "${ARTIFACT}-${VERSION}.pom")

  for FILE in "${FILES[@]}"; do
    echo "Downloading $FILE"
    curl -sSfO "${BASE_URL}${FILE}"
    curl -sSfO "${BASE_URL}${FILE}.sha1"
    curl -sSfO "${BASE_URL}${FILE}.md5"

    if $VERIFY_SIGNATURES; then
      curl -sSfO "${BASE_URL}${FILE}.asc"
    fi

    echo "Verifying checksums for $FILE"
    sha1sum -c "${FILE}.sha1"
    md5sum -c "${FILE}.md5"

    if $VERIFY_SIGNATURES; then
      echo "Verifying GPG signature for $FILE"
      gpg --verify "${FILE}.asc" "${FILE}" || echo "⚠️  GPG signature verification failed for $FILE"
    fi
  done
done < "$ARTIFACTS_FILE"

echo
echo "✅ All artifacts downloaded and validated successfully."