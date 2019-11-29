//
//  SZAVPlayerDatabase.swift
//  SZAVPlayer
//
//  Created by CaiSanze on 2019/11/28.
//

import UIKit
import SQLite

public class SZAVPlayerDatabase: NSObject {

    public static let shared = SZAVPlayerDatabase()
    private let mimeTypesTable = Table("mimeTypes")
    private let id = Expression<Int64>("id")

    private let dbFileName = SZAVPlayerFileSystem.documentsDirectory.appendingPathComponent("SZAVPlayer.sqlite").absoluteString
    private lazy var db: Connection = createDB()

    override init() {
        super.init()

        createMIMETypesTable()
    }

}

// MARK: - MIMEType

extension SZAVPlayerDatabase {

    public func mimeType(uniqueID: String) -> String? {
        do {
            let query = mimeTypesTable.select(SZAVPlayerMIMEType.mimeType).filter(SZAVPlayerMIMEType.uniqueID == uniqueID)
            if let row = try db.pluck(query) {
                return row[SZAVPlayerMIMEType.mimeType]
            }
        } catch {
            SZLogError("\(error)")
        }

        return nil
    }

    public func update(mimeType: String, uniqueID: String) {
        do {
            let updated = Int64(Date().timeIntervalSince1970)
            let query = mimeTypesTable.insert(or: .replace,
                                              SZAVPlayerMIMEType.mimeType <- mimeType,
                                              SZAVPlayerMIMEType.uniqueID <- uniqueID,
                                              SZAVPlayerMIMEType.updated <- updated)
            try db.run(query)
        } catch {
            SZLogError("\(error)")
        }
    }

    public func delete(uniqueID: String) {
        do {
            let query = mimeTypesTable.filter(SZAVPlayerMIMEType.uniqueID == uniqueID).delete()
            try db.run(query)
        } catch {
            SZLogError("\(error)")
        }
    }

    private func createMIMETypesTable() {
        do {
            try db.run(mimeTypesTable.create(ifNotExists: true) { t in
                t.column(id, primaryKey: .autoincrement)
                t.column(SZAVPlayerMIMEType.uniqueID, unique: true)
                t.column(SZAVPlayerMIMEType.mimeType)
                t.column(SZAVPlayerMIMEType.updated)
            })
        } catch {
            SZLogError("\(error)")
        }
    }

}

// MARK: - Getter

extension SZAVPlayerDatabase {

    private func createDB() -> Connection {
        do {
            return try Connection(dbFileName)
        } catch {
            fatalError("\(error)")
        }
    }

}
