//
//  CandidateOrganizer.swift
//  CantoboardFramework
//
//  Created by Alex Man on 3/19/21.
//

import Foundation

enum GroupByMode {
    case byFrequency, byRomanization, byRadical, byTotalStroke
    
    var title: String {
        switch self {
        case .byFrequency: return "詞頻"
        case .byRomanization: return "粵拼"
        case .byRadical: return "部首"
        case .byTotalStroke: return "筆畫"
        }
    }
}

protocol CandidateSource: class {
    func updateCandidates(reload: Bool)
    func getNumberOfSections() -> Int
    func getCandidate(indexPath: IndexPath) -> String?
    func selectCandidate(indexPath: IndexPath) -> String?
    func getCandidateComment(indexPath: IndexPath) -> String?
    func getCandidateCount(section: Int) -> Int
    func getSectionHeader(section: Int) -> String?
    var supportedGroupByModes: [GroupByMode] { get }
    var groupByMode: GroupByMode { get set }
}

class InputEngineCandidateSource: CandidateSource {
    private static let unihanDict: LevelDbTable = LevelDbTable(DataFileManager.builtInUnihanDictDirectory, createDbIfMissing: false)
    private static let radicalChars = [Int](0..<214).map({ String(Character(Unicode.Scalar(0x2F00 + $0)!)) })
    
    private var candidatePaths: [[CandidatePath]] = []
    private var sectionHeaders: [String] = []
    private var curRimeCandidateIndex = 0
    private var hasLoadedAllBestRimeCandidates = false
    private var hasPopulatedPrefectEnglishCandidates = false, hasPopulatedBestEnglishCandidates = false, hasPopulatedWorstEnglishCandidates = false
    private weak var inputController: InputController?
    private var _groupByMode = GroupByMode.byFrequency

    init(inputController: InputController) {
        self.inputController = inputController
    }
    
    private func resetCandidates() {
        curRimeCandidateIndex = 0
        
        candidatePaths = []
        sectionHeaders = []
        
        hasLoadedAllBestRimeCandidates = false
        hasPopulatedPrefectEnglishCandidates = false
        hasPopulatedBestEnglishCandidates = false
        hasPopulatedWorstEnglishCandidates = false
    }
    
    private func populateCandidates() {
        switch groupByMode {
        case .byFrequency: populateCandidatesByFreq()
        case .byRomanization: populateCandidatesByRomanization()
        case .byRadical: populateCandidatesByRadical()
        case .byTotalStroke: populateCandidatesByTotalStroke()
        }
    }
    
    private func populateCandidatesByFreq() {
        guard let inputController = inputController,
              let inputEngine = inputController.inputEngine else { return }
        let inputMode = inputController.state.inputMode
        let doesSchemaSupportMixedMode = inputEngine.rimeSchema.supportMixedMode
        let isInRimeOnlyMode = inputEngine.isForcingRimeMode || !doesSchemaSupportMixedMode
        let isEnglishActive = inputMode == .english || inputMode == .mixed && !isInRimeOnlyMode
        let englishCandidates = inputEngine.englishCandidates
        
        if candidatePaths.isEmpty {
            candidatePaths.append([])
        }
        
        let rawInputWithoutDigits = inputEngine.englishComposition?.text.lowercased() ?? ""
        var demotedEnglishCandidateIndices: [Int] = []
        
        // If input is an English word, insert best English candidates first.
        if !hasPopulatedPrefectEnglishCandidates && isEnglishActive {
            for i in 0..<inputEngine.englishPrefectCandidatesStartIndex {
                if inputMode == .english || englishCandidates[i].lowercased() != rawInputWithoutDigits.lowercased() {
                    candidatePaths[0].append(CandidatePath(source: .english, index: i))
                } else {
                    demotedEnglishCandidateIndices.append(i)
                }
            }
            hasPopulatedPrefectEnglishCandidates = true
        }
        
        let firstRimeCandidateLength = inputEngine.getRimeCandidate(0)?.count ?? 0
        let firstRimeCode = (inputEngine.getRimeCandidateComment(0) ?? "").lowercased().filter({ !$0.isNumber && $0 != " " })
        let composeTextFirstRimeCodeLCS = rawInputWithoutDigits.longestCommonSubsequence(firstRimeCode)
        let isRimeExactMatch = composeTextFirstRimeCodeLCS.count == rawInputWithoutDigits.count
        //let isRimeExactMatch = firstRimeCode.starts(with: rawInputWithoutDigits)

        if !isRimeExactMatch { hasLoadedAllBestRimeCandidates = true }
        
        // Populate the best Rime candidates. It's in the best candidates set if the user input is the prefix of candidate's composition.
        while inputMode != .english &&
              isRimeExactMatch &&
              !hasLoadedAllBestRimeCandidates &&
              curRimeCandidateIndex < inputEngine.rimeLoadedCandidatesCount {
            guard let candidate = inputEngine.getRimeCandidate(curRimeCandidateIndex) else {
                hasLoadedAllBestRimeCandidates = true
                break
            }
            
            if firstRimeCandidateLength - candidate.count > 0 {
                hasLoadedAllBestRimeCandidates = true
                break
            }
            
            candidatePaths[0].append(CandidatePath(source: .rime, index: curRimeCandidateIndex))
            curRimeCandidateIndex += 1
        }
        
        // Do not populate remaining English candidates until all best Rime candidates are populated.
        if !hasLoadedAllBestRimeCandidates && inputMode != .english && !inputEngine.hasRimeLoadedAllCandidates { return }
        
        // If input is not an English word, insert best English candidates after populating Rime best candidates.
        if !hasPopulatedBestEnglishCandidates && isEnglishActive {
            for i in demotedEnglishCandidateIndices {
                candidatePaths[0].append(CandidatePath(source: .english, index: i))
            }
            for i in inputEngine.englishPrefectCandidatesStartIndex..<inputEngine.englishWorstCandidatesStartIndex {
                candidatePaths[0].append(CandidatePath(source: .english, index: i))
            }
            hasPopulatedBestEnglishCandidates = true
        }
        
        // Populate remaining Rime candidates.
        while inputMode != .english && curRimeCandidateIndex < inputEngine.rimeLoadedCandidatesCount {
            candidatePaths[0].append(CandidatePath(source: .rime, index: curRimeCandidateIndex))
            curRimeCandidateIndex += 1
        }
        
        // Populate worst English candidates.
        if (inputMode == .english || inputEngine.hasRimeLoadedAllCandidates) && !hasPopulatedWorstEnglishCandidates && isEnglishActive {
            for i in inputEngine.englishWorstCandidatesStartIndex..<englishCandidates.count {
                candidatePaths[0].append(CandidatePath(source: .english, index: i))
            }
            hasPopulatedWorstEnglishCandidates = true
        }
    }
    
    private func populateCandidatesByRomanization() {
        guard let inputController = inputController,
              let inputEngine = inputController.inputEngine,
              inputController.state.inputMode != .english else { return }
        
        while inputEngine.loadMoreRimeCandidates() {}
        
        var sections: [String] = []
        var candidateCount = Dictionary<String, Int>()
        var candidateGroupByRomanization = Dictionary<String, [Int]>()
        for i in 0..<inputEngine.rimeLoadedCandidatesCount {
            guard let romanization = inputEngine.getRimeCandidateComment(i), !romanization.isEmpty else { continue }
            let firstCharRomanizations = String(romanization.prefix(while: { $0 != " " })).split(separator: "/").map({ String($0) })
            
            for firstCharRomanization in firstCharRomanizations {
                if !candidateGroupByRomanization.keys.contains(firstCharRomanization) {
                    candidateGroupByRomanization[firstCharRomanization] = []
                    candidateCount[firstCharRomanization] = 0
                    sections.append(firstCharRomanization)
                }
                candidateGroupByRomanization[firstCharRomanization]?.append(i)
                candidateCount[firstCharRomanization] = (candidateCount[firstCharRomanization] ?? 0) + 1
            }
        }
        
        // Merge single buckets.
        var headersToRemove = Set<String>()
        for i in 0..<sections.count {
            let header = sections[i]
            guard candidateCount[header] == 1 else { continue }
            
            // If there are slibling romainization, do not merge the bucket.
            let headerWithoutTone = header.prefix(header.count - 1)
            guard sections.filter({ $0.starts(with: headerWithoutTone) }).count == 1 else { continue }
            
            headersToRemove.insert(header)
            let newHeader = String(header.first!)
            if !candidateGroupByRomanization.keys.contains(newHeader) {
                candidateGroupByRomanization[newHeader] = []
                sections.append(newHeader)
            }
            if let candidateIndices = candidateGroupByRomanization[header] {
                candidateGroupByRomanization[newHeader]?.append(contentsOf: candidateIndices)
            }
        }
        
        // Show exact match (without tones) first. The rest in alphabetical order.
        let composingTextEnglishSuffix = inputEngine.rimeComposition?.text.filter({ $0.isEnglishLetter }).lowercased() ?? ""
        let bestSections = sections.filter({ composingTextEnglishSuffix.starts(with: $0.withoutTailingDigit) }).sorted(by: { a, b in
            if a.count == b.count {
                return a.compare(b) == .orderedAscending
            } else {
                return a.count > b.count
            }
        })
        sections = bestSections + sections.filter({ !composingTextEnglishSuffix.starts(with: $0.withoutTailingDigit) }).sorted()
        
        sectionHeaders = []
        for i in 0..<sections.count {
            let header = sections[i]
            guard !headersToRemove.contains(header),
                  let candidates = candidateGroupByRomanization[header]?.map({ CandidatePath(source: .rime, index: $0) }) else { continue }
            candidatePaths.append(candidates)
            sectionHeaders.append(header)
        }
    }
    
    private func populateCandidatesByRadical() {
        guard let inputController = inputController,
              let inputEngine = inputController.inputEngine,
              inputController.state.inputMode != .english else { return }
        
        while inputEngine.loadMoreRimeCandidates() {}
                
        var candidateGroupByRadical = Dictionary<UInt8, [Int]>()
        var radicalStrokes = Dictionary<Int, UInt8>()
        for i in 0..<inputEngine.rimeLoadedCandidatesCount {
            guard let candidate = inputEngine.getRimeCandidate(i),
                  let candidateFirstCharInUtf32 = candidate.first?.unicodeScalars.first?.value else { continue }
            
            let unihanEntry = Self.unihanDict.getUnihanEntry(candidateFirstCharInUtf32)
            let radical = unihanEntry.radical
            guard radical != 0 else { continue }
            if !candidateGroupByRadical.keys.contains(radical) {
                candidateGroupByRadical[radical] = []
            }
            candidateGroupByRadical[radical]?.append(i)
            radicalStrokes[i] = unihanEntry.radicalStroke
        }
        
        let candidateGroupByKeysSorted = candidateGroupByRadical.keys.sorted()
        sectionHeaders = []
        for i in 0..<candidateGroupByKeysSorted.count {
            let header = candidateGroupByKeysSorted[i]
            guard let candidates = candidateGroupByRadical[header]?
                    .sorted(by: { radicalStrokes[$0] ?? 0 < radicalStrokes[$1] ?? 0 })
                    .map({ CandidatePath(source: .rime, index: $0) }) else { continue }
            candidatePaths.append(candidates)
            if let radicalChar = Self.radicalChars[safe: Int(header) - 1] {
                sectionHeaders.append(radicalChar)
            }
        }
    }
    
    private func populateCandidatesByTotalStroke() {
        guard let inputController = inputController,
              let inputEngine = inputController.inputEngine,
              inputController.state.inputMode != .english else { return }
        
        while inputEngine.loadMoreRimeCandidates() {}
        
        var candidateGroupByTotalStroke = Dictionary<UInt8, [Int]>()
        for i in 0..<inputEngine.rimeLoadedCandidatesCount {
            guard let candidate = inputEngine.getRimeCandidate(i),
                  let candidateFirstCharInUtf32 = candidate.first?.unicodeScalars.first?.value else { continue }
            
            let unihanEntry = Self.unihanDict.getUnihanEntry(candidateFirstCharInUtf32)
            let totalStroke = unihanEntry.totalStroke
            guard totalStroke != 0 else { continue }
            if !candidateGroupByTotalStroke.keys.contains(totalStroke) {
                candidateGroupByTotalStroke[totalStroke] = []
            }
            candidateGroupByTotalStroke[totalStroke]?.append(i)
        }
        
        let candidateGroupByKeysSorted = candidateGroupByTotalStroke.keys.sorted()
        sectionHeaders = []
        for i in 0..<candidateGroupByKeysSorted.count {
            let header = candidateGroupByKeysSorted[i]
            guard let candidates = candidateGroupByTotalStroke[header]?.map({ CandidatePath(source: .rime, index: $0) }) else { continue }
            candidatePaths.append(candidates)
            sectionHeaders.append(String(header))
        }
    }
    
    func updateCandidates(reload: Bool) {
        guard let inputEngine = inputController?.inputEngine,
              reload || groupByMode == .byFrequency else { return }
        if reload { resetCandidates() }
        
        if inputController?.inputEngine.rimeLoadedCandidatesCount == 0 || !reload { _ = inputEngine.loadMoreRimeCandidates() }
        populateCandidates()
    }

    func getNumberOfSections() -> Int {
        return candidatePaths.count
    }
    
    func getSectionHeader(section: Int) -> String? {
        return sectionHeaders[safe: section]
    }
    
    func getCandidate(indexPath: IndexPath) -> String? {
        guard let candidatePath = getCandidatePath(indexPath: indexPath) else { return nil }
        
        switch candidatePath.source {
        case .rime: return inputController?.inputEngine.getRimeCandidate(candidatePath.index)
        case .english: return inputController?.inputEngine.englishCandidates[safe: candidatePath.index]
        }
    }
    
    private func getCandidatePath(indexPath: IndexPath) -> CandidatePath? {
        return candidatePaths[safe: indexPath.section]?[safe: indexPath.row]
    }
    
    func selectCandidate(indexPath: IndexPath) -> String? {
        guard let candidatePath = getCandidatePath(indexPath: indexPath) else { return nil }
        
        let selectedCandidate: String?
        switch candidatePath.source {
        case .rime: selectedCandidate = inputController?.inputEngine.selectRimeCandidate(candidatePath.index)
        case .english: selectedCandidate = inputController?.inputEngine.selectEnglishCandidate(candidatePath.index)
        }
        resetCandidates()
        return selectedCandidate
    }
    
    func getCandidateComment(indexPath: IndexPath) -> String? {
        guard let candidatePath = getCandidatePath(indexPath: indexPath) else { return nil }
        
        let comment: String?
        switch candidatePath.source {
        case .rime: comment = inputController?.inputEngine.getRimeCandidateComment(candidatePath.index)
        default: return nil
        }
        
        if let reverseLookupPerChars = comment?.split(separator: " ").map({ $0.split(separator: "/") }) {
            var reverseLookupFirstChoice = ""
            for reverseLookupPerChar in reverseLookupPerChars {
                reverseLookupFirstChoice += (reverseLookupPerChar.first ?? "") + " "
            }
            _ = reverseLookupFirstChoice.popLast()
            return reverseLookupFirstChoice
        }
        return comment
    }
    
    func getCandidateCount(section: Int) -> Int {
        return candidatePaths[safe: section]?.count ?? 0
    }
    
    var supportedGroupByModes: [GroupByMode] {
        [ .byFrequency, .byRomanization, .byRadical, .byTotalStroke ]
    }
    
    var groupByMode: GroupByMode {
        get { _groupByMode }
        set {
            guard newValue != _groupByMode else { return }
            _groupByMode = newValue
            updateCandidates(reload: true)
        }
    }
}

class AutoSuggestionCandidateSource: CandidateSource {
    private let candidates: [String]
    let cannotExpand: Bool
    
    init(_ candidates: [String], cannotExpand: Bool = false) {
        self.candidates = candidates
        self.cannotExpand = cannotExpand
    }
    
    func updateCandidates(reload: Bool) {
    }
    
    func getNumberOfSections() -> Int {
        return 1
    }
    
    func getSectionHeader(section: Int) -> String? {
        return nil
    }
    
    func getCandidate(indexPath: IndexPath) -> String? {
        guard indexPath.section == 0 else { return nil }
        return candidates[safe: indexPath.row]
    }
    
    func selectCandidate(indexPath: IndexPath) -> String? {
        return getCandidate(indexPath: indexPath)
    }
    
    func getCandidateComment(indexPath: IndexPath) -> String? {
        return nil
    }
    
    func getCandidateCount(section: Int) -> Int {
        return candidates.count
    }
    
    var supportedGroupByModes: [GroupByMode] { [ .byFrequency ] }
    
    var groupByMode: GroupByMode = .byFrequency
}

struct CandidatePath {
    enum Source {
        case english, rime
    }
    let source: Source
    let index: Int
}

enum AutoSuggestionType {
    case halfWidthPunctuation
    case fullWidthPunctuation
    case halfWidthDigit
    case fullWidthArabicDigit
    case fullWidthLowerDigit
    case fullWidthUpperDigit
}

// This class filter, group by and sort the candidates.
class CandidateOrganizer {
    private static let halfWidthPunctuationCandidateSource = AutoSuggestionCandidateSource([".", ",", "?", "!", "。", "，", "？", "！"], cannotExpand: true)
    private static let fullWidthPunctuationCandidateSource = AutoSuggestionCandidateSource(["。", "，", "？", "！", ".", ",", "?", "!"], cannotExpand: true)
    private static let halfWidthDigitCandidateSource = AutoSuggestionCandidateSource(["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"])
    private static let fullWidthArabicDigitCandidateSource = AutoSuggestionCandidateSource(["０", "１", "２", "３", "４", "５", "６", "７", "８", "９"])
    private static let fullWidthLowerDigitCandidateSource = AutoSuggestionCandidateSource(["一", "二", "三", "四", "五", "六", "七", "八", "九", "十", "零", "廿", "百", "千", "萬", "億"])
    private static let fullWidthUpperDigitCandidateSource = AutoSuggestionCandidateSource(["零", "壹", "貳", "叄", "肆", "伍", "陸", "柒", "捌", "玖", "拾", "佰", "仟", "萬", "億"])
    
    enum GroupBy {
        case frequency, radical, stroke, tone
    }
    
    var onMoreCandidatesLoaded: ((CandidateOrganizer) -> Void)?
    var onReloadCandidates: ((CandidateOrganizer) -> Void)?
    var candidateSource: CandidateSource?
    var autoSuggestionType: AutoSuggestionType?
    
    weak var inputController: InputController?
    
    init(inputController: InputController) {
        self.inputController = inputController
    }
    
    func requestMoreCandidates(section: Int) {
        guard section == 0, !(inputController?.inputEngine.hasRimeLoadedAllCandidates ?? false) else { return }
        updateCandidates(reload: false)
    }
    
    func updateCandidates(reload: Bool) {
        if let inputController = inputController,
           inputController.inputEngine.isComposing {
            candidateSource = InputEngineCandidateSource(inputController: inputController)
        } else if let autoSuggestionType = autoSuggestionType {
            switch autoSuggestionType {
            case .fullWidthArabicDigit: candidateSource = Self.fullWidthArabicDigitCandidateSource
            case .fullWidthLowerDigit: candidateSource = Self.fullWidthLowerDigitCandidateSource
            case .fullWidthPunctuation: candidateSource = Self.fullWidthPunctuationCandidateSource
            case .fullWidthUpperDigit: candidateSource = Self.fullWidthUpperDigitCandidateSource
            case .halfWidthDigit: candidateSource = Self.halfWidthDigitCandidateSource
            case .halfWidthPunctuation: candidateSource = Self.halfWidthPunctuationCandidateSource
            }
        } else {
            candidateSource = nil
        }
        
        candidateSource?.updateCandidates(reload: reload)
        
        if reload {
            onReloadCandidates?(self)
        } else {
            onMoreCandidatesLoaded?(self)
        }
    }

    func getNumberOfSections() -> Int {
        return candidateSource?.getNumberOfSections() ?? 0
    }
    
    func getCandidate(indexPath: IndexPath) -> String? {
        return candidateSource?.getCandidate(indexPath: indexPath)
    }
    
    func selectCandidate(indexPath: IndexPath) -> String? {
        let candidate = candidateSource?.selectCandidate(indexPath: indexPath)
        updateCandidates(reload: true)
        return candidate
    }
    
    func getCandidateComment(indexPath: IndexPath) -> String? {
        return candidateSource?.getCandidateComment(indexPath: indexPath)
    }
    
    func getCandidateCount(section: Int) -> Int {
        return candidateSource?.getCandidateCount(section: section) ?? 0
    }
    
    func getSectionHeader(section: Int) -> String? {
        return candidateSource?.getSectionHeader(section: section)
    }
    
    var shouldCloseCandidatePaneOnCommit: Bool {
        candidateSource === Self.fullWidthArabicDigitCandidateSource ||
        candidateSource === Self.fullWidthLowerDigitCandidateSource ||
        candidateSource === Self.fullWidthUpperDigitCandidateSource ||
        candidateSource === Self.halfWidthDigitCandidateSource
    }
    
    var supportedGroupByModes: [GroupByMode] {
        candidateSource?.supportedGroupByModes ?? [ .byFrequency ]
    }
    
    var groupByMode: GroupByMode {
        get { candidateSource?.groupByMode ?? .byFrequency }
        set { candidateSource?.groupByMode = newValue }
    }
    
    var cannotExpand: Bool {
        (candidateSource as? AutoSuggestionCandidateSource)?.cannotExpand ?? false
    }
}
