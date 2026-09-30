# Сборка APK для RuStore

Из каталога Flutter-приложения `autoterra` выполните:

```bash
./scripts/build_rustore_apk.sh
```

Скрипт собирает подписанный release APK с сервером `https://autoterra.shop/api/`.
Готовый файл: `build/app/outputs/flutter-apk/app-release.apk`.

Подпись уже настроена: ключ находится в `android/app/autoterra-upload.jks`,
а `android/key.properties` содержит `storeFile=autoterra-upload.jks`.
Пароли и alias сохранены из существующих настроек. Эти два файла исключены
из Git; при переносе проекта на другой компьютер перенесите их отдельно.
Новый ключ для каждого обновления создавать не нужно.

Сейчас номер сборки берётся из `pubspec.yaml`. Для следующего обновления задайте
номер выше последнего загруженного в RuStore, например:

```bash
BUILD_NUMBER=3 ./scripts/build_rustore_apk.sh
```

Когда будет известен адрес карточки RuStore, его можно добавить в приглашения:

```bash
RUSTORE_APP_URL=https://www.rustore.ru/catalog/app/ВАШ_ПАКЕТ BUILD_NUMBER=3 ./scripts/build_rustore_apk.sh
```

Замените URL реальным адресом карточки. Без этого параметра приглашение содержит
ссылку регистрации и реферальный код; ссылки на Google Play нет.

Для отдельного тестового сервера:

```bash
API_BASE_URL=https://ВАШ_ТЕСТОВЫЙ_ДОМЕН/api/ ./scripts/build_rustore_apk.sh
```

Ключи ЮKassa в сборку не передавайте — они задаются только на бэкенде.
Успешная сборка APK не заменяет настройку сервера, чеков и проверку оплаты.
Перед публикацией установите release APK на телефон и проверьте вход,
заказ, оплату и возвращение в приложение.

Проверено: release APK успешно собран, подпись APK совпадает с сертификатом
`android/app/autoterra-upload.jks`. Пакет `com.autoterra.autoterra`, версия
`1.0.0`, versionCode `2`, размер около 64.6 МБ. Анализ изменённых Dart-файлов
прошёл без замечаний. При следующей публикации увеличьте BUILD_NUMBER, если
версия с номером 2 уже загружена в RuStore.
