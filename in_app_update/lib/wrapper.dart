import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:jni/jni.dart' as jni;

import 'src/bindings.g.dart';

/// High-level wrapper that hides direct JNI usage from Flutter apps.
class PlayInAppUpdate {
  PlayInAppUpdate._(this._manager, this._engineId);

  final AppUpdateManager _manager;
  final int? _engineId;
  AppUpdateInfo? _lastInfo;
  InstallStateUpdatedListenerProxy? _stateListenerProxy;
  InstallStateUpdatedListenerProxy$InstallStateCallbackInterface? _stateCallback;

  /// Creates a wrapper by obtaining the Android application context.
  static Future<PlayInAppUpdate> create({int? engineId}) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('play_in_app_update only works on Android');
    }

    final context = jni.Jni.androidApplicationContext;

    final manager = AppUpdateManagerFactory.create(context);
    return PlayInAppUpdate._(manager, engineId ?? PlatformDispatcher.instance.engineId);
  }

  /// Checks Play Core for update availability and caches the info for later flows.
  Future<InAppUpdateInfo> checkForUpdate() async {
    final info = await _awaitTask<AppUpdateInfo?, AppUpdateInfo>(
      _manager.getAppUpdateInfo(),
      op: 'getAppUpdateInfo',
      transform: (value) => value!,
    );

    if (info == null) {
      throw StateError('AppUpdateInfo is null');
    }

    final nonNullInfo = info;

    _lastInfo?.release();
    _lastInfo = nonNullInfo;

    return _mapInfo(nonNullInfo);
  }

  /// Starts the FLEXIBLE update flow and reports state changes.
  Future<void> startFlexibleUpdate({InstallStateCallback? onState}) async {
    final info = await _ensureInfo();
    if (!info.isFlexibleAllowed) {
      throw StateError('Flexible updates are not allowed for this app version');
    }

    _stateCallback = InstallStateUpdatedListenerProxy$InstallStateCallbackInterface.implement(
      $InstallStateUpdatedListenerProxy$InstallStateCallbackInterface(
        onStateUpdate$async: true,
        onStateUpdate: (state) {
          final snapshot = _mapInstallState(state);
          state.release();
          onState?.call(snapshot);
        },
      ),
    );

    final proxy = InstallStateUpdatedListenerProxy(_stateCallback!);
    _registerStateListener(proxy);

    final task = _manager.startUpdateFlow(
      _lastInfo!,
      _requireActivity(),
      AppUpdateOptions.newBuilder(AppUpdateType.FLEXIBLE) //
          .setAllowAssetPackDeletion(true)
          .build(),
    );

    if (task == null) {
      throw StateError('startUpdateFlow returned null');
    }

    await _awaitTask<jni.JInteger?, void>(task, op: 'startUpdateFlow');
  }

  /// Starts the IMMEDIATE update flow.
  Future<void> startImmediateUpdate() async {
    final info = await _ensureInfo();
    if (!info.isImmediateAllowed) {
      throw StateError('Immediate updates are not allowed for this app version');
    }

    final task = _manager.startUpdateFlow(
      _lastInfo!,
      _requireActivity(),
      AppUpdateOptions.newBuilder(AppUpdateType.IMMEDIATE).setAllowAssetPackDeletion(true).build(),
    );

    if (task == null) {
      throw StateError('startUpdateFlow returned null');
    }

    await _awaitTask<jni.JInteger?, void>(task, op: 'startUpdateFlow');
  }

  /// Completes a previously downloaded FLEXIBLE update.
  Future<void> completeFlexibleUpdate() async {
    await _awaitTask<jni.JObject?, void>(
      _manager.completeUpdate(),
      op: 'completeUpdate',
    );
  }

  /// Releases native resources. Call from `dispose` in your widgets.
  void dispose() {
    _unregisterStateListener();
    _lastInfo?.release();
    _manager.release();
  }

  Future<InAppUpdateInfo> _ensureInfo() async {
    if (_lastInfo == null) {
      return checkForUpdate();
    }
    return _mapInfo(_lastInfo!);
  }

  jni.JObject _requireActivity() {
    final id = _engineId ?? PlatformDispatcher.instance.engineId;
    if (id == null) {
      throw StateError('Flutter engineId is null; ensure WidgetsFlutterBinding is initialized');
    }

    final activity = jni.Jni.androidActivity(id);
    if (activity == null) {
      throw StateError('Android Activity is null');
    }
    return activity;
  }

  void _registerStateListener(InstallStateUpdatedListenerProxy listener) {
    _unregisterStateListener();
    _stateListenerProxy = listener;
    _manager.registerListener(listener.as(InstallStateUpdatedListener.type));
  }

  void _unregisterStateListener() {
    if (_stateListenerProxy != null) {
      _manager.unregisterListener(_stateListenerProxy!.as(InstallStateUpdatedListener.type));
      _stateListenerProxy!.release();
      _stateListenerProxy = null;
    }

    _stateCallback?.release();
    _stateCallback = null;
  }

  InAppUpdateInfo _mapInfo(AppUpdateInfo info) {
    final stalenessObj = info.clientVersionStalenessDays();
    final stalenessDays = stalenessObj?.intValue();
    stalenessObj?.release();

    final packageName = info.packageName();
    final name = packageName.toDartString(releaseOriginal: true);

    return InAppUpdateInfo(
      availability: _mapAvailability(info.updateAvailability()),
      installStatus: _mapInstallStatus(info.installStatus()),
      clientVersionStalenessDays: stalenessDays,
      updatePriority: info.updatePriority(),
      availableVersionCode: info.availableVersionCode(),
      bytesDownloaded: info.bytesDownloaded(),
      totalBytesToDownload: info.totalBytesToDownload(),
      packageName: name,
      isImmediateAllowed: info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE),
      isFlexibleAllowed: info.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE),
    );
  }

  InstallStateSnapshot _mapInstallState(InstallState state) {
    final bytes = state.bytesDownloaded();
    final total = state.totalBytesToDownload();
    final percent = total > 0 ? bytes / total : null;

    return InstallStateSnapshot(
      status: _mapInstallStatus(state.installStatus()),
      bytesDownloaded: bytes,
      totalBytesToDownload: total,
      fractionDownloaded: percent,
      installErrorCode: state.installErrorCode(),
    );
  }

  InAppInstallStatus _mapInstallStatus(int value) {
    switch (value) {
      case InstallStatus.PENDING:
        return InAppInstallStatus.pending;
      case InstallStatus.DOWNLOADING:
        return InAppInstallStatus.downloading;
      case InstallStatus.DOWNLOADED:
        return InAppInstallStatus.downloaded;
      case InstallStatus.INSTALLING:
        return InAppInstallStatus.installing;
      case InstallStatus.INSTALLED:
        return InAppInstallStatus.installed;
      case InstallStatus.FAILED:
        return InAppInstallStatus.failed;
      case InstallStatus.CANCELED:
        return InAppInstallStatus.canceled;
      case InstallStatus.REQUIRES_UI_INTENT:
        return InAppInstallStatus.requiresUiIntent;
      case InstallStatus.UNKNOWN:
      default:
        return InAppInstallStatus.unknown;
    }
  }

  InAppUpdateAvailability _mapAvailability(int value) {
    switch (value) {
      case UpdateAvailability.UPDATE_AVAILABLE:
        return InAppUpdateAvailability.updateAvailable;
      case UpdateAvailability.UPDATE_NOT_AVAILABLE:
        return InAppUpdateAvailability.updateNotAvailable;
      case UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS:
        return InAppUpdateAvailability.developerTriggeredInProgress;
      case UpdateAvailability.UNKNOWN:
      default:
        return InAppUpdateAvailability.unknown;
    }
  }

  Future<R?> _awaitTask<TResult extends jni.JObject?, R>(
    Task<TResult> task, {
    required String op,
    R Function(TResult? value)? transform,
  }) async {
    final completer = Completer<R?>();

    final success = OnSuccessListener.implement(
      $OnSuccessListener<TResult>(
        TResult: task.TResult,
        onSuccess$async: true,
        onSuccess: (value) {
          try {
            if (transform != null) {
              completer.complete(transform(value));
            } else {
              completer.complete(value as R?);
            }
          } catch (e, st) {
            completer.completeError(e, st);
          }
        },
      ),
    );

    final failure = OnFailureListener.implement(
      $OnFailureListener(
        onFailure$async: true,
        onFailure: (exception) => completer.completeError(StateError('$op failed: $exception')),
      ),
    );

    final canceled = OnCanceledListener.implement(
      $OnCanceledListener(
        onCanceled$async: true,
        onCanceled: () => completer.completeError(StateError('$op was canceled')),
      ),
    );

    task.addOnSuccessListener(success);
    task.addOnFailureListener(failure);
    task.addOnCanceledListener(canceled);

    try {
      return await completer.future;
    } finally {
      success.release();
      failure.release();
      canceled.release();
      task.release();
    }
  }
}

/// Summary of the current update info returned by Play Core.
class InAppUpdateInfo {
  InAppUpdateInfo({
    required this.availability,
    required this.installStatus,
    required this.clientVersionStalenessDays,
    required this.updatePriority,
    required this.availableVersionCode,
    required this.bytesDownloaded,
    required this.totalBytesToDownload,
    required this.packageName,
    required this.isImmediateAllowed,
    required this.isFlexibleAllowed,
  });

  final InAppUpdateAvailability availability;
  final InAppInstallStatus installStatus;
  final int? clientVersionStalenessDays;
  final int updatePriority;
  final int availableVersionCode;
  final int bytesDownloaded;
  final int totalBytesToDownload;
  final String packageName;
  final bool isImmediateAllowed;
  final bool isFlexibleAllowed;

  bool get isUpdateAvailable => availability == InAppUpdateAvailability.updateAvailable;
  bool get isDownloaded => installStatus == InAppInstallStatus.downloaded;
}

/// Snapshot of install state emitted during FLEXIBLE updates.
class InstallStateSnapshot {
  InstallStateSnapshot({
    required this.status,
    required this.bytesDownloaded,
    required this.totalBytesToDownload,
    required this.fractionDownloaded,
    required this.installErrorCode,
  });

  final InAppInstallStatus status;
  final int bytesDownloaded;
  final int totalBytesToDownload;
  final double? fractionDownloaded;
  final int installErrorCode;

  double get percent => fractionDownloaded == null ? 0 : fractionDownloaded! * 100;
}

enum InAppUpdateAvailability {
  unknown,
  updateNotAvailable,
  updateAvailable,
  developerTriggeredInProgress,
}

enum InAppInstallStatus {
  unknown,
  requiresUiIntent,
  pending,
  downloading,
  downloaded,
  installing,
  installed,
  failed,
  canceled,
}

typedef InstallStateCallback = void Function(InstallStateSnapshot state);
