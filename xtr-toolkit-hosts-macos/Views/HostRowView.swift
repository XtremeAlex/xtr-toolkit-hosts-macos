//
//  HostRowView.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 28/09/24.
//

// Views/HostRowView.swift
import SwiftUI

struct HostRowView: View {
    /// ObservedObject (non Binding a una classe): la riga si aggiorna quando cambia l'host.
    @ObservedObject var host: Host
    var viewController: MainViewController

    var body: some View {
        HStack(spacing: Theme.s4) {
            Toggle(isOn: $host.enabled) { EmptyView() }
                .toggleStyle(SwitchStyle())
                .labelsHidden()
                .disabled(viewController.isSaving)
                .onChange(of: host.enabled) {
                    // Salvataggio immediato come prima (persistenza automatica): il pulsante in
                    // alto mostra l'attesa e un secondo cambio non parte finche' il primo non finisce.
                    viewController.saveChanges()
                }
                .accessibilityLabel("\(host.fqdn) abilitato")
            Text(host.ip)
                .font(Theme.mono(12.5))
                .foregroundStyle(host.enabled ? Theme.text : Theme.textMuted)
                .frame(width: 150, alignment: .leading)
                .textSelection(.enabled)
            Text(host.fqdn)
                .font(Theme.mono(12.5))
                .foregroundStyle(host.enabled ? Theme.text : Theme.textMuted)
                .strikethrough(!host.enabled, color: Theme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            if !host.enabled { Badge(text: "off") }
        }
    }
}
