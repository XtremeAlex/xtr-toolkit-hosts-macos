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

print("\(passed) verifiche superate, \(failures) fallite")
exit(failures == 0 ? 0 : 1)
