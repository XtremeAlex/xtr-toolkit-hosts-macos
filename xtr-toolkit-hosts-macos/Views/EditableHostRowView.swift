//
//  EditableHostRowView.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 28/09/24.
//

// Views/EditableHostRowView.swift
import SwiftUI

struct EditableHostRowView: View {
    @ObservedObject var host: Host
    @ObservedObject var app: HostApp
    @ObservedObject var viewController: MainViewController

    var body: some View {
        HStack(spacing: Theme.s2) {
            Toggle(isOn: $host.enabled) { EmptyView() }
                .toggleStyle(SwitchStyle())
                .labelsHidden()
                .accessibilityLabel("Host abilitato")

            TextField("IP", text: $host.ip)
                .themedField(invalid: !HostsDocument.isValidIP(host.ip))
                .frame(width: 170)
                .accessibilityLabel("Indirizzo IP")

            TextField("FQDN", text: $host.fqdn)
                .themedField(invalid: !HostsDocument.isValidHostname(host.fqdn))
                .accessibilityLabel("Nome host")

            // Aggiorna IP risolvendo il nome del load balancer (solo se presente).
            if let lb = app.lb, !lb.isEmpty {
                Button {
                    viewController.updateIPForHost(host, lb: lb)
                } label: { Image(systemName: "arrow.triangle.2.circlepath") }
                .buttonStyle(.borderless)
                .foregroundStyle(Theme.text)
                .help("Aggiorna l'IP dal load balancer \(lb)")
                .accessibilityLabel("Aggiorna IP dal load balancer")
            }

            Button {
                viewController.presenter.removeHost(host)
            } label: {
                Image(systemName: "trash").foregroundStyle(Theme.accentText)
            }
            .buttonStyle(.borderless)
            .help("Elimina host")
            .accessibilityLabel("Elimina \(host.fqdn)")
        }
    }
}

// themedField(invalid:) e' definito in Theme/ThemeComponents.swift (condiviso con openmail).
