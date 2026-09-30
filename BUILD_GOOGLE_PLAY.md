# AAB для Google Play

Из каталога `autoterra`:

```bash
./scripts/build_google_play_aab.sh
```

Готовый подписанный файл:
`build/app/outputs/bundle/release/app-release.aab`.

Используется `android/app/autoterra-upload.jks` с настройками из
`android/key.properties` и API `https://autoterra.shop/api/`.
Ключи ЮKassa остаются на сервере, в сборку их передавать не нужно.

Номер версии берётся из `pubspec.yaml`. Если этот versionCode уже использован
в Google Play, задайте следующий свободный номер, например:

```bash
BUILD_NUMBER=3 ./scripts/build_google_play_aab.sh
```

Для другого сервера можно задать `API_BASE_URL=https://ваш-домен/api/`.

Загрузите AAB в Google Play Console, сначала в канал внутреннего тестирования.
Для существующего приложения сертификат ключа загрузки должен соответствовать
зарегистрированному в Play Console. Подпись распространяемых через Google Play
APK управляется отдельно через Play App Signing.

Официальные инструкции:
- https://docs.flutter.dev/deployment/android
- https://developer.android.com/studio/publish/app-signing

Сборка AAB не заменяет настройку серверных ключей/чеков и проверку реальной оплаты.

Проверочная сборка выполнена: AAB размером 61.9 МБ, версия из `pubspec.yaml`
`1.0.0+2`. Проверены целостность архива, цифровая подпись и совпадение
сертификата с `autoterra-upload.jks`. В Play Console файл не загружался.
