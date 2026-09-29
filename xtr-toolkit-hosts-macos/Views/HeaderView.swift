//
//  HeaderView.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 27/09/24.
//

// Views/HeaderView.swift
import SwiftUI

/// Barra superiore nello stile dell'header della web app: marchio con punto rosso,
/// azioni a destra, bordo inferiore 1px.
struct HeaderView: View {
    @Binding var isEditing: Bool
    @Binding var isMusicOn: Bool
    var isSaving: Bool = false
    var saveAction: () -> Void = {}
    var cancelAction: () -> Void = {}
    var addAppAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: Theme.s5) {
            VStack(alignment: .leading, spacing: 2) {
                MonoLabel("xtr toolkit", color: Theme.accentText)
                BrandMark(name: "hosts", size: 20)
            }

            Spacer()

            Toggle(isOn: $isMusicOn) { MonoLabel("Musica") }
                .toggleStyle(SwitchStyle())
                .help("Musica di sottofondo (ricordata tra un avvio e l'altro)")

            HStack(spacing: Theme.s2) {
                if isEditing {
                    if let addAppAction {
                        Button {
                            addAppAction()
                        } label: { Label("App", systemImage: "plus") }
                        .buttonStyle(XtrButtonStyle(kind: .ghost, small: true))
                        .disabled(isSaving)
                    }
                    Button("Annulla") { cancelAction() }
                        .buttonStyle(XtrButtonStyle(kind: .ghost, small: true))
                        .keyboardShortcut(.cancelAction)
                        .disabled(isSaving)
                    Button(isSaving ? "Salvataggio..." : "Salva") { saveAction() }
                        .buttonStyle(XtrButtonStyle(kind: .primary, small: true, isLoading: isSaving))
                        .disabled(isSaving)
                        .help("Scrive /etc/hosts (richiede la password di amministratore) ⌘S")
                } else {
                    Button {
                        isEditing = true
                    } label: { Label("Modifica", systemImage: "pencil") }
                    .buttonStyle(XtrButtonStyle(kind: .primary, small: true, isLoading: isSaving))
                    .disabled(isSaving)
                }
            }
        }
        .padding(.horizontal, Theme.s5)
        .padding(.vertical, Theme.s3)
        .background(Theme.bg)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
    }
}
