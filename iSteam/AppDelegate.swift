import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        CrashLogger.shared.install()
        // Keep every UIKit toggle visually consistent with the app's native iOS controls.
        UISwitch.appearance().onTintColor = .systemGreen
        UISwitch.appearance().tintColor = .systemGray4
        UISwitch.appearance().thumbTintColor = .white
        let window = UIWindow(frame: UIScreen.main.bounds)
        let navigation = UINavigationController(rootViewController: LibraryViewController())
        navigation.navigationBar.prefersLargeTitles = true
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
