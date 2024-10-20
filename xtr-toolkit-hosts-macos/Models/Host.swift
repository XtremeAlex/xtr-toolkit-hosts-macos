//
//  Host.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 27/09/24.
//

// Models/Host.swift
import Foundation

class Host: ObservableObject, Identifiable {
    let id = UUID()
    @Published var ip: String
    @Published var fqdn: String
    @Published var enabled: Bool

    init(ip: String, fqdn: String, enabled: Bool = true) {
        self.ip = ip
        self.fqdn = fqdn
        self.enabled = enabled
    }
}
