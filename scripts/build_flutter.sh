#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# Navigate to the Android directory
cd "$(dirname "$0")/../android"

# Execute Gradle build with specified parameters
./gradlew \
  --parallel \
  -Pverbose=true \
  -Ptarget-platform=android-x86 \
  -Ptarget="${HOME}/myapp/lib/main.dart" \
  -Pbase-application-name=android.app.Application \
  -Pdart-defines=RkxVVFRFUl9XRUJfQ0FOVkFTS0lUX1VSTD1odHRwczovL3d3dy5nc3RhdGljLmNvbS9mbHV0dGVyLWNhbnZhc2tpdC85NzU1MDkwN2I3MGY0ZjNiMzI4YjZjMTYwMGRmMjFmYWMxYTE4ODlhLw== \
  -Pdart-obfuscation=false \
  -Ptrack-widget-creation=true \
  -Ptree-shake-icons=false \
  -Pfilesystem-scheme=org-dartlang-root \
  assembleDebug

# TODO: Execute web build in debug mode
# Example:
# flutter build web --profile --dart-define=Dart2jsOptimization=O0
