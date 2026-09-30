#if os(iOS)
import UIKit
#endif

enum PlatformKeyboard {
    case decimalPad, numberPad, phonePad

    #if os(iOS)
    var uiKeyboardType: UIKeyboardType {
        switch self {
        case .decimalPad: .decimalPad
        case .numberPad:  .numberPad
        case .phonePad:   .phonePad
        }
    }
    #endif
}
