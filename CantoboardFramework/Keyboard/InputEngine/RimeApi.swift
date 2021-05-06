//
//  RimeApi.swift
//  KeyboardKit
//
//  Created by Alex Man on 2/19/21.
//

import Foundation

import CocoaLumberjackSwift

private let patchHeader = "patch:\n"
private let vxqToneConfig: String = """
  "speller/algebra/+":
    - xform/1/v/                  # 陰平
    - xform/4/vv/                 # 陽平
    - xform/2/x/                  # 陰上
    - xform/5/xx/                 # 陽上
    - xform/3/q/                  # 陰去
    - xform/6/qq/                 # 陽去
  
  translator/preedit_format:
    - xform/([aeioumngptk])vv/${1}4/
    - xform/([aeioumngptk])xx/${1}5/
    - xform/([aeioumngptk])qq/${1}6/
    - xform/([aeioumngptk])v/${1}1/
    - xform/([aeioumngptk])x/${1}2/
    - xform/([aeioumngptk])q/${1}3/
"""

private var correctorConfig = """
  translator/enable_correction: true
"""

// Make RimeApi a singleton with listener.
extension RimeApi {
    private static var _shared: RimeApi?
    private static var listener = RimeApiListener()
    static var stateChangeCallbacks: [RimeApiListener.StateChangeBlock] {
        get { listener.stateChangeCallbacks }
        set { listener.stateChangeCallbacks = newValue }
    }
    
    static var shared: RimeApi {
        if _shared == nil {
            atexit {
                RimeApi._shared = nil
            }
            _shared = RimeApi(bundle: Bundle(for: RimeApi.self))
        }
        return _shared!
    }
    
    static func closeShared() {
        DDLogInfo("Deinitializing RimeApi.")
        RimeApi._shared = nil
    }
}

// Proivde an app level initializer.
extension RimeApi {
    static func generateSchemaPatchFromSettings() {
        let documentsDirectory = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let userDataPath = documentsDirectory.appendingPathComponent("RimeUserData", isDirectory: true).path
        
        generateSchemaPatchFromSettings(userDataPath: userDataPath)
    }
    
    private static func generateSchemaPatchFromSettings(userDataPath: String) {
        let settings = Settings.cached
        var jyutPingCustomPatch = "", commonCustomPatch = ""
        
        let jyutPingSchemaCustomPath = userDataPath + "/jyut6ping3.custom.yaml"
        let commonSchemaCustomPath = userDataPath + "/common.custom.yaml"
        try? FileManager.default.removeItem(atPath: jyutPingSchemaCustomPath)
        try? FileManager.default.removeItem(atPath: commonSchemaCustomPath)

        if settings.rimeSettings.toneInputMode == .vxq {
            jyutPingCustomPatch += vxqToneConfig
        }
        
        if settings.rimeSettings.enableCorrector {
            commonCustomPatch += correctorConfig
        }
        
        if jyutPingCustomPatch.count > 0 {
            DDLogInfo("jyutPingCustomPatch: \(jyutPingCustomPatch)")
            jyutPingCustomPatch = patchHeader + jyutPingCustomPatch
            do {
                try jyutPingCustomPatch.write(toFile: jyutPingSchemaCustomPath, atomically: true, encoding: .utf8)
            } catch {
                DDLogInfo("Failed to generate custom schema patch at \(jyutPingSchemaCustomPath).")
            }
        }
        
        if commonCustomPatch.count > 0 {
            DDLogInfo("commonCustomPatch: \(commonCustomPatch)")
            commonCustomPatch = patchHeader + commonCustomPatch
            do {
                try commonCustomPatch.write(toFile: commonSchemaCustomPath, atomically: true, encoding: .utf8)
            } catch {
                DDLogInfo("Failed to generate custom schema patch at \(commonSchemaCustomPath).")
            }
        }
        DDLogInfo("Rime patches generated.")
    }
    
    convenience init(bundle: Bundle) {
        let schemaPath = DataFileManager.rimeSharedDirectory
        let userDataPath = DataFileManager.rimeUserDirectory
        
        if !DataFileManager.hasInstalled {
            fatalError("Data files not installed.")
        }
        
        // Generate schema patch.
        RimeApi.generateSchemaPatchFromSettings(userDataPath: userDataPath)
        
        DDLogInfo("Shared data path: \(schemaPath) User data path: \(userDataPath)")
        
        self.init(RimeApi.listener, sharedDataPath: schemaPath, userDataPath: userDataPath)
    }
    
    private static var appVersion: String {
        if let dict = Bundle.main.infoDictionary,
           let version = dict["CFBundleShortVersionString"] as? String,
           let bundleVersion = dict["CFBundleVersion"] as? String {
                return "\(version).\(bundleVersion)"
        }
        return "unknown"
    }
}

extension RimeApiState {
    public var debugDescription: String {
        description
    }
    
    public var description: String {
        switch self {
        case .uninitialized: return "uninitialized"
        case .deploying: return "deploying"
        case .failure: return "failure"
        case .succeeded: return "succeeded"
        @unknown default: return "unknown"
        }
    }
}

extension String.StringInterpolation {
    mutating func appendInterpolation(_ state: RimeApiState) {
        appendLiteral("\(state.description)")
    }
}
