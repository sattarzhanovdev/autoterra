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
if [[ -n "${RUSTORE_APP_URL:-}" ]]; then
  if [[ "$RUSTORE_APP_URL" != https://www.rustore.ru/catalog/app/* && "$RUSTORE_APP_URL" != https://rustore.ru/catalog/app/* ]]; then
    echo 'RUSTORE_APP_URL должен быть HTTPS-адресом карточки RuStore.' >&2
    exit 1
  fi
  build_args+=("--dart-define=RUSTORE_APP_URL=$RUSTORE_APP_URL")
fi
if [[ -n "${BUILD_NUMBER:-}" ]]; then
  if [[ ! "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
    echo 'BUILD_NUMBER должен быть положительным целым числом.' >&2
    exit 1
  fi
  build_args+=("--build-number=$BUILD_NUMBER")
fi

flutter pub get
flutter build apk --no-pub "${build_args[@]}"
printf '\nAPK: %s/build/app/outputs/flutter-apk/app-release.apk\n' "$project_dir"
