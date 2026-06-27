# Erste Schritte – Beispiel-Prompts

---

## 1. Neuen Controller erstellen (Pattern 2 – DataModul-Duplikation)

**Vorlage:**

> Erstelle einen neuen Controller „**[Name]**"

**Beispiel:**

> Erstelle einen neuen Controller „Fuhrpark"

Was passiert:
- `Shared\DataModuls\DataModulFuhrparkClass.pas` + `.dfm` werden angelegt
- USES-Eintrag in `CGIStandalone\IBApiTest.dpr` und `ApacheDll\mod_webbroker.dpr`
- Route `/fuhrpark/demo` in `Shared\WebModuleUnit1.pas`
- Postman-Delta-Collection in `postman\`

---

## 2. Vollständige CRUD-Endpunkte erstellen (Pattern 1)

**Vorlage:**

> Erstelle die CRUD-Endpunkte für die Tabelle **[TABELLENNAME]** im **[ControllerName]**.
> Der Generator heißt **[GEN_ID(GENERATORNAME,1)]**.
> Die Felder für den Filter sind: **[feld1, feld2, feld3, feld4]**
> Benutze als Prefix für den Pfad: **[prefix]**

**Beispiel:**

> Erstelle die CRUD-Endpunkte für die Tabelle EINSATZ im DemoController.
> Der Generator heißt GEN_ID(NEXT_EINSATZ_NR,1).
> Die Felder für den Filter sind: von, bis, fahrer1, fahrzeug
> Benutze als Prefix für den Pfad: demo

Was generiert wird (7 Methoden + 7 Routes + Postman):

| Route                          | Methode            | Beschreibung                        |
|--------------------------------|--------------------|-------------------------------------|
| `/demo/geteinsatz`             | `getEINSATZ`       | Alle Datensätze                     |
| `/demo/geteinsatzfiltered`     | `getEINSATZFiltered` | Gefiltert (von, bis, fahrer1, fahrzeug) |
| `/demo/geteinsatzbyid`         | `getEINSATZById`   | Einzelner Datensatz per `nr`        |
| `/demo/geteinsatzkey`          | `getEINSATZKey`    | Nächsten PK abrufen (Generator)     |
| `/demo/inserteinsatz`          | `insertEINSATZ`    | Neuen Datensatz anlegen             |
| `/demo/updateeinsatz`          | `updateEINSATZ`    | Datensatz aktualisieren             |
| `/demo/deleteeinsatz`          | `deleteEINSATZ`    | Datensatz löschen                   |

---

## 3. Nur lesende Endpunkte erstellen

Wenn kein Schreibzugriff benötigt wird, einfach explizit angeben:

**Vorlage:**

> Erstelle nur die **lesenden** Endpunkte für die Tabelle **[TABELLENNAME]** im **[ControllerName]**.
> Die Felder für den Filter sind: **[feld1, feld2, ...]**
> Benutze als Prefix für den Pfad: **[prefix]**

**Beispiel:**

> Erstelle nur die lesenden Endpunkte für die Tabelle EINSATZ im DemoController.
> Die Felder für den Filter sind: von, bis, fahrer1, fahrzeug
> Benutze als Prefix für den Pfad: demo

Was generiert wird (3 Methoden + 3 Routes + Postman):

| Route                          | Methode              | Beschreibung                             |
|--------------------------------|----------------------|------------------------------------------|
| `/demo/geteinsatz`             | `getEINSATZ`         | Alle Datensätze                          |
| `/demo/geteinsatzfiltered`     | `getEINSATZFiltered` | Gefiltert (von, bis, fahrer1, fahrzeug)  |
| `/demo/geteinsatzbyid`         | `getEINSATZById`     | Einzelner Datensatz per `nr`             |

> **Hinweis:** `getEINSATZKey` wird hier **nicht** generiert — obwohl es kein INSERT/UPDATE/DELETE ausführt,
> inkrementiert `GEN_ID(...)` den Datenbankzähler und ist damit kein reiner Lesezugriff.

---

## Hinweise

- Den **Ziel-Controller** immer angeben — sonst fragt Claude nach.
- Den **Generator-Namen** findest du in der Datenbank unter `RDB$GENERATORS`.
- Den **Pfad-Prefix** frei wählen — er bildet den ersten Teil aller Routes (`/prefix/methode`).
- Die **Filter-Felder** sind frei wählbar — nur im Body vorhandene Parameter werden als WHERE-Bedingung ausgewertet (alle Filter optional).
- **Token** und **Entwicklername** werden aus `token.local.txt` / `dev.local.txt` gelesen (einmalig einrichten, siehe `ClaudeCodeInstructions.md`).
