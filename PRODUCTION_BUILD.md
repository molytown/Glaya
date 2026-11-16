# Glaya Mobile App - Production Build Guide

## Overview
The Glaya mobile app is now configured for production deployment with the following changes:

### Configuration Changes
1. **ConfigService** - Hardcoded to use production API endpoints:
   - API Base URL: `https://api.glaya.space/api/v1`
   - Socket URL: `https://api.glaya.space`
   - Removed all localhost/development fallbacks
   - Removed Android emulator IP (10.0.2.2) references

2. **Google Maps API Key** - Removed hardcoded keys:
   - Removed from `AndroidManifest.xml`
   - Removed from `AppDelegate.swift`
   - Key is now loaded dynamically from backend at `/config/google-maps-api-key`

3. **Android Build Configuration**:
   - Enabled code minification (`isMinifyEnabled = true`)
   - Enabled resource shrinking (`isShrinkResources = true`)
   - Added ProGuard rules for Flutter, Firebase, Dio, Socket.IO, and Stripe

## Prerequisites

### Android
1. **Keystore Setup**:
   - Create a keystore file for signing the release APK/AAB
   - Create `android/key.properties` with:
     ```
     storeFile=path/to/your/keystore.jks
     storePassword=your_keystore_password
     keyAlias=your_key_alias
     keyPassword=your_key_password
     ```

2. **Build Commands**:
   ```bash
   # Build APK
   flutter build apk --release

   # Build App Bundle (recommended for Play Store)
   flutter build appbundle --release
   ```

### iOS
1. **Apple Developer Account**:
   - Required for App Store distribution
   - Configure Bundle Identifier in Xcode

2. **Build Commands**:
   ```bash
   # Build for iOS
   flutter build ios --release

   # Then open in Xcode for archive and upload
   open ios/Runner.xcworkspace
   ```

## Testing Before Release

1. **Test on Real Devices**:
   - Test API connectivity with production backend
   - Verify Google Maps functionality
   - Test Socket.IO real-time features
   - Verify push notifications
   - Test all core features (booking, chat, payments)

2. **Performance Testing**:
   - Test on slow network conditions
   - Verify app startup time
   - Check memory usage

## Environment Variables

The app no longer uses any hardcoded API URLs. All configuration is loaded from the production backend at startup.

## Security Notes

- The Google Maps API key is loaded from the backend, not hardcoded
- All API calls use HTTPS
- Tokens are stored securely using flutter_secure_storage
- ProGuard/R8 obfuscation is enabled for Android

## Deployment Checklist

- [ ] Keystore configured (Android)
- [ ] Apple Developer account configured (iOS)
- [ ] Test all features on production API
- [ ] Verify push notifications work
- [ ] Test on multiple device sizes
- [ ] Check app icon and splash screen
- [ ] Verify permissions are correctly requested
- [ ] Test payment flow (Stripe)
- [ ] Verify location services work correctly
- [ ] Test camera and image upload features
- [ ] Check background notification handling

## Post-Deployment

1. **Monitor Firebase Crashlytics** for crashes
2. **Monitor Firebase Analytics** for user behavior
3. **Check backend logs** for API errors
4. **Review user feedback** in app stores
