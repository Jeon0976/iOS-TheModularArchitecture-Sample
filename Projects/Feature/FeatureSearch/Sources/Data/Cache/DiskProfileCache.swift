//
//  DiskProfileCache.swift
//  FeatureSearch
//
//  Created by 전성훈 on 7/13/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

final class DiskProfileCache: ProfileCaching, @unchecked Sendable {
    private let directory: URL
    private let totalByteLimit: Int
    private let fileManger = FileManager.default
    
    private let lock = NSLock()
    
    init(
        directory: URL? = nil,
        totalByteLimit: Int = 64 * 1024 * 1024
    ) {
        if let directory = directory {
            self.directory = directory
        } else {
            let caches = FileManager.default.urls(
                for: .cachesDirectory,
                in: .userDomainMask
            )[0]
            
            self.directory = caches.appending(
                path: "ProfileDiskCache",
                directoryHint: .isDirectory
            )
        }
        
        self.totalByteLimit = totalByteLimit
        
        try? fileManger.createDirectory(
            at: self.directory,
            withIntermediateDirectories: true
        )
    }
    
    func data(forUserID id: Int) -> Data? {
        lock.withLock {
            let url = fileURL(id)
            
            guard let data = try? Data(contentsOf: url) else { return nil }
            
            try? fileManger.setAttributes(
                [.modificationDate: Date()],
                ofItemAtPath: url.path(percentEncoded: false)
            )
            
            return data
        }
    }
    
    func store(_ data: Data, forUserID id: Int) {
        lock.withLock {
            try? data.write(to: fileURL(id), options: .atomic)
            
            trimIfNeeded()
        }
    }
    
    // MARK: - private method
    
    private func fileURL(_ id: Int) -> URL {
        directory.appending(
            path: "\(id).img",
            directoryHint: .notDirectory
        )
    }
    
    // 총 용량이 상한을 넘으면 오래된 파일부터 상한 이하가 될 때까지 제거
    private func trimIfNeeded() {
        let keys: [URLResourceKey] = [
            .fileSizeKey,
            .contentModificationDateKey
        ]
        
        guard let files = try? fileManger.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys
        ) else { return }
        
        var entries = files.compactMap { url -> (url: URL, size: Int, date: Date)? in
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  let size = values.fileSize,
                  let date = values.contentModificationDate
            else { return nil }
            
            return (url, size, date)
        }
        
        var total = entries.reduce(0) { $0 + $1.size }
        guard total > totalByteLimit else { return }
        
        entries.sort { $0.date < $1.date }
        
        for entry in entries {
            guard total > totalByteLimit else { break }
            
            try? fileManger.removeItem(at: entry.url)
            
            total -= entry.size
        }
    }
}
