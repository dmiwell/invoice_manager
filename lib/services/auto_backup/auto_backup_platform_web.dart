// Web implementation backed by web/auto_backup.js (File System Access API).
import 'dart:js_interop';
import 'dart:typed_data';

@JS('autoBackup')
external JSObject? get _autoBackup;

@JS('autoBackup.isSupported')
external bool _isSupported();

@JS('autoBackup.chooseDirectory')
external JSPromise<JSString> _chooseDirectory();

@JS('autoBackup.getDirectoryName')
external JSPromise<JSString?> _getDirectoryName();

@JS('autoBackup.disable')
external JSPromise<JSAny?> _disable();

@JS('autoBackup.permissionState')
external JSPromise<JSString> _permissionState();

@JS('autoBackup.requestPermission')
external JSPromise<JSString> _requestPermission();

@JS('autoBackup.writeBackup')
external JSPromise<JSString?> _writeBackup(
  JSUint8Array bytes,
  JSString fileName,
  JSString prefix,
  JSNumber keepCount,
);

// The null check guards against auto_backup.js not being loaded (e.g. a
// stale service worker cache serving a mixed app version).
bool get isSupported => _autoBackup != null && _isSupported();

/// Returns the chosen directory name, or null if the user cancelled the picker.
Future<String?> chooseDirectory() async {
  try {
    return (await _chooseDirectory().toDart).toDart;
  } catch (_) {
    // AbortError: the user dismissed the directory picker.
    return null;
  }
}

Future<String?> getDirectoryName() async => (await _getDirectoryName().toDart)?.toDart;

Future<void> disable() async {
  await _disable().toDart;
}

Future<String> permissionState() async => (await _permissionState().toDart).toDart;

Future<String> requestPermission() async => (await _requestPermission().toDart).toDart;

Future<String?> writeBackup(List<int> bytes, String fileName, String prefix, int keepCount) async {
  final result = await _writeBackup(
    Uint8List.fromList(bytes).toJS,
    fileName.toJS,
    prefix.toJS,
    keepCount.toJS,
  ).toDart;
  return result?.toDart;
}
