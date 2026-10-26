import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    static var allowLandscape = false

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        AppDelegate.allowLandscape ? .allButUpsideDown : .portrait
    }
}
