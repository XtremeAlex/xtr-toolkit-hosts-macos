//
//  AppHeaderView.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 28/09/24.
//

// Views/AppHeaderView.swift
import SwiftUI

/// Intestazione di un gruppo: nome in grassetto, load balancer come badge, contatore host.
/// (Il gradiente arcobaleno e' sostituito dall'accento del tema 2AD, leggibile in chiaro e scuro.)
struct AppHeaderView: View {
    @ObservedObject var app: HostApp

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.s3) {
            Rectangle().fill(Theme.accent).frame(width: 3, height: 16)
            Text(app.name.isEmpty ? "(senza nome)" : app.name)
                .font(Theme.heading(16))
                .foregroundStyle(Theme.text)
            if let lb = app.lb, !lb.isEmpty {
                Badge(text: "LB \(lb)", accent: true)
                    .help("Load balancer")
            }
            Spacer()
            let active = app.hosts.filter(\.enabled).count
            MonoLabel("\(active)/\(app.hosts.count) attivi")
        }
        .accessibilityElement(children: .combine)
    }
}
