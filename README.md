# Wake Up In Time

A Flutter iOS/Android wake-up app with a pose-detection challenge: the alarm is dismissed after 15 detected push-ups, or after entering a random 20-digit emergency code.

Licensed under the [MIT License](LICENSE).

## Run

Install Flutter, then run:

```powershell
flutter create .
flutter pub get
flutter run
```

Run `flutter create .` once to generate the platform project files missing from this source-only starter. It preserves `lib/main.dart`, `pubspec.yaml`, `ios/Runner/Info.plist`, and the Android manifest.

## iOS requirements

- Use iOS 15.5+ and Xcode 15.3+ because the pose detector requires them.
- In `ios/Podfile`, set `platform :ios, '15.5'` and exclude `armv7` as required by the ML Kit plugin.
- Local notifications can sound at the scheduled time, but iOS cannot force an app into the foreground or prevent a user from silencing a notification. Tapping the notification opens the app; the in-app challenge then controls dismissal of this app's scheduled notification.
- iOS only plays notification audio for about 30 seconds. A production alarm needs an approved `UNNotificationSound` custom sound file in the app bundle, subject to that system limit.

## Ringtones

The setup screen exposes ringtone selection. The starter currently schedules the iOS system notification sound. To ship distinct tones, add short `.aiff`, `.wav`, or `.caf` files to the iOS app bundle and map each picker choice to `DarwinNotificationDetails(sound: ...)`.

## Pose counter

The detector counts a down/up cycle from the nose-to-shoulder vertical distance. It is a usable starting point rather than a certified exercise counter: test it on target devices and tune the thresholds for the intended phone placement and camera framing.

## GitHub Actions IPA build

The workflow at `.github/workflows/ios-ipa.yml` creates a signed release IPA on `main`, version tags, or manual dispatch. Add these repository Actions secrets before running it:

- `BUILD_CERTIFICATE_BASE64`: base64-encoded Apple Distribution `.p12` certificate.
- `P12_PASSWORD`: password used to export that certificate.
- `BUILD_PROVISION_PROFILE_BASE64`: base64-encoded App Store, Ad Hoc, or Development provisioning profile.
- `KEYCHAIN_PASSWORD`: a random CI-only keychain password.
- `EXPORT_OPTIONS_PLIST_BASE64`: base64-encoded export options plist matching the profile and distribution method.

The IPA is retained as the `wakeup-in-time-ipa` Actions artifact. Never commit certificates, provisioning profiles, export files containing team data, or API keys.
