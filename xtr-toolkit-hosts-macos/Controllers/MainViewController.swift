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
    @Published var isMusicOn: Bool = true {
        didSet {
            if isMusicOn {
                AudioManager.shared.playBackgroundMusic()
            } else {
                AudioManager.shared.pauseBackgroundMusic()
            }
        }
    }
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

    init() {
        self.presenter = MainPresenter(view: self)
        self.presenter.initialize()
        
        // Avvia la musica se il toogle isMusicOn è true
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

    func saveChanges() {
        DispatchQueue.global(qos: .background).async {
            do {
                try self.presenter.saveChanges()
                DispatchQueue.main.async {
                    self.showInfo("Modifiche salvate con successo!")
                    self.presenter.toggleEditMode(false)
                }
            } catch {
                self.handleError(error)
            }
        }
    }

    func handleError(_ error: Error) {
        DispatchQueue.main.async {
            self.showError(error.localizedDescription)
        }
    }
    
}
