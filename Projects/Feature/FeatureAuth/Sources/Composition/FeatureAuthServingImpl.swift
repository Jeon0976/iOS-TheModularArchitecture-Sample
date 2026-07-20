import UIKit

import CoreNetwork
import CoreStorage
import FeatureAuthInterface

@MainActor
public final class FeatureAuthServingImpl: FeatureAuthServing {
    private let requestAuthURLUseCase: RequestGithubAuthURLUseCaseImpl
    private let exchangeTokenUseCase: ExchangeGithubTokenUseCaseImpl
    private let readStoredTokenUseCase: ReadStoredTokenUseCaseImpl
    private let clearStoredTokenUseCase: ClearStoredTokenUseCaseImpl
    
    private weak var activeLoginViewModel: LoginViewModel?
    
    public init(
        session: any NetworkRequesting,
        tokenStorage: any TokenStorage,
        credentials: OAuthCredentials?
    ) {
        let repository = GithubTokenRepository(
            session: session,
            credentials: credentials
        )
        
        self.requestAuthURLUseCase = RequestGithubAuthURLUseCaseImpl(githubTokenRepository: repository)
        self.exchangeTokenUseCase = ExchangeGithubTokenUseCaseImpl(
            tokenStorage: tokenStorage,
            githubTokenRepository: repository
        )
        self.readStoredTokenUseCase = ReadStoredTokenUseCaseImpl(tokenStorage: tokenStorage)
        self.clearStoredTokenUseCase = ClearStoredTokenUseCaseImpl(tokenStorage: tokenStorage)
    }
    
    public var isLoggedIn: Bool {
        readStoredTokenUseCase.execute() != nil
    }
    
    public func makeLoginViewController(
        actions: FeatureAuthCoordinatorActions?
    ) -> UIViewController {
        let viewModel = LoginViewModel(
            requestAuthURLUseCase: requestAuthURLUseCase,
            exchangeTokenUseCase: exchangeTokenUseCase,
            actions: actions
        )
        
        activeLoginViewModel = viewModel
        
        return LoginViewController(viewModel: viewModel)
    }
    
    @discardableResult
    public func handleOAuthCallback(_ url: URL) -> Bool {
        guard url.scheme == AuthCallback.scheme else { return false }
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              !code.isEmpty
        else { return false }

        activeLoginViewModel?.receiveAuthorizationCode(code)

        return true
    }
    
    public func logout() {
        clearStoredTokenUseCase.execute()
    }
}
