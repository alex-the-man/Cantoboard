//
//  Character+Extension.swift
//  KeyboardKit
//
//  Created by Alex Man on 2/11/21.
//

import Foundation

extension Character {
    var isEnglishLetter: Bool {
        isASCII && isLetter
    }
    
    var isEnglishLetterOrDigit: Bool {
        isASCII && (isLetter || isNumber)
    }
    
    var isPunctuation: Bool {
        // TODO Distingish apostrophe & single quote.
        self == ":" || self == ";" || self == "." || self == "," || self == "?" || self == "!" || self == "'" || self ==  "\n" ||
            self == ")" || self == "}" || self == "]" ||
            isFullShapePunctuation
    }
    
    var isFullShapePunctuation: Bool {
        self == "，" || self == "。" || self == "？" || self == "！"
    }
    
    var isHalfShapeTerminalPunctuation: Bool {
        // TODO Distingish apostrophe & single quote.
        self == "." || self == "?" || self == "!"
    }
    
    var isFullShapeTerminalPunctuation: Bool {
        self == "。" || self == "？" || self == "！"
    }
    
    var couldBeFollowedBySmartSpace: Bool {
        self != ":" && self != ";" && self != "." && self != "," && self != "?" && self != "!" && self != " " &&
        self != "，" && self != "。" && self != "？" && self != "！"
    }
    
    var lowercasedChar: Character {
        lowercased().first!
    }
    
    var isRimeSpecialChar: Bool {
        let isFixedRimeSpecialChar = self == "'" || self == "/"
        let isModeDependentRimeSpecialChar = Settings.cached.toneInputMode == .longPress ? isNumber : false
        return isFixedRimeSpecialChar || isModeDependentRimeSpecialChar
    }
    
    var isChineseChar: Bool {
        !isASCII && self != "､" && self != "｢" && self != "｣" && self != "«" && self != "»" && self != "•" && self != "…"
        /* TODO if char is in CJK range */
    }
    
    var isVowel: Bool {
        return self == "a" || self == "e" || self == "i" || self == "o" || self == "u" ||
            self == "A" || self == "E" || self == "I" || self == "O" || self == "U"
    }
    
    var needsAdjustment: Bool {
        !isNumber && !isChineseChar && !isUppercase
    }
}
