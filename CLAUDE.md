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



## Projektkontext (Kurzfassung)
Delphi WebBroker REST-API, Apache-DLL + CGI, FireDAC/IB, JWT-Auth, OpenAI GPT-4o, Touristik-Domain.
