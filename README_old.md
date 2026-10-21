# StreamBox Flutter Android App

A Flutter Android video gallery using the Eporner video search API directly.
No custom backend is required.

## Features
- Search
- Sort: Top Weekly, Latest, Most Popular, Top Rated, Longest, Shortest
- Responsive two-column video grid
- Thumbnail, title, duration and views
- Infinite scroll pagination and pull-to-refresh
- Opens provider video pages in the external browser
- Loading, empty and error states

## Requirements
- Flutter SDK (stable)
- Android SDK / Android Studio or command-line SDK tools
- Internet connection

## Build APK
From this project directory:

```bash
flutter pub get
flutter doctor
flutter build apk --release
```

APK output:
`build/app/outputs/flutter-apk/app-release.apk`

For a universal APK use `flutter build apk --release`.
For smaller device-specific APKs use `flutter build apk --split-per-abi`.

## Notes
- This app consumes the provider API directly. Availability and response fields depend on the provider.
- Confirm the provider's API terms and applicable laws before distribution.
- Before publishing, add age-appropriate access controls and store-compliant content safeguards.
- For a Play Store release, configure app signing and review Google Play policies.
