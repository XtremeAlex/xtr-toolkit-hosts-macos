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
    /// Politica aziendale letta all'avvio (MDM): sola lettura, backup, cache DNS.
    let policy: HostsPolicy

    init(view: IMainViewController, policy: HostsPolicy = .current()) {
        self.view = view
        self.policy = policy
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
                self.view?.showError("Errore durante l'inizializzazione: \(error.localizedDescription)")
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
        // Sola lettura imposta da MDM: la modifica non si apre nemmeno.
        if isEditing && policy.readOnly {
            view?.showError(HostsWriteError.readOnly.localizedDescription)
            return
        }
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
        try saveChanges(snapshots: apps.map(\.snapshot))
    }

    /// Salvataggio a partire da copie immutabili del modello: puo' girare fuori dal main
    /// thread senza leggere gli ObservableObject della UI mentre l'utente li modifica.
    @discardableResult
    func saveChanges(snapshots: [HostAppSnapshot]) throws -> String? {
        guard !policy.readOnly else { throw HostsWriteError.readOnly }
        // Voci non valide: si blocca tutto invece di scrivere righe malformate nel file di sistema.
        let invalid = HostsDocument.invalidEntries(in: snapshots)
        guard invalid.isEmpty else { throw HostsWriteError.invalidEntries(invalid) }

        // Si parte dal file attuale: tutto cio' che precede il marcatore resta invariato.
        guard let original = try? String(contentsOfFile: hostsFilePath, encoding: .utf8) else {
            throw HostsWriteError.unreadable
        }
        let updatedContent = HostsDocument.merge(original: original,
                                                 section: HostsDocument.section(for: snapshots))
        if updatedContent == original { return nil }   // niente da scrivere: nessuna richiesta di password
        let backup = try IOHostParser.writeHostsFileWithPrivileges(
            content: updatedContent, expectedOriginalSHA256: HostsDocument.sha256Hex(original), policy: policy)
        IOHostParser.appendAudit(HostsAuditRecord(date: Date(), user: NSUserName(), hostsPath: hostsFilePath,
                                                  backupPath: backup, before: original, after: updatedContent))
        return backup
    }

    func saveChangesAsync() {
        view?.setSaving(true)
        // Copia del modello sul thread chiamante (main): il lavoro in background non tocca la UI
        let snapshots = apps.map(\.snapshot)
        // userInitiated: l'utente attende l'esito (prima .background poteva ritardare il prompt).
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let backup = try self.saveChanges(snapshots: snapshots)
                DispatchQueue.main.async {
                    if backup != nil { self.originalApps = self.deepCopyApps(self.apps) }
                    self.view?.setSaving(false)
                    self.view?.showInfo(backup.map { "Modifiche salvate. Backup in \($0)" }
                                        ?? "Nessuna modifica da salvare.")
                    self.toggleEditMode(false)
                }
            } catch {
                DispatchQueue.main.async {
                    self.view?.setSaving(false)
                    // Fuori dalla modalita' modifica (interruttore con salvataggio immediato) lo
                    // stato mostrato deve restare quello del file: se la scrittura non avviene
                    // si torna all'ultimo stato salvato.
                    if !self.isEditingMode { self.cancelChanges() }
                }
                self.handleError(error)
            }
        }
    }

    // MARK: - Ripristino da backup

    /// Ripristino della sola sezione dell'app da un backup: file attuale letto di nuovo, hash
    /// verificato dallo script privilegiato, nuovo backup (quindi il ripristino e' annullabile)
    /// e riga di audit con `action: "restore"`.
    @discardableResult
    func restoreSection(from backup: HostsBackup) throws -> String? {
        guard !policy.readOnly else { throw HostsWriteError.readOnly }
        guard let original = try? String(contentsOfFile: hostsFilePath, encoding: .utf8) else {
            throw HostsWriteError.unreadable
        }
        guard let saved = try? String(contentsOfFile: backup.path, encoding: .utf8) else {
            throw HostsWriteError.failed("backup non leggibile (\(backup.path)).")
        }
        guard let updated = HostsBackups.restoredContent(current: original, backup: saved) else {
            throw HostsWriteError.failed("il backup non contiene la sezione dell'app.")
        }
        if updated == original { return nil }
        let newBackup = try IOHostParser.writeHostsFileWithPrivileges(
            content: updated, expectedOriginalSHA256: HostsDocument.sha256Hex(original), policy: policy)
        IOHostParser.appendAudit(HostsAuditRecord(date: Date(), user: NSUserName(), hostsPath: hostsFilePath,
                                                  backupPath: newBackup, before: original, after: updated,
                                                  action: "restore", restoredFrom: backup.path))
        return newBackup
    }

    func restorePreview(_ backup: HostsBackup) -> (added: Int, removed: Int)? {
        guard let original = try? String(contentsOfFile: hostsFilePath, encoding: .utf8),
              let saved = try? String(contentsOfFile: backup.path, encoding: .utf8),
              let updated = HostsBackups.restoredContent(current: original, backup: saved) else { return nil }
        let d = HostsDocument.diff(old: HostsDocument.sectionLines(of: original), new: HostsDocument.sectionLines(of: updated))
        return (d.added.count, d.removed.count)
    }

    func restoreFromBackupAsync(_ backup: HostsBackup) {
        // Con modifiche aperte il ripristino le cancellerebbe senza chiedere: prima si salva o annulla.
        guard !isEditingMode else {
            view?.showError("Salva o annulla le modifiche in corso prima di ripristinare un backup.")
            return
        }
        view?.setSaving(true)
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let newBackup = try self.restoreSection(from: backup)
                DispatchQueue.main.async {
                    self.view?.setSaving(false)
                    // Si rilegge il file: la UI mostra esattamente cio' che e' stato scritto.
                    self.initialize()
                    self.view?.showInfo(newBackup.map { "Sezione ripristinata. Backup dello stato precedente in \($0)" }
                                        ?? "Il file coincide gia' con il backup: nulla da ripristinare.")
                }
            } catch {
                DispatchQueue.main.async { self.view?.setSaving(false) }
                self.handleError(error)
            }
        }
    }

    func handleError(_ error: Error) {
        DispatchQueue.main.async {
            self.view?.showError(error.localizedDescription)
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
