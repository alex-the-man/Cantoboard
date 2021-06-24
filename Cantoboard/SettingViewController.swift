//
//  ViewController.swift
//  CantoboardApp
//
//  Created by Alex Man on 3/2/21.
//
import UIKit

import CantoboardFramework

class SettingViewController: UITableViewController, UITextFieldDelegate {
    @IBOutlet weak private var charFormControl: UISegmentedControl!
    @IBOutlet weak private var enableMixedModeControl: UISwitch!
    @IBOutlet weak private var autoCapControl: UISwitch!
    @IBOutlet weak private var smartFullStopControl: UISwitch!
    @IBOutlet weak private var symbolShapeControl: UISegmentedControl!
    @IBOutlet weak private var candidateFontSizeControl: UISegmentedControl!
    @IBOutlet weak private var spaceActionControl: UISegmentedControl!
    @IBOutlet weak private var toneInputControl: UISegmentedControl!
    @IBOutlet weak private var rimeEnableCorrector: UISwitch!
    @IBOutlet weak private var englishLocaleInputControl: UISegmentedControl!
    @IBOutlet weak private var showRomanizationControl: UISwitch!
    @IBOutlet weak private var audioFeedbackControl: UISwitch!
    @IBOutlet weak private var hapticFeedbackControl: UISwitch!
    @IBOutlet weak private var inputTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        populateSettings()
        
        charFormControl.addTarget(self, action: #selector(updateSettings), for: .valueChanged)
        enableMixedModeControl.addTarget(self, action: #selector(updateSettings), for: .valueChanged)
        autoCapControl.addTarget(self, action: #selector(updateSettings), for: .valueChanged)
        smartFullStopControl.addTarget(self, action: #selector(updateSettings), for: .valueChanged)
        symbolShapeControl.addTarget(self, action: #selector(updateSettings), for: .valueChanged)
        candidateFontSizeControl.addTarget(self, action: #selector(updateSettings), for: .valueChanged)
        spaceActionControl.addTarget(self, action: #selector(updateSettings), for: .valueChanged)
        toneInputControl.addTarget(self, action: #selector(updateSettings), for: .valueChanged)
        rimeEnableCorrector.addTarget(self, action: #selector(updateSettings), for: .valueChanged)
        englishLocaleInputControl.addTarget(self, action: #selector(updateSettings), for: .valueChanged)
        showRomanizationControl.addTarget(self, action: #selector(updateSettings), for: .valueChanged)
        audioFeedbackControl.addTarget(self, action: #selector(updateSettings), for: .valueChanged)
        hapticFeedbackControl.addTarget(self, action: #selector(updateSettings), for: .valueChanged)
        inputTextField.delegate = self
        
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    @objc func updateSettings(_ sender: Any) {
        let selectedCharForm: CharForm = charFormControl.selectedSegmentIndex == 1 ? .traditionalHK : .simplified
        
        let selectedSymbolShape: SymbolShape
        switch symbolShapeControl.selectedSegmentIndex {
        case 0: selectedSymbolShape = .half
        case 1: selectedSymbolShape = .full
        case 2: selectedSymbolShape = .smart
        default: selectedSymbolShape = .smart
        }
        
        let candidateFontSize: CandidateFontSize
        switch candidateFontSizeControl.selectedSegmentIndex {
        case 1: candidateFontSize = .large
        default: candidateFontSize = .normal
        }
        
        let spaceAction: SpaceAction = spaceActionControl.selectedSegmentIndex == 0 ? .nextPage : .insertText
        let toneInputMode: ToneInputMode =  toneInputControl.selectedSegmentIndex == 0 ? .vxq : .longPress
        
        let englishLocale: EnglishLocale
        switch englishLocaleInputControl.selectedSegmentIndex {
        case 0: englishLocale = .au
        case 1: englishLocale = .ca
        case 2: englishLocale = .gb
        case 3: englishLocale = .us
        default: englishLocale = .us
        }
        
        var settings = Settings()
        settings.charForm = selectedCharForm
        settings.isMixedModeEnabled = enableMixedModeControl.isOn
        settings.isAutoCapEnabled = autoCapControl.isOn
        settings.isSmartFullStopEnabled = smartFullStopControl.isOn
        settings.symbolShape = selectedSymbolShape
        settings.candidateFontSize = candidateFontSize
        settings.spaceAction = spaceAction
        settings.toneInputMode = toneInputMode
        settings.rimeSettings.enableCorrector = rimeEnableCorrector.isOn
        settings.englishLocale = englishLocale
        settings.shouldShowRomanization = showRomanizationControl.isOn
        settings.isAudioFeedbackEnabled = audioFeedbackControl.isOn
        settings.isTapHapticFeedbackEnabled = hapticFeedbackControl.isOn
        Settings.save(settings)
    }
    
    @objc func appMovedToBackground(_ notification: NSNotification) {
        populateSettings()
        tableView.reloadData()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let orgValue = super.tableView(tableView, titleForHeaderInSection: section)
        switch section {
        case 0: return orgValue
        default: return isKeyboardEnabled() ? orgValue : nil
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let orgValue = super.tableView(tableView, titleForFooterInSection: section)
        switch section {
        case 0: return orgValue
        default: return isKeyboardEnabled() ? orgValue : nil
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let orgValue = super.tableView(tableView, numberOfRowsInSection: section)
        switch section {
        case 0: return orgValue
        default: return isKeyboardEnabled() ? orgValue : 0
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        switch indexPath.section {
        case 0: UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
        default: ()
        }
    }
    
    private func populateSetting(toSegmentedControl: UISegmentedControl, settingToIndexMapper: ((Settings) -> Int)) {
        let selectedIndex = settingToIndexMapper(Settings.cached)
        toSegmentedControl.selectedSegmentIndex = selectedIndex
    }
    
    private func populateSettings() {
        let settings = Settings.reload()
        populateCharFormSetting(settings)
        populateSmartInputSettings(settings)
        populateSymbolShape(settings)
        populateSpaceOutputMode(settings)
        populateToneInput(settings)
    }
    
    private func populateCharFormSetting(_ settings: Settings) {
        populateSetting(toSegmentedControl: charFormControl, settingToIndexMapper: {
            switch $0.charForm {
            case .traditionalHK, .traditionalTW: return 1
            case .simplified: return 0
            }
        })
    }
    
    private func populateSmartInputSettings(_ settings: Settings) {
        enableMixedModeControl.isOn = settings.isMixedModeEnabled
        autoCapControl.isOn = settings.isAutoCapEnabled
        smartFullStopControl.isOn = settings.isSmartFullStopEnabled
        showRomanizationControl.isOn = settings.shouldShowRomanization
        audioFeedbackControl.isOn = settings.isAudioFeedbackEnabled
        hapticFeedbackControl.isOn = settings.isTapHapticFeedbackEnabled
        rimeEnableCorrector.isOn = settings.rimeSettings.enableCorrector
        
        populateSetting(toSegmentedControl: englishLocaleInputControl, settingToIndexMapper: {
            switch $0.englishLocale {
            case .au: return 0
            case .ca: return 1
            case .gb: return 2
            case .us: return 3
            }
        })
        
        populateSetting(toSegmentedControl: candidateFontSizeControl, settingToIndexMapper: {
            switch $0.candidateFontSize {
            case .normal: return 0
            case .large: return 1
            }
        })
    }
    
    private func populateSymbolShape(_ settings: Settings) {
        populateSetting(toSegmentedControl: symbolShapeControl, settingToIndexMapper: {
            switch $0.symbolShape {
            case .half: return 0
            case .full: return 1
            case .smart: return 2
            }
        })
    }
    
    private func populateSpaceOutputMode(_ settings: Settings) {
        populateSetting(toSegmentedControl: spaceActionControl, settingToIndexMapper: {
            switch $0.spaceAction {
            case .nextPage: return 0
            case .insertText: return 1
            }
        })
    }
    
    private func populateToneInput(_ settings: Settings) {
        populateSetting(toSegmentedControl: toneInputControl, settingToIndexMapper: {
            switch $0.toneInputMode {
            case .vxq: return 0
            case .longPress: return 1
            }
        })
    }
    
    private func isKeyboardEnabled() -> Bool {
        guard let keyboards = UserDefaults.standard.object(forKey: "AppleKeyboards") as? [String] else {
            return false
        }
        let extensionBundleIdentifier = "\(Bundle.main.bundleIdentifier ?? "").CantoboardExtension"
        return keyboards.contains(extensionBundleIdentifier)
    }
}
