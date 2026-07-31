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

The workflow at `.github/workflows/ios-ipa.yml` creates an unsigned release IPA on `main`, version tags, or manual dispatch. It does not require Apple signing secrets and uploads `wakeup-in-time-unsigned-ipa` as an Actions artifact.

For standard iOS installation, build a signed IPA with an Apple Distribution certificate and provisioning profile. This workflow's output is specifically intended for a loader that supports unsigned apps, such as the user's LiveContainer setup.
