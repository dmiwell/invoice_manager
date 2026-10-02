// Auto-backup support for the PWA, built on the File System Access API
// (Chromium-only). The chosen directory handle is persisted in IndexedDB so
// backups can be written on later launches without re-picking the folder.
(function () {
  const DB_NAME = 'invoice_manager_auto_backup';
  const STORE = 'handles';
  const KEY = 'backup_dir';

  function openDb() {
    return new Promise((resolve, reject) => {
      const req = indexedDB.open(DB_NAME, 1);
      req.onupgradeneeded = () => req.result.createObjectStore(STORE);
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => reject(req.error);
    });
  }

  async function withStore(mode, fn) {
    const db = await openDb();
    return new Promise((resolve, reject) => {
      const tx = db.transaction(STORE, mode);
      const req = fn(tx.objectStore(STORE));
      req.onsuccess = () => resolve(req.result ?? null);
      req.onerror = () => reject(req.error);
    });
  }

  const getHandle = () => withStore('readonly', (s) => s.get(KEY));

  window.autoBackup = {
    isSupported() {
      return 'showDirectoryPicker' in window;
    },

    async chooseDirectory() {
      const handle = await window.showDirectoryPicker({ mode: 'readwrite' });
      await withStore('readwrite', (s) => s.put(handle, KEY));
      return handle.name;
    },

    async getDirectoryName() {
      const handle = await getHandle();
      return handle ? handle.name : null;
    },

    async disable() {
      await withStore('readwrite', (s) => s.delete(KEY));
    },

    // 'granted' | 'prompt' | 'denied' | 'none' (no directory chosen)
    async permissionState() {
      const handle = await getHandle();
      if (!handle) return 'none';
      return handle.queryPermission({ mode: 'readwrite' });
    },

    // Must be called from a user gesture when the state is 'prompt'.
    async requestPermission() {
      const handle = await getHandle();
      if (!handle) return 'none';
      return handle.requestPermission({ mode: 'readwrite' });
    },

    // Writes bytes to fileName in the chosen directory, then prunes old
    // backups (prefix*.zip) beyond keepCount. Returns fileName, or null when
    // no directory is chosen or permission isn't granted.
    async writeBackup(bytes, fileName, prefix, keepCount) {
      const handle = await getHandle();
      if (!handle) return null;
      if ((await handle.queryPermission({ mode: 'readwrite' })) !== 'granted') {
        return null;
      }

      const file = await handle.getFileHandle(fileName, { create: true });
      const writable = await file.createWritable();
      await writable.write(bytes);
      await writable.close();

      const names = [];
      for await (const entry of handle.values()) {
        if (entry.kind === 'file' && entry.name.startsWith(prefix) && entry.name.endsWith('.zip')) {
          names.push(entry.name);
        }
      }
      names.sort();
      while (names.length > keepCount) {
        await handle.removeEntry(names.shift());
      }
      return fileName;
    },
  };
})();
