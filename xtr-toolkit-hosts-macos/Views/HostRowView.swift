//
//  HostRowView.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 28/09/24.
//

// Views/HostRowView.swift
import SwiftUI

struct HostRowView: View {
    @Binding var host: Host
    var viewController: MainViewController

    var body: some View {
        HStack {
            Toggle("", isOn: $host.enabled)
                .toggleStyle(CustomToggleStyle())
                .frame(width: 60)
                .onChange(of: host.enabled) { newValue in
                    // Salva le modifiche quando il toggle cambia, devo gestire meglio i permessi...
                    viewController.presenter.saveChangesAsync()
                }
            Text("\(host.ip) \(host.fqdn)")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
