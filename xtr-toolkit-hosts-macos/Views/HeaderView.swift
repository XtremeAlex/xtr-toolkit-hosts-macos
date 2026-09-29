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
    /// Sola lettura imposta da MDM: "Modifica" resta visibile ma disattivato, con spiegazione.
    var readOnly: Bool = false
    var saveAction: () -> Void = {}
    var cancelAction: () -> Void = {}
    var addAppAction: (() -> Void)? = nil
    @AppStorage(AppearancePreference.storageKey) private var appearance = AppearancePreference.system.rawValue

    var body: some View {
        HStack(alignment: .center, spacing: Theme.s5) {
            VStack(alignment: .leading, spacing: 2) {
                Eyebrow("xtr toolkit")
                BrandMark(name: "hosts")
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
                    Button { saveAction() } label: {
                        // Larghezza fissa: il testo cambia ma il pulsante non "salta" (come il web)
                        Text(isSaving ? "Salvataggio..." : "Salva").frame(minWidth: 104)
                    }
                        .buttonStyle(XtrButtonStyle(kind: .primary, small: true, isLoading: isSaving))
                        .disabled(isSaving)
                        .help("Scrive /etc/hosts (richiede la password di amministratore) ⌘S")
                } else {
                    Button {
                        isEditing = true
                    } label: { Label("Modifica", systemImage: readOnly ? "lock" : "pencil") }
                    .buttonStyle(XtrButtonStyle(kind: .primary, small: true, isLoading: isSaving))
                    .disabled(isSaving || readOnly)
                    .help(readOnly ? "Modifiche disattivate dall'amministratore" : "Modifica le voci")
                }
            }
            ThemeToggleButton(preference: $appearance, disabled: AppearancePreference.isManaged)
        }
        .padding(.horizontal, Theme.s5)
        .padding(.vertical, Theme.s3)
        .headerBar()
    }
}
