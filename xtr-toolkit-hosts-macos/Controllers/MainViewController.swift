//
//  MainViewController.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 27/09/24.
//

// Controllers/MainViewController.swift
import Foundation
import SwiftUI

class MainViewController: ObservableObject, IMainViewController {
    @Published var apps: [HostApp] = []
    @Published var isEditing: Bool = false
    /// Musica spenta di default e scelta ricordata: in ufficio un'app che parte con l'audio
    /// e' un problema (riunioni, open space). Chiave in UserDefaults gestibile anche da MDM.
    static let musicDefaultsKey = "musicOn"
    @Published var isMusicOn: Bool = UserDefaults.standard.bool(forKey: MainViewController.musicDefaultsKey) {
        didSet {
            UserDefaults.standard.set(isMusicOn, forKey: Self.musicDefaultsKey)
            if isMusicOn {
                AudioManager.shared.playBackgroundMusic()
            } else {
                AudioManager.shared.pauseBackgroundMusic()
            }
        }
    }
    @Published var isSaving: Bool = false
    @Published var showMainContentFlag: Bool = false
    @Published var notificationMessage: String?

    @Published var isShowingAddLBModal: Bool = false
    @Published var currentAppForLB: HostApp?
    @Published var isShowingAddAppModal: Bool = false
    @Published var isShowingUpdateIPModal: Bool = false
    @Published var currentHostForUpdateIP: Host?
    @Published var currentLBForUpdateIP: String?

    @Published var errorMessage: String = ""
    @Published var showingError: Bool = false

    @Published var infoMessage: String = ""
    @Published var showingInfo: Bool = false

    @Published var isShowingAddHostModal: Bool = false
    @Published var currentAppForAddHost: HostApp?

    var presenter: IMainPresenter!

    /// Sola lettura imposta dall'amministratore (chiave `ReadOnly` del profilo MDM).
    let isReadOnly = HostsPolicy.current().readOnly

    init() {
        self.presenter = MainPresenter(view: self)
        self.presenter.initialize()
        
        // Avvia la musica solo se l'utente l'ha attivata in precedenza.
        if isMusicOn {
            AudioManager.shared.playBackgroundMusic()
        }
    }

    func showAddLBModal(for app: HostApp) {
        currentAppForLB = app
        isShowingAddLBModal = true
    }

    func showAddAppModal() {
        isShowingAddAppModal = true
    }

    func updateIPForHost(_ host: Host, lb: String) {
        currentHostForUpdateIP = host
        currentLBForUpdateIP = lb
        isShowingUpdateIPModal = true
    }

    func setApps(_ apps: [HostApp]) {
        DispatchQueue.main.async {
            self.apps = apps
        }
    }

    func refreshApps() {
        // L'aggiornamento avviene automaticamente grazie a @Published, non serve per adesso ...
    }

    func setEditing(_ isEditing: Bool) {
        DispatchQueue.main.async {
            self.isEditing = isEditing
        }
    }

    func toggleEditMode(_ isEditing: Bool) {
        presenter.toggleEditMode(isEditing)
    }

    func displayMainContent() {
        DispatchQueue.main.async {
            self.showMainContentFlag = true
        }
    }

    func showError(_ message: String) {
        DispatchQueue.main.async {
            self.errorMessage = message
            self.showingError = true
        }
    }

    func showInfo(_ message: String) {
        DispatchQueue.main.async {
            self.infoMessage = message
            self.showingInfo = true
        }
    }

    func showNotification(_ message: String) {
        DispatchQueue.main.async {
            self.notificationMessage = message
        }
    }

    func askUserForHostsFilePath() -> String? {
        // qui andrebbe implementata la logica per chiedere all'utente il percorso del file hosts, in caso di sviluppi extra, poi vediamo ...
        return nil
    }

    /// Un solo percorso di salvataggio (quello del presenter): stato "in corso", backup e
    /// validazione sono gestiti li'. Ignorato se un salvataggio e' gia' in corso.
    func saveChanges() {
        guard !isSaving else { return }
        presenter.saveChangesAsync()
    }

    func setSaving(_ saving: Bool) {
        DispatchQueue.main.async {
            self.isSaving = saving
        }
    }

    func handleError(_ error: Error) {
        DispatchQueue.main.async {
            self.showError(error.localizedDescription)
        }
    }
    
}
