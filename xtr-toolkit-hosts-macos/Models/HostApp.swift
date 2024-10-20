//
//  HostApp.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 27/09/24.
//

// Models/HostApp.swift
import Foundation

class HostApp: ObservableObject, Identifiable {
    let id = UUID()
    @Published var name: String
    @Published var info: String
    @Published var lb: String?
    @Published var hosts: [Host]

    init(name: String, info: String = "", lb: String? = nil, hosts: [Host] = []) {
        self.name = name
        self.info = info
        self.lb = lb
        self.hosts = hosts
    }
}
