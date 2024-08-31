//
// Created by Joey Jarosz on 5/24/24.
// Copyright (c) 2024 hot-n-GUI, LLC. All rights reserved.
//

import Foundation
import CloudKit

struct ChunkGenerator {
    static let defaultNumberOfChunks = 1
    static let defaultSizeOfChunkInBytes = Measurement<UnitInformationStorage>(value: 100, unit: .megabytes).converted(to: .bytes).value
    
    func generate(numberOfChunks: Int, sizeOfChunksInBytes: Double) async throws {
        let pieces = sizeOfChunksInBytes / 10.0
        let timestamp = Date().timeIntervalSince1970
        var outputStr = ""
        
        for _ in 0..<Int64(pieces) {
            outputStr += "0123456789"
        }
        
        let data = Data(outputStr.utf8)
        var urls: [URL] = []
        
        for n in 0..<numberOfChunks {
            let name = "File_\(timestamp)_\(n)"
            let url = URL.documentsDirectory.appending(path: name)

            urls.append(url)

            try data.write(to: url, options: [.atomic])
        }
        
        let record = CKRecord(recordType: "GeneratedData")
        
        record["chunkSize"] = sizeOfChunksInBytes
        record["numberOfChunks"] = numberOfChunks
        record["assets"] = urls.map({ url in
            CKAsset(fileURL: url)
        })
        
        try await CloudKitService().save([record])
        
        try urls.forEach { url in
            try FileManager.default.removeItem(at: url)
        }
    }
    
    func removeFiles(_ count: Int? = nil) async throws {
        try await CloudKitService().deleteNewestRecords(count)
    }
    
    // MARK: - Our Disk Space Usage
    
    func usedCloudSpace(_ delay: UInt64) async throws ->  Double {
        let size = try await CloudKitService().getTotalRecordSize(delay)
        return size
    }
}
