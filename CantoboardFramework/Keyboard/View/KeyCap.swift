//
//  KeyCap.swift
//  KeyboardKit
//
//  Created by Alex Man on 2/11/21.
//

import Foundation
import UIKit

/**
 This action enum specifies all currently supported keyboard
 actions and their standard behavior.
 
 Most actions have a standard behavior for a certain gesture
 when their used in system keyboards. This standard behavior
 is provided through `standardInputViewControllerAction` and
 `standardTextDocumentProxyAction`. Keyboard action handlers
 can choose to use these standard actions or ignore them.
 
 Many actions require manual handling since they do not have
 universal, app-agnostic behaviors. For instance, the `image`
 action depends on what you want to do with the tapped image.
 Actions like these are a way for you to express your intent,
 but require manual handling in a custom action handler.
*/
enum SpaceKeyMode: String {
    case space = "空格"
    case select = "選字"
    case nextPage = "下一頁"
}

enum KeyCap: Equatable, ExpressibleByStringLiteral {
    case
    none,
    backspace,
    capsLock,
    character(String),
    characterWithConditioanlPopup(String),
    cangjie(String),
    stroke(String),
    emoji(String),
    keyboardType(KeyboardType),
    returnKey(UIReturnKeyType?),
    nextKeyboard,
    space(SpaceKeyMode),
    shift(_ state: KeyboardShiftState),
    rime(RimeChar),
    contexualSymbols(ContextualType),
    reverseLookup(RimeSchema),
    changeSchema(RimeSchema),
    switchToEnglishMode,
    exportFile(String, String),
    exit
    
    private static let cangjieKeyCaps = ["日", "月", "金", "木", "水", "火", "土", "竹", "戈", "十", "大", "中", "一", "弓", "人", "心", "手", "口", "尸", "廿", "山", "女", "田", "難", "卜", "符"]
    
    public init(stringLiteral value: String) {
        self = .character(value)
    }
    
    var action: KeyboardAction {
        switch self {
        case .none: return .none
        case .backspace: return .backspace
        case .capsLock: return .capsLock
        case .character(let c): return .character(c)
        case .characterWithConditioanlPopup(let c): return .character(c)
        case .cangjie(let c): return .character(c)
        case .stroke(let c): return .character(c)
        case .emoji(let e): return .emoji(e)
        case .keyboardType(let type): return .keyboardType(type)
        case .returnKey: return .newLine
        case .nextKeyboard: return .nextKeyboard
        case .space: return .space
        case .shift(let shiftState): return .shift(shiftState)
        case .rime(let rc): return .rime(rc)
        case .contexualSymbols(.chinese): return "，"
        case .contexualSymbols(.english): return ","
        case .contexualSymbols(.rime): return .rime(.delimiter)
        case .contexualSymbols(.url): return "."
        case .reverseLookup(let s): return .reverseLookup(s)
        case .changeSchema(let s): return .changeSchema(s)
        case .switchToEnglishMode: return .toggleInputMode
        case .exportFile(let namePrefix, let path): return .exportFile(namePrefix, path)
        case .exit: return .exit
        }
    }
    
    var buttonFont: UIFont {
        switch self {
        case .keyboardType(.symbolic), .returnKey(.emergencyCall): return UIFont.systemFont(ofSize: 12)
        case .rime, "^_^", .keyboardType, .returnKey, .space, .contexualSymbols(.rime): return UIFont.systemFont(ofSize: 16)
        case .character(let c), .characterWithConditioanlPopup(let c):
            if let c = c.first {
                if c.isEnglishLetter { return UIFont(name: "CustomFont", size: 24)! }
                if c.isASCII { return UIFont(name: "CustomFont", size: 22)! }
            }
        default: ()
        }
        return UIFont.systemFont(ofSize: 22)
    }
    
    var popupFont: UIFont {
        switch self {
        case .reverseLookup, .rime(.delimiter), .rime(.sym): return UIFont.systemFont(ofSize: 24)
        case .exportFile, .exit: return UIFont.systemFont(ofSize: 12)
        case .rime, "……", "⋯⋯", "——", "^_^", ".com", ".net", ".org", ".edu": return UIFont.systemFont(ofSize: 16)
        case .character(let c) where c.first?.isASCII ?? false: return UIFont(name: "CustomFont", size: 30)!
        default: return UIFont.systemFont(ofSize: 30)
        }
    }
    
    var buttonBgColor: UIColor {
        switch self {
        case .character, .characterWithConditioanlPopup, .cangjie, .stroke, .space, .contexualSymbols: return ButtonColor.inputKeyBackgroundColor
        case .shift(.uppercased), .shift(.capsLocked): return ButtonColor.shiftKeyHighlightedBackgroundColor
        case .returnKey(nil), .returnKey(.default), .returnKey(.next), .returnKey(.continue): return ButtonColor.systemKeyBackgroundColor
        case .returnKey(_): return UIColor.systemBlue
        default: return ButtonColor.systemKeyBackgroundColor
        }
    }
    
    var buttonBgHighlightedColor: UIColor? {
        switch self {
        case .character, .characterWithConditioanlPopup, .cangjie, .contexualSymbols, .shift(.uppercased), .shift(.capsLocked): return nil
        case .space: return ButtonColor.spaceKeyHighlightedBackgroundColor
        default: return ButtonColor.systemHighlightedKeyBackgroundColor
        }
    }
    
    var keypadButtonBgHighlightedColor: UIColor? {
        switch self {
        case .keyboardType, .backspace, .none, .returnKey: return ButtonColor.systemHighlightedKeyBackgroundColor
        default: return ButtonColor.spaceKeyHighlightedBackgroundColor
        }
    }
    
    var buttonFgColor: UIColor {
        switch self {
        case .returnKey(nil), .returnKey(.default), .returnKey(.next), .returnKey(.continue): return ButtonColor.keyForegroundColor
        case .returnKey(_): return UIColor.white
        case .shift(.uppercased), .shift(.capsLocked): return ButtonColor.shiftKeyHighlightedForegroundColor
        default: return ButtonColor.keyForegroundColor
        }
    }
    
    var buttonHintFgColor: UIColor {
        return ButtonColor.keyHintColor
    }
    
    // TODO Return images < iOS 12
    var buttonImage: UIImage? {
        switch self {
        case .backspace: return ButtonImage.backspace
        case .nextKeyboard: return ButtonImage.globe
        case .shift(.lowercased): return ButtonImage.shift
        case .shift(.uppercased): return ButtonImage.shiftFilled
        case .shift(.capsLocked): return ButtonImage.capLockFilled
        // case .keyboardType(.numeric): return ButtonImage.oneTwoThree
        default: return nil
        }
    }
    
    var buttonText: String? {
        switch self {
        case .characterWithConditioanlPopup(let text): return text
        case .returnKey(nil): return "確認"
        case .returnKey(.default): return "換行"
        case .returnKey(.go): return "前往"
        case .returnKey(.search), .returnKey(.google), .returnKey(.yahoo): return "搜尋"
        case .returnKey(.join): return "加入"
        case .returnKey(.next): return "下一個"
        case .returnKey(.route): return "路線"
        case .returnKey(.send): return "傳送"
        case .returnKey(.done): return "完成"
        case .returnKey(.emergencyCall): return "緊急電話"
        case .returnKey(.continue): return "繼續"
        case .space(let label): return label.rawValue
        case .keyboardType(.numeric): return "123"
        case .keyboardType(.symbolic): return "#+="
        case .keyboardType(.alphabetic): return "ABC"
        case .rime(.tone1): return "陰平"
        case .rime(.tone2): return "陰上"
        case .rime(.tone3): return "陰去"
        case .rime(.tone4): return "陽平"
        case .rime(.tone5): return "陽上"
        case .rime(.tone6): return "陽去"
        case .rime(.delimiter): return "隔"
        case .rime(.sym): return "符"
        case .reverseLookup(let schema): return schema.signChar
        case .changeSchema(let schema): return schema.shortName
        case .switchToEnglishMode: return "英文"
        case .contexualSymbols(.chinese): return "，"
        case .contexualSymbols(.english): return ","
        case .contexualSymbols(.rime): return "隔"
        case .contexualSymbols(.url): return "."
        // case "^_^": return "^͟^"
        case .character(let text) where "（［｛〈《「".contains(text): return text + "　"
        case .character(let text) where "）］｝〉》」".contains(text): return "  " + text
        case .character(let text): return text
        case .cangjie(let c):
            guard let asciiCode = c.lowercased().first?.asciiValue else { return nil }
            let letterIndex = Int(asciiCode - "a".first!.asciiValue!)
            return Self.cangjieKeyCaps[safe: letterIndex] ?? c
        case .stroke(let c):
            switch c.lowercased() {
            case "h": return "一"
            case "s": return "丨"
            case "p": return "丿"
            case "n": return "丶"
            case "z": return "乙"
            default: return nil
            }
        case .exportFile("user", _): return "用戶檔"
        case .exportFile("logs", _): return "紀錄檔"
        case .exit: return "退出"
        default: return nil
        }
    }
    
    var buttonHint: String? {
        if Settings.cached.toneInputMode == .longPress {
            switch self {
            case .characterWithConditioanlPopup("F"), .characterWithConditioanlPopup("f"): return "4"
            case .characterWithConditioanlPopup("G"), .characterWithConditioanlPopup("g"): return "5"
            case .characterWithConditioanlPopup("H"), .characterWithConditioanlPopup("h"): return "6"
            case .characterWithConditioanlPopup("C"), .characterWithConditioanlPopup("c"): return "1"
            case .characterWithConditioanlPopup("V"), .characterWithConditioanlPopup("v"): return "2"
            case .characterWithConditioanlPopup("B"), .characterWithConditioanlPopup("b"): return "3"
            case .rime(.tone1): return "1"
            case .rime(.tone2): return "2"
            case .rime(.tone3): return "3"
            case .rime(.tone4): return "4"
            case .rime(.tone5): return "5"
            case .rime(.tone6): return "6"
            default: ()
            }
        } else {
            switch self {
            case "V", "v": return "1/4"
            case "X", "x": return "2/5"
            case "Q", "q": return "3/6"
            default: ()
            }
        }
        
        switch self {
        case .characterWithConditioanlPopup("R"), .characterWithConditioanlPopup("r"): return "反"
        case .contexualSymbols(.chinese), .contexualSymbols(.english): return "符"
        case .contexualSymbols(.url): return "/"
        case .space: return "Cantoboard"
        default: return nil
        }
    }
    
    var barHint: String? {
        switch self {
        case "，", "。", "？", "！", "—", "——", "＆", "．",
             "－", "／", "：", "；", "（", "）", "＠", "、", "⋯", "⋯⋯",
             "１", "２", "３", "４", "５", "６", "７", "８", "９", "０",
             "［", "］", "｛", "｝", "＃", "％", "＾", "＊", "＋", "＝",
             "＿", "＼", "｜", "～", "〈", "〉", "《", "》", "＜", "＞",
             "￠", "＄", "￡", "￥", "￦", "＂", "＇", "「", "」": return "全"
        default: return nil
        }
    }
    
    var buttonHintFontSize: CGFloat {
        let layoutConstants = LayoutConstants.forMainScreen
        if Settings.cached.toneInputMode == .vxq {
            switch self {
            case .character("V"), .character("v"),
                 .character("X"), .character("x"),
                 .character("Q"), .character("q"):
                return layoutConstants.smallKeyHintFontSize
            default: ()
            }
        }
        
        return layoutConstants.mediumKeyHintFontSize
    }
    
    func buttonWidth(_ layoutConstants: LayoutConstants) -> CGFloat {
        switch self {
        case .shift, .capsLock, .keyboardType(.symbolic), .backspace:
            return layoutConstants.shiftButtonWidth
        case .returnKey:
            return 1.5 * layoutConstants.systemButtonWidth
        case .character, .characterWithConditioanlPopup, .cangjie, .contexualSymbols:
            return layoutConstants.keyButtonWidth
        default:
            return layoutConstants.systemButtonWidth
        }
    }
    
    var hasPopup: Bool {
        switch self {
        case .character, .characterWithConditioanlPopup, .contexualSymbols, .cangjie: return true
        // For debugging
        case .keyboardType(.emojis): return true
        default: return false
        }
    }
    
    private static var logsPath: String = DataFileManager.logsDirectory
    private static let userDataPath: String = DataFileManager.userDataDirectory
    
    var childrenKeyCaps: [KeyCap] {
        switch self {
        case .characterWithConditioanlPopup(let c):
            switch c {
            case "F", "f": return [.character(c), .rime(RimeChar.tone4)]
            case "G", "g": return [.character(c), .rime(RimeChar.tone5)]
            case "H", "h": return [.character(c), .rime(RimeChar.tone6)]
            case "C", "c": return [.character(c), .rime(RimeChar.tone1)]
            case "V", "v": return [.character(c), .rime(RimeChar.tone2)]
            case "B", "b": return [.character(c), .rime(RimeChar.tone3)]
            case "R", "r": return [.character(c), .reverseLookup(.cangjie), .reverseLookup(.quick), .reverseLookup(.mandarin), .reverseLookup(.loengfan), .reverseLookup(.stroke)]
            default: return [self]
            }
        case .contexualSymbols(.chinese): return ["。", "，", "？", "！", ".", ",", .rime(.sym)]
        case .contexualSymbols(.english): return [".", ",", "?", "!", "。", "，", .rime(.sym)]
        case .contexualSymbols(.rime): return [self, ".", ",", "?", "!"]
        case .contexualSymbols(.url): return ["/", ".", ".com", ".net", ".org", ".edu", .rime(.delimiter)]
        case .keyboardType(.emojis): return [.exportFile("user", Self.userDataPath), .exportFile("logs", Self.logsPath), .exit]
        // 123 1st row
        case "1": return ["1", "一", "壹", "１", "①", "⑴", "⒈", "❶", "㊀", "㈠"]
        case "2": return ["貳", "2", "二", "２", "②", "⑵", "⒉", "❷", "㊁", "㈡"]
        case "3": return ["③", "叁", "3", "三", "３", "⑶", "⒊", "❸", "㊂", "㈢"]
        case "4": return ["⒋", "④", "肆", "4", "四", "４", "⑷", "❹", "㊃", "㈣"]
        case "5": return ["㊄", "⒌", "⑤", "伍", "5", "五", "５", "⑸", "❺", "㈤"]
        case "6": return ["❻", "⑹", "６", "六", "6", "陸", "⑥", "⒍", "㊅", "㈥"]
        case "7": return ["⑺", "７", "七", "7", "柒", "⑦", "⒎", "❼", "㊆", "㈦"]
        case "8": return ["８", "八", "8", "捌", "⑧", "⑻", "⒏", "❽", "㊇", "㈧"]
        case "9": return ["九", "9", "玖", "９", "⑨", "⑼", "⒐", "❾", "㊈", "㈨"]
        case "0": return ["0", "０", "零", "十", "拾", "⓪", "°"]
        // 123 2nd row
        case "-": return ["-", "－", "—", "——", "–", "•"]
        case "/": return ["/", "／", "\\"]
        case ":": return [":", "："]
        case ";": return [";", "；"]
        case "(": return ["(", "（"]
        case ")": return [")", "）"]
        case "$": return ["¢", "$", "€", "£", "¥", "₩", "₽"]
        case "\"": return ["\"", "＂", "”", "“", "„", "»", "«"]
        case "｢": return ["｢", "「", "『", "“", "‘"]
        case "｣": return ["｣", "」", "』", "”", "’"]
        // 123 3rd row
        case ".": return [".", "。", "．"]
        case ",": return [",", "，"]
        case "､": return ["､", "、"]
        case "?": return ["?", "？", "¿"]
        case "!": return ["!", "！", "¡"]
        case "'": return ["'", "＇", "’", "‘", "`"]
        // 123 4rd row
        case "…": return ["…", "……", "⋯", "⋯⋯"]
        // #+= 1st row
        case "[": return ["[", "［", "【", "〔"]
        case "]": return ["]", "］", "】", "〕"]
        case "{": return ["{", "｛"]
        case "}": return ["}", "｝"]
        case "#": return ["#", "＃"]
        case "%": return ["%", "％", "‰"]
        case "^": return ["^", "＾"]
        case "*": return ["*", "＊"]
        case "+": return ["+", "＋"]
        case "=": return ["=", "≠", "≈", "＝"]
        // #+= 2nd row
        case "_": return ["_", "＿"]
        case "\\": return ["\\", "＼"]
        case "|": return ["|", "｜"]
        case "~": return ["~", "～"]
        case "<": return ["<", "〈", "＜"]
        case ">": return [">", "〉", "＞"]
        case "«": return ["«", "《"]
        case "»": return ["»", "》"]
        case "&": return ["＆", "&", "§"]
        case "•": return ["•", "·", "．", "°"]
        // #+= 4rd row
        case "@": return ["@", "＠"]
        // 123 1st row full width
        case "１": return ["１", "一", "壹", "1", "①", "⑴", "⒈", "❶", "㊀", "㈠"]
        case "２": return ["貳", "２", "二", "2", "②", "⑵", "⒉", "❷", "㊁", "㈡"]
        case "３": return ["③", "叁", "３", "三", "3", "⑶", "⒊", "❸", "㊂", "㈢"]
        case "４": return ["⒋", "④", "肆", "４", "四", "4", "⑷", "❹", "㊃", "㈣"]
        case "５": return ["㊄", "⒌", "⑤", "伍", "５", "五", "5", "⑸", "❺", "㈤"]
        case "６": return ["❻", "⑹", "6", "六", "６", "陸", "⑥", "⒍", "㊅", "㈥"]
        case "７": return ["⑺", "7", "七", "７", "柒", "⑦", "⒎", "❼", "㊆", "㈦"]
        case "８": return ["8", "八", "８", "捌", "⑧", "⑻", "⒏", "❽", "㊇", "㈧"]
        case "９": return ["九", "９", "玖", "9", "⑨", "⑼", "⒐", "❾", "㊈", "㈨"]
        case "０": return ["０", "0", "零", "十", "拾", "⓪", "°"]
        // 123 2nd row full width
        case "—": return ["—", "——", "－", "-", "–", "•"]
        case "／": return ["／", "/", "\\"]
        case "：": return ["：", ":"]
        case "；": return ["；", ";"]
        case "（": return ["（", "("]
        case "）": return ["）", ")"]
        case "＄": return ["￠", "$", "＄", "€", "￡", "￥", "￦", "₽"]
        case "＂": return ["＂", "\"", "”", "“", "c", "»", "«"]
        case "「": return ["「", "｢", "『", "“", "‘"]
        case "」": return ["」", "｣", "』", "”", "’"]
        // 123 3rd row full width
        case "。": return ["。", ".", "．"]
        case "，": return ["，", ","]
        case "、": return ["､", "、"]
        case "？": return ["？", "?", "¿"]
        case "！": return ["！", "!", "¡"]
        case "＇": return ["＇", "'", "’", "‘", "｀"]
        // 123 4rd row full width
        case "⋯": return ["⋯", "⋯⋯", "…", "……"]
        // #+= 1st row full width
        case "［": return ["［", "[", "【", "〔"]
        case "］": return ["］", "]", "】", "〕"]
        case "｛": return ["｛", "{"]
        case "｝": return ["｝", "}"]
        case "＃": return ["＃", "#"]
        case "％": return ["％", "%", "‰"]
        case "＾": return ["＾", "^"]
        case "＊": return ["＊", "*"]
        case "＋": return ["＋", "+"]
        case "＝": return ["＝", "=", "≠", "≈"]
        // #+= 2nd row full width
        case "＿": return ["＿", "_"]
        case "＼": return ["＼", "\\"]
        case "｜": return ["｜", "|"]
        case "～": return ["～", "~"]
        case "〈": return ["〈", "<", "＜"]
        case "〉": return ["〉", ">", "＞"]
        case "《": return ["《", "«"]
        case "》": return ["》", "»"]
        case "＆": return ["&", "＆", "§"]
        case "·": return ["·", "．", "•", "°"]
        // #+= 4rd row full width
        case "＠": return ["＠", "@"]
        default: return [self]
        }
    }
    
    var defaultChildKeyCap: KeyCap? {
        self
    }
}

let FrameworkBundle = Bundle(for: KeyView.self)

class ButtonImage {
    static let globe = UIImage(named: "globe", in: Bundle(for: ButtonImage.self), with: nil)
    static let backspace = UIImage(named: "delete.left", in: Bundle(for: ButtonImage.self), with: nil)
    static let shift = UIImage(named: "shift", in: Bundle(for: ButtonImage.self), with: nil)
    static let shiftFilled = UIImage(named: "shift.fill", in: Bundle(for: ButtonImage.self), with: nil)
    static let capLockFilled = UIImage(named: "capslock.fill", in: Bundle(for: ButtonImage.self), with: nil)
    static let emojiKeyboardLight = UIImage(named: "face.smiling", in: Bundle(for: ButtonImage.self), with: UIImage.SymbolConfiguration(pointSize: 18))
    static let emojiKeyboardDark = UIImage(named: "face.smiling.fill", in: Bundle(for: ButtonImage.self), with: UIImage.SymbolConfiguration(pointSize: 18))
    static let paneCollapseButtonImage = UIImage(named: "chevron.up", in: Bundle(for: ButtonImage.self), with: nil)
    static let paneExpandButtonImage = UIImage(named: "chevron.down", in: Bundle(for: ButtonImage.self), with: nil)
    // static let oneTwoThree = UIImage(systemName: "textformat.123", in: Bundle(for: ButtonImage.self), with: nil)
}

class ButtonColor {
    static let systemKeyBackgroundColor = UIColor(named: "systemKeyBackgroundColor", in: FrameworkBundle, compatibleWith: nil)!
    static let inputKeyBackgroundColor = UIColor(named: "inputKeyBackgroundColor", in: FrameworkBundle, compatibleWith: nil)!
    static let keyForegroundColor = UIColor(named: "keyForegroundColor", in: FrameworkBundle, compatibleWith: nil)!
    static let keyHintColor = UIColor(named: "keyHintColor", in: FrameworkBundle, compatibleWith: nil)!
    static let popupBackgroundColor = UIColor(named: "PopupBackgroundColor", in: FrameworkBundle, compatibleWith: nil)!
    static let keyShadowColor = UIColor(named: "keyShadowColor", in: FrameworkBundle, compatibleWith: nil)!
    static let shiftKeyHighlightedBackgroundColor = UIColor(named: "ShiftKeyHighlightedBackgroundColor", in: FrameworkBundle, compatibleWith: nil)!
    static let shiftKeyHighlightedForegroundColor = UIColor(named: "ShiftKeyHighlightedForegroundColor", in: FrameworkBundle, compatibleWith: nil)!
    static let spaceKeyHighlightedBackgroundColor = UIColor(named: "spaceKeyHighlightedBackgroundColor", in: FrameworkBundle, compatibleWith: nil)!
    static let systemHighlightedKeyBackgroundColor = UIColor(named: "systemHighlightedKeyBackgroundColor", in: FrameworkBundle, compatibleWith: nil)!
}
