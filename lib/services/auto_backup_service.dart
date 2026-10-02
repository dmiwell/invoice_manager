import '../database/app_database.dart';
import 'auto_backup/auto_backup_platform.dart'
    if (dart.library.js_interop) 'auto_backup/auto_backup_platform_web.dart'
    as platform;
import 'backup_service.dart';

/// Automatic backups to a user-chosen local folder (File System Access API,
/// Chromium browsers only). One ZIP per day, the last [keepCount] are kept.
class AutoBackupService {
  static const _prefix = 'invoice-backup-';
  static const keepCount = 7;

  static bool get isSupported => platform.isSupported;

  static Future<String?> directoryName() => platform.getDirectoryName();

  static Future<String?> chooseDirectory() => platform.chooseDirectory();

  static Future<void> disable() => platform.disable();

  /// 'granted' | 'prompt' | 'denied' | 'none' (no directory chosen)
  static Future<String> permissionState() => platform.permissionState();

  /// Must be called from a user interaction (button tap).
  static Future<String> requestPermission() => platform.requestPermission();

  /// Writes today's backup if a folder is chosen and permission is granted.
  /// Returns the written file name, or null if auto backup is off/unavailable.
  static Future<String?> runBackup(AppDatabase db) async {
    if (!isSupported) return null;
    if (await permissionState() != 'granted') return null;

    final bytes = await BackupService(db).exportToZip();
    final date = DateTime.now().toIso8601String().substring(0, 10);
    return platform.writeBackup(bytes, '$_prefix$date.zip', _prefix, keepCount);
  }
}
