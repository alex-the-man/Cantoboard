//
//  StockboardKeyRow.swift
//  KeyboardKit
//
//  Created by Alex Man on 1/16/21.
//

import Foundation
import UIKit

class KeyRowView: UIView {
    enum RowLayoutMode: Equatable {
        case phoneRowTop, phoneRowNormal, phoneRowBottom
        case padRow(Int)
    }
    
    private(set) var leftKeys, middleKeys, rightKeys: [KeyView]!
    private var keyboardType: KeyboardType = .none
    private var rowId: Int = -1
    var needsInputModeSwitchKey = false
    
    private weak var layoutConstants: Reference<LayoutConstants>?
    
    var isEnabled: Bool = true {
        didSet {
            leftKeys.forEach { $0.isKeyEnabled = isEnabled }
            middleKeys.forEach { $0.isKeyEnabled = isEnabled }
            rightKeys.forEach { $0.isKeyEnabled = isEnabled }
        }
    }
    
    init(layoutConstants: Reference<LayoutConstants>) {
        self.layoutConstants = layoutConstants
        super.init(frame: .zero)
        
        insetsLayoutMarginsFromSafeArea = false
        preservesSuperviewLayoutMargins = true
        
        leftKeys = []
        middleKeys = []
        rightKeys = []
    }

    required init?(coder: NSCoder) {
        fatalError("NSCoder is not supported")
    }
    
    func setupRow(keyboardType: KeyboardType, _ keyCapGroups: [[KeyCap]], rowId: Int) {
        assert(keyCapGroups.count == 1 || keyCapGroups.count == 3)
        
        self.keyboardType = keyboardType
        self.rowId = rowId
        
        let leftKeyCaps, middleKeyCaps, rightKepCaps: [KeyCap]
        if keyCapGroups.count == 1 {
            leftKeyCaps = []
            middleKeyCaps = keyCapGroups[0]
            rightKepCaps = []
        } else {
            leftKeyCaps = keyCapGroups[0]
            middleKeyCaps = keyCapGroups[1]
            rightKepCaps = keyCapGroups[2]
        }
        
        prepareKeys(keyCaps: leftKeyCaps, keys: &leftKeys)
        prepareKeys(keyCaps: middleKeyCaps, keys: &middleKeys)
        prepareKeys(keyCaps: rightKepCaps, keys: &rightKeys, reuseKeyFromLeft: false)
    }
    
    private func prepareKeys(keyCaps: [KeyCap]?, keys: inout [KeyView], reuseKeyFromLeft: Bool = true) {
        guard let keyCaps = keyCaps,
              let layoutConstants = layoutConstants
            else { return }
        
        // Reuse keys. Only create/remove keys if necessary.
        
        // Create new keys if necessary.
        while keyCaps.count > keys.count {
            let newKey = KeyView(layoutConstants: layoutConstants)
            addSubview(newKey)
            if reuseKeyFromLeft {
                keys.append(newKey)
            } else {
                keys.insert(newKey, at: 0)
            }
        }
        
        // Remove extra keys to free memory.
        while keyCaps.count < keys.count {
            guard keys.count > 0 else { break }
            if reuseKeyFromLeft {
                keys.removeLast().removeFromSuperview()
            } else {
                keys.removeFirst().removeFromSuperview()
            }
        }
        
        for i in 0..<keyCaps.count {
            var keyCap = keyCaps[i]
            
            switch keyCap {
                case .nextKeyboard: keyCap = needsInputModeSwitchKey ? KeyCap.nextKeyboard : KeyCap.keyboardType(.emojis)
                default: ()
            }
            
            keys[i].keyCap = keyCap
        }
    }
}

// Layout related coded.
extension KeyRowView {
    private enum GroupLayoutDirection {
        case left, middle, right
    }
    
    override func layoutSubviews() {
        guard let layoutIdiom = layoutConstants?.ref.idiom else { return }
        switch layoutIdiom {
        case .phone: layoutPhoneSubviews()
        case .pad: layoutPadSubviews()
        }
    }
    
    private func layoutPhoneSubviews() {
        guard let layoutConstants = self.layoutConstants?.ref else { return }
        
        // First, put the keys to where they should be.
        let leftKeyFrames = layoutPhoneKeys(leftKeys, direction: .left, layoutConstants: layoutConstants)
        let middleKeyFrames = layoutPhoneKeys(middleKeys, direction: .middle, layoutConstants: layoutConstants)
        let rightKeyFrames = layoutPhoneKeys(rightKeys, direction: .right, layoutConstants: layoutConstants)
        
        let allKeys = leftKeys + middleKeys + rightKeys
        var allFrames = leftKeyFrames + middleKeyFrames + rightKeyFrames
        
        // Special case, widen the space key to fill the empty space.
        if rowId == 3 && middleKeys.count == 1, case .space = middleKeys.first!.keyCap {
            let thisKeyFrame = allFrames[leftKeyFrames.count]
            let spaceStartX = allFrames[leftKeyFrames.count - 1].maxX + layoutConstants.buttonGapX
            let spaceEndX = allFrames[leftKeyFrames.count + middleKeyFrames.count].minX - layoutConstants.buttonGapX
            allFrames[leftKeyFrames.count] = CGRect(x: spaceStartX, y: thisKeyFrame.minY, width: spaceEndX - spaceStartX, height: thisKeyFrame.maxY - thisKeyFrame.minY)
        }
        
        // Then, expand the keys to fill the void between keys.
        // In the stock keyboard, if the user tap between two keys, the event is sent to the nearest key.
        expandKeysToFillGap(allKeys, allFrames)
    }
    
    private func layoutPhoneKeys(_ keys: [KeyView], direction: GroupLayoutDirection, layoutConstants: LayoutConstants) -> [CGRect] {
        var x: CGFloat
        switch direction {
        case .left:
            x = directionalLayoutMargins.leading
        case .middle:
            let middleKeysCount = CGFloat(keys.count)
            let middleKeysWidth = keys.reduce(0, { $0 + getPhoneKeyWidth($1, layoutConstants) }) + (middleKeysCount - 1) * layoutConstants.buttonGapX
            x = (bounds.width - middleKeysWidth) / 2
        case .right:
            let rightKeysCount = CGFloat(keys.count)
            let rightKeysWidth = keys.reduce(0, { $0 + getPhoneKeyWidth($1, layoutConstants) }) + (rightKeysCount - 1) * layoutConstants.buttonGapX
            x = bounds.maxX - directionalLayoutMargins.trailing - rightKeysWidth
        }
        
        let frames: [CGRect] = keys.map { key in
            let keyWidth = getPhoneKeyWidth(key, layoutConstants)
            let rect = CGRect(x: x, y: layoutMargins.top, width: keyWidth, height: layoutConstants.keyHeight)
            x += keyWidth + layoutConstants.buttonGapX
            
            return rect
        }
        return frames
    }
    
    private func layoutPadSubviews() {
        guard let layoutConstants = layoutConstants?.ref else { return }
        
        let availableWidth = bounds.width - directionalLayoutMargins.leading - directionalLayoutMargins.trailing
        let rightShiftKeyWidth = layoutConstants.padLayoutConstants!.rightShiftKeyWidth
        let row3LeftGroupWidth = availableWidth - rightShiftKeyWidth - layoutConstants.buttonGapX
        let keyWidthRow3n4 = (row3LeftGroupWidth - 9 * layoutConstants.buttonGapX) / 10
        
        let allKeys: [KeyView]
        var allFrames: [CGRect]
        
        switch rowId {
        case 0:
            let keyWidth = (availableWidth - 10 * layoutConstants.buttonGapX) / 11
            var x = directionalLayoutMargins.leading
            
            allKeys = leftKeys + middleKeys + rightKeys
            allFrames = layoutPadKeys(keys: allKeys, keyWidth: keyWidth, layoutConstants: layoutConstants, x: &x)
        case 1:
            let leftInset: CGFloat = keyWidthRow3n4 / 2
            let lastKeyWidth = layoutConstants.padLayoutConstants!.returnKeyWidth
            let keyWidth = (availableWidth - leftInset - lastKeyWidth - 9 * layoutConstants.buttonGapX) / 9
            var x = directionalLayoutMargins.leading + leftInset
            
            allKeys = leftKeys + middleKeys + rightKeys
            allFrames = layoutPadKeys(keys: allKeys, keyWidth: keyWidth, layoutConstants: layoutConstants, x: &x)
            
            overrideLastFrame(frames: &allFrames, width: lastKeyWidth)
        case 2:
            var x = directionalLayoutMargins.leading
            allKeys = leftKeys + middleKeys + rightKeys
            allFrames = layoutPadKeys(keys: allKeys, keyWidth: keyWidthRow3n4, layoutConstants: layoutConstants, x: &x)
            
            overrideLastFrame(frames: &allFrames, width: rightShiftKeyWidth)
        case 3:
            let leftRightGroupWidth: CGFloat = 3 * keyWidthRow3n4 + 2 * layoutConstants.buttonGapX
            var x = directionalLayoutMargins.leading
            
            let leftKeyWidth = (leftRightGroupWidth - CGFloat(leftKeys.count - 1) * layoutConstants.buttonGapX) / CGFloat(leftKeys.count)
            let leftFrames = layoutPadKeys(keys: leftKeys, keyWidth: leftKeyWidth, layoutConstants: layoutConstants, x: &x)
            
            let middleGroupWidth: CGFloat = availableWidth - 2 * leftRightGroupWidth - 2 * layoutConstants.buttonGapX
            let middleKeyWidth = (middleGroupWidth - CGFloat(middleKeys.count - 1) * layoutConstants.buttonGapX) / CGFloat(middleKeys.count)
            let middleFrames = layoutPadKeys(keys: middleKeys, keyWidth: middleKeyWidth, layoutConstants: layoutConstants, x: &x)
            
            let rightKeyWidth: CGFloat = (leftRightGroupWidth - CGFloat(rightKeys.count - 1) * layoutConstants.buttonGapX) / CGFloat(rightKeys.count)
            let rightFrames = layoutPadKeys(keys: rightKeys, keyWidth: rightKeyWidth, layoutConstants: layoutConstants, x: &x)
            
            allKeys = leftKeys + middleKeys + rightKeys
            allFrames = leftFrames + middleFrames + rightFrames
        default: fatalError("Bug. Unexpected type \(rowId). Expecting .padRow(0...4).")
        }
        
        // Then, expand the keys to fill the void between keys.
        // In the stock keyboard, if the user tap between two keys, the event is sent to the nearest key.
        expandKeysToFillGap(allKeys, allFrames)
    }
    
    private func layoutPadKeys(keys: [KeyView], keyWidth: CGFloat, layoutConstants: LayoutConstants, x: inout CGFloat) -> [CGRect] {
        return keys.map { key in
            let rect = CGRect(x: x, y: layoutMargins.top, width: keyWidth, height: layoutConstants.keyHeight)
            x += rect.width + layoutConstants.buttonGapX
            
            return rect
        }
    }
    
    private func overrideLastFrame(frames: inout [CGRect], width: CGFloat) {
        if let lastFrame = frames.popLast() {
            frames.append(lastFrame.with(width: width))
        }
    }
    
    private func getPhoneKeyWidth(_ key: KeyView, _ layoutConstants: LayoutConstants) -> CGFloat {
        switch key.keyCap {
        case .shift, .capsLock, .keyboardType(.symbolic), .backspace:
            return layoutConstants.phoneLayoutConstants!.shiftKeyWidth
        case .returnKey:
            return 1.5 * layoutConstants.phoneLayoutConstants!.systemKeyWidth
        case .character, .cangjie, .contextualSymbols, .currency:
            return layoutConstants.phoneLayoutConstants!.letterKeyWidth
        default:
            return layoutConstants.phoneLayoutConstants!.systemKeyWidth
        }
    }
    
    private func expandKeysToFillGap(_ allKeys: [KeyView], _ allFrames: [CGRect]) {
        var startX = bounds.minX
        let allKeyCount = allKeys.count
        for (index, key) in allKeys.enumerated() {
            let isLastKey = index == allKeyCount - 1
            let thisKeyFrame = allFrames[index]
            
            if rowId == 0 {
                key.heightClearance = frame.minY + 8
            }
            key.frame = thisKeyFrame
            let midXBetweenThisAndNextKey = isLastKey ? bounds.maxX : (thisKeyFrame.maxX + allFrames[index + 1].minX) / 2
            let hitTestFrame = CGRect(x: startX, y: 0, width: midXBetweenThisAndNextKey - startX, height: bounds.height)
            key.hitTestFrame = hitTestFrame
            
            startX = midXBetweenThisAndNextKey
        }
    }
}

extension KeyRowView {
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
    }
}
