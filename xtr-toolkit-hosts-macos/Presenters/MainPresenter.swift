//
//  MainPresenter.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 27/09/24.
//

// Presenters/MainPresenter.swift
import Foundation
import SwiftUI

class MainPresenter: IMainPresenter {
    weak var view: IMainViewController?
    private var isEditingMode: Bool = false
    private var apps: [HostApp] = []
    private var originalApps: [HostApp] = []
    private var hostsFilePath: String = "/etc/hosts"

    init(view: IMainViewController) {
        self.view = view
    }

    func initialize() {
        do {
            // Verifico i permessi...
            guard FileManager.default.isReadableFile(atPath: hostsFilePath) else {
                DispatchQueue.main.async {
                    self.view?.showError("Permessi insufficienti per leggere il file hosts.")
                }
                return
            }

            self.apps = try IOHostParser.parseHostsFile(filePath: hostsFilePath)
            self.originalApps = deepCopyApps(apps)
            DispatchQueue.main.async {
                self.view?.setApps(self.apps)
                self.view?.refreshApps()
                self.view?.displayMainContent()
            }
        } catch {
            DispatchQueue.main.async {
                self.view?.showError("Errore durante l'inizializzazione: \(error)")
            }
        }
    }

    func getApps() -> [HostApp] {
        return apps
    }

    func isEditing() -> Bool {
        return isEditingMode
    }

    func toggleEditMode(_ isEditing: Bool) {
        isEditingMode = isEditing
        view?.setEditing(isEditing)
    }

    func handleModifyAction() {
        toggleEditMode(true)
    }

    func removeHost(_ host: Host) {
        for app in apps {
            if let index = app.hosts.firstIndex(where: { $0.id == host.id }) {
                app.hosts.remove(at: index)
                break
            }
        }
        view?.setApps(apps)
        view?.refreshApps()
    }

    func addHost(_ host: Host, to app: HostApp) {
        app.hosts.append(host)
        view?.refreshApps()
    }

    func addApp(_ app: HostApp) {
        apps.append(app)
        view?.setApps(apps)
        view?.refreshApps()
    }

    func updateApp(_ app: HostApp) {
        if let index = apps.firstIndex(where: { $0.id == app.id }) {
            apps[index] = app
            view?.setApps(apps)
            view?.refreshApps()
        }
    }

    func updateHost(_ host: Host, in app: HostApp) {
        if let appIndex = apps.firstIndex(where: { $0.id == app.id }) {
            if let hostIndex = apps[appIndex].hosts.firstIndex(where: { $0.id == host.id }) {
                apps[appIndex].hosts[hostIndex] = host
                view?.setApps(apps)
                view?.refreshApps()
            }
        }
    }

    func removeApp(_ app: HostApp) {
        if let index = apps.firstIndex(where: { $0.id == app.id }) {
            apps.remove(at: index)
            view?.setApps(apps)
            view?.refreshApps()
        }
    }

    func saveChanges() throws {
        // Creo un nuovo file
        let customSection = IOHostParser.generateOrderedCustomSection(apps)
        let updatedContent = customSection.joined(separator: "\n")
        
        do {
            // cerco di modificare il file hosts chiedendo i privilegi
            try IOHostParser.writeHostsFileWithPrivileges(content: updatedContent)
            print("Salvataggio completato con successo.")
        } catch {
            print("Errore durante il salvataggio: \(error.localizedDescription)")
            throw error
        }
    }

    func saveChangesAsync() {
        DispatchQueue.global(qos: .background).async {
            do {
                try self.saveChanges()
                DispatchQueue.main.async {
                    self.view?.showInfo("Modifiche salvate con successo!")
                    self.toggleEditMode(false)
                }
            } catch {
                self.handleError(error)
            }
        }
    }

    func handleError(_ error: Error) {
        DispatchQueue.main.async {
            self.view?.showError("Si è verificato un errore: \(error.localizedDescription)")
        }
    }

    func cancelChanges() {
        apps = deepCopyApps(originalApps)
        view?.setApps(apps)
        view?.refreshApps()
        toggleEditMode(false)
    }

    private func deepCopyApps(_ apps: [HostApp]) -> [HostApp] {
        return apps.map { app in
            let copiedHosts = app.hosts.map { host in
                Host(ip: host.ip, fqdn: host.fqdn, enabled: host.enabled)
            }
            return HostApp(name: app.name, info: app.info, lb: app.lb, hosts: copiedHosts)
        }
    }
}
