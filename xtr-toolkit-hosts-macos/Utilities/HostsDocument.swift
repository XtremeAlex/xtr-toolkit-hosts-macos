//
//  HostsDocument.swift
//  xtr-toolkit-hosts-macos
//
//  Logica pura (senza UI ne' privilegi) per validare le voci e comporre il nuovo /etc/hosts.
//  Separata da IOHostParser perche' e' la parte che puo' danneggiare il sistema: cosi' e'
//  testabile da riga di comando (Tests/run-tests.sh) senza toccare il file reale.
//

import CryptoKit
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

    // MARK: - Lettura delle righe

    /// Parole significative di una riga hosts: separatori multipli e tabulazioni non creano
    /// parole vuote, e tutto cio' che segue un `#` a meta' riga e' un commento.
    ///
    /// Perche': `components(separatedBy: .whitespaces)` restituiva stringhe vuote per
    /// "10.0.0.1   nome" o righe allineate con tab, creando host senza nome che poi bloccavano
    /// ogni salvataggio; "1.2.3.4 nome # nota" diventava un host chiamato "nota".
    static func tokens(of line: String) -> [String] {
        var out: [String] = []
        for word in line.split(whereSeparator: { $0 == " " || $0 == "\t" }) {
            if word.hasPrefix("#") { break }
            out.append(String(word))
        }
        return out
    }

    // MARK: - Differenze e integrita'

    /// Nomi di una riga "ip nome1 nome2 ...": `#nome` attaccato (formato storico dell'app)
    /// e' un nome disabilitato, mentre `#` seguito da spazio o da testo che non e' un nome
    /// host apre un commento e chiude la riga.
    static func hostEntries(of line: String) -> [(name: String, enabled: Bool)] {
        var out: [(String, Bool)] = []
        for word in line.split(whereSeparator: { $0 == " " || $0 == "\t" }).dropFirst() {
            if word.hasPrefix("#") {
                let name = String(word.drop(while: { $0 == "#" }))
                guard isValidHostname(name) else { break }
                out.append((name, false))
            } else {
                out.append((String(word), true))
            }
        }
        return out
    }

    // MARK: - Differenze e integrita'

    /// Righe aggiunte e rimosse fra due versioni della sezione (confronto per righe non
    /// vuote, conteggio delle ripetizioni). Usato dal registro di audit.
    static func diff(old: [String], new: [String]) -> (added: [String], removed: [String]) {
        func counts(_ lines: [String]) -> [String: Int] {
            lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.reduce(into: [:]) { $0[$1, default: 0] += 1 }
        }
        let a = counts(old), b = counts(new)
        func extra(_ lines: [String], _ mine: [String: Int], _ other: [String: Int]) -> [String] {
            var seen = Set<String>(), out: [String] = []
            for line in lines where mine[line] != nil && seen.insert(line).inserted {
                let n = mine[line]! - (other[line] ?? 0)
                if n > 0 { out.append(contentsOf: Array(repeating: line, count: n)) }
            }
            return out
        }
        return (extra(new, b, a), extra(old, a, b))
    }

    /// Righe della sezione dell'app presenti nel testo (dal marcatore a fine file).
    static func sectionLines(of text: String) -> [String] {
        guard let range = markerLineRange(in: text) else { return [] }
        return text[range.lowerBound...].components(separatedBy: "\n")
    }

    /// SHA-256 esadecimale (minuscolo) del testo UTF-8: stesso valore di `shasum -a 256`.
    static func sha256Hex(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
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


// MARK: - Politica aziendale

/// Preferenze gestibili via MDM (profilo di configurazione sul dominio dell'app).
/// Logica pura: si prova con Tests/run-tests.sh.
struct HostsPolicy: Equatable {
    enum Key {
        static let readOnly = "ReadOnly"
        static let backupRetention = "BackupRetention"
        static let flushDNS = "FlushDNS"
    }

    static let allowedRetention: ClosedRange<Int> = 1...50
    static let defaultRetention = 5

    /// Sola lettura: l'app mostra le voci ma non permette di modificarle ne' salvarle.
    var readOnly = false
    /// Numero di backup datati conservati in /etc (i piu' vecchi vengono eliminati).
    var backupRetention = HostsPolicy.defaultRetention
    /// Svuota la cache DNS dopo il salvataggio (default si').
    var flushDNS = true

    static func from(_ values: [String: Any]) -> HostsPolicy {
        var p = HostsPolicy()
        p.readOnly = bool(values[Key.readOnly]) ?? false
        p.flushDNS = bool(values[Key.flushDNS]) ?? true
        let retention: Int?
        switch values[Key.backupRetention] {
        case let n as Int: retention = n
        case let n as NSNumber: retention = n.intValue
        case let s as String: retention = Int(s.trimmingCharacters(in: .whitespaces))
        default: retention = nil
        }
        p.backupRetention = min(max(retention ?? defaultRetention, allowedRetention.lowerBound), allowedRetention.upperBound)
        return p
    }

    static func current(_ defaults: UserDefaults = .standard) -> HostsPolicy {
        from(defaults.dictionaryRepresentation())
    }

    private static func bool(_ value: Any?) -> Bool? {
        switch value {
        case let b as Bool: return b
        case let n as NSNumber: return n.boolValue
        case let s as String: return ["1", "true", "yes", "si"].contains(s.lowercased())
        default: return nil
        }
    }
}

// MARK: - Script privilegiato

/// Comando shell eseguito con privilegi di amministratore per sostituire /etc/hosts.
///
/// Scelte (uso aziendale):
/// - codici d'uscita dedicati, riconosciuti dall'app: 70 = file modificato da altri dopo la
///   lettura (un agente MDM o un altro amministratore: meglio fermarsi che sovrascrivere),
///   71 = verifica dopo la scrittura fallita, 72 = backup non riuscito, 73 = installazione fallita;
/// - `install -S`: copia sicura su file temporaneo + rinomina, niente file hosts troncato se
///   il processo si interrompe a meta';
/// - backup datati con rotazione, cosi' due salvataggi di fila non cancellano l'ultimo buono;
/// - ogni percorso passa da `shellQuote`: nessuna interpolazione non controllata.
enum HostsWriteScript {
    static let exitModified: Int = 70
    static let exitVerify: Int = 71
    static let exitBackup: Int = 72
    static let exitInstall: Int = 73

    /// Percorso del backup datato, es. /etc/hosts.xtr-toolkit.20260930-013300.bak.
    static func backupPath(for hostsPath: String, date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd-HHmmss"
        return "\(hostsPath).xtr-toolkit.\(f.string(from: date)).bak"
    }

    static func command(source: String, hostsPath: String, backupPath: String, expectedSHA256: String,
                        policy: HostsPolicy) -> String {
        precondition(expectedSHA256.allSatisfy { $0.isHexDigit }, "hash non esadecimale")
        let src = shellQuote(source), dst = shellQuote(hostsPath), bak = shellQuote(backupPath)
        var parts = [
            "h=$(/usr/bin/shasum -a 256 < \(dst) | /usr/bin/cut -d ' ' -f 1)",
            "[ \"$h\" = \"\(expectedSHA256)\" ] || exit \(exitModified)",
            "/bin/cp -p \(dst) \(bak) || exit \(exitBackup)",
            "/usr/bin/install -S -o root -g wheel -m 0644 \(src) \(dst) || exit \(exitInstall)",
            "/usr/bin/cmp -s \(src) \(dst) || exit \(exitVerify)",
        ]
        // Rotazione solo con un percorso "semplice": il glob non puo' stare fra apici.
        if hostsPath.range(of: "^[A-Za-z0-9/._-]+$", options: .regularExpression) != nil {
            parts.append("/bin/ls -1t \(hostsPath).xtr-toolkit.*.bak 2>/dev/null | /usr/bin/tail -n +\(policy.backupRetention + 1) | while IFS= read -r f; do /bin/rm -f \"$f\"; done")
        }
        if policy.flushDNS {
            parts.append("(/usr/bin/dscacheutil -flushcache; /usr/bin/killall -HUP mDNSResponder) >/dev/null 2>&1")
        }
        parts.append("exit 0")
        return parts.joined(separator: "; ")
    }

    /// Apici singoli POSIX: `'` diventa `'\''`.
    static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

// MARK: - Audit

/// Riga del registro di audit (JSON Lines): chi, quando, cosa e dove sta il backup.
/// Le voci hosts sono dati di configurazione, non personali: si registrano per esteso
/// (massimo 200 per lato) cosi' un revisore ricostruisce ogni modifica.
struct HostsAuditRecord: Encodable {
    let timestamp: String
    let user: String
    let hostsPath: String
    let backupPath: String
    let sha256Before: String
    let sha256After: String
    let added: [String]
    let removed: [String]

    init(date: Date, user: String, hostsPath: String, backupPath: String, before: String, after: String) {
        let iso = ISO8601DateFormatter()
        self.timestamp = iso.string(from: date)
        self.user = user
        self.hostsPath = hostsPath
        self.backupPath = backupPath
        self.sha256Before = HostsDocument.sha256Hex(before)
        self.sha256After = HostsDocument.sha256Hex(after)
        let d = HostsDocument.diff(old: HostsDocument.sectionLines(of: before), new: HostsDocument.sectionLines(of: after))
        self.added = Array(d.added.prefix(200))
        self.removed = Array(d.removed.prefix(200))
    }

    func jsonLine() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = (try? encoder.encode(self)) ?? Data("{}".utf8)
        return String(decoding: data, as: UTF8.self) + "\n"
    }
}
