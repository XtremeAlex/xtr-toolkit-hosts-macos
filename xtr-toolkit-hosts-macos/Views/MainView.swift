//
//  MainView.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 28/09/24.
//

// Views/MainView.swift
import SwiftUI

struct MainView: View {
    @ObservedObject var viewController: MainViewController

    var body: some View {
        VStack(spacing: 0) {
            if viewController.isEditing {
                EditingView(viewController: viewController)
            } else {
                ViewingView(viewController: viewController)
            }
        }
        .background(Theme.bg)
        .tint(Theme.accent)
        .alert("Errore", isPresented: $viewController.showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewController.errorMessage)
        }
        .alert("Informazione", isPresented: $viewController.showingInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewController.infoMessage)
        }
    }
}

/// Stato vuoto comune: nessuna sezione trovata nel file hosts.
struct EmptyHostsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s3) {
            MonoLabel("Nessuna voce", color: Theme.accentText)
            Text("Sezione non trovata in /etc/hosts")
                .font(Theme.heading(20))
                .foregroundStyle(Theme.text)
            Text("Premi Modifica e aggiungi un'app: al primo salvataggio la riga ##start-xtr-toolkit-host viene aggiunta in fondo al file, lasciando intatto il resto.")
                .foregroundStyle(Theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 520, alignment: .leading)
        .card()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
