//
//  StockboardKey.swift
//  KeyboardKit
//
//  Created by Alex Man on 1/16/21.
//

import Foundation
import UIKit

class KeyView: HighlightableButton {
    private var keyHintLayer: KeyHintLayer?
    private var popupView: KeyPopupView?
    private var isPopupInLongPressMode: Bool?
    private var _keyCap: KeyCap = .none
    var keyCap: KeyCap {
        get { _keyCap }
        set {
            if _keyCap != newValue {
                setKeyCap(newValue)
            }
        }
    }
    private var action: KeyboardAction = KeyboardAction.none
    
    var isKeyEnabled: Bool = true {
        didSet {
            setupView()
        }
    }
    
    var selectedAction: KeyboardAction {
        if keyCap.childrenKeyCaps.count > 1 {
            return popupView?.selectedAction ?? action
        } else {
            return action
        }
    }
    
    var hitTestFrame: CGRect?
    
    var isLabelHidden: Bool {
        get { titleLabel?.isHidden ?? true }
        set { titleLabel?.isHidden = newValue }
    }
    
    var hasInputAcceptingPopup: Bool {
        popupView?.keyCaps.count ?? 0 > 1
    }
    
    var shouldDisablePopup: Bool = false
    
    var heightClearance: CGFloat?
    
    required init?(coder: NSCoder) {
        fatalError("NSCoder is not supported")
    }
    
    init() {
        super.init(frame: .zero)
        setupUIButton()
    }
    
    private func setupUIButton() {
        setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(weight: .light), forImageIn: .normal)
        
        isUserInteractionEnabled = true
        layer.cornerRadius = 5
        layer.shadowOffset = CGSize(width: 0.0, height: 1.0)
        layer.shadowColor = ButtonColor.keyShadowColor.resolvedColor(with: traitCollection).cgColor
        layer.shadowRadius = 0.0
        layer.masksToBounds = false
        layer.cornerRadius = 5
    }
    
    internal func setKeyCap(_ keyCap: KeyCap) {
        self._keyCap = keyCap
        self.action = keyCap.action
        setupView()
    }
        
    internal func setupView() {
        backgroundColor = keyCap.buttonBgColor
        
        let foregroundColor = keyCap.buttonFgColor
        setTitleColor(foregroundColor, for: .normal)
        tintColor = foregroundColor
        
        var maskedCorners: CACornerMask = [.layerMaxXMaxYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMinXMinYCorner]
        var shadowOpacity: Float = 1.0
        var buttonHintTitle = keyCap.buttonHint
        highlightedColor = nil

        if !isKeyEnabled {
            setImage(nil, for: .normal)
            setTitle(nil, for: .normal)
            titleLabel?.text = nil
            let backgroundColorAlpha = backgroundColor?.alpha ?? 1
            if case .shift = keyCap {
                // Hide the highlighted color in swipe mode.
                backgroundColor = ButtonColor.systemKeyBackgroundColor
            }
            backgroundColor = backgroundColor?.withAlphaComponent(backgroundColorAlpha * 0.8)
            shadowOpacity = 0
            buttonHintTitle = nil
        } else if popupView != nil {
            setImage(nil, for: .normal)
            setTitle(nil, for: .normal)
            titleLabel?.text = nil
            backgroundColor = ButtonColor.popupBackgroundColor
            maskedCorners = [.layerMaxXMaxYCorner, .layerMinXMaxYCorner]
        } else if let buttonText = keyCap.buttonText {
            setImage(nil, for: .normal)
            setTitle(buttonText, for: .normal)
            titleLabel?.font = keyCap.buttonFont
            titleLabel?.baselineAdjustment = .alignCenters
            titleLabel?.lineBreakMode = .byClipping
            highlightedColor = keyCap.buttonBgHighlightedColor
        } else {
            var buttonImage = keyCap.buttonImage
            if keyCap == .keyboardType(.emojis) {
                // Special handling for emoji icon. We use different symbols in light/dark mode.
                let isDarkMode = traitCollection.userInterfaceStyle == .dark
                buttonImage = isDarkMode ? ButtonImage.emojiKeyboardDark : ButtonImage.emojiKeyboardLight
            }
            setImage(buttonImage, for: .normal)
            setTitle(nil, for: .normal)
            titleLabel?.text = nil
            highlightedColor = keyCap.buttonBgHighlightedColor
        }
        
        switch keyCap {
        case .character(let c), .characterWithConditioanlPopup(let c):
            titleEdgeInsets = UIEdgeInsets(top: c.first?.needsAdjustment ?? false ? -4 : 0, left: 0, bottom: 0, right: 0)
        default: titleEdgeInsets = UIEdgeInsets.zero
        }
        
        setupKeyHint(keyCap, buttonHintTitle, keyCap.buttonHintFgColor)
        
        layer.maskedCorners = maskedCorners
        layer.shadowOpacity = shadowOpacity
        
        // isUserInteractionEnabled = action == .nextKeyboard
        // layoutPopupView()
        setNeedsLayout()
    }
    
    private func setupKeyHint(_ keyCap: KeyCap, _ buttonHintTitle: String?, _ foregroundColor: UIColor) {
        if let buttonHintTitle = buttonHintTitle {
            if keyHintLayer == nil {
                let keyHintLayer = KeyHintLayer()
                keyHintLayer.foregroundColor = keyCap.buttonHintFgColor.resolvedColor(with: traitCollection).cgColor
                self.keyHintLayer = keyHintLayer
                layer.addSublayer(keyHintLayer)
                keyHintLayer.layoutSublayers()
            }
            self.keyHintLayer?.setup(keyCap: keyCap, hintText: buttonHintTitle)
        } else {
            keyHintLayer?.removeFromSuperlayer()
            keyHintLayer = nil
        }
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if let hitTestFrame = hitTestFrame {
            if isHidden || window == nil { return false }
            // Translate hit test frame to hit test bounds.
            let hitTestBounds = hitTestFrame.offsetBy(dx: -frame.origin.x, dy: -frame.origin.y)
            return hitTestBounds.contains(point)
        } else {
            return super.point(inside: point, with: event)
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        layer.shadowColor = ButtonColor.keyShadowColor.resolvedColor(with: traitCollection).cgColor
        
        if keyCap == .keyboardType(.emojis) { setupView() }
        
        if let keyHintLayer = keyHintLayer {
            keyHintLayer.foregroundColor = keyCap.buttonHintFgColor.resolvedColor(with: traitCollection).cgColor
            keyHintLayer.fontSize = keyCap.buttonHintFontSize
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layoutPopupView()
        keyHintLayer?.isHidden = popupView != nil
        keyHintLayer?.layout(insets: KeyHintLayer.buttonInsets)
    }
    
    private func layoutPopupView() {
        guard let popupView = popupView else { return }
        popupView.heightClearance = heightClearance
        popupView.layoutView()
        
        let popupViewSize = popupView.bounds.size
        let layoutOffsetX = popupView.leftAnchorX
        let popupViewFrame = CGRect(origin: CGPoint(x: -layoutOffsetX, y: -popupViewSize.height + 1), size: popupViewSize)
        popupView.frame = popupViewFrame
    }
}

extension KeyView {
    // Forward all touch events to the superview.
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        superview?.touchesBegan(touches, with: event)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        superview?.touchesMoved(touches, with: event)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        superview?.touchesEnded(touches, with: event)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        superview?.touchesCancelled(touches, with: event)
        isHighlighted = false
    }
}

extension KeyView {
    func keyTouchBegan(_ touch: UITouch) {
        isHighlighted = true
        updatePopup(isLongPress: false)
    }
    
    func keyTouchMoved(_ touch: UITouch) {
        popupView?.updateSelectedAction(touch)
    }
    
    func keyTouchEnded() {
        isHighlighted = false
        popupView?.removeFromSuperview()
        popupView = nil
        
        isPopupInLongPressMode = nil
        
        // Restore lables and rounded corners.
        setupView()
    }
    
    func keyLongPressed(_ touch: UITouch) {
        updatePopup(isLongPress: true)
    }
    
    private func updatePopup(isLongPress: Bool) {
        guard keyCap.hasPopup && !shouldDisablePopup else { return }
        
        // Special case, do not show "enhance" keycap of the emoji button.
        if keyCap == .keyboardType(.emojis) && !isLongPress {
            return
        }
                
        createPopupViewIfNecessary()
        guard let popup = popupView else { return }
        guard isLongPress != isPopupInLongPressMode else { return }
        
        let popupDirection = computePopupDirection()
        let keyCaps = computeKeyCap(isLongPress: isLongPress)
        let defaultKeyCapIndex: Int
        if let defaultChildKeyCap = keyCap.defaultChildKeyCap {
            defaultKeyCapIndex = keyCaps.firstIndex(of: defaultChildKeyCap) ?? 0
        } else {
            defaultKeyCapIndex = 0
        }
        popup.setup(keyCaps: keyCaps, defaultKeyCapIndex: defaultKeyCapIndex, direction: popupDirection)
        
        isPopupInLongPressMode = isLongPress
        setupView()
    }
    
    private func createPopupViewIfNecessary() {
        if popupView == nil {
            let popup = KeyPopupView()
            addSubview(popup)
            self.popupView = popup
        }
    }
    
    private func computePopupDirection() -> KeyPopupView.PopupDirection {
        guard let superview = superview else { return .middle }

        let keyViewFrame = convert(bounds, to: superview)
        if keyViewFrame.minX < LayoutConstants.forMainScreen.keyButtonWidth / 2 {
            // Special case, for key 1, it has 10 children.
            if self.keyCap.childrenKeyCaps.count > 9 {
                return .middle
            } else {
                return .right
            }
        }
        
        if superview.bounds.width - keyViewFrame.maxX < LayoutConstants.forMainScreen.keyButtonWidth / 2 {
            return .left
        }
        
        let isKeyOnTheLeft = keyViewFrame.midX / superview.bounds.width <= 0.5
        return isKeyOnTheLeft ? .middle : .middleExtendLeft
    }
    
    private func computeKeyCap(isLongPress: Bool) -> [KeyCap] {
        if isLongPress {
            return keyCap.childrenKeyCaps
        } else {
            return [keyCap]
        }
    }
}
