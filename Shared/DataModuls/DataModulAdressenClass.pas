unit DataModulAdressenClass;

interface

uses
  Web.HTTPApp, System.JSON, System.SysUtils, System.Classes,
  DataModulTableBaseClass, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt, FireDAC.UI.Intf, FireDAC.Stan.Def,
  FireDAC.Stan.Pool, FireDAC.Phys, FireDAC.Phys.IB, FireDAC.Phys.IBDef, FireDAC.VCLUI.Wait, Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet;

type
  TDataModulAdressen = class(TDataModulTableBase)
  private

  public
    procedure Demo;
    procedure getAdressen;
    procedure getAdressenFiltered;
   procedure getAdressenJoinedQuery;
    procedure getAdresseById;
    procedure getNextKennziffer;
    procedure getKategorien;
    procedure getKategorieById;
    procedure insertKategorie;
    procedure updateKategorie;
    procedure deleteKategorie;
    procedure insertAdresse;
    procedure updateAdresse;
    procedure deleteAdresse;
    procedure getZusatztabelle;
    procedure getZusatztabelleFiltered;
    procedure getZusatztabelleById;
    procedure getZusatztabelleKey;
    procedure insertZusatztabelle;
    procedure updateZusatztabelle;
    procedure deleteZusatztabelle;
  end;

function CreateDataModulAdressen(Request: TWebRequest; Response: TWebResponse): TObject;

implementation

uses webutils;

function CreateDataModulAdressen(Request: TWebRequest; Response: TWebResponse): TObject;
begin
  Result := TDataModulAdressen.Create(Request, Response);
end;

{%CLASSGROUP 'Vcl.Controls.TControl'}
{$R *.dfm}

{ TDataModulAdressen }

(*
  ============================  DEMO-Endpunkt  ============================
  Referenz-Vorlage fuer die Entwicklung neuer Endpunkte.
  Demonstriert den SICHEREN Zugriff auf Parameter aus zwei Quellen und den
  Umgang mit fehlenden Werten (ein, mehrere oder gar kein Parameter gesetzt).

  Hinweis: Fuer diesen Controller ist KEINE /demo-Route registriert - die
  Prozedur dient als Code-Vorlage. Zum Live-Test in WebModuleUnit1 eine Route
  ergaenzen, z.B.:
    FRouter.AddRoute('/adressen/demo', CreateDataModulAdressen, TDataModulAdressen(nil).Demo);

  Quellen:
    1) URL / QueryString  -> Request.QueryFields   (Beispiel-Parameter: id, filter)
    2) JSON-Body          -> isParamFromBody / getParamFromBody        (Beispiel-Parameter: name, menge)

  ----------------------------- Aufruf (Postman) -----------------------------
    Methode : POST   (GET reicht, wenn nur URL-Parameter genutzt werden)
    URL     : http://localhost:<port>/ibapi/adressen/demo?id=42&filter=Mueller
    Header  : Authorization: Bearer <JWT-Token>     (Route verlangt Auth)
              Content-Type : application/json
    Body    : (raw / JSON, optional)
              { "name": "Helga", "menge": 5 }

    Test-Kombinationen:
      - nur URL   : POST /adressen/demo?id=42&filter=Mueller   (Body leer lassen)
      - nur Body  : POST /adressen/demo   Body { "name":"Helga","menge":5 }
      - gemischt  : beide Quellen gleichzeitig
      - nichts    : POST /adressen/demo ohne Parameter -> alle Felder als null
    Fehlende Werte erzeugen KEINEN Fehler, sondern erscheinen im Ergebnis als null.
  ----------------------------------------------------------------------------
*)
procedure TDataModulAdressen.Demo;
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

// Route: /getadressen  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getAdressen;
// Body: { "fields": ["kennziffer","name1",...] | "*", "orderby": "name1" }
const
  ALLOWED: array[0..12] of string = (
    'kennziffer','gruppe','anrede','titel','name1','name2',
    'strasse','plz','ort','telefon1','email','matchcode','lvorgang'
  );
begin
  DoSelect('ADRESSEN', ALLOWED);
end;

// Route: /getadressenfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getAdressenFiltered;
// Body: { "fields": [...] | "*", "gruppe": "K", "orderby": "name1" }
const
  ALLOWED: array[0..12] of string = (
    'kennziffer','gruppe','anrede','titel','name1','name2',
    'strasse','plz','ort','telefon1','email','matchcode','lvorgang'
  );
  CONDITIONS: array[0..0] of string = (
    'gruppe = :gruppe'
  );
  FILTER_PARAMS: array[0..0] of string = ('gruppe');
begin
  DoSelectFilteredDynamic('ADRESSEN', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;


// Route: /getjoin  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getAdressenJoinedQuery;
// Body: {  "gruppe": 1,"name1":"Helga" }
const
  FILTER_PARAMS: array[0..1] of string = ('gruppe','name1');
begin
  var joinedSql:='Select a.name1,a.name2,a.ort,a.gruppe,k.bezeichnung from adressen a join adrkats k on a.gruppe=k.gruppe where a.name1=:name1 and a.gruppe= :gruppe';
  DoJoinedSelect(joinedSql, FILTER_PARAMS);
end;




// Route: /getadressebyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getAdresseById;
// Body: { "kennziffer": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..10] of string = (
    'kennziffer','gruppe','anrede','titel','name1','name2',
    'strasse','plz','ort','telefon1','email'
  );
begin
  DoSelectOne('ADRESSEN', ALLOWED, 'kennziffer');
end;

// Route: /getnextkennziffer  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getNextKennziffer;
begin
  Query.SQL.Text := 'SELECT * FROM ADRESSEN_NEXTKENNZIFFER';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /adressen/getkategorien  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getKategorien;
// Body: { "fields": ["gruppe","bezeichnung",...] | "*", "orderby": "bezeichnung" }
const
  ALLOWED: array[0..27] of string = (
    'gruppe','kat1','kat2','kat3','kat4','kat5','kat6','kat7',
    'kat8','kat9','kat10','kat11','kat12','bezeichnung','debitkredit',
    'symbol','kat13','kat14','kat15','kat16','kat17','kat18','kat19',
    'kat20','kat21','kat22','kat23','kat24'
  );
begin
  DoSelect('ADRKATS', ALLOWED);
end;

// Route: /adressen/getkategoriebyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getKategorieById;
// Body: { "gruppe": 1, "fields": [...] | "*" }
const
  ALLOWED: array[0..27] of string = (
    'gruppe','kat1','kat2','kat3','kat4','kat5','kat6','kat7',
    'kat8','kat9','kat10','kat11','kat12','bezeichnung','debitkredit',
    'symbol','kat13','kat14','kat15','kat16','kat17','kat18','kat19',
    'kat20','kat21','kat22','kat23','kat24'
  );
begin
  DoSelectOne('ADRKATS', ALLOWED, 'gruppe');
end;

// Route: /adressen/insertkategorie  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.insertKategorie;
// Body: { "gruppe": 1, "bezeichnung": "...", "kat1": "...", ... }
const
  ALLOWED: array[0..27] of string = (
    'gruppe','kat1','kat2','kat3','kat4','kat5','kat6','kat7',
    'kat8','kat9','kat10','kat11','kat12','bezeichnung','debitkredit',
    'symbol','kat13','kat14','kat15','kat16','kat17','kat18','kat19',
    'kat20','kat21','kat22','kat23','kat24'
  );
begin
  DoInsert('ADRKATS', ALLOWED);
end;

// Route: /adressen/updatekategorie  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.updateKategorie;
// Body: { "gruppe": 1, "bezeichnung": "...", "kat1": "...", ... }
const
  ALLOWED: array[0..26] of string = (
    'kat1','kat2','kat3','kat4','kat5','kat6','kat7',
    'kat8','kat9','kat10','kat11','kat12','bezeichnung','debitkredit',
    'symbol','kat13','kat14','kat15','kat16','kat17','kat18','kat19',
    'kat20','kat21','kat22','kat23','kat24'
  );
begin
  DoUpdate('ADRKATS', ALLOWED, 'gruppe');
end;

// Route: /adressen/deletekategorie  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.deleteKategorie;
// Body: { "gruppe": 1 }
begin
  DoDelete('ADRKATS', 'gruppe');
end;

// Route: /insertadresse  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.insertAdresse;
// Body: { "name1": "...", "ort": "...", ... }
const
  ALLOWED: array[0..10] of string = (
    'gruppe','anrede','titel','name1','name2','strasse','plz','ort','telefon1','email','code'
  );
begin
  DoInsert('ADRESSEN', ALLOWED);
end;

// Route: /updateadresse  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.updateAdresse;
// Body: { "kennziffer": 42, "name1": "...", ... }
const
  ALLOWED: array[0..9] of string = (
    'gruppe','anrede','titel','name1','name2','strasse','plz','ort','telefon1','email'
  );
begin
  DoUpdate('ADRESSEN', ALLOWED, 'kennziffer');
end;

// Route: /deleteadresse  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.deleteAdresse;
// Body: { "kennziffer": 42 }
begin
  DoDelete('ADRESSEN', 'kennziffer');
end;

// Route: /adressen/getzusatztabelle  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getZusatztabelle;
// Body: { "fields": ["nr","reftable",...] | "*", "orderby": "nr" }
const
  ALLOWED: array[0..33] of string = (
    'nr','reftable','refnr','modul','bereich',
    'zusatzfeld1','zusatzfeld2','zusatzfeld3','zusatzfeld4','zusatzfeld5',
    'zusatzfeld6','zusatzfeld7','zusatzfeld8','zusatzfeld9','zusatzfeld10',
    'zusatzdatum1','zusatzdatum2','zusatzdatum3',
    'zusatzzahl1','zusatzzahl2','zusatzzahl3',
    'zusatznum1','zusatznum2','zusatznum3',
    'zusatzblob1','zusatzblob2','zusatzblob3',
    'erstellt','geaendert','erfasstvon','geaendertvon',
    'kennziffer','sortierung','bemerkung'
  );
begin
  DoSelect('ZUSATZTABELLE', ALLOWED);
end;

// Route: /adressen/getzusatztabellefiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getZusatztabelleFiltered;
// Body: { "fields": [...] | "*", "reftable": "ADRESSEN", "refnr": 42, "orderby": "nr" }
// Alle Filter-Parameter sind optional - nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
// zusatzblob1/2/3 sind Blob-Felder und daher nur in ALLOWED, nicht in CONDITIONS/FILTER_PARAMS.
const
  ALLOWED: array[0..33] of string = (
    'nr','reftable','refnr','modul','bereich',
    'zusatzfeld1','zusatzfeld2','zusatzfeld3','zusatzfeld4','zusatzfeld5',
    'zusatzfeld6','zusatzfeld7','zusatzfeld8','zusatzfeld9','zusatzfeld10',
    'zusatzdatum1','zusatzdatum2','zusatzdatum3',
    'zusatzzahl1','zusatzzahl2','zusatzzahl3',
    'zusatznum1','zusatznum2','zusatznum3',
    'zusatzblob1','zusatzblob2','zusatzblob3',
    'erstellt','geaendert','erfasstvon','geaendertvon',
    'kennziffer','sortierung','bemerkung'
  );
  CONDITIONS: array[0..30] of string = (
    'nr = :nr',
    'reftable = :reftable',
    'refnr = :refnr',
    'modul = :modul',
    'bereich = :bereich',
    'zusatzfeld1 = :zusatzfeld1',
    'zusatzfeld2 = :zusatzfeld2',
    'zusatzfeld3 = :zusatzfeld3',
    'zusatzfeld4 = :zusatzfeld4',
    'zusatzfeld5 = :zusatzfeld5',
    'zusatzfeld6 = :zusatzfeld6',
    'zusatzfeld7 = :zusatzfeld7',
    'zusatzfeld8 = :zusatzfeld8',
    'zusatzfeld9 = :zusatzfeld9',
    'zusatzfeld10 = :zusatzfeld10',
    'zusatzdatum1 = :zusatzdatum1',
    'zusatzdatum2 = :zusatzdatum2',
    'zusatzdatum3 = :zusatzdatum3',
    'zusatzzahl1 = :zusatzzahl1',
    'zusatzzahl2 = :zusatzzahl2',
    'zusatzzahl3 = :zusatzzahl3',
    'zusatznum1 = :zusatznum1',
    'zusatznum2 = :zusatznum2',
    'zusatznum3 = :zusatznum3',
    'erstellt = :erstellt',
    'geaendert = :geaendert',
    'erfasstvon = :erfasstvon',
    'geaendertvon = :geaendertvon',
    'kennziffer = :kennziffer',
    'sortierung = :sortierung',
    'bemerkung = :bemerkung'
  );
  FILTER_PARAMS: array[0..30] of string = (
    'nr','reftable','refnr','modul','bereich',
    'zusatzfeld1','zusatzfeld2','zusatzfeld3','zusatzfeld4','zusatzfeld5',
    'zusatzfeld6','zusatzfeld7','zusatzfeld8','zusatzfeld9','zusatzfeld10',
    'zusatzdatum1','zusatzdatum2','zusatzdatum3',
    'zusatzzahl1','zusatzzahl2','zusatzzahl3',
    'zusatznum1','zusatznum2','zusatznum3',
    'erstellt','geaendert','erfasstvon','geaendertvon',
    'kennziffer','sortierung','bemerkung'
  );
begin
  DoSelectFilteredDynamic('ZUSATZTABELLE', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /adressen/getzusatztabellebyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getZusatztabelleById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..33] of string = (
    'nr','reftable','refnr','modul','bereich',
    'zusatzfeld1','zusatzfeld2','zusatzfeld3','zusatzfeld4','zusatzfeld5',
    'zusatzfeld6','zusatzfeld7','zusatzfeld8','zusatzfeld9','zusatzfeld10',
    'zusatzdatum1','zusatzdatum2','zusatzdatum3',
    'zusatzzahl1','zusatzzahl2','zusatzzahl3',
    'zusatznum1','zusatznum2','zusatznum3',
    'zusatzblob1','zusatzblob2','zusatzblob3',
    'erstellt','geaendert','erfasstvon','geaendertvon',
    'kennziffer','sortierung','bemerkung'
  );
begin
  DoSelectOne('ZUSATZTABELLE', ALLOWED, 'nr');
end;

// Route: /adressen/getzusatztabellekey  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getZusatztabelleKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(ZUSATZTABELLE_NR_GEN, 1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /adressen/insertzusatztabelle  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.insertZusatztabelle;
// Body: { "reftable": "ADRESSEN", "refnr": 42, "modul": "...", ... }
const
  ALLOWED: array[0..32] of string = (
    'reftable','refnr','modul','bereich',
    'zusatzfeld1','zusatzfeld2','zusatzfeld3','zusatzfeld4','zusatzfeld5',
    'zusatzfeld6','zusatzfeld7','zusatzfeld8','zusatzfeld9','zusatzfeld10',
    'zusatzdatum1','zusatzdatum2','zusatzdatum3',
    'zusatzzahl1','zusatzzahl2','zusatzzahl3',
    'zusatznum1','zusatznum2','zusatznum3',
    'zusatzblob1','zusatzblob2','zusatzblob3',
    'erstellt','geaendert','erfasstvon','geaendertvon',
    'kennziffer','sortierung','bemerkung'
  );
begin
  DoInsert('ZUSATZTABELLE', ALLOWED);
end;

// Route: /adressen/updatezusatztabelle  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.updateZusatztabelle;
// Body: { "nr": 42, "bemerkung": "...", ... }
const
  ALLOWED: array[0..32] of string = (
    'reftable','refnr','modul','bereich',
    'zusatzfeld1','zusatzfeld2','zusatzfeld3','zusatzfeld4','zusatzfeld5',
    'zusatzfeld6','zusatzfeld7','zusatzfeld8','zusatzfeld9','zusatzfeld10',
    'zusatzdatum1','zusatzdatum2','zusatzdatum3',
    'zusatzzahl1','zusatzzahl2','zusatzzahl3',
    'zusatznum1','zusatznum2','zusatznum3',
    'zusatzblob1','zusatzblob2','zusatzblob3',
    'erstellt','geaendert','erfasstvon','geaendertvon',
    'kennziffer','sortierung','bemerkung'
  );
begin
  DoUpdate('ZUSATZTABELLE', ALLOWED, 'nr');
end;

// Route: /adressen/deletezusatztabelle  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.deleteZusatztabelle;
// Body: { "nr": 42 }
begin
  DoDelete('ZUSATZTABELLE', 'nr');
end;

end.
