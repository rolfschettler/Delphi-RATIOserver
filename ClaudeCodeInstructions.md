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

Claude Code MUSS immer zuerst die DB-Struktur ermitteln:

```bash
curl -H "Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJJbnRlcmJhc2Utd2VibW9kdWxlIiwic3ViIjoiU1VQRVJWSVNPUiIsImlhdCI6MTc3NzM3NDUxOCwiZXhwIjo1NTc3NzM3NDUxOCwicm9sZSI6IntcImxvZ2lubmFtZVwiOlwiU1VQRVJWSVNPUlwiLFwidXNlcm5hbWVcIjpcIlJvbGYgU2NoZXR0bGVyXCIsXCJwYXNzd29ydFwiOlwiXCIsXCJncnVwcGVcIjpcIlhZWlwiLFwienVncnVwcGVcIjpcIlwiLFwiYWdlbnR1cmNvZGVcIjpcIlwiLFwia2VubnppZmZlclwiOlwiXCIsXCJmaWxpYWxlXCI6XCJcIixcImFidGVpbHVuZ1wiOlwiXCJ9In0.VcuTlWenXqPx9P4GqvzDN0LaVy9O9uJhJ_tStnvoh1w" \
  "http://localhost/ibapi/tablestructure?table=TABELLENNAME"
```

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

---

## Wichtige Regeln für Claude Code

✅ **MÜSSEN:**
- Pattern-Datei als einzige Referenz nutzen
- Tabellenstruktur vor Codegenerierung abrufen (curl)
- Methodennamen exakt wie im Pattern
- Zieldatei und Sequence-Name fragen (falls nicht genannt)

❌ **DÜRFEN NICHT:**
- Neue .pas oder .dfm Dateien erstellen
- Bestehenden Code ändern
- Andere Dateien im Projekt konsultieren
- Methodennamen variieren
- Business-Logik hinzufügen (nur CRUD)





