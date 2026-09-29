//
//  EditableAppHeaderView.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 28/09/24.
//
 
// Views/EditableAppHeaderView.swift
import SwiftUI

struct EditableAppHeaderView: View {
    @ObservedObject var app: HostApp
    @ObservedObject var viewController: MainViewController
    @State private var confirmDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s3) {
            HStack(spacing: Theme.s3) {
                VStack(alignment: .leading, spacing: 4) {
                    MonoLabel("App")
                    TextField("Nome app", text: $app.name)
                        .themedField()
                }
                Button {
                    confirmDelete = true
                } label: {
                    Image(systemName: "trash").foregroundStyle(Theme.accentText)
                }
                .buttonStyle(.borderless)
                .help("Elimina l'app e tutti i suoi host")
                .accessibilityLabel("Elimina \(app.name)")
                .padding(.top, 16)
            }
            HStack(spacing: Theme.s2) {
                if let lb = app.lb, !lb.isEmpty {
                    Badge(text: "LB \(lb)", accent: true)
                    Button {
                        app.lb = nil
                    } label: { Image(systemName: "xmark.circle") }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Theme.textMuted)
                    .help("Rimuovi load balancer")
                    .accessibilityLabel("Rimuovi load balancer")
                } else {
                    Button {
                        viewController.showAddLBModal(for: app)
                    } label: { Label("Load balancer", systemImage: "plus") }
                    .buttonStyle(XtrButtonStyle(kind: .ghost, small: true))
                }
            }
        }
        // Conferma: eliminare un gruppo rimuove tutte le sue righe al prossimo salvataggio.
        .confirmationDialog("Eliminare \(app.name.isEmpty ? "l'app" : app.name)?",
                            isPresented: $confirmDelete) {
            Button("Elimina", role: .destructive) { viewController.presenter.removeApp(app) }
        } message: {
            Text("Verranno rimossi \(app.hosts.count) host al prossimo salvataggio.")
        }
    }
}
