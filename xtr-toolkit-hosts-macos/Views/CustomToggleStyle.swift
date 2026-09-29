//
//  CustomToggleStyle.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 27/09/24.
//

// Views/CustomToggleStyle.swift
import SwiftUI

/// Interruttore del tema 2AD (`.switch` della web app): binario 44x24, pallino 16,
/// acceso = accento rosso con pallino bianco, spento = --surface-2 con bordo --control.
///
/// Perche' un Button e non onTapGesture: cosi' l'interruttore e' raggiungibile con Tab,
/// si attiva con Spazio e VoiceOver lo annuncia come interruttore con il suo stato.
struct SwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: Theme.s3) {
                configuration.label
                    .foregroundStyle(Theme.text)
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(configuration.isOn ? Theme.accent : Theme.surface2)
                        .overlay(Capsule().strokeBorder(configuration.isOn ? Theme.accent : Theme.control))
                        .frame(width: 44, height: 24)
                    Circle()
                        .fill(configuration.isOn ? Color.white : Theme.textMuted)
                        .frame(width: 16, height: 16)
                        .padding(.horizontal, 4)
                }
                .animation(.easeInOut(duration: 0.18), value: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? "attivo" : "disattivo")
    }
}

/// Nome storico mantenuto per compatibilita' con le viste esistenti.
typealias CustomToggleStyle = SwitchStyle
