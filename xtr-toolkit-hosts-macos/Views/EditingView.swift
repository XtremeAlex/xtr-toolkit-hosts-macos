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
        VStack(spacing: 0) {
            HeaderView(
                isEditing: Binding(get: { viewController.isEditing },
                                   set: { viewController.toggleEditMode($0) }),
                isMusicOn: $viewController.isMusicOn,
                isSaving: viewController.isSaving,
                readOnly: viewController.isReadOnly,
                saveAction: { viewController.saveChanges() },
                cancelAction: { viewController.presenter.cancelChanges() },
                addAppAction: { viewController.showAddAppModal() }
            )

            Callout(kind: .warn) {
                Text("Modalita' modifica: le modifiche vengono scritte in /etc/hosts solo con Salva (⌘S). Il resto del file resta invariato e viene creato un backup.")
                    .font(.callout)
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding([.horizontal, .top], Theme.s5)

            if viewController.apps.isEmpty {
                EmptyHostsView()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.s4) {
                        ForEach(viewController.apps) { app in
                            EditableAppCard(app: app, viewController: viewController)
                        }
                    }
                    .padding(Theme.s5)
                }
            }
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

/// Card di un gruppo in modifica: intestazione editabile, righe host, "Aggiungi host".
private struct EditableAppCard: View {
    @ObservedObject var app: HostApp
    @ObservedObject var viewController: MainViewController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            EditableAppHeaderView(app: app, viewController: viewController)
                .padding(Theme.s4)
            Divider().overlay(Theme.border)
            ForEach(app.hosts) { host in
                EditableHostRowView(host: host, app: app, viewController: viewController)
                    .padding(.horizontal, Theme.s4)
                    .padding(.vertical, Theme.s2)
            }
            Button {
                viewController.currentAppForAddHost = app
                viewController.isShowingAddHostModal = true
            } label: {
                Label("Aggiungi host", systemImage: "plus")
            }
            .buttonStyle(XtrButtonStyle(kind: .ghost, small: true))
            .padding(Theme.s4)
        }
        .background(Theme.bgAlt, in: RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusLarge).strokeBorder(Theme.border))
    }
}
