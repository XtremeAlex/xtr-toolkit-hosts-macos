//
//  EditableHostRowView.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 28/09/24.
//

// Views/EditableHostRowView.swift
import SwiftUI

struct EditableHostRowView: View {
    @Binding var host: Host
    let app: HostApp
    @ObservedObject var viewController: MainViewController

    var body: some View {
        HStack {
            TextField("IP", text: $host.ip)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 100)

            TextField("FQDN", text: $host.fqdn)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 200)

            // Bottone per eliminare l'host
            Button(action: {
                viewController.presenter.removeHost(host)
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(BorderlessButtonStyle())

            // Bottone "Aggiorna IP" se il LB è presente
            if let lb = app.lb, !lb.isEmpty {
                Button(action: {
                    viewController.updateIPForHost(host, lb: lb)
                }) {
                    Text("Aggiorna IP")
                }
            }
        }
    }
}
