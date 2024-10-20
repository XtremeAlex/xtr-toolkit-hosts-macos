//
//  IMainPresenter.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 27/09/24.
//

// Protocols/IMainPresenter.swift
import Foundation

protocol IMainPresenter {
    func initialize()
    func getApps() -> [HostApp]
    func isEditing() -> Bool
    func toggleEditMode(_ isEditing: Bool)
    func handleModifyAction()
    func removeHost(_ host: Host)
    func addHost(_ host: Host, to app: HostApp)
    func addApp(_ app: HostApp)
    func updateApp(_ app: HostApp)
    func updateHost(_ host: Host, in app: HostApp)
    func removeApp(_ app: HostApp)
    func saveChanges() throws
    func cancelChanges()
    func saveChangesAsync()
}
