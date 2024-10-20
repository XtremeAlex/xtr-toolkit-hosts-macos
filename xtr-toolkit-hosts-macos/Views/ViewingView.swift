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

    var body: some View {
        VStack {
            // Header con i pulsanti
            HeaderView(
                isEditing: $viewController.isEditing,
                isMusicOn: $viewController.isMusicOn
            )

            // Lista delle app e host in modalità visualizzazione
            List {
                ForEach(viewController.apps.indices, id: \.self) { appIndex in
                    let app = viewController.apps[appIndex]
                    Section(header: AppHeaderView(app: app)) {
                        ForEach(app.hosts.indices, id: \.self) { hostIndex in
                            HostRowView(
                                host: $viewController.apps[appIndex].hosts[hostIndex],
                                viewController: viewController
                            )
                        }
                    }
                }
            }
            .listStyle(SidebarListStyle())
        }
    }
}
