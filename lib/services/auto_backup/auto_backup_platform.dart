// Non-web stub — auto backup via the File System Access API is browser-only.

bool get isSupported => false;

Future<String?> chooseDirectory() async => null;

Future<String?> getDirectoryName() async => null;

Future<void> disable() async {}

Future<String> permissionState() async => 'none';

Future<String> requestPermission() async => 'none';

Future<String?> writeBackup(List<int> bytes, String fileName, String prefix, int keepCount) async =>
    null;
