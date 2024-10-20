//
//  SplashScreenView.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 27/09/24.
//

// Views/SplashScreenView.swift
import SwiftUI

// NON LO USO PIU, DEPRECATO
struct SplashScreenView: View {
    var body: some View {
        VStack {
            Text("XTR TOOLKIT HOST")
                .font(.system(size: 35))
                .foregroundColor(.black)
                .padding()
            Text("by XtremeAlex")
                .font(.system(size: 15))
                .foregroundColor(Color.gray)
            Spacer()
        }
    }
}
