//
//  AddHostModalView.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 28/09/24.
//

// Views/AddHostModalView.swift
import SwiftUI

struct AddHostModalView: View {
    @ObservedObject var app: HostApp
    @Binding var isPresented: Bool
    @State private var ipText: String = ""
    @State private var fqdnText: String = ""

    var body: some View {
        VStack {
            Text("Aggiungi Host")
                .font(.headline)
            TextField("Indirizzo IP", text: $ipText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            TextField("FQDN", text: $fqdnText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            HStack {
                Button("Annulla") {
                    isPresented = false
                }
                Button("Salva") {
                    let newHost = Host(ip: ipText, fqdn: fqdnText, enabled: true)
                    app.hosts.append(newHost)
                    isPresented = false
                }
            }
        }
        .padding()
    }
}
