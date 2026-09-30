#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"

if ! command -v flutter >/dev/null 2>&1; then
  echo 'Flutter не найден. Добавьте flutter/bin в PATH.' >&2
  exit 1
fi
if [[ ! -f android/key.properties ]]; then
  echo 'Нужен android/key.properties с параметрами release-подписи.' >&2
  exit 1
fi
if [[ ! -f .env ]]; then
  # Flutter включает этот файл в assets; только публичная настройка API.
  printf '%s\n' 'API_BASE_URL=https://autoterra.shop/api/' > .env
fi

api_base_url="${API_BASE_URL:-https://autoterra.shop/api/}"
if [[ "$api_base_url" != https://* ]]; then
  echo 'Для release укажите API_BASE_URL с HTTPS.' >&2
  exit 1
fi

build_args=(--release "--dart-define=API_BASE_URL=$api_base_url")
if [[ -n "${BUILD_NUMBER:-}" ]]; then
  if [[ ! "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
    echo 'BUILD_NUMBER должен быть положительным целым числом.' >&2
    exit 1
  fi
  build_args+=("--build-number=$BUILD_NUMBER")
fi

flutter pub get
flutter build appbundle --no-pub "${build_args[@]}"
printf '\nAAB: %s/build/app/outputs/bundle/release/app-release.aab\n' "$project_dir"
