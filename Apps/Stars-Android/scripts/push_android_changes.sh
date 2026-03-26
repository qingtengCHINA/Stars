#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../../.." && pwd)"
branch="$(git -C "$repo_root" branch --show-current)"

do_commit=0
do_push=0
deindex_noise=0
with_apks=0
commit_message=""

usage() {
  cat <<'EOF'
Usage:
  ./Apps/Stars-Android/scripts/push_android_changes.sh [--deindex-noise] [--with-apks] [--commit "message"] [--push]

Behavior:
  - stages only the Android project source/config/resources by default
  - APK files are staged only when --with-apks is passed
  - never stages .gradle/ or app/build/ intermediates
  - optionally removes already-tracked build noise from the index with --deindex-noise

Examples:
  ./Apps/Stars-Android/scripts/push_android_changes.sh
  ./Apps/Stars-Android/scripts/push_android_changes.sh --with-apks --commit "Android parity round" --push
  ./Apps/Stars-Android/scripts/push_android_changes.sh --deindex-noise --commit "Android parity round" --push
EOF
}

while (($# > 0)); do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --push)
      do_push=1
      shift
      ;;
    --deindex-noise)
      deindex_noise=1
      shift
      ;;
    --with-apks)
      with_apks=1
      shift
      ;;
    --commit)
      if (($# < 2)); then
        echo "--commit requires a message" >&2
        exit 1
      fi
      do_commit=1
      commit_message="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

allowed_paths=(
  "Apps/Stars-Android/.gitignore"
  "Apps/Stars-Android/build.gradle.kts"
  "Apps/Stars-Android/gradle.properties"
  "Apps/Stars-Android/gradlew"
  "Apps/Stars-Android/gradlew.bat"
  "Apps/Stars-Android/settings.gradle.kts"
  "Apps/Stars-Android/app/build.gradle.kts"
  "Apps/Stars-Android/app/proguard-rules.pro"
  "Apps/Stars-Android/app/src"
  "Apps/Stars-Android/scripts"
)

if ((with_apks)); then
  allowed_paths+=(
    "Apps/Stars-Android/Stars-debug.apk"
    "Apps/Stars-Android/Stars-release.apk"
  )
fi

if ((deindex_noise)); then
  git -C "$repo_root" rm -r --cached --ignore-unmatch \
    "Apps/Stars-Android/.gradle" \
    "Apps/Stars-Android/.gradle-home" \
    "Apps/Stars-Android/build" \
    "Apps/Stars-Android/app/build" \
    "Apps/Stars-Android/.idea" \
    "Apps/Stars-Android/local.properties"
fi

git -C "$repo_root" add --all -- "${allowed_paths[@]}"

echo
echo "Staged Android paths:"
git -C "$repo_root" status --short -- "${allowed_paths[@]}"

if ((do_commit)); then
  git -C "$repo_root" commit -m "$commit_message"
fi

if ((do_push)); then
  git -C "$repo_root" push origin "$branch"
fi
