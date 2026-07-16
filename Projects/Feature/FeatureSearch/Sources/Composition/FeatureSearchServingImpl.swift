import UIKit

import CoreNetwork
import FeatureSearchInterface

@MainActor
public final class FeatureSearchServingImpl: FeatureSearchServing {
    private let session: any NetworkRequesting
    
    public init(session: any NetworkRequesting) {
        self.session = session
    }
    
    public func makeSearchEntryViewController(
        actions: FeatureSearchCoordinatorActions?
    ) -> UIViewController {
        let profileCache = DiskProfileCache()
        
        let searchRepository = SearchUserRepository(session: session)
        let profileRepository = ProfileImageRepository(session: session, cache: profileCache)
        
        let searchUsersUseCase = SearchUsersUseCaseImpl(searchUserRepository: searchRepository)
        let fetchProfileUseCase = FetchProfileUseCaseImpl(profileImageRepository: profileRepository)
        
        let viewModel = SearchUserViewModel(
            searchUsersUseCase: searchUsersUseCase,
            fetchProfileUseCase: fetchProfileUseCase,
            actions: actions
        )
        
        return SearchUserViewController(viewModel: viewModel)
    }
}
