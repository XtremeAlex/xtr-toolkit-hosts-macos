//
//  HostsDocument.swift
//  xtr-toolkit-hosts-macos
//
//  Logica pura (senza UI ne' privilegi) per validare le voci e comporre il nuovo /etc/hosts.
//  Separata da IOHostParser perche' e' la parte che puo' danneggiare il sistema: cosi' e'
//  testabile da riga di comando (Tests/run-tests.sh) senza toccare il file reale.
//

import Foundation

enum HostsDocument {

    static let sectionMarker = "##start-xtr-toolkit-host"

    // MARK: - Composizione

    /// Nuovo contenuto completo del file hosts.
    ///
    /// Perche': prima veniva scritta SOLO la sezione dell'app, cancellando tutto cio' che
    /// precede il marcatore (`127.0.0.1 localhost`, `::1 localhost`, `broadcasthost`, voci
    /// aziendali gestite da MDM). Ora la parte prima del marcatore resta byte per byte
    /// identica e viene sostituita solo la sezione, che il parser legge fino a fine file.
    /// Se il marcatore manca, la sezione viene aggiunta in coda senza toccare il resto.
    static func merge(original: String, section: [String]) -> String {
        let sectionText = section.joined(separator: "\n")
        var prefix: String
        if let range = markerLineRange(in: original) {
            prefix = String(original[..<range.lowerBound])
        } else {
            prefix = original
            if !prefix.isEmpty && !prefix.hasSuffix("\n") { prefix += "\n" }
            if !prefix.isEmpty { prefix += "\n" }
        }
        var result = prefix + sectionText
        if !result.hasSuffix("\n") { result += "\n" }
        return result
    }

    /// Righe della sezione dell'app, in ordine stabile (stesso ordine della UI).
    ///
    /// Perche': prima gli host venivano raggruppati in un dizionario per IP, il cui ordine in
    /// Swift e' casuale a ogni esecuzione: ogni salvataggio rimescolava il file e rendeva
    /// inutile il confronto (diff) fra versioni.
    static func section(for apps: [HostAppSnapshot]) -> [String] {
        var lines = [sectionMarker]
        for app in apps {
            let name = singleLine(app.name).replacingOccurrences(of: ":", with: "")
            if !name.isEmpty { lines.append("#APP: \(name)") }
            if let lb = app.lb.map(singleLine)?.replacingOccurrences(of: ":", with: ""), !lb.isEmpty {
                lines.append("#LB: \(lb)")
            }
            // Nessun filtro qui: le voci non valide bloccano il salvataggio a monte
            // (invalidEntries), cosi' nessun dato dell'utente sparisce in silenzio.
            for host in app.hosts {
                lines.append((host.enabled ? "" : "#") + "\(host.ip) \(host.fqdn)")
            }
            lines.append("")
        }
        return lines
    }

    /// Voci non valide: se non vuoto il salvataggio viene rifiutato con l'elenco.
    static func invalidEntries(in apps: [HostAppSnapshot]) -> [String] {
        apps.flatMap { app in
            app.hosts.compactMap { host in
                validationError(ip: host.ip, fqdn: host.fqdn).map { "\(app.name): \($0)" }
            }
        }
    }

    // MARK: - Validazione

    /// Messaggio d'errore oppure nil se la coppia IP/FQDN e' scrivibile in /etc/hosts.
    ///
    /// Perche': il valore finisce in un file di sistema. Uno spazio, un "#" o un a capo
    /// nell'FQDN creerebbero righe arbitrarie (voci nascoste o commentate per errore).
    static func validationError(ip: String, fqdn: String) -> String? {
        if !isValidIP(ip) { return "indirizzo IP non valido '\(ip)'" }
        if !isValidHostname(fqdn) { return "nome host non valido '\(fqdn)'" }
        return nil
    }

    static func isValidIP(_ value: String) -> Bool {
        let v = value.trimmingCharacters(in: .whitespaces)
        guard !v.isEmpty, v == value else { return false }
        var v4 = in_addr()
        if inet_pton(AF_INET, v, &v4) == 1 { return true }
        // IPv6 con zona (es. fe80::1%lo0, presente nel file hosts di default di macOS).
        let address = v.split(separator: "%", maxSplits: 1).first.map(String.init) ?? v
        if v.contains("%") {
            let zone = v.split(separator: "%", maxSplits: 1).dropFirst().first ?? ""
            guard !zone.isEmpty, zone.allSatisfy({ $0.isLetter || $0.isNumber }) else { return false }
        }
        var v6 = in6_addr()
        return inet_pton(AF_INET6, address, &v6) == 1
    }

    /// Nome host RFC 1123: etichette 1-63 caratteri [A-Za-z0-9-], senza trattino ai bordi,
    /// totale massimo 253. Ammesso il punto finale (FQDN assoluto) e il trattino basso,
    /// frequente nei nomi interni aziendali e accettato dal resolver di macOS.
    static func isValidHostname(_ value: String) -> Bool {
        var name = value
        if name.hasSuffix(".") { name.removeLast() }
        guard !name.isEmpty, name.utf8.count <= 253 else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        for label in name.split(separator: ".", omittingEmptySubsequences: false) {
            guard (1...63).contains(label.utf8.count),
                  label.unicodeScalars.allSatisfy(allowed.contains),
                  !label.hasPrefix("-"), !label.hasSuffix("-") else { return false }
        }
        return true
    }

    // MARK: - Helper

    private static func singleLine(_ s: String) -> String {
        s.components(separatedBy: .newlines).joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }

    /// Range della riga del marcatore (confronto sulla riga ripulita, come fa il parser).
    private static func markerLineRange(in text: String) -> Range<String.Index>? {
        var searchStart = text.startIndex
        while let r = text.range(of: sectionMarker, range: searchStart..<text.endIndex) {
            let lineStart = text[..<r.lowerBound].lastIndex(of: "\n").map { text.index(after: $0) } ?? text.startIndex
            let lineEnd = text[r.upperBound...].firstIndex(of: "\n") ?? text.endIndex
            if text[lineStart..<lineEnd].trimmingCharacters(in: .whitespaces) == sectionMarker {
                return lineStart..<lineEnd
            }
            searchStart = r.upperBound
        }
        return nil
    }
}

/// Copia immutabile del modello, per comporre il file fuori dal main thread senza toccare
/// gli ObservableObject della UI.
struct HostAppSnapshot {
    struct Entry { let ip: String; let fqdn: String; let enabled: Bool }
    let name: String
    let lb: String?
    let hosts: [Entry]
}
