//
//  AnimatedLetter.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 20/10/24.
//

// Views/AnimatedLetter.swift

import SwiftUI

struct AnimatedLetter: Identifiable {
    let id = UUID()
    let character: String
    var isVisible: Bool = false
}
