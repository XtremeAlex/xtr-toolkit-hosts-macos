//
//  CustomToggleStyle.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 27/09/24.
//

// Views/CustomToggleStyle.swift
import SwiftUI

struct CustomToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            // Etichetta (opzionale)
            configuration.label

            Spacer()

            // Pulsante del toggle
            ZStack {
                // Sfondo
                RoundedRectangle(cornerRadius: 16)
                    .fill(configuration.isOn ? Color.green : Color.gray)
                    .frame(width: 50, height: 30)

                // Cerchio mobile dentor il pulsante
                Circle()
                    .fill(Color.white)
                    .frame(width: 26, height: 26)
                    .offset(x: configuration.isOn ? 10 : -10)
                    .animation(.easeInOut(duration: 0.2), value: configuration.isOn)
            }
            .onTapGesture {
                configuration.isOn.toggle()
            }
        }
    }
}
// Che dire è questa personalizzazione che manca a JAVA :D