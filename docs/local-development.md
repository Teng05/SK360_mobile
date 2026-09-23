# API connection

The app defaults to `https://sk360lipacity.org/api/mobile`. A normal build uses
the live server without additional configuration.

For local testing in an Android Emulator, start Laravel on your development
computer and run:

```powershell
flutter run -d emulator-5554 --dart-define=SK360_API_BASE_URL=http://10.0.2.2:8000/api/mobile
```

`10.0.2.2` reaches the development computer's localhost from the Android
Emulator. For a physical phone, use the computer's current LAN address and run
Laravel on an interface reachable from the phone. Both devices must be on the
same network. For example, from the backend directory:

```powershell
php artisan serve --host=0.0.0.0 --port=8000
```

From the mobile project, supply the appropriate API address:

```powershell
flutter run --dart-define=SK360_API_BASE_URL=http://192.168.1.41:8000/api/mobile
```

The LAN address above is an example and can change.
Use the full URL ending in `/api/mobile`, without a trailing slash.
Restart `flutter run` after changing a `--dart-define` value.

A timeout means the configured server did not respond in time. Check the
server address and listener before increasing the request timeout. A quick
read-only check is `GET /api/mobile/barangays` on the configured server.
