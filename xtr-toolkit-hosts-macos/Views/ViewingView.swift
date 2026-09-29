//
//  ViewingView.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 27/09/24.
//

// Views/ViewingView.swift
import SwiftUI

struct ViewingView: View {
    @ObservedObject var viewController: MainViewController
    @State private var filter = ""

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(
                isEditing: Binding(get: { viewController.isEditing },
                                   set: { viewController.toggleEditMode($0) }),
                isMusicOn: $viewController.isMusicOn,
                isSaving: viewController.isSaving
            )

            if viewController.apps.isEmpty {
                EmptyHostsView()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.s4) {
                        ForEach(filteredApps) { app in
                            VStack(alignment: .leading, spacing: 0) {
                                AppHeaderView(app: app)
                                    .padding(.horizontal, Theme.s4)
                                    .padding(.vertical, Theme.s3)
                                Divider().overlay(Theme.border)
                                ForEach(Array(visibleHosts(app).enumerated()), id: \.element.id) { index, host in
                                    HostRowView(host: host, viewController: viewController)
                                        .padding(.horizontal, Theme.s4)
                                        .padding(.vertical, Theme.s2)
                                        .background(index.isMultiple(of: 2) ? Color.clear : Theme.text.opacity(0.025))
                                }
                            }
                            .background(Theme.bgAlt, in: RoundedRectangle(cornerRadius: Theme.radiusLarge))
                            .overlay(RoundedRectangle(cornerRadius: Theme.radiusLarge).strokeBorder(Theme.border))
                        }
                    }
                    .padding(Theme.s5)
                }
            }
        }
        // Ricerca per app, IP o nome host: con decine di ambienti la lista diventa lunga.
        .searchable(text: $filter, placement: .toolbar, prompt: "Filtra app, IP o host")
    }

    private var filteredApps: [HostApp] {
        guard !filter.isEmpty else { return viewController.apps }
        return viewController.apps.filter { app in
            app.name.localizedCaseInsensitiveContains(filter) || !visibleHosts(app).isEmpty
        }
    }

    private func visibleHosts(_ app: HostApp) -> [Host] {
        guard !filter.isEmpty, !app.name.localizedCaseInsensitiveContains(filter) else { return app.hosts }
        return app.hosts.filter {
            $0.ip.localizedCaseInsensitiveContains(filter) || $0.fqdn.localizedCaseInsensitiveContains(filter)
        }
    }
}
