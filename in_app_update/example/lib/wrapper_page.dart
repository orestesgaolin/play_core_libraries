import 'dart:io';

import 'package:flutter/material.dart';
import 'package:play_in_app_update/wrapper.dart';

class InAppWrapperUpdatePage extends StatelessWidget {
  const InAppWrapperUpdatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: UpdateBody());
  }
}

class UpdateBody extends StatefulWidget {
  const UpdateBody({super.key});

  @override
  State<UpdateBody> createState() => _UpdateBodyState();
}

class _UpdateBodyState extends State<UpdateBody> {
  PlayInAppUpdate? _updater;
  InAppUpdateInfo? _info;
  InstallStateSnapshot? _installState;
  String? _status;
  String? _error;
  bool _initializing = false;
  bool _checking = false;
  bool _startingFlexible = false;
  bool _startingImmediate = false;
  bool _completing = false;

  bool get _canUseFlexible => _info?.isFlexibleAllowed == true && !_initializing && !_startingFlexible;
  bool get _canUseImmediate => _info?.isImmediateAllowed == true && !_initializing && !_startingImmediate;
  bool get _canCompleteFlexible =>
      _installState?.status == InAppInstallStatus.downloaded && !_initializing && !_completing;

  @override
  void initState() {
    super.initState();
    _warmUp();
  }

  @override
  void dispose() {
    _updater?.dispose();
    super.dispose();
  }

  Future<void> _warmUp() async {
    if (!Platform.isAndroid) {
      setState(() {
        _error = 'In-app updates are only available on Android.';
        _status = null;
      });
      return;
    }

    await _ensureUpdater();
  }

  Future<PlayInAppUpdate?> _ensureUpdater() async {
    if (_updater != null) {
      return _updater;
    }

    if (!Platform.isAndroid) {
      setState(() {
        _error = 'In-app updates are only available on Android.';
      });
      return null;
    }

    setState(() {
      _initializing = true;
      _error = null;
    });

    try {
      final updater = await PlayInAppUpdate.create();
      if (!mounted) {
        updater.dispose();
        return null;
      }
      setState(() {
        _updater = updater;
      });
      return updater;
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to initialize Play Core: $e';
        });
      }
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _initializing = false;
        });
      }
    }
  }

  Future<void> _checkForUpdate() async {
    final updater = await _ensureUpdater();
    if (updater == null) return;

    setState(() {
      _checking = true;
      _error = null;
      _status = 'Checking for updates...';
      _installState = null;
    });

    try {
      final info = await updater.checkForUpdate();
      if (!mounted) return;
      setState(() {
        _info = info;
        _status = _availabilityLabel(info.availability);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Check failed: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _checking = false;
        });
      }
    }
  }

  Future<void> _startFlexibleUpdate() async {
    final updater = await _ensureUpdater();
    if (updater == null) return;
    if (_info == null) {
      _showSnack('Check for an update first.');
      return;
    }
    if (_info?.isFlexibleAllowed != true) {
      _showSnack('Flexible updates are not allowed for this release.');
      return;
    }

    setState(() {
      _startingFlexible = true;
      _error = null;
      _status = 'Starting flexible update...';
    });

    try {
      await updater.startFlexibleUpdate(
        onState: (state) {
          if (!mounted) return;
          setState(() {
            _installState = state;
            _status = _installStatusLabel(state.status);
          });

          if (state.status == InAppInstallStatus.downloaded) {
            _showSnack('Download finished. Complete the update to install.');
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Flexible update failed: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _startingFlexible = false;
        });
      }
    }
  }

  Future<void> _completeFlexibleUpdate() async {
    final updater = await _ensureUpdater();
    if (updater == null) return;
    if (_installState?.status != InAppInstallStatus.downloaded) {
      _showSnack('Start a flexible update and wait for download to finish.');
      return;
    }

    setState(() {
      _completing = true;
      _error = null;
      _status = 'Installing downloaded update...';
    });

    try {
      await updater.completeFlexibleUpdate();
      if (mounted) {
        _showSnack('Update installation launched.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Completing update failed: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _completing = false;
        });
      }
    }
  }

  Future<void> _startImmediateUpdate() async {
    final updater = await _ensureUpdater();
    if (updater == null) return;
    if (_info == null) {
      _showSnack('Check for an update first.');
      return;
    }
    if (_info?.isImmediateAllowed != true) {
      _showSnack('Immediate updates are not allowed for this release.');
      return;
    }

    setState(() {
      _startingImmediate = true;
      _error = null;
      _status = 'Starting immediate update...';
    });

    try {
      await updater.startImmediateUpdate();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Immediate update failed: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _startingImmediate = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('In-app updates')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Check Play Core for an available update and try both flows.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              if (_status != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _status!,
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: _initializing || _checking ? null : _checkForUpdate,
                    icon: _checking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.system_update),
                    label: const Text('Check update'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _canUseFlexible ? _startFlexibleUpdate : null,
                    icon: _startingFlexible
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download),
                    label: const Text('Flexible update'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _canUseImmediate ? _startImmediateUpdate : null,
                    icon: _startingImmediate
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.flash_on),
                    label: const Text('Immediate update'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _canCompleteFlexible ? _completeFlexibleUpdate : null,
                    icon: _completing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.install_mobile),
                    label: const Text('Complete flexible'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_info != null) _buildInfoCard(context, _info!),
                      if (_installState != null) _buildInstallCard(context, _installState!),
                      if (_info == null) const Text('Run the check to see update availability and allowed flows.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, InAppUpdateInfo info) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Update info', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _InfoRow(label: 'Availability', value: _availabilityLabel(info.availability)),
            _InfoRow(label: 'Install status', value: _installStatusLabel(info.installStatus)),
            _InfoRow(label: 'Package', value: info.packageName),
            _InfoRow(label: 'Available version', value: info.availableVersionCode.toString()),
            _InfoRow(label: 'Update priority', value: info.updatePriority.toString()),
            _InfoRow(label: 'Immediate allowed', value: info.isImmediateAllowed ? 'Yes' : 'No'),
            _InfoRow(label: 'Flexible allowed', value: info.isFlexibleAllowed ? 'Yes' : 'No'),
            if (info.clientVersionStalenessDays != null)
              _InfoRow(
                label: 'Staleness (days)',
                value: info.clientVersionStalenessDays.toString(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstallCard(BuildContext context, InstallStateSnapshot state) {
    final percent = state.fractionDownloaded?.clamp(0.0, 1.0);
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Flexible update state', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _InfoRow(label: 'Status', value: _installStatusLabel(state.status)),
            _InfoRow(label: 'Downloaded', value: '${state.bytesDownloaded} / ${state.totalBytesToDownload}'),
            if (percent != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: percent),
              const SizedBox(height: 4),
              Text('${(percent * 100).toStringAsFixed(1)}%'),
            ],
            if (state.installErrorCode != 0) _InfoRow(label: 'Error code', value: state.installErrorCode.toString()),
          ],
        ),
      ),
    );
  }

  String _availabilityLabel(InAppUpdateAvailability availability) {
    switch (availability) {
      case InAppUpdateAvailability.updateAvailable:
        return 'Update available';
      case InAppUpdateAvailability.updateNotAvailable:
        return 'No update available';
      case InAppUpdateAvailability.developerTriggeredInProgress:
        return 'Developer triggered update in progress';
      case InAppUpdateAvailability.unknown:
        return 'Unknown availability';
    }
  }

  String _installStatusLabel(InAppInstallStatus status) {
    switch (status) {
      case InAppInstallStatus.pending:
        return 'Pending';
      case InAppInstallStatus.downloading:
        return 'Downloading';
      case InAppInstallStatus.downloaded:
        return 'Downloaded';
      case InAppInstallStatus.installing:
        return 'Installing';
      case InAppInstallStatus.installed:
        return 'Installed';
      case InAppInstallStatus.failed:
        return 'Failed';
      case InAppInstallStatus.canceled:
        return 'Canceled';
      case InAppInstallStatus.requiresUiIntent:
        return 'Requires user action';
      case InAppInstallStatus.unknown:
        return 'Unknown';
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
