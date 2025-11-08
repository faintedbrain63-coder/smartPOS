# SmartPOS v3.0.11 - Release Build Installation Guide

This directory contains **properly signed RELEASE builds** for both Android and iOS platforms.

## 📦 What's Included

### Android Builds (Release Mode - Signed)
Located in: `installer/android/`

1. **SmartPOS-v3.0.11-release.aab** (38.4 MB)
   - **Android App Bundle** - Optimized for Google Play Store
   - **This is the file you should upload to Google Play Console**
   - Signed with release keystore
   - Optimized size for faster downloads
   - Google Play will generate optimized APKs for each device

2. **SmartPOS-v3.0.11-release.apk** (74.8 MB)
   - **Android Package** - For direct installation
   - Signed with release keystore
   - Can be installed directly on Android devices
   - Useful for distribution outside Play Store

### iOS Build (Release Mode)
Located in: `installer/ios/`

1. **SmartPOS-v3.0.11-release.ipa** (94.3 MB)
   - **iOS App Package**
   - Built in release mode (not codesigned yet)
   - **Important**: Requires signing before distribution
   - See iOS installation instructions below

---

## 🤖 Android Installation

### For Google Play Store (Recommended)

1. Go to [Google Play Console](https://play.google.com/console)
2. Select your app or create a new app
3. Navigate to **Production** → **Create new release**
4. Upload the **SmartPOS-v3.0.11-release.aab** file
5. Follow the Play Console prompts to complete the release

**✅ This file is properly signed in RELEASE mode and will be accepted by Google Play Store**

### For Direct Installation (APK)

1. Enable "Install from Unknown Sources" on your Android device
2. Transfer **SmartPOS-v3.0.11-release.apk** to your device
3. Open the APK file and follow installation prompts
4. The app is signed and ready for production use

---

## 🍎 iOS Installation

The iOS build requires additional steps for App Store distribution:

### Option 1: Upload to App Store (Recommended)

1. Open **Xcode** on your Mac
2. Open the project: `ios/Runner.xcworkspace`
3. Select **Product** → **Archive**
4. Once archived, the Organizer window will open
5. Select the archive and click **Distribute App**
6. Choose **App Store Connect**
7. Follow the prompts to upload to App Store Connect
8. Complete the release process in [App Store Connect](https://appstoreconnect.apple.com)

### Option 2: TestFlight Distribution

1. Follow the same steps as App Store upload
2. In **Distribute App**, choose **TestFlight**
3. Upload to App Store Connect
4. Add testers in App Store Connect

### Option 3: Enterprise/Ad-Hoc Distribution

If you have an Enterprise account or want to distribute to specific devices:

1. Open Xcode and archive the project
2. Choose **Ad Hoc** or **Enterprise** distribution
3. Sign with your distribution certificate
4. Export the signed IPA
5. Distribute via your preferred method (MDM, direct installation, etc.)

**Note**: The provided IPA file is built in release mode but not yet signed. You must sign it through Xcode or use Xcode to create a properly signed distribution build.

---

## 🔐 Build Details

### Android Signing Information
- **Keystore**: `smartpos-release-key.jks`
- **Key Alias**: smartpos-key-alias
- **Signing Config**: Configured in `android/app/build.gradle.kts`
- **Build Mode**: RELEASE (not debug)

### iOS Build Information
- **Bundle ID**: com.smartpos.smartPos
- **Build Mode**: RELEASE
- **Signing**: Not codesigned (requires signing in Xcode)

### App Version
- **Version**: 3.0.11
- **Build Number**: 1

---

## 🚀 Verification

### To verify Android builds are in release mode:
```bash
# Extract and check
unzip -l SmartPOS-v3.0.11-release.aab
# Should NOT contain any files in 'debug' directories
```

### To verify iOS build:
- The build was created with `--release` flag
- No debug symbols included
- Optimized for production

---

## 📝 Build Commands Used

These builds were created using the following commands:

```bash
# Clean previous builds
flutter clean

# Android App Bundle (for Play Store)
flutter build appbundle --release

# Android APK (for direct installation)
flutter build apk --release

# iOS App (requires signing in Xcode)
flutter build ios --release --no-codesign
```

---

## ⚠️ Important Notes

1. **Google Play Store**: Always upload the `.aab` file, not the `.apk`
2. **iOS App Store**: The IPA needs to be signed through Xcode before submission
3. **Versioning**: Both platforms use version 3.0.11 (build 1)
4. **Release Mode**: All builds are in RELEASE mode, not DEBUG mode
5. **Production Ready**: These builds are optimized and ready for production use

---

## 🆘 Troubleshooting

### "App not signed properly" error on Google Play
- This should NOT happen with these builds
- They are properly signed with the release keystore
- If you see this, verify you're uploading the `.aab` file from this directory

### iOS signing issues
- Make sure your Apple Developer account is active
- Verify your signing certificates in Xcode
- Check provisioning profiles are up to date

### Build verification
- Android builds can be verified with: `keytool -printcert -jarfile [filename]`
- Both builds were created after a `flutter clean` to ensure fresh compilation

---

## 📞 Support

For build issues or questions:
1. Check the main project README.md
2. Review Flutter documentation: https://docs.flutter.dev/deployment
3. Android deployment: https://docs.flutter.dev/deployment/android
4. iOS deployment: https://docs.flutter.dev/deployment/ios

---

**Built on**: November 7, 2025
**Flutter SDK**: Version as specified in project
**Build Type**: Production Release
**Debug Mode**: ❌ Disabled
**Release Mode**: ✅ Enabled

