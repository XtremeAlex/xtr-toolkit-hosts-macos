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

    /// Validazione prima dell'inserimento: un valore sbagliato finirebbe in un file di sistema.
    private var error: String? {
        if ipText.isEmpty && fqdnText.isEmpty { return nil }
        return HostsDocument.validationError(ip: ipText.trimmingCharacters(in: .whitespaces),
                                             fqdn: fqdnText.trimmingCharacters(in: .whitespaces))
    }

    private var canSave: Bool { !ipText.isEmpty && !fqdnText.isEmpty && error == nil }

    var body: some View {
        ModalScaffold(eyebrow: app.name.isEmpty ? "Host" : app.name, title: "Aggiungi host") {
            LabeledField(label: "Indirizzo IP", placeholder: "10.0.0.10 oppure fd00::10", text: $ipText,
                         invalid: !ipText.isEmpty && !HostsDocument.isValidIP(ipText.trimmingCharacters(in: .whitespaces)))
            LabeledField(label: "Nome host (FQDN)", placeholder: "app.example.internal", text: $fqdnText,
                         invalid: !fqdnText.isEmpty && !HostsDocument.isValidHostname(fqdnText.trimmingCharacters(in: .whitespaces)))
            if let error {
                Callout(kind: .alert) { Text(error.prefix(1).uppercased() + error.dropFirst()).font(.callout) }
            }
        } actions: {
            Button("Annulla") { isPresented = false }
                .buttonStyle(XtrButtonStyle(kind: .ghost))
                .keyboardShortcut(.cancelAction)
            Button("Aggiungi") {
                app.hosts.append(Host(ip: ipText.trimmingCharacters(in: .whitespaces),
                                      fqdn: fqdnText.trimmingCharacters(in: .whitespaces), enabled: true))
                isPresented = false
            }
            .buttonStyle(XtrButtonStyle(kind: .primary))
            .keyboardShortcut(.defaultAction)
            .disabled(!canSave)
        }
    }
}

/// Struttura comune delle modali (`.legal-modal` della web app): eyebrow rossa, titolo,
/// contenuto, azioni allineate a destra.
struct ModalScaffold<Content: View, Actions: View>: View {
    let eyebrow: String
    let title: String
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s4) {
            VStack(alignment: .leading, spacing: Theme.s1) {
                MonoLabel(eyebrow, color: Theme.accentText)
                Text(title).font(Theme.heading(20)).foregroundStyle(Theme.text)
            }
            content
            HStack(spacing: Theme.s2) {
                Spacer()
                actions
            }
            .padding(.top, Theme.s2)
        }
        .padding(Theme.s6)
        .frame(width: 460)
        .background(Theme.bgAlt)
    }
}

/// Etichetta mono + campo del tema, con bordo rosso se non valido.
struct LabeledField: View {
    let label: String
    var placeholder = ""
    @Binding var text: String
    var invalid = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MonoLabel(label)
            TextField(placeholder, text: $text)
                .themedField(invalid: invalid)
                .accessibilityLabel(label)
        }
    }
}
