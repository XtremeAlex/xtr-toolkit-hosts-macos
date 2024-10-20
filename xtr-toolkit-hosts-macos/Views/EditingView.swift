//
//  EditingView.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 27/09/24.
//

// Views/EditingView.swift
import SwiftUI

struct EditingView: View {
    @ObservedObject var viewController: MainViewController

    var body: some View {
        VStack {
            // Header con i pulsanti
            HeaderView(
                isEditing: $viewController.isEditing,
                isMusicOn: $viewController.isMusicOn,
                saveAction: {
                    viewController.saveChanges()
                },
                cancelAction: {
                    viewController.presenter.cancelChanges()
                },
                addAppAction: {
                    viewController.showAddAppModal()
                }
            )

            // Lista delle app e host in modalità modifica
            List {
                ForEach(viewController.apps.indices, id: \.self) { appIndex in
                    let app = viewController.apps[appIndex]
                    Section(header: EditableAppHeaderView(app: app, viewController: viewController)) {
                        ForEach(app.hosts.indices, id: \.self) { hostIndex in
                            EditableHostRowView(
                                host: $viewController.apps[appIndex].hosts[hostIndex],
                                app: app,
                                viewController: viewController
                            )
                        }
                        // Bottone per aggiungere un nuovo host
                        Button(action: {
                            viewController.currentAppForAddHost = app
                            viewController.isShowingAddHostModal = true
                        }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Aggiungi Host")
                            }
                        }
                    }
                }
            }
            .listStyle(SidebarListStyle())
        }
        // Gestione delle modali per aggiungere LB, App e aggiornare IP
        .sheet(isPresented: $viewController.isShowingAddLBModal) {
            if let app = viewController.currentAppForLB {
                AddLBModalView(app: app, isPresented: $viewController.isShowingAddLBModal)
            }
        }
        .sheet(isPresented: $viewController.isShowingAddAppModal) {
            AddAppModalView(
                isPresented: $viewController.isShowingAddAppModal,
                viewController: viewController
            )
        }
        .sheet(isPresented: $viewController.isShowingUpdateIPModal) {
            if let host = viewController.currentHostForUpdateIP,
               let lb = viewController.currentLBForUpdateIP {
                UpdateIPModalView(
                    host: host,
                    lb: lb,
                    isPresented: $viewController.isShowingUpdateIPModal,
                    viewController: viewController
                )
            }
        }
        // Aggiungi la `sheet` per "Aggiungi Host"
        .sheet(isPresented: $viewController.isShowingAddHostModal) {
            if let app = viewController.currentAppForAddHost {
                AddHostModalView(
                    app: app,
                    isPresented: $viewController.isShowingAddHostModal
                )
            }
        }
    }
}
