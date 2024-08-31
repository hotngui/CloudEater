//
// Created by Joey Jarosz on 8/19/24.
// Copyright (c) 2024 hot-n-GUI, LLC. All rights reserved.
//

import CloudKit
import os

///
final class CloudKitService {
    private enum Constants {
        static let recordType = "GeneratedData"
        static let limit = 1_000_000
    }
    
    private static let logger = Logger(
        subsystem: "com.hotngui.CloudEater2",
        category: String(describing: CloudKitService.self)
    )

    var database: CKDatabase {
        CKContainer(identifier: "iCloud.com.hotngui.CloudEater2").privateCloudDatabase
    }
    
    ///
    func checkAccountStatus() async throws -> CKAccountStatus {
        try await CKContainer.default().accountStatus()
    }
    
    ///
    func save(_ records: [CKRecord]) async throws {
        let results  = try await database.modifyRecords(saving: records, deleting: []).saveResults
        
        for result in results {
            if case .failure(let error) = result.1 {
                throw error
            }
        }
    }
    
    ///
    func deleteNewestRecords(_ count: Int?) async throws {
        let limit = count ?? Constants.limit
        
        let query = CKQuery(recordType: Constants.recordType,
                            predicate: NSPredicate(format: "TRUEPREDICATE"))
        
        query.sortDescriptors = [.init(key: "creationDate", ascending: false)]
        
        let results = try await database.records(matching: query, desiredKeys: [], resultsLimit: limit).matchResults
        _ = try await database.modifyRecords(saving: [], deleting: results.map { $0.0 })
    }
    
    
    /// Queries the cloud database for all its records and tally's up the sizes.
    ///
    /// - Parameter delay: An optional time delay in seconds to add before making the query
    /// - Returns: the total size of space used as implied by the `chunkSize` and `numberOfChunks` fields of the records
    ///
    /// - Note: If we try to do another query immediately after adding/deleting records I do not seem to always
    ///         get back all the records, so through some experimentation I discovered that adding a little
    ///         delay helps. I would never do this is production code, but since this is just a debugging tool it
    ///         not as terrible as it seems.
    ///
    func getTotalRecordSize(_ delay: UInt64 = 0) async throws -> Double {
        try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
            
        let query = CKQuery(recordType: Constants.recordType,
                            predicate: NSPredicate(format: "TRUEPREDICATE"))
        
        query.sortDescriptors = [.init(key: "creationDate", ascending: false)]
        
        let results = try await database.records(matching: query, desiredKeys: ["chunkSize", "numberOfChunks"], resultsLimit: Constants.limit).matchResults

        let total = results.reduce(0.0, { value, record  in
            guard let record = try? record.1.get() else {
                return value
            }
            
            let chunkSize: Int = (record["chunkSize"] ?? 0)
            let numberOfChunks: Int = (record["numberOfChunks"] ?? 0)

            let x = value + Double(chunkSize * numberOfChunks)
            return x
        })

        return total
    }
}
