//
//  CellProfileLoader.swift
//  FeatureSearch
//
//  Created by 전성훈 on 7/15/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import UIKit

import CoreDesignSystem

@MainActor
final class CellProfileLoader {
    private let fetchProfile: (GithubUser) async throws -> Data
    
    // 메모리 이미지 캐시, Decoding, Downsampling된 UIImage
    private let imageCache = Cache<Int, UIImage>(countLimit: 500, totalCostLimit: 64 * 1024 * 1024)
    
    private var tasks: [Int: ManagedTask] = [:]
    private var representedCells: [Int: WeakCell] = [:]
    
    private struct WeakCell {
        weak var cell: UserListCell?
    }
    
    private let scale: CGFloat
    private let pointSize: CGSize
    
    init(
        scale: CGFloat = 3,
        fetchProfile: @escaping (GithubUser) async throws -> Data
    ) {
        self.scale = scale
        self.pointSize = CGSize(
            width: UserListCell.profileSize,
            height: UserListCell.profileSize
        )
        self.fetchProfile = fetchProfile
    }
    
    var cacheStatistics: CacheStatistics { imageCache.statistics }

    // MARK: - 보이는 셀 로딩
    
    func load(_ user: GithubUser, into cell: UserListCell) {
        cell.representedID = user.id
        
        if let image = imageCache.value(forKey: user.id) {
            cell.setProfile(image)
            
            return
        }
        
        cell.setProfileLoading()
        representedCells[user.id] = WeakCell(cell: cell)
        startIfNeeded(user)
    }
    
    // MARK: - Prefetch (곧 나타날 행 미리 받기)
    
    func prefetch(_ user: GithubUser) {
        guard imageCache.value(forKey: user.id) == nil else { return }
        
        startIfNeeded(user)
    }
    
    func cancelPrefetch(forID id: Int) {
        guard representedCells[id]?.cell == nil else { return }
        
        cancel(id)
    }
    
    // MARK: - 화면 이탈 취소
    
    func cancelLoad(forID id: Int) {
        cancel(id)
    }
    
    // MARK: - 내부
    
    private func startIfNeeded(_ user: GithubUser) {
        let slot = tasks[user.id] ?? ManagedTask()
        
        tasks[user.id] = slot
        
        slot.runIfIdle(with: self) { owner in
            do {
                let data = try await owner.fetchProfile(user)
                
                let image = await ImageDownsampler.makeImage(
                    from: data,
                    pointSize: owner.pointSize,
                    scale: owner.scale
                )
                
                guard !Task.isCancelled else { return }
                
                if let image {
                    let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
                    
                    owner.imageCache.insert(image, forKey: user.id, cost: cost)
                }
                
                owner.deliver(user.id, image: image, failed: image == nil)
            } catch is CancellationError {
                // 화면 밖으로 나가 취소된 것
            }
            catch {
                owner.deliver(user.id, image: nil, failed: true)
            }
        }
    }
    
    /// 완료된 id를 아직 표시 중인 셀에만 반영
    /// 셀이 재사용됐거나 없으면 뭇 ㅣ
    private func deliver(_ id: Int, image: UIImage?, failed: Bool) {
        defer { representedCells[id] = nil }
        
        guard let cell = representedCells[id]?.cell,
              cell.representedID == id else { return }
        
        if let image {
            cell.setProfile(image)
        } else if failed {
            cell.setProfile(nil)
        }
    }
    
    private func cancel(_ id: Int) {
        tasks[id]?.cancel()
        tasks[id] = nil
        
        representedCells[id] = nil
    }
}
