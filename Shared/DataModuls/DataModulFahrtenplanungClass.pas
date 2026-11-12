unit DataModulFahrtenplanungClass;

interface

uses
  Web.HTTPApp,   System.JSON,
  DataModulTableBaseClass,
  System.SysUtils, System.Classes, DataModulBaseClass, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt, FireDAC.UI.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Phys, FireDAC.Phys.IB, FireDAC.Phys.IBDef, FireDAC.VCLUI.Wait, Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet;

type
  TDataModulFahrtenplanung = class(TDataModulTableBase)
  private

    { Private-Deklarationen }
  public
    { Public-Deklarationen }
     procedure Demo;
    procedure getT_Z_Planung;
    procedure getT_Z_PlanungFiltered;
    procedure getT_Z_PlanungById;
    procedure getT_Z_PlanungKey;
    procedure insertT_Z_Planung;
    procedure updateT_Z_Planung;
    procedure deleteT_Z_Planung;
    procedure getT_Z_Reise;
    procedure getT_Z_ReiseFiltered;
    procedure getT_Z_ReiseById;
    procedure getT_Z_ReiseKey;
    procedure insertT_Z_Reise;
    procedure updateT_Z_Reise;
    procedure deleteT_Z_Reise;
    procedure getT_Z_Fahrzeug;
    procedure getT_Z_FahrzeugFiltered;
    procedure getT_Z_FahrzeugById;
    procedure getT_Z_FahrzeugKey;
    procedure insertT_Z_Fahrzeug;
    procedure updateT_Z_Fahrzeug;
    procedure deleteT_Z_Fahrzeug;
    procedure getT_Z_Weg;
    procedure getT_Z_WegFiltered;
    procedure getT_Z_WegById;
    procedure getT_Z_WegKey;
    procedure insertT_Z_Weg;
    procedure updateT_Z_Weg;
    procedure deleteT_Z_Weg;
    procedure getT_Z_Einteilung;
    procedure getT_Z_EinteilungFiltered;
    procedure getT_Z_EinteilungById;
    procedure getT_Z_EinteilungKey;
    procedure insertT_Z_Einteilung;
    procedure updateT_Z_Einteilung;
    procedure deleteT_Z_Einteilung;
    procedure getT_Knoten;
    procedure getT_KnotenFiltered;
    procedure getT_KnotenById;
    procedure getT_KnotenKey;
    procedure insertT_Knoten;
    procedure updateT_Knoten;
    procedure deleteT_Knoten;
    procedure getT_Knotenhalt;
    procedure getT_KnotenhaltFiltered;
    procedure getT_KnotenhaltById;
    procedure getT_KnotenhaltKey;
    procedure insertT_Knotenhalt;
    procedure updateT_Knotenhalt;
    procedure deleteT_Knotenhalt;
    procedure getT_Zustiege;
    procedure getT_ZustiegeFiltered;
    procedure getT_ZustiegeById;
    procedure getT_ZustiegeKey;
    procedure insertT_Zustiege;
    procedure updateT_Zustiege;
    procedure deleteT_Zustiege;
    procedure getT_Haltestelle;
    procedure getT_HaltestelleFiltered;
    procedure getT_HaltestelleById;
    procedure getT_HaltestelleKey;
    procedure insertT_Haltestelle;
    procedure updateT_Haltestelle;
    procedure deleteT_Haltestelle;
  end;


function CreateDataModulFahrtenplanung(Request: TWebRequest; Response: TWebResponse): TObject;

implementation
uses webutils;

function CreateDataModulFahrtenplanung(Request: TWebRequest; Response: TWebResponse): TObject;
begin
  Result := TDataModulFahrtenplanung.Create(Request, Response);
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
    2) JSON-Body          -> isParamFromBody / getParamFromBody (Beispiel-Parameter: name, menge)

  ----------------------------- Aufruf (Postman) -----------------------------
    Methode : POST   (GET reicht, wenn nur URL-Parameter genutzt werden)
    URL     : http://localhost:<port>/ibapi/<controller>/demo?id=42&filter=Mueller
    Header  : Authorization: Bearer <JWT-Token>     (Route verlangt Auth)
              Content-Type : application/json
    Body    : (raw / JSON, optional)
              { "name": "Helga", "menge": 5 }

    Test-Kombinationen:
      - nur URL   : POST /<controller>/demo?id=42&filter=Mueller   (Body leer lassen)
      - nur Body  : POST /<controller>/demo   Body { "name":"Helga","menge":5 }
      - gemischt  : beide Quellen gleichzeitig
      - nichts    : POST /<controller>/demo ohne Parameter -> alle Felder als null
    Fehlende Werte erzeugen KEINEN Fehler, sondern erscheinen im Ergebnis als null.
  ----------------------------------------------------------------------------

  *)


procedure TDataModulFahrtenplanung.Demo;
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

{ T_Z_PLANUNG }

// Route: /fahrtenplanung/gett_z_planung  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_Z_Planung;
// Body: { "fields": ["nr","bezeichnung",...] | "*", "orderby": "nr" }
const
  ALLOWED: array[0..13] of string = (
    'nr','bezeichnung','datum','planung','art','text','erstellt',
    'erstellt_von','geandert','geandert_von','status','gesperrt',
    'zusatzfeld1','zusatzfeld2'
  );
begin
  DoSelect('T_Z_PLANUNG', ALLOWED);
end;

// Route: /fahrtenplanung/gett_z_planungfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_Z_PlanungFiltered;
// Body: { "fields": [...] | "*", "bezeichnung": "value1", "status": "value2", "orderby": "nr" }
// Alle Filter-Parameter sind optional – nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..13] of string = (
    'nr','bezeichnung','datum','planung','art','text','erstellt',
    'erstellt_von','geandert','geandert_von','status','gesperrt',
    'zusatzfeld1','zusatzfeld2'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS übereinstimmen).
  CONDITIONS: array[0..13] of string = (
    'nr = :nr',
    'bezeichnung = :bezeichnung',
    'datum = :datum',
    'planung = :planung',
    'art = :art',
    'text = :text',
    'erstellt = :erstellt',
    'erstellt_von = :erstellt_von',
    'geandert = :geandert',
    'geandert_von = :geandert_von',
    'status = :status',
    'gesperrt = :gesperrt',
    'zusatzfeld1 = :zusatzfeld1',
    'zusatzfeld2 = :zusatzfeld2'
  );
  FILTER_PARAMS: array[0..13] of string = (
    'nr','bezeichnung','datum','planung','art','text','erstellt',
    'erstellt_von','geandert','geandert_von','status','gesperrt',
    'zusatzfeld1','zusatzfeld2'
  );
begin
  DoSelectFilteredDynamic('T_Z_PLANUNG', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /fahrtenplanung/gett_z_planungbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_Z_PlanungById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..13] of string = (
    'nr','bezeichnung','datum','planung','art','text','erstellt',
    'erstellt_von','geandert','geandert_von','status','gesperrt',
    'zusatzfeld1','zusatzfeld2'
  );
begin
  DoSelectOne('T_Z_PLANUNG', ALLOWED, 'nr');
end;

// Route: /fahrtenplanung/gett_z_planungkey  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_Z_PlanungKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(T_Z_PLANUNG_NR_GEN, 1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /fahrtenplanung/insertt_z_planung  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.insertT_Z_Planung;
// Body: { "nr": 42, "bezeichnung": "...", "datum": "...", ... }
const
  ALLOWED: array[0..13] of string = (
    'nr','bezeichnung','datum','planung','art','text','erstellt',
    'erstellt_von','geandert','geandert_von','status','gesperrt',
    'zusatzfeld1','zusatzfeld2'
  );
begin
  DoInsert('T_Z_PLANUNG', ALLOWED);
end;

// Route: /fahrtenplanung/updatet_z_planung  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.updateT_Z_Planung;
// Body: { "nr": 42, "bezeichnung": "...", ... }
const
  ALLOWED: array[0..12] of string = (
    'bezeichnung','datum','planung','art','text','erstellt',
    'erstellt_von','geandert','geandert_von','status','gesperrt',
    'zusatzfeld1','zusatzfeld2'
  );
begin
  DoUpdate('T_Z_PLANUNG', ALLOWED, 'nr');
end;

// Route: /fahrtenplanung/deletet_z_planung  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.deleteT_Z_Planung;
// Body: { "nr": 42 }
begin
  DoDelete('T_Z_PLANUNG', 'nr');
end;

{ T_Z_REISE }

// Route: /fahrtenplanung/gett_z_reise  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_Z_Reise;
// Body: { "fields": ["nr","zplanungsnr","tzubringernr"] | "*", "orderby": "nr" }
const
  ALLOWED: array[0..2] of string = (
    'nr','zplanungsnr','tzubringernr'
  );
begin
  DoSelect('T_Z_REISE', ALLOWED);
end;

// Route: /fahrtenplanung/gett_z_reisefiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_Z_ReiseFiltered;
// Body: { "fields": [...] | "*", "zplanungsnr": 1, "tzubringernr": 2, "orderby": "nr" }
// Alle Filter-Parameter sind optional – nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..2] of string = (
    'nr','zplanungsnr','tzubringernr'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS übereinstimmen).
  CONDITIONS: array[0..2] of string = (
    'nr = :nr',
    'zplanungsnr = :zplanungsnr',
    'tzubringernr = :tzubringernr'
  );
  FILTER_PARAMS: array[0..2] of string = ('nr', 'zplanungsnr', 'tzubringernr');
begin
  DoSelectFilteredDynamic('T_Z_REISE', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /fahrtenplanung/gett_z_reisebyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_Z_ReiseById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..2] of string = (
    'nr','zplanungsnr','tzubringernr'
  );
begin
  DoSelectOne('T_Z_REISE', ALLOWED, 'nr');
end;

// Route: /fahrtenplanung/gett_z_reisekey  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_Z_ReiseKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(T_Z_REISE_NR_GEN, 1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /fahrtenplanung/insertt_z_reise  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.insertT_Z_Reise;
// Body: { "nr": 42, "zplanungsnr": 1, "tzubringernr": 2 }
const
  ALLOWED: array[0..2] of string = (
    'nr','zplanungsnr','tzubringernr'
  );
begin
  DoInsert('T_Z_REISE', ALLOWED);
end;

// Route: /fahrtenplanung/updatet_z_reise  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.updateT_Z_Reise;
// Body: { "nr": 42, "zplanungsnr": 1, "tzubringernr": 2 }
const
  ALLOWED: array[0..1] of string = (
    'zplanungsnr','tzubringernr'
  );
begin
  DoUpdate('T_Z_REISE', ALLOWED, 'nr');
end;

// Route: /fahrtenplanung/deletet_z_reise  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.deleteT_Z_Reise;
// Body: { "nr": 42 }
begin
  DoDelete('T_Z_REISE', 'nr');
end;

{ T_Z_FAHRZEUG }

// Route: /fahrtenplanung/gett_z_fahrzeug  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_Z_Fahrzeug;
// Body: { "fields": ["nr","bezeichnung",...] | "*", "orderby": "nr" }
const
  ALLOWED: array[0..16] of string = (
    'nr','zplanungsnr','bezeichnung','typ','kennzeichen','kennziffer',
    'zielhaltnr','kmprofil','zieluhrzeit','refnr','status','zusatzinfo',
    'info','erledigt','farbe','zusatzfeld1','zusatzfeld2'
  );
begin
  DoSelect('T_Z_FAHRZEUG', ALLOWED);
end;

// Route: /fahrtenplanung/gett_z_fahrzeugfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_Z_FahrzeugFiltered;
// Body: { "fields": [...] | "*", "zplanungsnr": 1, "kennzeichen": "value", "orderby": "nr" }
// Alle Filter-Parameter sind optional – nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
// Blob-Feld 'info' ist nur lesbar, nicht filterbar.
const
  ALLOWED: array[0..16] of string = (
    'nr','zplanungsnr','bezeichnung','typ','kennzeichen','kennziffer',
    'zielhaltnr','kmprofil','zieluhrzeit','refnr','status','zusatzinfo',
    'info','erledigt','farbe','zusatzfeld1','zusatzfeld2'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS übereinstimmen).
  CONDITIONS: array[0..15] of string = (
    'nr = :nr',
    'zplanungsnr = :zplanungsnr',
    'bezeichnung = :bezeichnung',
    'typ = :typ',
    'kennzeichen = :kennzeichen',
    'kennziffer = :kennziffer',
    'zielhaltnr = :zielhaltnr',
    'kmprofil = :kmprofil',
    'zieluhrzeit = :zieluhrzeit',
    'refnr = :refnr',
    'status = :status',
    'zusatzinfo = :zusatzinfo',
    'erledigt = :erledigt',
    'farbe = :farbe',
    'zusatzfeld1 = :zusatzfeld1',
    'zusatzfeld2 = :zusatzfeld2'
  );
  FILTER_PARAMS: array[0..15] of string = (
    'nr','zplanungsnr','bezeichnung','typ','kennzeichen','kennziffer',
    'zielhaltnr','kmprofil','zieluhrzeit','refnr','status','zusatzinfo',
    'erledigt','farbe','zusatzfeld1','zusatzfeld2'
  );
begin
  DoSelectFilteredDynamic('T_Z_FAHRZEUG', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /fahrtenplanung/gett_z_fahrzeugbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_Z_FahrzeugById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..16] of string = (
    'nr','zplanungsnr','bezeichnung','typ','kennzeichen','kennziffer',
    'zielhaltnr','kmprofil','zieluhrzeit','refnr','status','zusatzinfo',
    'info','erledigt','farbe','zusatzfeld1','zusatzfeld2'
  );
begin
  DoSelectOne('T_Z_FAHRZEUG', ALLOWED, 'nr');
end;

// Route: /fahrtenplanung/gett_z_fahrzeugkey  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_Z_FahrzeugKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(T_Z_FAHRZEUG_NR_GEN, 1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /fahrtenplanung/insertt_z_fahrzeug  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.insertT_Z_Fahrzeug;
// Body: { "nr": 42, "zplanungsnr": 1, "bezeichnung": "...", ... }
const
  ALLOWED: array[0..16] of string = (
    'nr','zplanungsnr','bezeichnung','typ','kennzeichen','kennziffer',
    'zielhaltnr','kmprofil','zieluhrzeit','refnr','status','zusatzinfo',
    'info','erledigt','farbe','zusatzfeld1','zusatzfeld2'
  );
begin
  DoInsert('T_Z_FAHRZEUG', ALLOWED);
end;

// Route: /fahrtenplanung/updatet_z_fahrzeug  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.updateT_Z_Fahrzeug;
// Body: { "nr": 42, "bezeichnung": "...", ... }
const
  ALLOWED: array[0..15] of string = (
    'zplanungsnr','bezeichnung','typ','kennzeichen','kennziffer',
    'zielhaltnr','kmprofil','zieluhrzeit','refnr','status','zusatzinfo',
    'info','erledigt','farbe','zusatzfeld1','zusatzfeld2'
  );
begin
  DoUpdate('T_Z_FAHRZEUG', ALLOWED, 'nr');
end;

// Route: /fahrtenplanung/deletet_z_fahrzeug  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.deleteT_Z_Fahrzeug;
// Body: { "nr": 42 }
begin
  DoDelete('T_Z_FAHRZEUG', 'nr');
end;

{ T_Z_WEG }

// Route: /fahrtenplanung/gett_z_weg  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_Z_Weg;
// Body: { "fields": ["nr","haltnr",...] | "*", "orderby": "wegefolge" }
const
  ALLOWED: array[0..4] of string = (
    'nr','zubringerfahrzeugnr','haltnr','wegefolge','uhrzeit'
  );
begin
  DoSelect('T_Z_WEG', ALLOWED);
end;

// Route: /fahrtenplanung/gett_z_wegfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_Z_WegFiltered;
// Body: { "fields": [...] | "*", "zubringerfahrzeugnr": 1, "haltnr": 2, "orderby": "wegefolge" }
// Alle Filter-Parameter sind optional – nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..4] of string = (
    'nr','zubringerfahrzeugnr','haltnr','wegefolge','uhrzeit'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS übereinstimmen).
  CONDITIONS: array[0..4] of string = (
    'nr = :nr',
    'zubringerfahrzeugnr = :zubringerfahrzeugnr',
    'haltnr = :haltnr',
    'wegefolge = :wegefolge',
    'uhrzeit = :uhrzeit'
  );
  FILTER_PARAMS: array[0..4] of string = ('nr', 'zubringerfahrzeugnr', 'haltnr', 'wegefolge', 'uhrzeit');
begin
  DoSelectFilteredDynamic('T_Z_WEG', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /fahrtenplanung/gett_z_wegbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_Z_WegById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..4] of string = (
    'nr','zubringerfahrzeugnr','haltnr','wegefolge','uhrzeit'
  );
begin
  DoSelectOne('T_Z_WEG', ALLOWED, 'nr');
end;

// Route: /fahrtenplanung/gett_z_wegkey  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_Z_WegKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(T_Z_WEG_NR_GEN, 1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /fahrtenplanung/insertt_z_weg  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.insertT_Z_Weg;
// Body: { "nr": 42, "zubringerfahrzeugnr": 1, "haltnr": 2, "wegefolge": 1, "uhrzeit": "07:30" }
const
  ALLOWED: array[0..4] of string = (
    'nr','zubringerfahrzeugnr','haltnr','wegefolge','uhrzeit'
  );
begin
  DoInsert('T_Z_WEG', ALLOWED);
end;

// Route: /fahrtenplanung/updatet_z_weg  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.updateT_Z_Weg;
// Body: { "nr": 42, "wegefolge": 2, "uhrzeit": "07:35" }
const
  ALLOWED: array[0..3] of string = (
    'zubringerfahrzeugnr','haltnr','wegefolge','uhrzeit'
  );
begin
  DoUpdate('T_Z_WEG', ALLOWED, 'nr');
end;

// Route: /fahrtenplanung/deletet_z_weg  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.deleteT_Z_Weg;
// Body: { "nr": 42 }
begin
  DoDelete('T_Z_WEG', 'nr');
end;

{ T_Z_EINTEILUNG }

// Route: /fahrtenplanung/gett_z_einteilung  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_Z_Einteilung;
// Body: { "fields": ["nr","zwegenr",...] | "*", "orderby": "einteilungsfolge" }
const
  ALLOWED: array[0..4] of string = (
    'nr','zwegenr','tzustiegenr','einteilungsfolge','uhrzeit_ha'
  );
begin
  DoSelect('T_Z_EINTEILUNG', ALLOWED);
end;

// Route: /fahrtenplanung/gett_z_einteilungfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_Z_EinteilungFiltered;
// Body: { "fields": [...] | "*", "zwegenr": 1, "tzustiegenr": 2, "orderby": "einteilungsfolge" }
// Alle Filter-Parameter sind optional – nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..4] of string = (
    'nr','zwegenr','tzustiegenr','einteilungsfolge','uhrzeit_ha'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS übereinstimmen).
  CONDITIONS: array[0..4] of string = (
    'nr = :nr',
    'zwegenr = :zwegenr',
    'tzustiegenr = :tzustiegenr',
    'einteilungsfolge = :einteilungsfolge',
    'uhrzeit_ha = :uhrzeit_ha'
  );
  FILTER_PARAMS: array[0..4] of string = ('nr', 'zwegenr', 'tzustiegenr', 'einteilungsfolge', 'uhrzeit_ha');
begin
  DoSelectFilteredDynamic('T_Z_EINTEILUNG', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /fahrtenplanung/gett_z_einteilungbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_Z_EinteilungById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..4] of string = (
    'nr','zwegenr','tzustiegenr','einteilungsfolge','uhrzeit_ha'
  );
begin
  DoSelectOne('T_Z_EINTEILUNG', ALLOWED, 'nr');
end;

// Route: /fahrtenplanung/gett_z_einteilungkey  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_Z_EinteilungKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(T_Z_EINTEILUNG_NR_GEN, 1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /fahrtenplanung/insertt_z_einteilung  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.insertT_Z_Einteilung;
// Body: { "nr": 42, "zwegenr": 1, "tzustiegenr": 2, "einteilungsfolge": 1, "uhrzeit_ha": "07:30" }
const
  ALLOWED: array[0..4] of string = (
    'nr','zwegenr','tzustiegenr','einteilungsfolge','uhrzeit_ha'
  );
begin
  DoInsert('T_Z_EINTEILUNG', ALLOWED);
end;

// Route: /fahrtenplanung/updatet_z_einteilung  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.updateT_Z_Einteilung;
// Body: { "nr": 42, "einteilungsfolge": 2, "uhrzeit_ha": "07:35" }
const
  ALLOWED: array[0..3] of string = (
    'zwegenr','tzustiegenr','einteilungsfolge','uhrzeit_ha'
  );
begin
  DoUpdate('T_Z_EINTEILUNG', ALLOWED, 'nr');
end;

// Route: /fahrtenplanung/deletet_z_einteilung  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.deleteT_Z_Einteilung;
// Body: { "nr": 42 }
begin
  DoDelete('T_Z_EINTEILUNG', 'nr');
end;

// Route: /fahrtenplanung/gett_knoten  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_Knoten;
// Body: { "fields": ["nr","zubringer",...] | "*", "orderby": "reihenfolge" }
const
  ALLOWED: array[0..14] of string = (
    'nr','zubringer','reisenr','datum','land','ort','region','zielknoten',
    'reihenfolge','art','geraet','zielknotenhaltnr','knotenladen','internet','sortierung'
  );
begin
  DoSelect('T_KNOTEN', ALLOWED);
end;

// Route: /fahrtenplanung/gett_knotenfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_KnotenFiltered;
// Body: { "fields": [...] | "*", "zubringer": 1, "reisenr": 2, "orderby": "reihenfolge" }
// Alle Filter-Parameter sind optional – nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..14] of string = (
    'nr','zubringer','reisenr','datum','land','ort','region','zielknoten',
    'reihenfolge','art','geraet','zielknotenhaltnr','knotenladen','internet','sortierung'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS übereinstimmen).
  CONDITIONS: array[0..14] of string = (
    'nr = :nr',
    'zubringer = :zubringer',
    'reisenr = :reisenr',
    'datum = :datum',
    'land = :land',
    'ort = :ort',
    'region = :region',
    'zielknoten = :zielknoten',
    'reihenfolge = :reihenfolge',
    'art = :art',
    'geraet = :geraet',
    'zielknotenhaltnr = :zielknotenhaltnr',
    'knotenladen = :knotenladen',
    'internet = :internet',
    'sortierung = :sortierung'
  );
  FILTER_PARAMS: array[0..14] of string = ('nr', 'zubringer', 'reisenr', 'datum', 'land', 'ort', 'region', 'zielknoten',
    'reihenfolge', 'art', 'geraet', 'zielknotenhaltnr', 'knotenladen', 'internet', 'sortierung');
begin
  DoSelectFilteredDynamic('T_KNOTEN', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /fahrtenplanung/gett_knotenbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_KnotenById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..14] of string = (
    'nr','zubringer','reisenr','datum','land','ort','region','zielknoten',
    'reihenfolge','art','geraet','zielknotenhaltnr','knotenladen','internet','sortierung'
  );
begin
  DoSelectOne('T_KNOTEN', ALLOWED, 'nr');
end;

// Route: /fahrtenplanung/gett_knotenkey  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_KnotenKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(T_KNOTEN_NR_GEN, 1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /fahrtenplanung/insertt_knoten  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.insertT_Knoten;
// Body: { "nr": 42, "zubringer": 1, "reisenr": 2, "datum": "2026-11-03", "land": "DE", "ort": "...", ... }
const
  ALLOWED: array[0..14] of string = (
    'nr','zubringer','reisenr','datum','land','ort','region','zielknoten',
    'reihenfolge','art','geraet','zielknotenhaltnr','knotenladen','internet','sortierung'
  );
begin
  DoInsert('T_KNOTEN', ALLOWED);
end;

// Route: /fahrtenplanung/updatet_knoten  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.updateT_Knoten;
// Body: { "nr": 42, "ort": "...", "reihenfolge": 2, ... }
const
  ALLOWED: array[0..13] of string = (
    'zubringer','reisenr','datum','land','ort','region','zielknoten',
    'reihenfolge','art','geraet','zielknotenhaltnr','knotenladen','internet','sortierung'
  );
begin
  DoUpdate('T_KNOTEN', ALLOWED, 'nr');
end;

// Route: /fahrtenplanung/deletet_knoten  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.deleteT_Knoten;
// Body: { "nr": 42 }
begin
  DoDelete('T_KNOTEN', 'nr');
end;

// Route: /fahrtenplanung/gett_knotenhalt  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_Knotenhalt;
// Body: { "fields": ["nr","knoten",...] | "*", "orderby": "sortierung" }
const
  ALLOWED: array[0..10] of string = (
    'nr','knoten','halt','datum','zeit','zuschlag','internet',
    'sortierung','inhouse','maximumpers','exportierbar'
  );
begin
  DoSelect('T_KNOTENHALT', ALLOWED);
end;

// Route: /fahrtenplanung/gett_knotenhaltfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_KnotenhaltFiltered;
// Body: { "fields": [...] | "*", "knoten": 1, "halt": 2, "orderby": "sortierung" }
// Alle Filter-Parameter sind optional – nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..10] of string = (
    'nr','knoten','halt','datum','zeit','zuschlag','internet',
    'sortierung','inhouse','maximumpers','exportierbar'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS übereinstimmen).
  CONDITIONS: array[0..10] of string = (
    'nr = :nr',
    'knoten = :knoten',
    'halt = :halt',
    'datum = :datum',
    'zeit = :zeit',
    'zuschlag = :zuschlag',
    'internet = :internet',
    'sortierung = :sortierung',
    'inhouse = :inhouse',
    'maximumpers = :maximumpers',
    'exportierbar = :exportierbar'
  );
  FILTER_PARAMS: array[0..10] of string = ('nr', 'knoten', 'halt', 'datum', 'zeit', 'zuschlag', 'internet',
    'sortierung', 'inhouse', 'maximumpers', 'exportierbar');
begin
  DoSelectFilteredDynamic('T_KNOTENHALT', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /fahrtenplanung/gett_knotenhaltbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_KnotenhaltById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..10] of string = (
    'nr','knoten','halt','datum','zeit','zuschlag','internet',
    'sortierung','inhouse','maximumpers','exportierbar'
  );
begin
  DoSelectOne('T_KNOTENHALT', ALLOWED, 'nr');
end;

// Route: /fahrtenplanung/gett_knotenhaltkey  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_KnotenhaltKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(T_KNOTENHALT_NR_GEN, 1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /fahrtenplanung/insertt_knotenhalt  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.insertT_Knotenhalt;
// Body: { "nr": 42, "knoten": 1, "halt": 2, "datum": "2026-11-03", "zeit": "07:30", ... }
const
  ALLOWED: array[0..10] of string = (
    'nr','knoten','halt','datum','zeit','zuschlag','internet',
    'sortierung','inhouse','maximumpers','exportierbar'
  );
begin
  DoInsert('T_KNOTENHALT', ALLOWED);
end;

// Route: /fahrtenplanung/updatet_knotenhalt  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.updateT_Knotenhalt;
// Body: { "nr": 42, "zeit": "07:35", "zuschlag": 5.0, ... }
const
  ALLOWED: array[0..9] of string = (
    'knoten','halt','datum','zeit','zuschlag','internet',
    'sortierung','inhouse','maximumpers','exportierbar'
  );
begin
  DoUpdate('T_KNOTENHALT', ALLOWED, 'nr');
end;

// Route: /fahrtenplanung/deletet_knotenhalt  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.deleteT_Knotenhalt;
// Body: { "nr": 42 }
begin
  DoDelete('T_KNOTENHALT', 'nr');
end;

// Route: /fahrtenplanung/gett_zustiege  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_Zustiege;
// Body: { "fields": ["nr","knotenhaltnr",...] | "*", "orderby": "nr" }
const
  ALLOWED: array[0..5] of string = (
    'nr','knotenhaltnr','teilnehmernr','art','richtung','platznummer'
  );
begin
  DoSelect('T_ZUSTIEGE', ALLOWED);
end;

// Route: /fahrtenplanung/gett_zustiegefiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_ZustiegeFiltered;
// Body: { "fields": [...] | "*", "knotenhaltnr": 1, "teilnehmernr": 2, "orderby": "nr" }
// Alle Filter-Parameter sind optional – nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..5] of string = (
    'nr','knotenhaltnr','teilnehmernr','art','richtung','platznummer'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS übereinstimmen).
  CONDITIONS: array[0..5] of string = (
    'nr = :nr',
    'knotenhaltnr = :knotenhaltnr',
    'teilnehmernr = :teilnehmernr',
    'art = :art',
    'richtung = :richtung',
    'platznummer = :platznummer'
  );
  FILTER_PARAMS: array[0..5] of string = ('nr', 'knotenhaltnr', 'teilnehmernr', 'art', 'richtung', 'platznummer');
begin
  DoSelectFilteredDynamic('T_ZUSTIEGE', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /fahrtenplanung/gett_zustiegebyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_ZustiegeById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..5] of string = (
    'nr','knotenhaltnr','teilnehmernr','art','richtung','platznummer'
  );
begin
  DoSelectOne('T_ZUSTIEGE', ALLOWED, 'nr');
end;

// Route: /fahrtenplanung/gett_zustiegekey  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_ZustiegeKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(T_ZUSTIEGE_NR_GEN, 1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /fahrtenplanung/insertt_zustiege  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.insertT_Zustiege;
// Body: { "nr": 42, "knotenhaltnr": 1, "teilnehmernr": 2, "art": "..", "richtung": "H", "platznummer": "12A" }
const
  ALLOWED: array[0..5] of string = (
    'nr','knotenhaltnr','teilnehmernr','art','richtung','platznummer'
  );
begin
  DoInsert('T_ZUSTIEGE', ALLOWED);
end;

// Route: /fahrtenplanung/updatet_zustiege  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.updateT_Zustiege;
// Body: { "nr": 42, "platznummer": "14B", ... }
const
  ALLOWED: array[0..4] of string = (
    'knotenhaltnr','teilnehmernr','art','richtung','platznummer'
  );
begin
  DoUpdate('T_ZUSTIEGE', ALLOWED, 'nr');
end;

// Route: /fahrtenplanung/deletet_zustiege  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.deleteT_Zustiege;
// Body: { "nr": 42 }
begin
  DoDelete('T_ZUSTIEGE', 'nr');
end;

// Route: /fahrtenplanung/gett_haltestelle  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_Haltestelle;
// Body: { "fields": ["nr","bezeichnung",...] | "*", "orderby": "sortierung" }
const
  ALLOWED: array[0..16] of string = (
    'nr','land','plz','ort','strasse','gesperrt','xkoord','ykoord','code',
    'zuschlag','bezeichnung','hausabholung','sortierung','externenr1','externenr2','internet','exportierbar'
  );
begin
  DoSelect('T_HALTESTELLE', ALLOWED);
end;

// Route: /fahrtenplanung/gett_haltestellefiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_HaltestelleFiltered;
// Body: { "fields": [...] | "*", "plz": "12345", "ort": "...", "orderby": "sortierung" }
// Alle Filter-Parameter sind optional – nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..16] of string = (
    'nr','land','plz','ort','strasse','gesperrt','xkoord','ykoord','code',
    'zuschlag','bezeichnung','hausabholung','sortierung','externenr1','externenr2','internet','exportierbar'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS übereinstimmen).
  CONDITIONS: array[0..16] of string = (
    'nr = :nr',
    'land = :land',
    'plz = :plz',
    'ort = :ort',
    'strasse = :strasse',
    'gesperrt = :gesperrt',
    'xkoord = :xkoord',
    'ykoord = :ykoord',
    'code = :code',
    'zuschlag = :zuschlag',
    'bezeichnung = :bezeichnung',
    'hausabholung = :hausabholung',
    'sortierung = :sortierung',
    'externenr1 = :externenr1',
    'externenr2 = :externenr2',
    'internet = :internet',
    'exportierbar = :exportierbar'
  );
  FILTER_PARAMS: array[0..16] of string = ('nr', 'land', 'plz', 'ort', 'strasse', 'gesperrt', 'xkoord', 'ykoord', 'code',
    'zuschlag', 'bezeichnung', 'hausabholung', 'sortierung', 'externenr1', 'externenr2', 'internet', 'exportierbar');
begin
  DoSelectFilteredDynamic('T_HALTESTELLE', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /fahrtenplanung/gett_haltestellebyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_HaltestelleById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..16] of string = (
    'nr','land','plz','ort','strasse','gesperrt','xkoord','ykoord','code',
    'zuschlag','bezeichnung','hausabholung','sortierung','externenr1','externenr2','internet','exportierbar'
  );
begin
  DoSelectOne('T_HALTESTELLE', ALLOWED, 'nr');
end;

// Route: /fahrtenplanung/gett_haltestellekey  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.getT_HaltestelleKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(T_HALTESTELLE_NR_GEN, 1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /fahrtenplanung/insertt_haltestelle  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.insertT_Haltestelle;
// Body: { "nr": 42, "land": "DE", "plz": "12345", "ort": "...", "strasse": "...", "bezeichnung": "...", ... }
const
  ALLOWED: array[0..16] of string = (
    'nr','land','plz','ort','strasse','gesperrt','xkoord','ykoord','code',
    'zuschlag','bezeichnung','hausabholung','sortierung','externenr1','externenr2','internet','exportierbar'
  );
begin
  DoInsert('T_HALTESTELLE', ALLOWED);
end;

// Route: /fahrtenplanung/updatet_haltestelle  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.updateT_Haltestelle;
// Body: { "nr": 42, "bezeichnung": "...", "gesperrt": "N", ... }
const
  ALLOWED: array[0..15] of string = (
    'land','plz','ort','strasse','gesperrt','xkoord','ykoord','code',
    'zuschlag','bezeichnung','hausabholung','sortierung','externenr1','externenr2','internet','exportierbar'
  );
begin
  DoUpdate('T_HALTESTELLE', ALLOWED, 'nr');
end;

// Route: /fahrtenplanung/deletet_haltestelle  |  Auth: true  |  LocalOnly: false
procedure TDataModulFahrtenplanung.deleteT_Haltestelle;
// Body: { "nr": 42 }
begin
  DoDelete('T_HALTESTELLE', 'nr');
end;




end.
