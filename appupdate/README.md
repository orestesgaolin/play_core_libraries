# AppUpdate

A Flutter plugin for implementing Google Play In-App Updates using JNI bindings to directly access the Google Play Core App Update API.

This is alternative plugin to [in_app_update](https://pub.dev/packages/in_app_update) which uses platform channels. This plugin uses JNI bindings generated with jnigen and exposes lower-level API, similar to the official Android library.

## Features

- **Flexible Updates**: Download updates in the background while users continue to use the app
- **Immediate Updates**: Force users to update before they can continue using the app
- **Update Availability Check**: Query Google Play to check if an app update is available
- **Progress Monitoring**: Track download and installation progress with real-time callbacks
- **Error Handling**: Handle update failures, cancellations, and various error states
- **Direct JNI Integration**: Uses JNI bindings for direct access to native Android APIs

## Platform Support

Currently supports:

- ✅ Android (API level 21+)
- ❌ iOS (In-App Updates are not available on iOS)

## Usage

### Basic Setup

See `example/lib/main.dart` for a complete example.

```dart
import 'package:appupdate/appupdate.dart';

// Initialize the App Update Manager
final engineId = PlatformDispatcher.instance.engineId;

final context = Jni.androidApplicationContext;
final manager = AppUpdateManagerFactory.create(context);

// Check for available updates
final appInfoTask = manager.getAppUpdateInfo();
```

### Flexible Update Flow

```dart
// Start a flexible update
final engineId = PlatformDispatcher.instance.engineId;
final activity = Jni.androidActivity(engineId);
final updateTask = manager.startUpdateFlow(
  appUpdateInfo,
  activity,
  AppUpdateOptions.newBuilder(AppUpdateType.FLEXIBLE)
    .setAllowAssetPackDeletion(true)
    .build(),
);

// Monitor installation progress
manager.registerListener(installStateListener);
```

### Immediate Update Flow

```dart
// Start an immediate update
final updateTask = manager.startUpdateFlow(
  appUpdateInfo,
  activity,
  AppUpdateOptions.newBuilder(AppUpdateType.IMMEDIATE)
    .setAllowAssetPackDeletion(true)
    .build(),
);
```

## Example

See the [example](example/lib/main.dart) for a complete implementation showing how to:

- Check for updates
- Handle both flexible and immediate update flows
- Monitor progress and handle errors
- Complete the installation process

## Technical Details

This plugin uses:

- **JNI (Java Native Interface)** for direct integration with Android APIs
- **jnigen** for generating Dart bindings from Java classes
- **Google Play Core App Update API** for the underlying update functionality

The plugin generates bindings for the following key classes:

- `AppUpdateManager` and `AppUpdateManagerFactory`
- `AppUpdateInfo` and `AppUpdateOptions`
- `InstallStateUpdatedListener` and related callback interfaces
- Various enums for update types, install status, and error codes

## Testing in-app updates with Google Play Internal App Sharing

To test in-app updates, you can use Google Play's Internal App Sharing feature. This allows you to upload your app and test updates without going through the full release process.

1. Enable Internal App Sharing in your Play Console.
2. Upload your app's APK or App Bundle built with this plugin.
3. Install the app from the above version.
4. Build and upload a new version with a higher version code.
5. Wait few minutes, you may need to open Google Play few times to see the update.
6. Open the app and trigger the update flow to test the in-app update functionality.

## Contributing

Contributions are welcome!

## License

See the [LICENSE](LICENSE) file for details.
