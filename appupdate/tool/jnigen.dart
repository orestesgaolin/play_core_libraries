import 'dart:io';

import 'package:jnigen/jnigen.dart';

void main(List<String> args) {
  final packageRoot = Platform.script.resolve('../');
  generateJniBindings(
    Config(
      outputConfig: OutputConfig(
        dartConfig: DartCodeOutputConfig(
          // Required. Output path for generated bindings.
          path: packageRoot.resolve('lib/src/bindings.g.dart'),
          // Optional. Write bindings into a single file (instead of one file per class).
          structure: OutputStructure.singleFile,
        ),
      ),
      // Optional. Configuration to search for Android SDK libraries.
      androidSdkConfig: AndroidSdkConfig(
        addGradleDeps: true,
        addGradleSources: true,
        androidExample: 'example/',
      ),
      // Optional. List of directories that contain the source files for which to generate bindings.
      sourcePath: [packageRoot.resolve('android/src/main/kotlin')],
      // Required. List of classes or packages for which bindings should be generated.
      classes: [
        'dev.roszkowski.appupdate.InstallStateUpdatedListenerProxy',
        'com.google.android.play.core.appupdate.AppUpdateManager',
        'com.google.android.play.core.appupdate.AppUpdateManagerFactory',
        'com.google.android.play.core.appupdate.AppUpdateInfo',
        'com.google.android.play.core.appupdate.AppUpdateOptions',
        'com.google.android.play.core.install.model.AppUpdateType',
        'com.google.android.play.core.install.model.InstallStatus',
        'com.google.android.play.core.install.model.InstallErrorCode',
        'com.google.android.play.core.install.model.UpdateAvailability',
        'com.google.android.play.core.install.model.UpdatePrecondition',
        'com.google.android.play.core.install.model.ActivityResult',
        'com.google.android.play.core.install.InstallStateUpdatedListener',
        'com.google.android.play.core.listener.StateUpdatedListener',
        'com.google.android.play.core.install.InstallState',
        'com.google.android.play.core.install.InstallException',
        'com.google.android.gms.tasks.Task',
        'com.google.android.gms.tasks.OnSuccessListener',
        'com.google.android.gms.tasks.OnFailureListener',
        'com.google.android.gms.tasks.OnCompleteListener',
        'com.google.android.gms.tasks.OnCanceledListener',
        'com.google.android.gms.tasks.OnTokenCanceledListener',
        'com.google.android.gms.tasks.RuntimeExecutionException',
      ],
    ),
  );
}
