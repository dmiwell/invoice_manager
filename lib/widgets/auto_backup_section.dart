import 'dart:async';

import 'package:flutter/material.dart';
import 'package:invoice_manager/repositories/app_repository.dart';
import 'package:provider/provider.dart';

import '../services/auto_backup_service.dart';

/// Settings section for automatic backups into a local folder.
/// Rendered only when the File System Access API is available.
class AutoBackupSection extends StatefulWidget {
  const AutoBackupSection({super.key});

  @override
  State<AutoBackupSection> createState() => _AutoBackupSectionState();
}

class _AutoBackupSectionState extends State<AutoBackupSection> {
  String? _directoryName;
  String _permission = 'none';
  String? _message;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final name = await AutoBackupService.directoryName();
    final permission = await AutoBackupService.permissionState();
    if (!mounted) return;
    setState(() {
      _directoryName = name;
      _permission = permission;
    });
  }

  Future<void> _backupNow() async {
    final db = context.read<AppRepository>().database;
    final file = await AutoBackupService.runBackup(db);
    if (!mounted) return;
    setState(() {
      _message = file != null ? 'Saved $file' : 'Backup failed: folder not writable';
    });
  }

  Future<void> _chooseFolder() async {
    final name = await AutoBackupService.chooseDirectory();
    if (name == null) return; // picker cancelled
    await _refresh();
    await _backupNow();
  }

  Future<void> _grantAccess() async {
    await AutoBackupService.requestPermission();
    await _refresh();
    if (_permission == 'granted') {
      await _backupNow();
    }
  }

  Future<void> _disable() async {
    await AutoBackupService.disable();
    setState(() {
      _message = null;
    });
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _directoryName != null;

    return Column(
      children: [
        const Text(
          'Auto Backup',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          enabled
              ? 'Backing up to "$_directoryName" on every launch (last ${AutoBackupService.keepCount} kept)'
              : 'Pick a local folder to back up automatically on every launch',
          style: const TextStyle(color: Colors.grey),
        ),
        if (enabled && _permission == 'prompt') ...[
          const SizedBox(height: 8),
          const Text(
            'The browser needs you to re-confirm access to the folder.',
            style: TextStyle(color: Colors.orange, fontSize: 12),
          ),
        ],
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(_message!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 16,
          children: [
            if (enabled && _permission == 'prompt')
              ElevatedButton.icon(
                onPressed: _grantAccess,
                icon: const Icon(Icons.lock_open),
                label: const Text('Grant Access'),
              ),
            ElevatedButton.icon(
              onPressed: _chooseFolder,
              icon: const Icon(Icons.folder_open),
              label: Text(enabled ? 'Change Folder' : 'Choose Folder'),
            ),
            if (enabled && _permission == 'granted')
              OutlinedButton.icon(
                onPressed: _backupNow,
                icon: const Icon(Icons.save),
                label: const Text('Backup Now'),
              ),
            if (enabled)
              TextButton(
                onPressed: _disable,
                child: const Text('Disable'),
              ),
          ],
        ),
      ],
    );
  }
}
