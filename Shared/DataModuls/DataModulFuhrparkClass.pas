unit DataModulFuhrparkClass;

interface

uses
  Web.HTTPApp,   System.JSON,
  DataModulTableBaseClass,
  System.SysUtils, System.Classes, DataModulBaseClass, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt, FireDAC.UI.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Phys, FireDAC.Phys.IB, FireDAC.Phys.IBDef, FireDAC.VCLUI.Wait, Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet;

type
  TDataModulFuhrpark = class(TDataModulTableBase)
  private

    { Private-Deklarationen }
  public
    { Public-Deklarationen }
    procedure Demo;
    procedure getFahrtenbuch;
    procedure getFahrtenbuchFiltered;
    procedure getFahrtenbuchById;
    procedure getFahrtenbuchKey;
    procedure insertFahrtenbuch;
    procedure updateFahrtenbuch;
    procedure deleteFahrtenbuch;
    procedure getRepvorgang;
    procedure getRepvorgangFiltered;
    procedure getRepvorgangById;
    procedure getRepvorgangKey;
    procedure insertRepvorgang;
    procedure updateRepvorgang;
    procedure deleteRepvorgang;
    procedure getTankung;
    procedure getTankungFiltered;
    procedure getTankungById;
    procedure getTankungKey;
    procedure insertTankung;
    procedure updateTankung;
    procedure deleteTankung;
    procedure getAuslandfahrt;
    procedure getAuslandfahrtFiltered;
    procedure getAuslandfahrtById;
    procedure getAuslandfahrtKey;
    procedure insertAuslandfahrt;
    procedure updateAuslandfahrt;
    procedure deleteAuslandfahrt;
    procedure getFahrzeug;
    procedure getFahrzeugFiltered;
    procedure getFahrzeugById;
    procedure updateFahrzeug;
    procedure deleteFahrzeug;
    procedure getLand;
    procedure getLandFiltered;
    procedure getLandById;
  end;


function CreateDataModulFuhrpark(Request: TWebRequest; Response: TWebResponse): TObject;

implementation
uses webutils;

function CreateDataModulFuhrpark(Request: TWebRequest; Response: TWebResponse): TObject;
begin
  Result := TDataModulFuhrpark.Create(Request, Response);
end;

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}




(*
  ============================  DEMO-Endpunkt  ============================
  Referenz-Vorlage fuer die Entwicklung neuer Endpunkte.
  Demonstriert den SICHEREN Zugriff auf Parameter aus zwei Quellen und den
  Umgang mit fehlenden Werten (ein, mehrere oder gar kein Parameter gesetzt).

  Quellen:
    1) URL / QueryString  -> Request.QueryFields   (Beispiel-Parameter: id, filter)
    2) JSON-Body          -> isParamFromBody / getParamFromBody        (Beispiel-Parameter: name, menge)

  ----------------------------- Aufruf (Postman) -----------------------------
    Methode : POST   (GET reicht, wenn nur URL-Parameter genutzt werden)
    URL     : http://localhost:<port>/ibapi/dispo/demo?id=42&filter=Mueller
    Header  : Authorization: Bearer <JWT-Token>     (Route verlangt Auth)
              Content-Type : application/json
    Body    : (raw / JSON, optional)
              { "name": "Helga", "menge": 5 }

    Test-Kombinationen:
      - nur URL   : POST /dispo/demo?id=42&filter=Mueller   (Body leer lassen)
      - nur Body  : POST /dispo/demo   Body { "name":"Helga","menge":5 }
      - gemischt  : beide Quellen gleichzeitig
      - nichts    : POST /dispo/demo ohne Parameter -> alle Felder als null
    Fehlende Werte erzeugen KEINEN Fehler, sondern erscheinen im Ergebnis als null.
  ----------------------------------------------------------------------------

  *)


procedure TDataModulFuhrpark.Demo;
var
  // --- 1) URL-Parameter ---
  idText      : string;
  id          : Integer;
  idGesetzt   : Boolean;
  filter      : string;
  // --- 2) Body-Parameter ---
  name        : string;
  nameGesetzt : Boolean;
  menge       : Integer;
  mengeGesetzt: Boolean;
  // --- Antwort ---
  UrlObj, BodyObj, Ergebnis: TJSONObject;
begin
  // ===== 1) Parameter aus der URL (QueryString) =====
  // QueryFields.Values liefert IMMER einen String ('' wenn nicht vorhanden) -
  // also nie nil und nie eine Exception.

  // a) numerisch "id": sicher ueber StrToIntDef, Praesenz ueber ''-Pruefung
  idText    := Trim(Request.QueryFields.Values['id']);
  idGesetzt := idText <> '';
  id        := StrToIntDef(idText, 0);   // Default 0, falls fehlt oder keine Zahl

  // b) String "filter": '' bedeutet "nicht gesetzt"
  filter := Trim(Request.QueryFields.Values['filter']);

  // ===== 2) Parameter aus dem JSON-Body =====
  // Body-Parameter liest man ueber zwei Methoden der Basisklasse - fuer JEDEN
  // Parameter immer nach demselben Muster:
  //   isParamFromBody('x')  -> ist 'x' im Body vorhanden (und nicht null)?
  //   getParamFromBody('x') -> Wert von 'x' als String ('' wenn nicht vorhanden)
  //
  // Der Body wird dabei intern EINMAL geparst (leak-sicher) und beim Zerstoeren
  // des Moduls automatisch freigegeben. Deshalb hier KEIN ParseJSONObject und
  // KEIN try/finally noetig - und keine Gefahr eines Leaks.
  //
  // Werte kommen IMMER als String (so wie im JSON). Brauchst du eine Zahl,
  // wandelst du an der Aufrufstelle mit StrToIntDef - es gibt bewusst keine
  // typgetrennten Varianten.

  // a) String "name"
  nameGesetzt := isParamFromBody('name');
  name        := getParamFromBody('name');

  // b) Zahl "menge": String-Wert mit StrToIntDef in Integer wandeln
  mengeGesetzt := isParamFromBody('menge');
  menge        := StrToIntDef(getParamFromBody('menge'), 0);

  // ===== 3) Antwort aufbauen und senden =====
  // JsonOrNull(gesetzt, wert) -> Wert oder JSON null (eine Zeile pro Feld).
  // SendJson(obj)             -> setzt Content-Type + Status, sendet obj als
  //                              JSON und gibt es frei (auch verschachtelte
  //                              Objekte). Kein try/finally, kein manuelles Free.
  UrlObj := TJSONObject.Create;
  UrlObj.AddPair('id',     JsonOrNull(idGesetzt,    id));
  UrlObj.AddPair('filter', JsonOrNull(filter <> '', filter));

  BodyObj := TJSONObject.Create;
  BodyObj.AddPair('name',  JsonOrNull(nameGesetzt,  name));
  BodyObj.AddPair('menge', JsonOrNull(mengeGesetzt, menge));

  Ergebnis := TJSONObject.Create;
  Ergebnis.AddPair('url',  UrlObj);    // Ownership geht an Ergebnis ueber
  Ergebnis.AddPair('body', BodyObj);   // Ownership geht an Ergebnis ueber
  SendJson(Ergebnis);
end;




// Route: /fuhrpark/getfahrtenbuch  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.getFahrtenbuch;
// Body: { "fields": ["nr","von","bis",...] | "*", "orderby": "von" }
const
  ALLOWED: array[0..34] of string = (
    'nr','kz','von','bis','strecke','auftragsgeber',
    'kminland','kmausland','kmleer','kmanfang','kmende','kmgesamt',
    'personen','fahrer','umsatz','rvlin','rvlaus','eleistung',
    'kennzeichen','text','steuerfahr','steuermarge','freiemarge',
    'freieumsatz','ratiobusfahrtnr','steuer','sonstigervl','sonstrvlpz',
    'steuermarge2','fahrer2','beguenstigt','zusatz1','zusatz2',
    'km_stand_zustieg_1_kunde','km_stand_ausstieg_l_kunde'
  );
begin
  DoSelect('FAHRTENBUCH', ALLOWED);
end;

// Route: /fuhrpark/getfahrtenbuchfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.getFahrtenbuchFiltered;
// Body: { "fields": [...] | "*", "kennzeichen": "B-RX 123", "orderby": "von" }
const
  ALLOWED: array[0..34] of string = (
    'nr','kz','von','bis','strecke','auftragsgeber',
    'kminland','kmausland','kmleer','kmanfang','kmende','kmgesamt',
    'personen','fahrer','umsatz','rvlin','rvlaus','eleistung',
    'kennzeichen','text','steuerfahr','steuermarge','freiemarge',
    'freieumsatz','ratiobusfahrtnr','steuer','sonstigervl','sonstrvlpz',
    'steuermarge2','fahrer2','beguenstigt','zusatz1','zusatz2',
    'km_stand_zustieg_1_kunde','km_stand_ausstieg_l_kunde'
  );
  CONDITIONS: array[0..0] of string = (
    'kennzeichen = :kennzeichen'
  );
  FILTER_PARAMS: array[0..0] of string = ('kennzeichen');
begin
  DoSelectFilteredDynamic('FAHRTENBUCH', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /fuhrpark/getfahrtenbuchbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.getFahrtenbuchById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..34] of string = (
    'nr','kz','von','bis','strecke','auftragsgeber',
    'kminland','kmausland','kmleer','kmanfang','kmende','kmgesamt',
    'personen','fahrer','umsatz','rvlin','rvlaus','eleistung',
    'kennzeichen','text','steuerfahr','steuermarge','freiemarge',
    'freieumsatz','ratiobusfahrtnr','steuer','sonstigervl','sonstrvlpz',
    'steuermarge2','fahrer2','beguenstigt','zusatz1','zusatz2',
    'km_stand_zustieg_1_kunde','km_stand_ausstieg_l_kunde'
  );
begin
  DoSelectOne('FAHRTENBUCH', ALLOWED, 'nr');
end;

// Route: /fuhrpark/getfahrtenbuchkey  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.getFahrtenbuchKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(FAHRTENBUCH_NR, 1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /fuhrpark/insertfahrtenbuch  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.insertFahrtenbuch;
// Body: { "kz": "A", "von": "2026-06-19T08:00", "bis": "...", "kennzeichen": "B-RX 123", ... }
const
  ALLOWED: array[0..33] of string = (
    'kz','von','bis','strecke','auftragsgeber',
    'kminland','kmausland','kmleer','kmanfang','kmende','kmgesamt',
    'personen','fahrer','umsatz','rvlin','rvlaus','eleistung',
    'kennzeichen','text','steuerfahr','steuermarge','freiemarge',
    'freieumsatz','ratiobusfahrtnr','steuer','sonstigervl','sonstrvlpz',
    'steuermarge2','fahrer2','beguenstigt','zusatz1','zusatz2',
    'km_stand_zustieg_1_kunde','km_stand_ausstieg_l_kunde'
  );
begin
  DoInsert('FAHRTENBUCH', ALLOWED);
end;

// Route: /fuhrpark/updatefahrtenbuch  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.updateFahrtenbuch;
// Body: { "nr": 42, "kz": "A", "von": "2026-06-19T08:00", ... }
const
  ALLOWED: array[0..33] of string = (
    'kz','von','bis','strecke','auftragsgeber',
    'kminland','kmausland','kmleer','kmanfang','kmende','kmgesamt',
    'personen','fahrer','umsatz','rvlin','rvlaus','eleistung',
    'kennzeichen','text','steuerfahr','steuermarge','freiemarge',
    'freieumsatz','ratiobusfahrtnr','steuer','sonstigervl','sonstrvlpz',
    'steuermarge2','fahrer2','beguenstigt','zusatz1','zusatz2',
    'km_stand_zustieg_1_kunde','km_stand_ausstieg_l_kunde'
  );
begin
  DoUpdate('FAHRTENBUCH', ALLOWED, 'nr');
end;

// Route: /fuhrpark/deletefahrtenbuch  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.deleteFahrtenbuch;
// Body: { "nr": 42 }
begin
  DoDelete('FAHRTENBUCH', 'nr');
end;

// Route: /fuhrpark/getrepvorgang  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.getRepvorgang;
// Body: { "fields": ["nr","kennzeichen",...] | "*", "orderby": "datum" }
const
  ALLOWED: array[0..13] of string = (
    'nr','kennzeichen','bezeichnung','vorgangsart','unfall','erledigt',
    'datum','meldungam','meldungvon','beschreibung','dringlichkeit',
    'zyklischertermin','wiedervorlage','notizen'
  );
begin
  DoSelect('REPVORGANG', ALLOWED);
end;

// Route: /fuhrpark/getrepvorgangfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.getRepvorgangFiltered;
// Body: { "fields": [...] | "*", "kennzeichen": "B-RX 123", "erledigt": "N", "orderby": "datum" }
// Alle Filter-Parameter sind optional – nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..13] of string = (
    'nr','kennzeichen','bezeichnung','vorgangsart','unfall','erledigt',
    'datum','meldungam','meldungvon','beschreibung','dringlichkeit',
    'zyklischertermin','wiedervorlage','notizen'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS übereinstimmen).
  CONDITIONS: array[0..13] of string = (
    'nr = :nr',
    'kennzeichen = :kennzeichen',
    'bezeichnung = :bezeichnung',
    'vorgangsart = :vorgangsart',
    'unfall = :unfall',
    'erledigt = :erledigt',
    'datum = :datum',
    'meldungam = :meldungam',
    'meldungvon = :meldungvon',
    'beschreibung = :beschreibung',
    'dringlichkeit = :dringlichkeit',
    'zyklischertermin = :zyklischertermin',
    'wiedervorlage = :wiedervorlage',
    'notizen = :notizen'
  );
  FILTER_PARAMS: array[0..13] of string = (
    'nr','kennzeichen','bezeichnung','vorgangsart','unfall','erledigt',
    'datum','meldungam','meldungvon','beschreibung','dringlichkeit',
    'zyklischertermin','wiedervorlage','notizen'
  );
begin
  DoSelectFilteredDynamic('REPVORGANG', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /fuhrpark/getrepvorgangbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.getRepvorgangById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..13] of string = (
    'nr','kennzeichen','bezeichnung','vorgangsart','unfall','erledigt',
    'datum','meldungam','meldungvon','beschreibung','dringlichkeit',
    'zyklischertermin','wiedervorlage','notizen'
  );
begin
  DoSelectOne('REPVORGANG', ALLOWED, 'nr');
end;

// Route: /fuhrpark/getrepvorgangkey  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.getRepvorgangKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(REPVORGANG_NR_GEN, 1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /fuhrpark/insertrepvorgang  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.insertRepvorgang;
// Body: { "kennzeichen": "B-RX 123", "bezeichnung": "...", "vorgangsart": "...", ... }
const
  ALLOWED: array[0..12] of string = (
    'kennzeichen','bezeichnung','vorgangsart','unfall','erledigt',
    'datum','meldungam','meldungvon','beschreibung','dringlichkeit',
    'zyklischertermin','wiedervorlage','notizen'
  );
begin
  DoInsert('REPVORGANG', ALLOWED);
end;

// Route: /fuhrpark/updaterepvorgang  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.updateRepvorgang;
// Body: { "nr": 42, "kennzeichen": "B-RX 123", "bezeichnung": "...", ... }
const
  ALLOWED: array[0..12] of string = (
    'kennzeichen','bezeichnung','vorgangsart','unfall','erledigt',
    'datum','meldungam','meldungvon','beschreibung','dringlichkeit',
    'zyklischertermin','wiedervorlage','notizen'
  );
begin
  DoUpdate('REPVORGANG', ALLOWED, 'nr');
end;

// Route: /fuhrpark/deleterepvorgang  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.deleteRepvorgang;
// Body: { "nr": 42 }
begin
  DoDelete('REPVORGANG', 'nr');
end;

// Route: /fuhrpark/gettankung  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.getTankung;
// Body: { "fields": ["nr","datum",...] | "*", "orderby": "datum" }
const
  ALLOWED: array[0..15] of string = (
    'nr','datum','bezeichnung','kraftstoffart','menge','preis','km',
    'landkennung','heimtankung','kennzeichen','lieferantennr',
    'lieferantenname','exttanknr','einsatznr','mitarbeiter','waehrung'
  );
begin
  DoSelect('TANKUNG', ALLOWED);
end;

// Route: /fuhrpark/gettankungfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.getTankungFiltered;
// Body: { "fields": [...] | "*", "kennzeichen": "B-RX 123", "kraftstoffart": "Diesel", "orderby": "datum" }
// Alle Filter-Parameter sind optional – nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..15] of string = (
    'nr','datum','bezeichnung','kraftstoffart','menge','preis','km',
    'landkennung','heimtankung','kennzeichen','lieferantennr',
    'lieferantenname','exttanknr','einsatznr','mitarbeiter','waehrung'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS übereinstimmen).
  CONDITIONS: array[0..15] of string = (
    'nr = :nr',
    'datum = :datum',
    'bezeichnung = :bezeichnung',
    'kraftstoffart = :kraftstoffart',
    'menge = :menge',
    'preis = :preis',
    'km = :km',
    'landkennung = :landkennung',
    'heimtankung = :heimtankung',
    'kennzeichen = :kennzeichen',
    'lieferantennr = :lieferantennr',
    'lieferantenname = :lieferantenname',
    'exttanknr = :exttanknr',
    'einsatznr = :einsatznr',
    'mitarbeiter = :mitarbeiter',
    'waehrung = :waehrung'
  );
  FILTER_PARAMS: array[0..15] of string = (
    'nr','datum','bezeichnung','kraftstoffart','menge','preis','km',
    'landkennung','heimtankung','kennzeichen','lieferantennr',
    'lieferantenname','exttanknr','einsatznr','mitarbeiter','waehrung'
  );
begin
  DoSelectFilteredDynamic('TANKUNG', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /fuhrpark/gettankungbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.getTankungById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..15] of string = (
    'nr','datum','bezeichnung','kraftstoffart','menge','preis','km',
    'landkennung','heimtankung','kennzeichen','lieferantennr',
    'lieferantenname','exttanknr','einsatznr','mitarbeiter','waehrung'
  );
begin
  DoSelectOne('TANKUNG', ALLOWED, 'nr');
end;

// Route: /fuhrpark/gettankungkey  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.getTankungKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(TANKUNG_NR, 1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /fuhrpark/inserttankung  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.insertTankung;
// Body: { "datum": "2026-07-17", "bezeichnung": "...", "kraftstoffart": "Diesel", ... }
const
  ALLOWED: array[0..14] of string = (
    'datum','bezeichnung','kraftstoffart','menge','preis','km',
    'landkennung','heimtankung','kennzeichen','lieferantennr',
    'lieferantenname','exttanknr','einsatznr','mitarbeiter','waehrung'
  );
begin
  DoInsert('TANKUNG', ALLOWED);
end;

// Route: /fuhrpark/updatetankung  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.updateTankung;
// Body: { "nr": 42, "datum": "2026-07-17", "menge": 50.5, ... }
const
  ALLOWED: array[0..14] of string = (
    'datum','bezeichnung','kraftstoffart','menge','preis','km',
    'landkennung','heimtankung','kennzeichen','lieferantennr',
    'lieferantenname','exttanknr','einsatznr','mitarbeiter','waehrung'
  );
begin
  DoUpdate('TANKUNG', ALLOWED, 'nr');
end;

// Route: /fuhrpark/deletetankung  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.deleteTankung;
// Body: { "nr": 42 }
begin
  DoDelete('TANKUNG', 'nr');
end;

// Route: /fuhrpark/getauslandfahrt  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.getAuslandfahrt;
// Body: { "fields": ["nr","fahrtnr",...] | "*", "orderby": "datum" }
const
  ALLOWED: array[0..12] of string = (
    'nr','fahrtnr','landkennung','kmausland','transit','betrag','steuer',
    'grenzeintritt','grenzaustritt','kmleer','grenzeintritt_am',
    'grenzaustritt_am','datum'
  );
begin
  DoSelect('AUSLANDFAHRT', ALLOWED);
end;

// Route: /fuhrpark/getauslandfahrtfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.getAuslandfahrtFiltered;
// Body: { "fields": [...] | "*", "fahrtnr": 100, "landkennung": "F", "orderby": "datum" }
// Alle Filter-Parameter sind optional – nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..12] of string = (
    'nr','fahrtnr','landkennung','kmausland','transit','betrag','steuer',
    'grenzeintritt','grenzaustritt','kmleer','grenzeintritt_am',
    'grenzaustritt_am','datum'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS übereinstimmen).
  CONDITIONS: array[0..12] of string = (
    'nr = :nr',
    'fahrtnr = :fahrtnr',
    'landkennung = :landkennung',
    'kmausland = :kmausland',
    'transit = :transit',
    'betrag = :betrag',
    'steuer = :steuer',
    'grenzeintritt = :grenzeintritt',
    'grenzaustritt = :grenzaustritt',
    'kmleer = :kmleer',
    'grenzeintritt_am = :grenzeintritt_am',
    'grenzaustritt_am = :grenzaustritt_am',
    'datum = :datum'
  );
  FILTER_PARAMS: array[0..12] of string = (
    'nr','fahrtnr','landkennung','kmausland','transit','betrag','steuer',
    'grenzeintritt','grenzaustritt','kmleer','grenzeintritt_am',
    'grenzaustritt_am','datum'
  );
begin
  DoSelectFilteredDynamic('AUSLANDFAHRT', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /fuhrpark/getauslandfahrtbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.getAuslandfahrtById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..12] of string = (
    'nr','fahrtnr','landkennung','kmausland','transit','betrag','steuer',
    'grenzeintritt','grenzaustritt','kmleer','grenzeintritt_am',
    'grenzaustritt_am','datum'
  );
begin
  DoSelectOne('AUSLANDFAHRT', ALLOWED, 'nr');
end;

// Route: /fuhrpark/getauslandfahrtkey  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.getAuslandfahrtKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(AUSLANDFAHRT_NR, 1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /fuhrpark/insertauslandfahrt  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.insertAuslandfahrt;
// Body: { "fahrtnr": 100, "landkennung": "F", "kmausland": 250, "betrag": 120.00, ... }
const
  ALLOWED: array[0..11] of string = (
    'fahrtnr','landkennung','kmausland','transit','betrag','steuer',
    'grenzeintritt','grenzaustritt','kmleer','grenzeintritt_am',
    'grenzaustritt_am','datum'
  );
begin
  DoInsert('AUSLANDFAHRT', ALLOWED);
end;

// Route: /fuhrpark/updateauslandfahrt  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.updateAuslandfahrt;
// Body: { "nr": 42, "betrag": 150.00, "steuer": 28.50, ... }
const
  ALLOWED: array[0..11] of string = (
    'fahrtnr','landkennung','kmausland','transit','betrag','steuer',
    'grenzeintritt','grenzaustritt','kmleer','grenzeintritt_am',
    'grenzaustritt_am','datum'
  );
begin
  DoUpdate('AUSLANDFAHRT', ALLOWED, 'nr');
end;

// Route: /fuhrpark/deleteauslandfahrt  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.deleteAuslandfahrt;
// Body: { "nr": 42 }
begin
  DoDelete('AUSLANDFAHRT', 'nr');
end;

// Route: /fuhrpark/getfahrzeug  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.getFahrzeug;
// Body: { "fields": ["kennzeichen","bezeichnung",...] | "*", "orderby": "kennzeichen" }
const
  ALLOWED: array[0..48] of string = (
    'kennzeichen','bezeichnung','hersteller','typ','fahrzeugart','baujahr',
    'leistung','hubraum','fahrgestellnr','motornr','briefnr','scheinnr',
    'standort','angeschaft','abgeschaft','status','treibstoff','sitzplatz',
    'achsen','text','bild','sitznummern','sitzgesperrt','personen',
    'gesperrt','zusatzfeld1','zusatzfeld2','kmsatz','sortierung','reihen',
    'betrieb','profil','zuschlag1','zuschlag2','zuschlagarten','pin',
    'telematikdevice','xkoord','ykoord','standort_aktuell','sv_fahrzeugprofil','din_norm',
    'hinweise','km','lift','rueckfahrkamera','stammfahrer1','stammfahrer2',
    'telematik_gelesen_am'
  );
begin
  DoSelect('FAHRZEUG', ALLOWED);
end;

// Route: /fuhrpark/getfahrzeugfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.getFahrzeugFiltered;
// Body: { "fields": [...] | "*", "kennzeichen": "B-RX 123", "hersteller": "Setra", "orderby": "kennzeichen" }
// Alle Filter-Parameter sind optional – nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..48] of string = (
    'kennzeichen','bezeichnung','hersteller','typ','fahrzeugart','baujahr',
    'leistung','hubraum','fahrgestellnr','motornr','briefnr','scheinnr',
    'standort','angeschaft','abgeschaft','status','treibstoff','sitzplatz',
    'achsen','text','bild','sitznummern','sitzgesperrt','personen',
    'gesperrt','zusatzfeld1','zusatzfeld2','kmsatz','sortierung','reihen',
    'betrieb','profil','zuschlag1','zuschlag2','zuschlagarten','pin',
    'telematikdevice','xkoord','ykoord','standort_aktuell','sv_fahrzeugprofil','din_norm',
    'hinweise','km','lift','rueckfahrkamera','stammfahrer1','stammfahrer2',
    'telematik_gelesen_am'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS übereinstimmen).
  // Hinweis: die BLOB-Felder text und bild sind bewusst NICHT filterbar –
  // ein Gleichheitsvergleich auf BLOBs wird von InterBase nicht unterstuetzt.
  CONDITIONS: array[0..46] of string = (
    'kennzeichen = :kennzeichen',
    'bezeichnung = :bezeichnung',
    'hersteller = :hersteller',
    'typ = :typ',
    'fahrzeugart = :fahrzeugart',
    'baujahr = :baujahr',
    'leistung = :leistung',
    'hubraum = :hubraum',
    'fahrgestellnr = :fahrgestellnr',
    'motornr = :motornr',
    'briefnr = :briefnr',
    'scheinnr = :scheinnr',
    'standort = :standort',
    'angeschaft = :angeschaft',
    'abgeschaft = :abgeschaft',
    'status = :status',
    'treibstoff = :treibstoff',
    'sitzplatz = :sitzplatz',
    'achsen = :achsen',
    'sitznummern = :sitznummern',
    'sitzgesperrt = :sitzgesperrt',
    'personen = :personen',
    'gesperrt = :gesperrt',
    'zusatzfeld1 = :zusatzfeld1',
    'zusatzfeld2 = :zusatzfeld2',
    'kmsatz = :kmsatz',
    'sortierung = :sortierung',
    'reihen = :reihen',
    'betrieb = :betrieb',
    'profil = :profil',
    'zuschlag1 = :zuschlag1',
    'zuschlag2 = :zuschlag2',
    'zuschlagarten = :zuschlagarten',
    'pin = :pin',
    'telematikdevice = :telematikdevice',
    'xkoord = :xkoord',
    'ykoord = :ykoord',
    'standort_aktuell = :standort_aktuell',
    'sv_fahrzeugprofil = :sv_fahrzeugprofil',
    'din_norm = :din_norm',
    'hinweise = :hinweise',
    'km = :km',
    'lift = :lift',
    'rueckfahrkamera = :rueckfahrkamera',
    'stammfahrer1 = :stammfahrer1',
    'stammfahrer2 = :stammfahrer2',
    'telematik_gelesen_am = :telematik_gelesen_am'
  );
  FILTER_PARAMS: array[0..46] of string = (
    'kennzeichen','bezeichnung','hersteller','typ','fahrzeugart','baujahr',
    'leistung','hubraum','fahrgestellnr','motornr','briefnr','scheinnr',
    'standort','angeschaft','abgeschaft','status','treibstoff','sitzplatz',
    'achsen','sitznummern','sitzgesperrt','personen','gesperrt','zusatzfeld1',
    'zusatzfeld2','kmsatz','sortierung','reihen','betrieb','profil',
    'zuschlag1','zuschlag2','zuschlagarten','pin','telematikdevice','xkoord',
    'ykoord','standort_aktuell','sv_fahrzeugprofil','din_norm','hinweise','km',
    'lift','rueckfahrkamera','stammfahrer1','stammfahrer2','telematik_gelesen_am'
  );
begin
  DoSelectFilteredDynamic('FAHRZEUG', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /fuhrpark/getfahrzeugbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.getFahrzeugById;
// Body: { "kennzeichen": "B-RX 123", "fields": [...] | "*" }
const
  ALLOWED: array[0..48] of string = (
    'kennzeichen','bezeichnung','hersteller','typ','fahrzeugart','baujahr',
    'leistung','hubraum','fahrgestellnr','motornr','briefnr','scheinnr',
    'standort','angeschaft','abgeschaft','status','treibstoff','sitzplatz',
    'achsen','text','bild','sitznummern','sitzgesperrt','personen',
    'gesperrt','zusatzfeld1','zusatzfeld2','kmsatz','sortierung','reihen',
    'betrieb','profil','zuschlag1','zuschlag2','zuschlagarten','pin',
    'telematikdevice','xkoord','ykoord','standort_aktuell','sv_fahrzeugprofil','din_norm',
    'hinweise','km','lift','rueckfahrkamera','stammfahrer1','stammfahrer2',
    'telematik_gelesen_am'
  );
begin
  DoSelectOne('FAHRZEUG', ALLOWED, 'kennzeichen');
end;

// Route: /fuhrpark/updatefahrzeug  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.updateFahrzeug;
// Body: { "kennzeichen": "B-RX 123", "bezeichnung": "...", "standort": "...", ... }
const
  ALLOWED: array[0..47] of string = (
    'bezeichnung','hersteller','typ','fahrzeugart','baujahr','leistung',
    'hubraum','fahrgestellnr','motornr','briefnr','scheinnr','standort',
    'angeschaft','abgeschaft','status','treibstoff','sitzplatz','achsen',
    'text','bild','sitznummern','sitzgesperrt','personen','gesperrt',
    'zusatzfeld1','zusatzfeld2','kmsatz','sortierung','reihen','betrieb',
    'profil','zuschlag1','zuschlag2','zuschlagarten','pin','telematikdevice',
    'xkoord','ykoord','standort_aktuell','sv_fahrzeugprofil','din_norm','hinweise',
    'km','lift','rueckfahrkamera','stammfahrer1','stammfahrer2','telematik_gelesen_am'
  );
begin
  DoUpdate('FAHRZEUG', ALLOWED, 'kennzeichen');
end;

// Route: /fuhrpark/deletefahrzeug  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.deleteFahrzeug;
// Body: { "kennzeichen": "B-RX 123" }
begin
  DoDelete('FAHRZEUG', 'kennzeichen');
end;

// Route: /fuhrpark/getland  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.getLand;
// Body: { "fields": ["code","staat",...] | "*", "orderby": "sortierung" }
const
  ALLOWED: array[0..10] of string = (
    'code','staat','steuer','fiskel','euland','inland','formular','iso2',
    'iso3','sortierung','sachkonto'
  );
begin
  DoSelect('LAND', ALLOWED);
end;

// Route: /fuhrpark/getlandfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.getLandFiltered;
// Body: { "fields": [...] | "*", "code": "D", "euland": "J", "orderby": "staat" }
// Alle Filter-Parameter sind optional - nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..10] of string = (
    'code','staat','steuer','fiskel','euland','inland','formular','iso2',
    'iso3','sortierung','sachkonto'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS uebereinstimmen).
  CONDITIONS: array[0..10] of string = (
    'code = :code',
    'staat = :staat',
    'steuer = :steuer',
    'fiskel = :fiskel',
    'euland = :euland',
    'inland = :inland',
    'formular = :formular',
    'iso2 = :iso2',
    'iso3 = :iso3',
    'sortierung = :sortierung',
    'sachkonto = :sachkonto'
  );
  FILTER_PARAMS: array[0..10] of string = (
    'code','staat','steuer','fiskel','euland','inland','formular','iso2',
    'iso3','sortierung','sachkonto'
  );
begin
  DoSelectFilteredDynamic('LAND', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /fuhrpark/getlandbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulFuhrpark.getLandById;
// Body: { "code": "D", "fields": [...] | "*" }
const
  ALLOWED: array[0..10] of string = (
    'code','staat','steuer','fiskel','euland','inland','formular','iso2',
    'iso3','sortierung','sachkonto'
  );
begin
  DoSelectOne('LAND', ALLOWED, 'code');
end;

end.
