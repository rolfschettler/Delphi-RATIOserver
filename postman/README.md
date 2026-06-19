# Postman Collections – RATIOserver

In diesem Ordner liegen kleine Postman-Collections für **neu erstellte oder
geänderte API-Endpunkte**. Jede Datei ist ein "Delta" aus einer einzelnen
Arbeits-Session, kein Ersatz für die komplette Sammlung.

## Dateinamen

```
<name>_<datum>.postman_collection.json
```

Beispiele:
```
rolf_2026-06-19.postman_collection.json
harry_2026-06-19.postman_collection.json
```

- `<name>` = Rolf oder Harry
- `<datum>` = Tag der Session (JJJJ-MM-TT)

## Warum so?

- Jeder hat seine eigene Datei → **keine Merge-Konflikte** in Git
- Man sieht sofort, wer wann welche Endpunkte gebaut hat
- Bestehende Postman-Collections bleiben unberührt

## Workflow

### Wenn DU neue Endpunkte gebaut hast

1. Claude Code erstellt die Delta-Datei automatisch im richtigen Format
2. Committen und pushen:
   ```bash
   git add postman/<deine-datei>.json
   git commit -m "Postman: neue Endpunkte XY"
   git push
   ```

### Wenn der ANDERE neue Endpunkte gebaut hat

1. Neueste Änderungen holen:
   ```bash
   git fetch
   git merge origin/<branchname>
   ```
2. Die neue Datei liegt jetzt lokal in `postman/`
3. In Postman:
   - **Import** klicken
   - Die neue Datei auswählen (z. B. `harry_2026-06-19.postman_collection.json`)
   - Postman legt sie als eigene Collection an

➡️ Du musst **nichts zusammenführen** – einfach importieren und die Requests
sind sofort testbar.

## Aufräumen (optional, von Zeit zu Zeit)

Wenn der Ordner zu voll wird, können ältere Delta-Dateien gelöscht werden,
sobald ihre Endpunkte in der "echten", manuell gepflegten Haupt-Collection
gelandet sind. Das macht jeder selbst für seine eigenen Dateien.
