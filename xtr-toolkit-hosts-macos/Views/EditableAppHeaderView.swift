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

    var body: some View {
        VStack {
            HStack {
                TextField("Nome App", text: $app.name)
                    .font(.headline)
                    .italic()
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                // Bottone per eliminare l'app
                Button(action: {
                    viewController.presenter.removeApp(app)
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            HStack {
                if let lb = app.lb, !lb.isEmpty {
                    Text("LB: \(lb)")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .center)
                    // Bottone per rimuovere il LB
                    Button(action: {
                        app.lb = nil
                    }) {
                        Text("X")
                    }
                } else {
                    // Bottone per aggiungere il LB
                    Button(action: {
                        viewController.showAddLBModal(for: app)
                    }) {
                        Text("Aggiungi LB")
                    }
                }
            }
        }
    }
}
