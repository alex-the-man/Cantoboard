//
//  EnglishInputEngine.swift
//  KeyboardKit
//
//  Created by Alex Man on 1/20/21.
//

import Foundation
import UIKit

import CocoaLumberjackSwift

class InputTextBuffer {
    private(set) var _text: String
    private(set) var caretIndex: String.Index
    
    init() {
        _text = ""
        caretIndex = _text.endIndex
    }
    
    func insert(char: Character) {
        _text.insert(char, at: caretIndex)
        guard caretIndex != _text.endIndex else { return }
        caretIndex = _text.index(after: caretIndex)
        
        textOverride = nil
    }
        
    func moveCaret(offset: Int) -> Bool {
        guard abs(offset) == 1 else {
            DDLogInfo("moveCaret offset \(offset) not supproted.")
            return false
        }
        
        let isMovingLeft = offset < 0
        if isMovingLeft {
            guard caretIndex != _text.startIndex else { return false }
            caretIndex = _text.index(before: caretIndex)
            return true
        } else {
            guard caretIndex != _text.endIndex else { return false }
            caretIndex = _text.index(after: caretIndex)
            return true
        }
    }
    
    func setCaret(position: Int) -> Bool {
        guard 0 <= position && position <= _text.count else {
            DDLogInfo("setCaret position \(position) is OOB. Text length: \(_text.count)")
            return false
        }
        
        caretIndex = _text.index(_text.startIndex, offsetBy: position)
        return true
    }
    
    func clear() {
        _text = ""
        caretIndex = _text.endIndex
        textOverride = nil
    }
    
    func backspace() -> Bool {
        guard caretIndex != _text.startIndex else { return false }
        _text.remove(at: _text.index(before: caretIndex))
        _ = moveCaret(offset: -1)
        textOverride = nil
        return true
    }
    
    var caretPosition: Int {
        get {
            _text.distance(from: _text.startIndex, to: caretIndex)
        }
    }
    
    var textOverride: String?
    
    var text: String {
        textOverride == nil ? _text : textOverride!
    }
}

class EnglishInputEngine: InputEngine {
    static var language = Settings.cached.englishLocale.rawValue {
        didSet {
            englishDictionary = DefaultDictionary(locale: language)
        }
    }
    static var userDictionary = UserDictionary()
    
    private static let highFreqSuffixes = ["'m", "'t", "let's", "he's", "'ve", "'re", "what's", "this's", "that's", "which's", "these're", "there're"]
    private static let textChecker = UITextChecker()
    private(set) static var englishDictionary = DefaultDictionary(locale: language)
    
    private var inputTextBuffer = InputTextBuffer()
    var textBeforeInput: String?
    
    private(set) var candidates: [String] = []
    private(set) var isWord: Bool = false
    private(set) var prefectCandidatesStartIndex = 0, worstCandidatesStartIndex = 0
    
    init() {
        DispatchQueue.global(qos: .background).async {
            _ = Self.englishDictionary
        }
    }
    
    func processChar(_ char: Character) -> Bool {
        if char.isASCII {
            inputTextBuffer.insert(char: char)
            updateCandidates()
            return true
        }
        return false
    }
    
    func moveCaret(offset: Int) -> Bool {
        _ = inputTextBuffer.moveCaret(offset: offset)
        return false
    }
    
    func setCaret(position: Int) -> Bool {
        _ = inputTextBuffer.setCaret(position: position)
        return false
    }
    
    func clearInput() {
        inputTextBuffer.clear()
        updateCandidates()
    }
    
    func processBackspace() -> Bool {
        if inputTextBuffer.backspace() {
            updateCandidates()
            return true
        }
        return false
    }
    
    private func lookupInDictionary(wordLowercased: String) -> Set<String> {
        let englishDictionary = Self.englishDictionary
        let userDictionary = Self.userDictionary
        
        let defaultEnglishDictionaryWords = englishDictionary.getWords(wordLowercased: wordLowercased)
        let userDictionaryWords = userDictionary.getWords(wordLowercased: wordLowercased)
        let englishDictionaryWords = defaultEnglishDictionaryWords + userDictionaryWords
        let englishDictionaryWordsSet = englishDictionaryWords.mapToSet({ $0 })
        return englishDictionaryWordsSet
    }
    
    private func updateCandidates() {
        let text = inputTextBuffer.text, textLowercased = text.lowercased()
        guard !text.isEmpty && text.count < 25 else {
            isWord = false
            candidates = [text]
            prefectCandidatesStartIndex = 0
            worstCandidatesStartIndex = 0
            return
        }
        
        let documentContextBeforeInput = textBeforeInput
        let combined = (documentContextBeforeInput ?? "") + text
        let wordRange = combined.index(combined.endIndex, offsetBy: -text.count)..<combined.endIndex
        let nsWordRange = NSRange(wordRange, in: combined)
        
        let textChecker = Self.textChecker
        
        let isInAppleDictionary = textChecker.rangeOfMisspelledWord(in: combined, range: nsWordRange, startingAt: 0, wrap: false, language: Self.language).location == NSNotFound
        let englishDictionaryWordsSet = lookupInDictionary(wordLowercased: textLowercased).filter({ $0.count > 1 })
        var candidateSets = Set<String>()
        
        isWord = (!englishDictionaryWordsSet.isEmpty || text.allSatisfy({ $0.isUppercase }))
        
        candidates = []
        var worstCandidates: [String] = []
        prefectCandidatesStartIndex = 0
        worstCandidatesStartIndex = 0
        
        let spellCorrectionCandidates = textChecker.guesses(forWordRange: nsWordRange, in: combined, language: Self.language) ?? []
        
        // If the user is typing a word after an English word, run autocomplete.
        let autoCompleteCandidates: [String]
        if documentContextBeforeInput?.suffix(2).first?.isEnglishLetter ?? false {
            autoCompleteCandidates = textChecker.completions(forPartialWordRange: nsWordRange, in: combined, language: Self.language) ?? []
        } else {
            autoCompleteCandidates = []
        }
        
        if text.allSatisfy({ $0.isUppercase }) && text.count > 1 {
            candidateSets.insert(text)
            candidates.append(text)
            prefectCandidatesStartIndex += 1
        } else if text == "i" {
            candidateSets.insert("I")
            candidates.append("I")
            prefectCandidatesStartIndex += 1
        }
        
        englishDictionaryWordsSet.forEach({ word in
            var word = word
            if text.first!.isUppercase && word.first!.isLowercase && word.allSatisfy({ $0.isLowercase }) {
                word = word.capitalized
            }
            if candidateSets.contains(word) { return }
            if word == text {
                candidates.insert(word, at: 0)
            } else {
                candidates.append(word)
            }
            candidateSets.insert(word)
            prefectCandidatesStartIndex += 1
        })
        
        // TODO This's a hack to rule out words like Liu,Jiu which Apple considers as words.
        if isInAppleDictionary && !candidateSets.contains(text) {
            candidates.append(text)
            candidateSets.insert(text)
        }
        
        // If the dictionary doesn't contain the input word, but iOS considers it as a word, demote it.
        if isInAppleDictionary && !isWord && !candidateSets.contains(text) {
            worstCandidates.append(text)
            candidateSets.insert(text)
        }
        
        for word in spellCorrectionCandidates + autoCompleteCandidates {
            let wordLowercased = word.lowercased()
            if word.isEmpty || word == text || candidateSets.contains(word) {
                continue // We added the word already. Ignore.
            } else if Self.highFreqSuffixes.contains(where: { wordLowercased.hasSuffix($0) }) && word.filter({ $0.isEnglishLetter }).caseInsensitiveCompare(text) == .orderedSame {
                // Special case for correcting patterns like cant -> can't. lets -> let's.
                candidates.insert(word, at: 0)
                candidateSets.insert(word)
                prefectCandidatesStartIndex += 1
                isWord = true
            } else if word.contains(where: { $0 == " " || $0 == "-" }) {
                worstCandidates.append(word)
                candidateSets.insert(word)
            } else {
                let caseCorrectedCandidate = text.first!.isUppercase && word.first!.isLowercase ? word.capitalized : word
                if candidateSets.contains(caseCorrectedCandidate) { continue }
                if !lookupInDictionary(wordLowercased: word.lowercased()).isEmpty {
                    candidates.append(caseCorrectedCandidate)
                } else {
                    worstCandidates.append(caseCorrectedCandidate)
                }
                candidateSets.insert(caseCorrectedCandidate)
            }
        }
        
        worstCandidatesStartIndex = candidates.count
        candidates.append(contentsOf: worstCandidates)
        
        // DDLogInfo("English candidates \(candidates)")
    }
    
    func selectCandidate(_ index: Int) -> String? {
        return candidates[safe: index]
    }
    
    var composition: Composition? {
        get {
            return Composition(text: inputTextBuffer.text, caretIndex: inputTextBuffer.caretPosition)
        }
    }
}
