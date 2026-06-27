# Claude Code Automation Patterns für Delphi 13 + InterBase

## ⚠️ KRITISCHE REGELN (ABSOLUT)

1. **AUTORITATIVE QUELLE**: `ClaudeCodePatterns/DataModulWhateverClass.pas`
   - Nur diese Datei als Vorlage verwenden
   - Exakt die Methodennamen, Signaturen und Struktur kopieren
   - KEINE Abweichungen!

2. **KEINE neuen Dateien**
   - NIE: `.pas` oder `.dfm` Dateien erstellen
   - IMMER: Code in bestehende DataModul-Klasse einfügen

3. **KEINE bestehenden Funktionen ändern**
   - Nur neue CRUD-Methoden hinzufügen
   - Bestehender Code bleibt unverändert

4. **KEINE anderen Dateien als Referenz**
   - Nicht im Projekt rumschauen
   - Nicht "ähnliche Klassen" als Vorlage nutzen
   - Pattern-Datei = einzige Quelle der Wahrheit

---

## Workflow: CRUD-Generierung

### Schritt 1: Tabellenstruktur abrufen

Claude Code MUSS immer zuerst die DB-Struktur ermitteln.

**Token:** Wird aus `ClaudeCodePatterns/token.local.txt` gelesen (diese Datei
ist personenbezogen, NICHT Teil des Git-Repos und enthält pro Entwickler
einen eigenen gültigen Token).

Falls `token.local.txt` fehlt oder leer ist: **nachfragen**, NICHT raten,
NICHT einen Platzhalter oder alten Token aus dem Gedächtnis verwenden.

```bash
curl -H "Authorization: Bearer $(cat ClaudeCodePatterns/token.local.txt)" \
  "http://localhost/ibapi/tablestructure?table=TABELLENNAME"
```

(PowerShell-Äquivalent: `Get-Content ClaudeCodePatterns/token.local.txt` statt `cat`)

### Schritt 2: Pattern anwenden

- Öffne: `ClaudeCodePatterns/DataModulWhateverClass.pas`
- Kopiere die Methoden-Struktur EXAKT
- Ersetze nur: `[TableName]`, `[Entity]`, `[FieldNames]`, `[Sequence]`
- Behalte Methodennamen exakt bei

### Schritt 3: Code in Zieldatei einfügen

Beispiele für Zieldateien:
- Tabelle `Kunden` → `DataModulKundenController.pas`
- Tabelle `Produkte` → `DataModulProdukteController.pas`
- Tabelle `Adressen` → `DataModulAddressenController.pas`

**Falls die Zieldatei unklar ist:** Frage nach!

### Schritt 4: Routes registrieren (manuell)

Du ergänzt die Routes selbst in: `Shared\WebModuleUnit1.pas`

Muster (Beispiel Adressen):
```delphi
FRouter.AddRoute('/adressen/getadressen', CreateDataModulAdressen, TDataModulAdressen(nil).getAdressen);
FRouter.AddRoute('/adressen/getadressenfiltered', CreateDataModulAdressen, TDataModulAdressen(nil).getAdressenFiltered);
FRouter.AddRoute('/adressen/getadressebyid', CreateDataModulAdressen, TDataModulAdressen(nil).getAdresseById);
FRouter.AddRoute('/adressen/getnextkey', CreateDataModulAdressen, TDataModulAdressen(nil).getNextKey);
FRouter.AddRoute('/adressen/insertadresse', CreateDataModulAdressen, TDataModulAdressen(nil).insertAdresse);
FRouter.AddRoute('/adressen/updateadresse', CreateDataModulAdressen, TDataModulAdressen(nil).updateAdresse);
FRouter.AddRoute('/adressen/deleteadresse', CreateDataModulAdressen, TDataModulAdressen(nil).deleteAdresse);
```

### Schritt 5: Postman-Delta-Collection erstellen (automatisch)

Nach Abschluss von Schritt 3 (unabhängig von Schritt 4, da Routes manuell
ergänzt werden) erstellt Claude Code **automatisch** eine Postman Collection
JSON für die in dieser Session neu erstellten Endpunkte.

**Vorgaben:**
- Schema-Version: Postman Collection v2.1.0
- Speicherort: `postman/`
- Dateiname: `<NAME>_<JJJJ-MM-TT>.postman_collection.json`
  - `<NAME>` = Inhalt von `ClaudeCodePatterns/dev.local.txt` (Vorname des
    aktuellen Bearbeiters). Falls diese Datei fehlt oder leer ist: nachfragen,
    NICHT raten.
  - `<JJJJ-MM-TT>` = heutiges Datum
- Collection-Variable `{{baseUrl}}` verwenden, Wert: `http://localhost/ratioserver`
- **Nur** die in dieser Session neu hinzugefügten Endpunkte enthalten –
  keine bestehenden Endpunkte erneut exportieren
- Ordnerstruktur innerhalb der Collection nach Ressource (z.B. `Adressen`)
- Für `insert`/`update`-Endpunkte: Beispiel-Request-Body als JSON, basierend
  auf den tatsächlichen Feldern aus der Tabellenstruktur (Schritt 1)
- Für `getById`/`delete`: Beispiel-Parameter (z.B. `id`)
- Kurze Beschreibung je Request (was macht der Endpunkt)

Diese Datei wird **immer ohne separate Aufforderung** erzeugt, sobald neue
CRUD-Endpunkte nach diesem Pattern gebaut wurden.

---

## Verfügbare Patterns

### Pattern: Komplette CRUD

**Referenz-Datei:** `ClaudeCodePatterns/DataModulWhateverClass.pas`

**Methoden, die generiert werden:**
- `getNextKey()` → Sequence-Wert abrufen
- `get[Entity]()` → Alle Records
- `get[Entity]Filtered()` → Mit Filter
- `get[Entity]ById(Id)` → Ein Record
- `insert[Entity](Entity)` → Neuer Record
- `update[Entity](Entity)` → Record aktualisieren
- `delete[Entity](Id)` → Record löschen

**Fragen an dich (falls nicht genannt):**
1. Zieldatei-Name (z.B. `DataModulKundenController`)
2. Sequence-Name für `getNextKey()` (z.B. `GEN_KUNDEN_ID`)

---

## Request-Body lesen & Antwort senden

In Controller-Handlern Body-Parameter **NICHT** manuell parsen, sondern die
Methoden der Basisklasse `TDataModulBaseClass` nutzen (Body wird intern einmal
geparst und leak-sicher freigegeben):

- `isParamFromBody('x')` → ist Parameter `x` im Body vorhanden (und nicht null)?
- `getParamFromBody('x', default)` → Wert von `x` als String (Zahl bei Bedarf an
  der Aufrufstelle per `StrToIntDef`)
- `SendJson(obj)` → sendet `obj` als JSON-Antwort (setzt Content-Type + Status)
  und gibt es frei; kein `try/finally`/`Free` nötig
- `JsonOrNull(gesetzt, wert)` (in `webUtils`) → Wert oder JSON `null` für `AddPair`

**Vorbild/Vorlage:** `Demo`-Methode in `ClaudeCodePatterns/DataModulDemoClass.pas`.

---

## Häufige Fehler (Blacklist)

### ❌ Fehler 1: Methodennamen variieren
**Falsch:** `getTeilnehmerNextNr`, `GetTeilnehmerSequence`
**Richtig:** `getNextKey` (immer gleich)

### ❌ Fehler 2: Andere Dateien als Referenz
**Falsch:** "Ich kopiere das Pattern aus DataModulIncomingClass.pas"
**Richtig:** "Ich nutze nur ClaudeCodePatterns/DataModulWhateverClass.pas"

### ❌ Fehler 3: Neue Dateien erstellen
**Falsch:** `DataModulNeuesFunktionClass.pas` anlegen
**Richtig:** Code in bestehende Datei einfügen

### ❌ Fehler 4: Bestehenden Code ändern
**Falsch:** Existierende `getAdressen()`-Methode modifizieren
**Richtig:** Neue Methoden dazufügen

### ❌ Fehler 5: Postman-Export vergessen oder bestehende Endpunkte mit exportieren
**Falsch:** Keine Postman-Datei erzeugen, oder alle Endpunkte der Zieldatei exportieren
**Richtig:** Automatisch `postman/<Name>_<Datum>.postman_collection.json` nur mit den neuen Endpunkten dieser Session

### ❌ Fehler 6: Body-Parameter manuell parsen
**Falsch:** `Body := ParseJSONObject(Request.Content)` + `try/finally` im Handler
**Richtig:** `isParamFromBody('x')` / `getParamFromBody('x')` der Basisklasse nutzen

---

## Wichtige Regeln für Claude Code

✅ **MÜSSEN:**
- Pattern-Datei als einzige Referenz nutzen
- Tabellenstruktur vor Codegenerierung abrufen (curl)
- Methodennamen exakt wie im Pattern
- Zieldatei und Sequence-Name fragen (falls nicht genannt)
- Postman-Delta-Collection für neue Endpunkte automatisch erstellen (Schritt 5)

❌ **DÜRFEN NICHT:**
- Neue .pas oder .dfm Dateien erstellen
- Bestehenden Code ändern
- Andere Dateien im Projekt konsultieren
- Methodennamen variieren
- Business-Logik hinzufügen (nur CRUD)
- Bestehende Endpunkte erneut in die Postman-Collection aufnehmen

---

## Setup: Token-Datei (einmalig pro Entwickler)

1. `ClaudeCodePatterns/token.local.txt.example` kopieren nach
   `ClaudeCodePatterns/token.local.txt`
2. Eigenen gültigen Bearer-Token eintragen (nur der Token-String, keine
   Anführungszeichen, keine Zeilenumbrüche)
3. Sicherstellen, dass `ClaudeCodePatterns/token.local.txt` in der
   `.gitignore` steht:
   ```
   ClaudeCodePatterns/token.local.txt
   ```

Diese Datei ist **personenbezogen** – Rolfs Token und Harrys Token sind
unterschiedlich und jeweils nur lokal gültig/vorhanden. Sie wird nie
committed.

## Setup: Entwickler-Name-Datei (einmalig pro Entwickler)

1. `ClaudeCodePatterns/dev.local.txt.example` kopieren nach
   `ClaudeCodePatterns/dev.local.txt`
2. Eigenen Vornamen eintragen, z.B. `Rolf` (bei Harry entsprechend `Harry`)
   – nur das Wort, keine Anführungszeichen, keine Zeilenumbrüche
3. Sicherstellen, dass `ClaudeCodePatterns/dev.local.txt` in der
   `.gitignore` steht:
   ```
   ClaudeCodePatterns/dev.local.txt
   ```

Dient dazu, dass Claude Code beim Erzeugen der Postman-Delta-Collection
(Schritt 5) automatisch den richtigen Namen für den Dateinamen verwendet,
ohne jedes Mal nachfragen zu müssen.





