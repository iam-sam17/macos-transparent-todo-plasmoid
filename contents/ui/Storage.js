// Storage.js - SQLite LocalStorage & Fallback Persistence
.pragma library

var _db = null;

function getDb(LocalStorage) {
    if (!_db) {
        try {
            _db = LocalStorage.openDatabaseSync("MacOSFloatingTodoDB", "1.0", "macOS Floating Todo Storage", 100000);
            _db.transaction(function(tx) {
                tx.executeSql('CREATE TABLE IF NOT EXISTS tasks(id TEXT PRIMARY KEY, text TEXT, done INTEGER, priority TEXT, createdAt INTEGER)');
                tx.executeSql('CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY, value TEXT)');
            });
        } catch (e) {
            console.warn("Storage.js: Error initializing SQLite DB:", e);
        }
    }
    return _db;
}

function loadTasks(LocalStorage) {
    var db = getDb(LocalStorage);
    if (!db) return [];
    var list = [];
    try {
        db.readTransaction(function(tx) {
            var rs = tx.executeSql('SELECT * FROM tasks ORDER BY createdAt ASC');
            for (var i = 0; i < rs.rows.length; i++) {
                var item = rs.rows.item(i);
                list.push({
                    id: item.id,
                    text: item.text,
                    done: item.done === 1,
                    priority: item.priority || "none",
                    createdAt: item.createdAt || Date.now()
                });
            }
        });
    } catch (e) {
        console.warn("Storage.js: Error loading tasks:", e);
    }
    return list;
}

function saveTasks(LocalStorage, tasks) {
    var db = getDb(LocalStorage);
    if (!db) return;
    try {
        db.transaction(function(tx) {
            tx.executeSql('DELETE FROM tasks');
            if (tasks && tasks.length > 0) {
                for (var i = 0; i < tasks.length; i++) {
                    var t = tasks[i];
                    tx.executeSql('INSERT INTO tasks (id, text, done, priority, createdAt) VALUES (?, ?, ?, ?, ?)',
                        [t.id, t.text, t.done ? 1 : 0, t.priority || "none", t.createdAt || Date.now()]);
                }
            }
        });
    } catch (e) {
        console.warn("Storage.js: Error saving tasks:", e);
    }
}

function setSetting(LocalStorage, key, value) {
    var db = getDb(LocalStorage);
    if (!db) return;
    try {
        db.transaction(function(tx) {
            tx.executeSql('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)', [key, String(value)]);
        });
    } catch (e) {
        console.warn("Storage.js: Error saving setting:", e);
    }
}

function getSetting(LocalStorage, key, defaultValue) {
    var db = getDb(LocalStorage);
    if (!db) return defaultValue;
    var val = defaultValue;
    try {
        db.readTransaction(function(tx) {
            var rs = tx.executeSql('SELECT value FROM settings WHERE key = ?', [key]);
            if (rs.rows.length > 0) {
                val = rs.rows.item(0).value;
            }
        });
    } catch (e) {
        console.warn("Storage.js: Error reading setting:", e);
    }
    return val;
}

function generateId() {
    return "task_" + Date.now() + "_" + Math.floor(Math.random() * 10000);
}
