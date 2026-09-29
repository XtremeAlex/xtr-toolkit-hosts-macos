//
//  IMainViewController.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 27/09/24.
//

// Protocols/IMainViewController.swift
import Foundation

protocol IMainViewController: AnyObject {
    func setApps(_ apps: [HostApp])
    func refreshApps()
    func setEditing(_ isEditing: Bool)
    func toggleEditMode(_ isEditing: Bool)
    func displayMainContent()
    func showError(_ message: String)
    func showInfo(_ message: String)
    func showNotification(_ message: String)
    /// Stato di salvataggio in corso (pulsante Salva con effetto lampada, doppio invio bloccato).
    func setSaving(_ saving: Bool)
    func askUserForHostsFilePath() -> String?
}
