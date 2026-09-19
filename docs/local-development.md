# Local API connection

The app defaults to `http://10.0.2.2:8000/api/mobile` for the Android Emulator.
`10.0.2.2` reaches the development computer's localhost, where Laravel can
listen on `127.0.0.1:8000`.

Start the existing Laravel backend before signing in, then run:

```powershell
flutter run -d emulator-5554
```

For a physical phone, use the computer's current LAN address and run Laravel
on an interface reachable from the phone. Both devices must be on the same
network. For example, from the backend directory:

```powershell
php artisan serve --host=0.0.0.0 --port=8000
```

From the mobile project, supply the appropriate API address:

```powershell
flutter run --dart-define=SK360_API_BASE_URL=http://192.168.1.41:8000/api/mobile
```

The LAN address above is an example for this workstation and can change.
For a deployed backend, supply its HTTPS API URL using the same define.
Use the full URL ending in `/api/mobile`, without a trailing slash.
Restart `flutter run` after changing a `--dart-define` value.

A timeout means the configured server did not respond in time. Check the
server address and listener before increasing the request timeout. A quick
read-only check is `GET /api/mobile/barangays` on the configured server.
