// Test da riga di comando della logica che scrive /etc/hosts (nessun privilegio, nessun
// accesso al file reale): `Tests/run-tests.sh`. Solo dati sintetici (example.internal, RFC 5737).

import Foundation

var failures = 0
var passed = 0

func check(_ condition: @autoclosure () -> Bool, _ message: String, line: Int = #line) {
    if condition() {
        passed += 1
    } else {
        failures += 1
        print("FAIL (riga \(line)): \(message)")
    }
}

let systemPrefix = """
##
# Host Database
##
127.0.0.1\tlocalhost
255.255.255.255\tbroadcasthost
::1             localhost
10.9.9.9 managed.example.internal

"""

func app(_ name: String, lb: String? = nil, _ hosts: [(String, String, Bool)]) -> HostAppSnapshot {
    HostAppSnapshot(name: name, lb: lb, hosts: hosts.map { .init(ip: $0.0, fqdn: $0.1, enabled: $0.2) })
}

// 1. Il contenuto prima del marcatore resta identico (prima veniva cancellato).
do {
    let original = systemPrefix + "##start-xtr-toolkit-host\n#APP: Vecchia\n192.0.2.1 old.example.internal\n"
    let section = HostsDocument.section(for: [app("Nuova", [("192.0.2.10", "new.example.internal", true)])])
    let merged = HostsDocument.merge(original: original, section: section)
    check(merged.hasPrefix(systemPrefix), "prefisso di sistema preservato")
    check(merged.contains("192.0.2.10 new.example.internal"), "nuova voce presente")
    check(!merged.contains("old.example.internal"), "vecchia sezione sostituita")
    check(merged.components(separatedBy: HostsDocument.sectionMarker).count == 2, "un solo marcatore")
    check(merged.hasSuffix("\n"), "newline finale")
}

// 2. Marcatore assente: sezione aggiunta in coda, resto intatto.
do {
    let original = "127.0.0.1 localhost"
    let merged = HostsDocument.merge(original: original, section: HostsDocument.section(for: []))
    check(merged.hasPrefix("127.0.0.1 localhost\n"), "file senza marcatore preservato")
    check(merged.contains("\n" + HostsDocument.sectionMarker), "marcatore aggiunto in coda")
}

// 3. Marcatore solo come sottostringa (commento): non va confuso con la riga del marcatore.
do {
    let original = "# nota: ##start-xtr-toolkit-host va su una riga da sola\n127.0.0.1 localhost\n"
    let merged = HostsDocument.merge(original: original, section: HostsDocument.section(for: []))
    check(merged.hasPrefix(original), "sottostringa nel commento ignorata")
}

// 4. Ordine stabile (prima dipendeva da un dizionario e cambiava a ogni esecuzione).
do {
    let hosts = (1...20).map { ("192.0.2.\($0 % 3 + 1)", "h\($0).example.internal", $0 % 2 == 0) }
    let a = HostsDocument.section(for: [app("Ordine", hosts)])
    let b = HostsDocument.section(for: [app("Ordine", hosts)])
    check(a == b, "output deterministico")
    let fqdns = a.filter { $0.contains("example.internal") }.map { $0.split(separator: " ")[1] }
    check(fqdns == hosts.map { Substring($0.1) }, "stesso ordine della UI")
}

// 5. Validazione: niente righe iniettate nel file di sistema.
do {
    check(HostsDocument.isValidIP("192.0.2.1"), "IPv4 valido")
    check(HostsDocument.isValidIP("2001:db8::1"), "IPv6 valido")
    check(HostsDocument.isValidIP("fe80::1%lo0"), "IPv6 con zona valido")
    check(!HostsDocument.isValidIP("192.0.2.256"), "IPv4 fuori range")
    check(!HostsDocument.isValidIP(" 192.0.2.1"), "spazi non ammessi")
    check(!HostsDocument.isValidIP("fe80::1%"), "zona vuota")
    check(HostsDocument.isValidHostname("app.example.internal"), "FQDN valido")
    check(HostsDocument.isValidHostname("svc_1.example.internal."), "underscore e punto finale")
    check(!HostsDocument.isValidHostname("a b"), "spazio nell'FQDN")
    check(!HostsDocument.isValidHostname("x\n10.0.0.1 evil"), "a capo nell'FQDN")
    check(!HostsDocument.isValidHostname("#commento"), "cancelletto nell'FQDN")
    check(!HostsDocument.isValidHostname("-bad.example"), "trattino iniziale")
    check(!HostsDocument.isValidHostname(String(repeating: "a", count: 64) + ".example"), "etichetta > 63")
    let invalid = HostsDocument.invalidEntries(in: [app("X", [("192.0.2.1", "ok.example", true),
                                                               ("nope", "ok.example", true)])])
    check(invalid.count == 1, "una voce non valida segnalata")
}

// 6. Nomi app/LB su piu' righe non spezzano il file.
do {
    let lines = HostsDocument.section(for: [app("Riga1\nRiga2", lb: "lb.example\n#x", [])])
    check(lines.contains("#APP: Riga1 Riga2"), "nome app su una riga")
    check(!lines.contains { $0 == "#x" }, "LB su una riga")
}

// 7. Round trip con il parser dell'app (file temporaneo sintetico).
do {
    let apps = [app("Collaudo", lb: "lb.example.internal", [("192.0.2.10", "a.example.internal", true),
                                                          ("192.0.2.11", "b.example.internal", false)]),
                app("Sviluppo", [("2001:db8::5", "c.example.internal", false)])]
    let content = HostsDocument.merge(original: systemPrefix, section: HostsDocument.section(for: apps))
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("hosts-test-\(UUID().uuidString)")
    try! content.write(to: url, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: url) }
    let parsed = try! IOHostParser.parseHostsFile(filePath: url.path)
    check(parsed.map(\.name) == ["Collaudo", "Sviluppo"], "nomi app riletti")
    check(parsed.first?.lb == "lb.example.internal", "LB riletto")
    check(parsed.first?.hosts.map(\.enabled) == [true, false], "stato abilitato riletto")
    check(parsed.last?.hosts.first?.ip == "2001:db8::5", "IPv6 disabilitato riletto")
    check(parsed.last?.hosts.first?.enabled == false, "IPv6 disabilitato resta disabilitato")
}

// 8. Letterale AppleScript: virgolette e backslash non chiudono la stringa.
do {
    check(IOHostParser.appleScriptLiteral("a\"b\\c") == "\"a\\\"b\\\\c\"", "escape AppleScript")
}

// 9. Parser: separatori multipli, tab, commenti in coda e "# LB:" con spazio.
do {
    let content = systemPrefix + """
    ##start-xtr-toolkit-host
    # APP: Spazi
    # LB: lb.example.internal
    192.0.2.20   a.example.internal\tb.example.internal   # nota di servizio
    #192.0.2.21\tc.example.internal
    192.0.2.22 d.example.internal #e.example.internal

    """
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("hosts-ws-\(UUID().uuidString)")
    try! content.write(to: url, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: url) }
    let parsed = try! IOHostParser.parseHostsFile(filePath: url.path)
    check(parsed.first?.name == "Spazi", "'# APP:' con spazio: nome corretto")
    check(parsed.first?.lb == "lb.example.internal", "'# LB:' con spazio: niente ': ' residuo")
    let hosts = parsed.first?.hosts ?? []
    check(hosts.map(\.fqdn) == ["a.example.internal", "b.example.internal", "c.example.internal",
                                "d.example.internal", "e.example.internal"], "nessun host vuoto o 'nota': \(hosts.map(\.fqdn))")
    check(hosts.map(\.enabled) == [true, true, false, true, false], "stati abilitato/disabilitato")
    check(HostsDocument.invalidEntries(in: parsed.map(\.snapshot)).isEmpty, "il file riletto resta salvabile")
    check(HostsDocument.tokens(of: "1.2.3.4\t\tx  # y") == ["1.2.3.4", "x"], "tokens")
}

// 10. Integrita', differenze e audit.
do {
    check(HostsDocument.sha256Hex("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "SHA-256 come shasum")
    let d = HostsDocument.diff(old: ["#APP: A", "192.0.2.1 a", "192.0.2.2 b", ""],
                               new: ["#APP: A", "192.0.2.1 a", "192.0.2.3 c", ""])
    check(d.added == ["192.0.2.3 c"] && d.removed == ["192.0.2.2 b"], "diff righe")
    let before = systemPrefix + "##start-xtr-toolkit-host\n192.0.2.1 a.example.internal\n"
    let after = systemPrefix + "##start-xtr-toolkit-host\n192.0.2.9 z.example.internal\n"
    let record = HostsAuditRecord(date: Date(timeIntervalSince1970: 0), user: "tester", hostsPath: "/etc/hosts",
                                  backupPath: "/etc/hosts.xtr-toolkit.x.bak", before: before, after: after)
    let json = record.jsonLine()
    check(json.hasSuffix("\n") && !json.dropLast().contains("\n"), "una riga JSON")
    check(json.contains("\"added\":[\"192.0.2.9 z.example.internal\"]"), "audit: aggiunta registrata")
    check(json.contains("\"removed\":[\"192.0.2.1 a.example.internal\"]"), "audit: rimozione registrata")
    check(!json.contains("localhost"), "audit: solo la sezione dell'app")
}

// 11. Politica MDM e script privilegiato.
do {
    let p = HostsPolicy.from([HostsPolicy.Key.readOnly: true, HostsPolicy.Key.backupRetention: 999,
                              HostsPolicy.Key.flushDNS: "false"])
    check(p.readOnly && p.backupRetention == 50 && !p.flushDNS, "politica letta e limitata")
    check(HostsPolicy.from([:]) == HostsPolicy(), "default senza profilo")
    check(HostsPolicy.from([HostsPolicy.Key.backupRetention: "0"]).backupRetention == 1, "almeno un backup")

    let date = Date(timeIntervalSince1970: 1_790_000_000)
    let backup = HostsWriteScript.backupPath(for: "/etc/hosts", date: date)
    check(backup.hasPrefix("/etc/hosts.xtr-toolkit.") && backup.hasSuffix(".bak"), "backup datato")
    let cmd = HostsWriteScript.command(source: "/tmp/x y'z", hostsPath: "/etc/hosts", backupPath: backup,
                                       expectedSHA256: String(repeating: "a", count: 64), policy: HostsPolicy())
    check(cmd.contains("exit 70") && cmd.contains(String(repeating: "a", count: 64)), "verifica hash prima della scrittura")
    check(cmd.contains("/usr/bin/install -S -o root -g wheel -m 0644"), "installazione atomica di root")
    check(cmd.contains("'/tmp/x y'\\''z'"), "percorso con apice correttamente quotato")
    check(cmd.contains("tail -n +6"), "rotazione: 5 backup")
    check(cmd.contains("mDNSResponder"), "cache DNS svuotata")
    var noFlush = HostsPolicy(); noFlush.flushDNS = false
    check(!HostsWriteScript.command(source: "/tmp/a", hostsPath: "/etc/hosts", backupPath: backup,
                                    expectedSHA256: "ab", policy: noFlush).contains("mDNSResponder"), "FlushDNS=false")
    check(!HostsWriteScript.command(source: "/tmp/a", hostsPath: "/etc/ho sts", backupPath: backup,
                                    expectedSHA256: "ab", policy: HostsPolicy()).contains("ls -1t"), "niente glob con percorsi insoliti")

    // Lo script e' eseguibile davvero (senza privilegi) su file temporanei: hash, backup, installazione, rotazione.
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("hosts-script-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let target = dir.appendingPathComponent("hosts").path
    let source = dir.appendingPathComponent("new").path
    try! "vecchio\n".write(toFile: target, atomically: true, encoding: .utf8)
    try! "nuovo\n".write(toFile: source, atomically: true, encoding: .utf8)
    func run(_ command: String) -> Int32 {
        // Senza root: install -o root fallirebbe, si prova il resto con owner/group correnti
        let adapted = command.replacingOccurrences(of: "-o root -g wheel ", with: "")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", adapted]
        try! p.run()
        p.waitUntilExit()
        return p.terminationStatus
    }
    let wrongHash = HostsWriteScript.command(source: source, hostsPath: target, backupPath: target + ".bak",
                                             expectedSHA256: String(repeating: "0", count: 64), policy: noFlush)
    check(run(wrongHash) == 70, "file cambiato: uscita 70")
    check((try? String(contentsOfFile: target, encoding: .utf8)) == "vecchio\n", "file cambiato: nulla scritto")
    let good = HostsWriteScript.command(source: source, hostsPath: target, backupPath: target + ".bak",
                                        expectedSHA256: HostsDocument.sha256Hex("vecchio\n"), policy: noFlush)
    check(run(good) == 0, "scrittura riuscita")
    check((try? String(contentsOfFile: target, encoding: .utf8)) == "nuovo\n", "contenuto installato")
    check((try? String(contentsOfFile: target + ".bak", encoding: .utf8)) == "vecchio\n", "backup creato")
}

print("\(passed) verifiche superate, \(failures) fallite")
exit(failures == 0 ? 0 : 1)
