# RATIOserver – Projektregeln

## CRUD/Controller Workflow (Pflicht – absolut verbindlich)
`ClaudeCodeInstructions.md` ist die Standard-Referenz für alle Code-Generierungsaufgaben.
Vor jeder CRUD- oder Controller-Aufgabe ZUERST `ClaudeCodeInstructions.md` lesen und strikt befolgen.

**Kritische Regeln (absolut):**
1. Einzige Referenz: `ClaudeCodePatterns/DataModulWhateverClass.pas` — nur diese Datei als Vorlage, exakt kopieren.
2. Keine neuen Dateien: Niemals `.pas` oder `.dfm` erstellen (außer bei Pattern 2 – Controller-Duplikation).
3. Keinen bestehenden Code ändern: Nur neue CRUD-Methoden hinzufügen.
4. Keine anderen Projektdateien als Referenz konsultieren.

**Pattern 1 – CRUD-Generierung:**
- DB-Struktur per curl abrufen: `curl -H "Authorization: Bearer <token>" "http://localhost/ibapi/tablestructure?table=TABELLENNAME"`
- Token steht in `ClaudeCodePatterns/token.local.txt`
- Methoden: `get[Entity]Key`, `get[Entity]`, `get[Entity]Filtered`, `get[Entity]ById`, `insert[Entity]`, `update[Entity]`, `delete[Entity]`
- Achtung: Key-Methode heißt `get[Entity]Key` — NICHT `getNextKey`
- Entity-Name = exakter Tabellenname (inkl. Präfix): Tabelle `T_VORGANG` → Entity `T_Vorgang` → Methoden `getT_Vorgang`, `insertT_Vorgang` etc.; Routen `/gett_vorgang`, `/insertt_vorgang` etc.
- Routes in `Shared\WebModuleUnit1.pas` ergänzen

**Pattern 2 – DataModul-Duplikation (neuer Controller):**
- Template: `ClaudeCodePatterns/DataModulDemoClass.pas` + `.dfm`
- Beide Dateien kopieren, umbenennen, alle Klassennamen + Unit-Namen anpassen
- Ziel: `Shared\DataModuls\`
- USES in `CGIStandalone\IBApiTest.dpr` und `ApacheDll\mod_webbroker.dpr` ergänzen
- Template-Dateien NICHT verändern

**Blacklist (häufige Fehler):**
- Methodennamen variieren (falsch: `getTeilnehmerNextNr` → richtig: `getTeilnehmerKey`)
- Andere Dateien als Referenz nutzen (nur Pattern-Datei)
- Neue Dateien anlegen statt in bestehende einfügen
- Bestehende Methoden modifizieren
- Body-Parameter manuell parsen (`ParseJSONObject(Request.Content)` + `try/finally`) statt `isParamFromBody`/`getParamFromBody` der Basisklasse zu nutzen

## JSON Parsing
In `Shared\webUtils.pas` existiert die Funktion `ParseJSONObject(const AJson: string): TJSONObject`.
Sie ist der leak-sichere Drop-in-Ersatz für `TJSONObject.ParseJSONValue(X) as TJSONObject` und MUSS überall verwendet werden — auch in neuen CRUD-Handlern / Pattern-basiertem Code.

**Statt:** `X := TJSONObject.ParseJSONValue(s) as TJSONObject;`
**Immer:** `X := ParseJSONObject(s);`

Rückgabe ist das Objekt oder `nil` (bei Nicht-Objekt/ungültigem JSON) — vorhandene `if X = nil then raise` / `if Assigned(X)`-Guards bleiben gültig.

**Grund:** Der `as TJSONObject`-Cast leckt Speicher, wenn der Client gültiges JSON sendet, das aber kein Objekt ist (z.B. `[...]`, `"text"`, `123`, `true`): `ParseJSONValue` erzeugt ein `TJSONValue`, der Cast wirft `EInvalidCast`, das geparste Objekt wird nie freigegeben. In der Apache-DLL (Dauerläufer) ist das ein remote auslösbares Leck. Am 2026-06-04 wurden alle ~23 Fundstellen projektweit umgestellt.

Korrektes manuelles Muster (parse → `is TJSONObject` → `FreeAndNil`) als Vorbild: `DataModulDispoClass.pas`.

## Request-Body lesen & Antwort senden
In Controller-Handlern Body-Parameter NICHT manuell parsen, sondern die Methoden der Basisklasse `TDataModulBaseClass` nutzen (Body wird intern einmal geparst, leak-sicher freigegeben):
- `isParamFromBody('x')` — ist Parameter `x` im Body vorhanden (und nicht null)?
- `getParamFromBody('x', default)` — Wert von `x` als String (Zahl bei Bedarf an der Aufrufstelle per `StrToIntDef`).
- `SendJson(obj)` — sendet `obj` als JSON-Antwort (setzt Content-Type + Status) und gibt es frei; kein `try/finally`/`Free` nötig.
- `JsonOrNull(gesetzt, wert)` (in `webUtils`) — Wert oder JSON `null` für `AddPair`.

Vorbild/Vorlage: `Demo`-Methode in `ClaudeCodePatterns/DataModulDemoClass.pas`.

## Postman Collections
IMMER `auth`-Block verwenden (type: bearer, value: {{jwttoken}}) — NIEMALS manueller Authorization-Header.
Variablennamen: {{baseURL}} (nicht baseUrl), {{jwttoken}} (nicht token).
`header`: leeres Array `[]`.
Body: `options.raw.language` = `"json"` setzen.
`response`: leeres Array `[]` (nicht null).

IMMER jeder Request benötigt {{jwttoken}}

## Dateiformat von .pas/.dfm/.dpr/.dproj (Pflicht)
Die Schreibwerkzeuge (Write/Edit) speichern mit **LF und ohne BOM**. Delphi braucht **CRLF**. Folgen:
- Eine `.dfm` mit LF **öffnet der Formulardesigner nicht mehr.** Das Projekt kompiliert und läuft weiter — der Schaden fällt erst auf, wenn jemand das Formular visuell bearbeiten will.
- Eine `.pas`/`.dpr`, die ihr BOM verliert, wird als ANSI gelesen: alle Umlaute sind zerstört.

Deshalb bei JEDER Änderung an einer dieser Dateien:
1. **Vorher** den Zustand DIESER Datei feststellen: `head -c 3 <datei> | od -An -tx1` → `ef bb bf` = BOM vorhanden. Außerdem prüfen, ob CR- und LF-Anzahl gleich sind (= überall CRLF).
2. **Nach dem Schreiben** genau diesen Zustand zurückstellen (`$true` = mit BOM, `$false` = ohne, Wert aus Schritt 1):
```powershell
$p = "<pfad>"
$t = [System.IO.File]::ReadAllText($p)
$t = ($t -replace "`r`n", "`n") -replace "`n", "`r`n"
[System.IO.File]::WriteAllText($p, $t, (New-Object System.Text.UTF8Encoding($false)))
```
3. **Nachweisen**: CR-Anzahl = LF-Anzahl und BOM wie im Ausgangszustand. Erst dann die Aufgabe als erledigt melden. Dieser Schritt ist der entscheidende — die ersten beiden werden übersprungen, sobald eine Änderung "trivial" aussieht.

**Das BOM ist NICHT aus der Endung ableitbar.** Delphi setzt es nur bei Unicode-Inhalt, in diesem Projekt ist es gemischt (30 `.pas` mit BOM, 54 ohne; 2 `.dfm` mit, 31 ohne). Nicht raten — nachsehen. Referenzen: `git show HEAD:<pfad>` und der Ordner `__history`. Nur wenn der Ausgangszustand nicht feststellbar ist (neue Datei): bei `.pas`/`.dpr`/`.dproj` BOM setzen, bei `.dfm` nichts erzwingen. CRLF gilt immer.

**Umlaute im Quelltext sind erwünscht** — Kommentare und Strings auf Deutsch mit ä, ö, ü, ß. Umschreibungen wie „ue" sind kein Ersatz für ein korrektes BOM.

## Projektkontext (Kurzfassung)
Delphi WebBroker REST-API, Apache-DLL + CGI, FireDAC/IB, JWT-Auth, OpenAI GPT-4o, Touristik-Domain.
