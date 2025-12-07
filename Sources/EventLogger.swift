import Foundation
import SQLite3

enum EventType: String {
    case windowChange = "window_change"
    case screenshot = "screenshot"
    case appSwitch = "app_switch"
    case systemEvent = "system_event"
}

struct MemoryEvent {
    let id: Int64?
    let type: EventType
    let appName: String
    let windowTitle: String?
    let screenshotPath: String?
    let metadata: [String: Any]?
    let timestamp: Date
    let synced: Bool
}

class EventLogger {
    static let shared = EventLogger()
    private var db: OpaquePointer?

    init() {
        setupDatabase()
    }

    private func setupDatabase() {
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dbDir = appSupportDir.appendingPathComponent("NebulaTracker")
        try? FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)

        let dbPath = dbDir.appendingPathComponent("events.sqlite3").path

        if sqlite3_open(dbPath, &db) == SQLITE_OK {
            print("Database opened successfully at \(dbPath)")
            createTables()
        } else {
            print("Unable to open database")
        }
    }

    private func createTables() {
        let createTableString = """
            CREATE TABLE IF NOT EXISTS events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                type TEXT NOT NULL,
                app_name TEXT NOT NULL,
                window_title TEXT,
                screenshot_path TEXT,
                metadata TEXT,
                timestamp REAL NOT NULL,
                synced INTEGER DEFAULT 0
            );
        """

        if sqlite3_exec(db, createTableString, nil, nil, nil) == SQLITE_OK {
            print("Events table created/verified")

            // Create indexes
            sqlite3_exec(db, "CREATE INDEX IF NOT EXISTS idx_timestamp ON events(timestamp);", nil, nil, nil)
            sqlite3_exec(db, "CREATE INDEX IF NOT EXISTS idx_synced ON events(synced);", nil, nil, nil)
        } else {
            print("Error creating table")
        }
    }

    func logEvent(type: EventType,
                  appName: String,
                  windowTitle: String? = nil,
                  screenshotPath: String? = nil,
                  metadata: [String: Any]? = nil) {

        let metadataJson: String?
        if let metadata = metadata {
            if let jsonData = try? JSONSerialization.data(withJSONObject: metadata),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                metadataJson = jsonString
            } else {
                metadataJson = nil
            }
        } else {
            metadataJson = nil
        }

        let insertSQL = """
            INSERT INTO events (type, app_name, window_title, screenshot_path, metadata, timestamp, synced)
            VALUES (?, ?, ?, ?, ?, ?, 0);
        """

        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, type.rawValue, -1, nil)
            sqlite3_bind_text(statement, 2, appName, -1, nil)

            if let windowTitle = windowTitle {
                sqlite3_bind_text(statement, 3, windowTitle, -1, nil)
            } else {
                sqlite3_bind_null(statement, 3)
            }

            if let screenshotPath = screenshotPath {
                sqlite3_bind_text(statement, 4, screenshotPath, -1, nil)
            } else {
                sqlite3_bind_null(statement, 4)
            }

            if let metadataJson = metadataJson {
                sqlite3_bind_text(statement, 5, metadataJson, -1, nil)
            } else {
                sqlite3_bind_null(statement, 5)
            }

            sqlite3_bind_double(statement, 6, Date().timeIntervalSince1970)

            if sqlite3_step(statement) == SQLITE_DONE {
                print("Event logged: \(type.rawValue) for \(appName)")
            } else {
                print("Error inserting event")
            }
        } else {
            print("Error preparing insert statement")
        }

        sqlite3_finalize(statement)
    }

    func getUnsyncedEvents(limit: Int = 100) -> [MemoryEvent] {
        var unsyncedEvents: [MemoryEvent] = []

        let querySQL = """
            SELECT id, type, app_name, window_title, screenshot_path, metadata, timestamp, synced
            FROM events
            WHERE synced = 0
            ORDER BY timestamp ASC
            LIMIT ?;
        """

        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(limit))

            while sqlite3_step(statement) == SQLITE_ROW {
                let id = sqlite3_column_int64(statement, 0)
                let typeRaw = String(cString: sqlite3_column_text(statement, 1))
                let appName = String(cString: sqlite3_column_text(statement, 2))

                let windowTitle: String? = sqlite3_column_text(statement, 3) != nil
                    ? String(cString: sqlite3_column_text(statement, 3))
                    : nil

                let screenshotPath: String? = sqlite3_column_text(statement, 4) != nil
                    ? String(cString: sqlite3_column_text(statement, 4))
                    : nil

                let metadataJson: String? = sqlite3_column_text(statement, 5) != nil
                    ? String(cString: sqlite3_column_text(statement, 5))
                    : nil

                let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(statement, 6))
                let synced = sqlite3_column_int(statement, 7) == 1

                let metadata = parseMetadata(metadataJson)

                let event = MemoryEvent(
                    id: id,
                    type: EventType(rawValue: typeRaw) ?? .systemEvent,
                    appName: appName,
                    windowTitle: windowTitle,
                    screenshotPath: screenshotPath,
                    metadata: metadata,
                    timestamp: timestamp,
                    synced: synced
                )

                unsyncedEvents.append(event)
            }
        }

        sqlite3_finalize(statement)
        return unsyncedEvents
    }

    func markEventsSynced(eventIds: [Int64]) {
        for eventId in eventIds {
            let updateSQL = "UPDATE events SET synced = 1 WHERE id = ?;"
            var statement: OpaquePointer?

            if sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_int64(statement, 1, eventId)
                sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        }

        print("Marked \(eventIds.count) events as synced")
    }

    func deleteOldEvents(olderThanDays: Int = 30) {
        let cutoffTime = Date().addingTimeInterval(-Double(olderThanDays * 24 * 60 * 60)).timeIntervalSince1970

        let deleteSQL = "DELETE FROM events WHERE timestamp < ? AND synced = 1;"
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_double(statement, 1, cutoffTime)

            if sqlite3_step(statement) == SQLITE_DONE {
                let deletedCount = sqlite3_changes(db)
                print("Deleted \(deletedCount) old events")
            }
        }

        sqlite3_finalize(statement)
    }

    private func parseMetadata(_ jsonString: String?) -> [String: Any]? {
        guard let jsonString = jsonString,
              let data = jsonString.data(using: .utf8) else { return nil }

        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    func getEventStats() -> (total: Int, synced: Int, pending: Int) {
        var total = 0
        var synced = 0

        // Get total count
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM events;", -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                total = Int(sqlite3_column_int(statement, 0))
            }
        }
        sqlite3_finalize(statement)

        // Get synced count
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM events WHERE synced = 1;", -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                synced = Int(sqlite3_column_int(statement, 0))
            }
        }
        sqlite3_finalize(statement)

        let pending = total - synced

        return (total: total, synced: synced, pending: pending)
    }

    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }
}