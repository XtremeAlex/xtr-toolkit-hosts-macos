//
//  AddLBModalView.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 28/09/24.
//

// Views/AddLBModalView.swift
import SwiftUI

struct AddLBModalView: View {
    @ObservedObject var app: HostApp
    @Binding var isPresented: Bool
    @State private var lbText: String = ""

    private var trimmed: String { lbText.trimmingCharacters(in: .whitespaces) }
    private var invalid: Bool {
        !trimmed.isEmpty && !HostsDocument.isValidHostname(trimmed) && !HostsDocument.isValidIP(trimmed)
    }

    var body: some View {
        ModalScaffold(eyebrow: app.name.isEmpty ? "App" : app.name, title: "Aggiungi load balancer") {
            LabeledField(label: "Nome o IP del load balancer", placeholder: "lb.example.internal",
                         text: $lbText, invalid: invalid)
            Text("Con \"Aggiorna IP\" l'app risolve questo nome via DNS e propone l'indirizzo attuale.")
                .font(.callout)
                .foregroundStyle(Theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        } actions: {
            Button("Annulla") { isPresented = false }
                .buttonStyle(XtrButtonStyle(kind: .ghost))
                .keyboardShortcut(.cancelAction)
            Button("Salva") {
                app.lb = trimmed
                isPresented = false
            }
            .buttonStyle(XtrButtonStyle(kind: .primary))
            .keyboardShortcut(.defaultAction)
            .disabled(trimmed.isEmpty || invalid)
        }
    }
}
