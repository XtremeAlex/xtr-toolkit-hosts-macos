//
//  AppHeaderView.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 28/09/24.
//

// Views/AppHeaderView.swift
import SwiftUI

struct AppHeaderView: View {
    let app: HostApp

    var body: some View {
        VStack {
            if !app.name.isEmpty {
                // Gradient multicolore per il nome dell'app
                Text(app.name)
                    .font(.largeTitle)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.red, .yellow, .green, .blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            if let lb = app.lb, !lb.isEmpty {
                // Gradient multicolore in realtà singlecolor :D  per il Load Balancer
                Text("\(lb)")
                    .font(.subheadline)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .orange, .orange, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
        }
    }
}
