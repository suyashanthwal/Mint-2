import UIKit
import ObjectiveC

private var keyboardDismissCoordinatorKey: UInt8 = 0

extension UIViewController {

    func enableKeyboardDismissOnBackgroundTapAndSwipe() {
        let coordinator = keyboardDismissCoordinator
        coordinator.attach(to: view)
    }

    private var keyboardDismissCoordinator: KeyboardDismissCoordinator {
        if let coordinator = objc_getAssociatedObject(self, &keyboardDismissCoordinatorKey) as? KeyboardDismissCoordinator {
            return coordinator
        }

        let coordinator = KeyboardDismissCoordinator(viewController: self)
        objc_setAssociatedObject(
            self,
            &keyboardDismissCoordinatorKey,
            coordinator,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        return coordinator
    }
}

private final class KeyboardDismissCoordinator: NSObject, UIGestureRecognizerDelegate {

    weak var viewController: UIViewController?
    private weak var attachedView: UIView?

    init(viewController: UIViewController) {
        self.viewController = viewController
    }

    func attach(to view: UIView) {
        guard attachedView !== view else { return }
        attachedView = view

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleKeyboardDismissGesture))
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)

        let swipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleKeyboardDismissGesture))
        swipeGesture.direction = .down
        swipeGesture.cancelsTouchesInView = false
        swipeGesture.delegate = self
        view.addGestureRecognizer(swipeGesture)
    }

    @objc private func handleKeyboardDismissGesture() {
        viewController?.view.endEditing(true)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view is UIControl {
            return false
        }

        if let touchedView = touch.view,
           touchedView.closestTextInputView() != nil {
            return false
        }

        return true
    }
}

private extension UIView {

    func closestTextInputView() -> UIView? {
        var currentView: UIView? = self

        while let view = currentView {
            if view is UITextField || view is UITextView {
                return view
            }
            currentView = view.superview
        }

        return nil
    }
}
