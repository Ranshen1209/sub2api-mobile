# Sakrylle Admin for Android

Native Android client built with Jetpack Compose and Material Design 3. It mirrors the iOS navigation and page hierarchy: Overview, Users, Status, Servers, User Detail, Accounts, and Groups. User creation, balance and status changes, account creation, account testing, and scheduling controls are included.

## Build

Android Studio's bundled JDK and Android SDK 36 are supported.

```sh
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew testDebugUnitTest assembleDebug
```

The debug APK is written to `app/build/outputs/apk/debug/app-debug.apk`.

Server profiles and Admin Keys are encrypted with a key backed by Android Keystore. Cleartext HTTP is allowed for local/self-hosted admin endpoints; HTTPS remains recommended for deployed servers.
