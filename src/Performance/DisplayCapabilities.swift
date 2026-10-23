import Foundation

#if !os(visionOS)
import UIKit
#endif

/// Platform-safe refresh-rate capability. visionOS does not expose UIScreen;
/// use a conservative target ceiling there and let the compositor pace frames.
enum DisplayCapabilities {
    static var maximumFramesPerSecond: Int {
        #if os(visionOS)
        return 90
        #else
        return max(1, UIScreen.main.maximumFramesPerSecond)
        #endif
    }
}
