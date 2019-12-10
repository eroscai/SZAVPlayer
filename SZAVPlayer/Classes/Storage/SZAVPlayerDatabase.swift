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
    private let contentInfoTable = Table("contentInfo")
    private let localFileInfoTable = Table("localFileInfo")
    private let id = Expression<Int64>("id")

    private let dbFileName = SZAVPlayerFileSystem.documentsDirectory.appendingPathComponent("SZAVPlayer.sqlite").absoluteString
    private lazy var db: Connection = createDB()

    override init() {
        super.init()

        createMIMETypesTable()
        createLocalFileInfoTable()
    }

    private func delete(table: Table, key: Expression<String>, uniqueID: String) {
        do {
            let query = table.filter(key == uniqueID).delete()
            try db.run(query)
        } catch {
            SZLogError("\(error)")
        }
    }

}

// MARK: - ContentInfo

extension SZAVPlayerDatabase {

    public func contentInfo(uniqueID: String) -> SZAVPlayerContentInfo? {
        do {
            let query = contentInfoTable.filter(SZAVPlayerContentInfo.uniqueID == uniqueID)
            if let row = try db.pluck(query) {
                let info = SZAVPlayerContentInfo(uniqueID: row[SZAVPlayerContentInfo.uniqueID],
                                                 mimeType: row[SZAVPlayerContentInfo.mimeType],
                                                 contentLength: row[SZAVPlayerContentInfo.contentLength],
                                                 updated: row[SZAVPlayerContentInfo.updated])
                return info
            }
        } catch {
            SZLogError("\(error)")
        }

        return nil
    }

    public func update(contentInfo: SZAVPlayerContentInfo) {
        do {
            let updated = Int64(Date().timeIntervalSince1970)
            let query = contentInfoTable.insert(or: .replace,
                                                SZAVPlayerContentInfo.uniqueID <- contentInfo.uniqueID,
                                                SZAVPlayerContentInfo.mimeType <- contentInfo.mimeType,
                                                SZAVPlayerContentInfo.contentLength <- contentInfo.contentLength,
                                                SZAVPlayerContentInfo.updated <- updated)
            try db.run(query)
        } catch {
            SZLogError("\(error)")
        }
    }

    public func deleteMIMEType(uniqueID: String) {
        delete(table: contentInfoTable, key: SZAVPlayerContentInfo.uniqueID, uniqueID: uniqueID)
    }

    private func createMIMETypesTable() {
        do {
            try db.run(contentInfoTable.create(ifNotExists: true) { t in
                t.column(id, primaryKey: .autoincrement)
                t.column(SZAVPlayerContentInfo.uniqueID, unique: true)
                t.column(SZAVPlayerContentInfo.mimeType)
                t.column(SZAVPlayerContentInfo.contentLength)
                t.column(SZAVPlayerContentInfo.updated)
            })
        } catch {
            SZLogError("\(error)")
        }
    }

}

// MARK: - LocalFileInfo

extension SZAVPlayerDatabase {

    public func localFileInfos(uniqueID: String) -> [SZAVPlayerLocalFileInfo] {
        do {
            var infos: [SZAVPlayerLocalFileInfo] = []
            let query = localFileInfoTable
                .filter(SZAVPlayerLocalFileInfo.uniqueID == uniqueID && SZAVPlayerLocalFileInfo.loadedByteLength > 0)
                .order(SZAVPlayerLocalFileInfo.startOffset.asc)
            for info in try db.prepare(query) {
                let fileInfo = SZAVPlayerLocalFileInfo(uniqueID: info[SZAVPlayerLocalFileInfo.uniqueID],
                                                       startOffset: info[SZAVPlayerLocalFileInfo.startOffset],
                                                       loadedByteLength: info[SZAVPlayerLocalFileInfo.loadedByteLength],
                                                       localFileName: info[SZAVPlayerLocalFileInfo.localFileName],
                                                       updated: info[SZAVPlayerLocalFileInfo.updated])
                infos.append(fileInfo)
            }

            return infos
        } catch {
            SZLogError("\(error)")
        }

        return []
    }

    public func update(fileInfo: SZAVPlayerLocalFileInfo) {
        do {
            let updated = Int64(Date().timeIntervalSince1970)
            let query = localFileInfoTable.insert(or: .replace,
                                                  SZAVPlayerLocalFileInfo.uniqueID <- fileInfo.uniqueID,
                                                  SZAVPlayerLocalFileInfo.startOffset <- fileInfo.startOffset,
                                                  SZAVPlayerLocalFileInfo.loadedByteLength <- fileInfo.loadedByteLength,
                                                  SZAVPlayerLocalFileInfo.localFileName <- fileInfo.localFileName,
                                                  SZAVPlayerLocalFileInfo.updated <- updated)
            try db.run(query)
        } catch {
            SZLogError("\(error)")
        }
    }

    public func deleteLocalFileInfo(uniqueID: String) {
        delete(table: localFileInfoTable, key: SZAVPlayerLocalFileInfo.uniqueID, uniqueID: uniqueID)
    }

    private func createLocalFileInfoTable() {
        do {
            try db.run(localFileInfoTable.create(ifNotExists: true) { t in
                t.column(id, primaryKey: .autoincrement)
                t.column(SZAVPlayerLocalFileInfo.uniqueID)
                t.column(SZAVPlayerLocalFileInfo.startOffset)
                t.column(SZAVPlayerLocalFileInfo.loadedByteLength)
                t.column(SZAVPlayerLocalFileInfo.localFileName)
                t.column(SZAVPlayerLocalFileInfo.updated)
                t.unique(SZAVPlayerLocalFileInfo.uniqueID, SZAVPlayerLocalFileInfo.startOffset)
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
