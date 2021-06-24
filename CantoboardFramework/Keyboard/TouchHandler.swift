
import Foundation
import UIKit

import CocoaLumberjackSwift

class TouchHandler {
    enum InputMode: Equatable {
        case typing, backspacing, nextKeyboard, cursorMoving
    }
    static let keyRepeatInitialDelay = 7 // 5 * KeyRepeatInterval
    static let longPressDelay = 3
    static let keyRepeatInterval = 0.08
    static let cursorMovingStepX: CGFloat = 8
    static let initialCursorMovingThreshold = cursorMovingStepX * 1.25
    static let swipeXThreshold: CGFloat = 30
    
    private var currentTouch, shiftTouch: (UITouch, /*_ currentKeyView:*/ KeyView, /*_ initialAction:*/ KeyboardAction)?
    private var cursorMoveStartPosition: CGPoint?
    private var hasTakenAction = false
    private var _inputMode: InputMode = .typing
    private var inputMode: InputMode {
        get { _inputMode }
        set {
            if _inputMode != newValue {
                callKeyHandler(.enableKeyboard(newValue != .cursorMoving))
                if newValue == .cursorMoving { FeedbackProvider.selectionFeedback.selectionChanged() }
                
                if _inputMode == .typing {
                    currentTouch?.1.keyTouchEnded()
                }
                
                _inputMode = newValue
            }
        }
    }
    
    private weak var keyboardView: InputView?
    private var keyRepeatTimer: Timer?
    private var keyRepeatCounter: Int = 0
    
    init(keyboardView: InputView) {
        self.keyboardView = keyboardView
    }
    
    func touchBegan(_ touch: UITouch, key: KeyView, with event: UIEvent?) {
        guard key.isKeyEnabled &&
              inputMode == .typing && // Ignore new touches if we are not in typing mode.
              currentTouch?.0 != touch // Dedup began events coming from gesture recognizer and touch event.
            else { return }
        
        if Settings.cached.isTapHapticFeedbackEnabled {
            FeedbackProvider.lightImpact.impactOccurred()
        }
        
        let touchTuple = (touch, key, key.selectedAction)
        
        // DDLogInfo("touchBegan \(key.keyCap) \(touch) \(currentTouch?.0)")
        
        keyRepeatCounter = 0
        
        setupKeyRepeatTimer()
        
        if currentTouch?.0 != shiftTouch?.0, let lastTouch = currentTouch {
            // The the user is multi-touching multiple characters, end the older touch if it isn't shift related.
            // Ignore any non character touch.
            touchEnded(lastTouch.0, key: lastTouch.1, with: event)
        }
        
        key.keyTouchBegan(touch)
        
        hasTakenAction = false
        FeedbackProvider.play(keyboardAction: key.selectedAction)
        switch key.selectedAction {
        case .backspace:
            inputMode = .backspacing
        case .keyboardType:
            callKeyHandler(key.selectedAction)
        case .nextKeyboard:
            guard let event = event else { return }
            inputMode = .nextKeyboard
            keyboardView?.delegate?.handleInputModeList(from: key, with: event)
        case .shift:
            if touch.tapCount % 2 == 1 {
                // Single tapping shift.
                shiftTouch = touchTuple
                callKeyHandler(.shiftDown)
            } else {
                // Double tapping shift.
                callKeyHandler(.keyboardType(.alphabetic(.capsLocked)))
            }
        default: () // Ignore other keys on key down.
        }
        
        // print(Date(), Thread.current, "touchBegan currentTouch = ", touchTuple.0)
        currentTouch = touchTuple
        cursorMoveStartPosition = touch.location(in: keyboardView)
    }
    
    func touchMoved(_ touch: UITouch, key: KeyView?, with event: UIEvent?) {
        if keyRepeatTimer == nil { setupKeyRepeatTimer() }
        
        // DDLogInfo("touchMoved \(key?.keyCap ?? "nil") \(touch) \(currentTouch?.0)")
        
        switch inputMode {
        case .backspacing:
            // Swipe left to delete word.
            guard let cursorMoveStartPosition = cursorMoveStartPosition else {
                DDLogInfo("TouchHandler is backspacing in but cursorMoveStartPosition is nil.")
                return
            }
            let point = touch.location(in: keyboardView)
            let dX = point.x - cursorMoveStartPosition.x
            if dX < -Self.swipeXThreshold && !hasTakenAction {
                cancelKeyRepeatTimer()
                hasTakenAction = true
                callKeyHandler(.deleteWordSwipe)
                FeedbackProvider.mediumImpact.impactOccurred()
            }
        case .cursorMoving:
            guard let cursorMoveStartPosition = cursorMoveStartPosition else {
                DDLogInfo("TouchHandler is cursorMoving in but cursorMoveStartPosition is nil.")
                return
            }
            let point = touch.location(in: keyboardView)
            var dX = point.x - cursorMoveStartPosition.x
            let isLeft = dX < 0
            dX = isLeft ? -dX : dX
            let threshold = Self.cursorMovingStepX
            while dX > threshold {
                dX -= threshold
                callKeyHandler(isLeft ? .moveCursorBackward : .moveCursorForward)
                hasTakenAction = true
            }
            self.cursorMoveStartPosition = point
            self.cursorMoveStartPosition!.x -= isLeft ? -dX : dX
        case .nextKeyboard:
            guard let event = event, let currentTouch = currentTouch else { return }
            keyboardView?.delegate?.handleInputModeList(from: currentTouch.1, with: event)
        case .typing:
            guard touch == currentTouch?.0 else { return } // Ignore shift touch.
            
            guard let currentTouch = currentTouch, let key = key else { return }
            
            // If there's an popup accepting touch, forward all events to it.
            if currentTouch.1.hasInputAcceptingPopup {
                currentTouch.1.keyTouchMoved(touch)
                return
            }
            
            defer {
                self.currentTouch = (touch, key, currentTouch.2)
            }
            // Reset key repeat long press timer if we moved to another key.
            if currentTouch.1 != key {
                cancelKeyRepeatTimer()
                setupKeyRepeatTimer()
                currentTouch.1.keyTouchEnded()
                key.keyTouchBegan(touch)
                return
            }
            
            // Ignore short swipe.
            guard let cursorMoveStartPosition = cursorMoveStartPosition else { return }
            let point = touch.location(in: keyboardView), deltaX = abs(point.x - cursorMoveStartPosition.x)
            guard deltaX >= Self.initialCursorMovingThreshold else { return }
            
            // If the user is swiping the space key, or force swiping char keys, enter cursor moving mode.
            let tapStartAction = currentTouch.2
            let isForceSwiping = touch.force >= touch.maximumPossibleForce / 2 && deltaX > Self.swipeXThreshold
            switch tapStartAction {
            case .space,
                 .character(_) where isForceSwiping:
                self.cursorMoveStartPosition = point
                inputMode = .cursorMoving
                hasTakenAction = false
                currentTouch.1.keyTouchEnded()
            default: ()
            }
        }
    }
    
    func touchEnded(_ touch: UITouch, key: KeyView?, with event: UIEvent?) {
        let isCurrentTouch = currentTouch?.0 == touch
        let isShiftTouch = shiftTouch?.0 == touch
               
        // DDLogInfo("touchEnded \(key?.keyCap ?? "nil") \(touch) \(currentTouch?.0)")
        
        guard isCurrentTouch || isShiftTouch else { return }
        defer {
            if isCurrentTouch {
                // print(Date(), "touchEnded keyTouchEnded()", currentTouch?.1.keyCap)
                currentTouch?.1.keyTouchEnded()
                self.currentTouch = nil
                inputMode = .typing
            }
            if isShiftTouch {
                shiftTouch?.1.keyTouchEnded()
                self.shiftTouch = nil
            }
        }
        
        cancelKeyRepeatTimer()
        
        switch inputMode {
        case .backspacing:
            if !hasTakenAction { callKeyHandler(.backspace) }
            inputMode = .typing
        case .cursorMoving:
            callKeyHandler(.moveCursorEnded)
            inputMode = .typing
        case .nextKeyboard:
            guard let event = event, let currentTouch = currentTouch else { return }
            keyboardView?.delegate?.handleInputModeList(from: currentTouch.1, with: event)
        case .typing:
            var inputKey = key
            // If we are forwarding move events to a popup, we should input the source key of the popup, not the key being touched.
            if let currentTouch = currentTouch, currentTouch.1.hasInputAcceptingPopup {
                inputKey = currentTouch.1
            }
            guard let action = inputKey?.selectedAction else { return }
            
            switch action {
            case .shift:
                // Ignore the "bounce back" touch ended event when the hollow shift key just changed to filled shift.
                if let currentTouch = currentTouch, action == .shift(.uppercased) {
                    if currentTouch.2 == .shift(.lowercased) {
                        callKeyHandler(.shiftRelax)
                    } else {
                        callKeyHandler(.shiftUp)
                    }
                }
                if shiftTouch?.0 == touch && currentTouch?.0 != touch {
                    // If the user holds the shift key and type, when the user releases the shift key, shift up.
                    callKeyHandler(.shiftUp)
                }
            //case .keyboardType(.emojis), .character, .space, .newLine, .rime, .setCharForm:
            case .keyboardType(.alphabetic), .keyboardType(.numeric), .keyboardType(.symbolic): ()
            default:
                callKeyHandler(action)
                // If the user was dragging from the shift key (not locked) to a char key, change keyboard mode back to lowercase after typing.
                if case .character(_) = action,
                   let startingKeyAction = currentTouch?.2,
                   case .shift(_) = startingKeyAction {
                    callKeyHandler(.shiftUp)
                }
            }
        }
    }
    
    func touchCancelled(_ touch: UITouch, with event: UIEvent?) {
        // DDLogInfo("touchCancelled \(currentTouch?.0) \(touch)")
        
        cancelKeyRepeatTimer()
        
        currentTouch?.1.keyTouchEnded()
        currentTouch = nil
        
        shiftTouch?.1.keyTouchEnded()
        shiftTouch = nil
        
        inputMode = .typing
    }
    
    private func onKeyRepeat(_ timer: Timer) {
        guard timer == self.keyRepeatTimer else { timer.invalidate(); return } // Timer was overwritten.
        keyRepeatCounter += 1
        if self.inputMode == .backspacing && keyRepeatCounter > Self.keyRepeatInitialDelay {
            let action: KeyboardAction
            if keyRepeatCounter <= 20 {
                action = .backspace
            } else {
                action = .deleteWord
            }
            callKeyHandler(action)
            hasTakenAction = true
            FeedbackProvider.play(keyboardAction: action)
        } else if self.inputMode == .typing && keyRepeatCounter > Self.longPressDelay,
            let currentTouch = currentTouch {
            currentTouch.1.keyLongPressed(currentTouch.0)
            cancelKeyRepeatTimer()
        }
    }
    
    private func setupKeyRepeatTimer() {
        keyRepeatTimer?.invalidate()
        keyRepeatCounter = 0
        keyRepeatTimer = Timer.scheduledTimer(withTimeInterval: Self.keyRepeatInterval, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            self.onKeyRepeat(timer)
        }
    }
    
    private func cancelKeyRepeatTimer() {
        keyRepeatTimer?.invalidate()
        keyRepeatTimer = nil
    }
    
    private func callKeyHandler(_ action: KeyboardAction) {
        keyboardView?.delegate?.handleKey(action)
    }
}
