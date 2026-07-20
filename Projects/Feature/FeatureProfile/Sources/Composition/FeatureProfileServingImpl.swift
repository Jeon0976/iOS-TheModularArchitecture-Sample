import UIKit

import CoreNetwork
import FeatureAuthInterface
import FeatureProfileInterface

@MainActor
public final class FeatureProfileServingImpl: FeatureProfileServing {
    private let session: any NetworkRequesting
    private let auth: any FeatureAuthServing
    
    public init(
        session: any NetworkRequesting,
        auth: any FeatureAuthServing
    ) {
        self.session = session
        self.auth = auth
    }

    public func makeProfileEntryViewController(
        actions: FeatureProfileCoordinatorActions?
    ) -> UIViewController {
        let repository = UserRepository(
            session: session,
            userStorage: UserVolatileStorage()
        )
        
        let fetchUserUseCase = FetchUserUseCaseImpl(userRepository: repository)
        let refreshUserUseCase = RefreshUserUseCaseImpl(userRepository: repository)
        let clearCachedUserUseCase = ClearCachedUseUseCaseImpl(userRepository: repository)
        
        let viewModel = ProfileViewModel(
            fetchUserUseCase: fetchUserUseCase,
            refreshUserUseCase: refreshUserUseCase,
            clearCachedUserUseCase: clearCachedUserUseCase,
            actions: actions
        )
        
        // 토큰 삭제를 Auth 쪽으로 위임
        // 피처 간 유일한 호출
        viewModel.onLogout = { [auth] in
            auth.logout()
        }
        
        return ProfileViewController(viewModel: viewModel)
    }
}
