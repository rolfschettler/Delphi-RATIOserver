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
    2) JSON-Body          -> ParseJSONObject        (Beispiel-Parameter: name, menge)

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
  Body        : TJSONObject;
  name        : string;
  nameGesetzt : Boolean;
  mengeVal    : TJSONValue;
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
  // ParseJSONObject ist leak-sicher und liefert das Objekt ODER nil
  // (nil = Body leer, ungueltig oder kein JSON-Objekt).
  name         := '';
  nameGesetzt  := False;
  menge        := 0;
  mengeGesetzt := False;

  Body := ParseJSONObject(Request.Content);
  if Assigned(Body) then
  try
    // a) String "name": GetValue<string> mit Default wirft nicht, auch wenn Feld fehlt
    name        := Trim(Body.GetValue<string>('name', ''));
    nameGesetzt := name <> '';

    // b) numerisch "menge": GetValue liefert nil, wenn das Feld fehlt
    //    -> auf Assigned UND (nicht) Null pruefen, bevor man den Wert nutzt
    mengeVal := Body.GetValue('menge');
    if Assigned(mengeVal) and not mengeVal.Null then
    begin
      menge        := StrToIntDef(mengeVal.Value, 0);
      mengeGesetzt := True;
    end;
  finally
    Body.Free;   // Body gehoert uns -> immer freigeben
  end;

  // ===== 3) Antwort aufbauen =====
  // Pro Parameter: Wert wenn gesetzt, sonst JSON null. So ist sofort erkennbar,
  // was tatsaechlich uebergeben wurde.
  Ergebnis := TJSONObject.Create;
  try
    UrlObj := TJSONObject.Create;
    if idGesetzt   then UrlObj.AddPair('id', TJSONNumber.Create(id))
                   else UrlObj.AddPair('id', TJSONNull.Create);
    if filter <> '' then UrlObj.AddPair('filter', filter)
                    else UrlObj.AddPair('filter', TJSONNull.Create);

    BodyObj := TJSONObject.Create;
    if nameGesetzt  then BodyObj.AddPair('name', name)
                    else BodyObj.AddPair('name', TJSONNull.Create);
    if mengeGesetzt then BodyObj.AddPair('menge', TJSONNumber.Create(menge))
                    else BodyObj.AddPair('menge', TJSONNull.Create);

    Ergebnis.AddPair('url',  UrlObj);   // Ownership geht an Ergebnis ueber
    Ergebnis.AddPair('body', BodyObj);  // Ownership geht an Ergebnis ueber

    Response.ContentType := 'application/json';
    Response.StatusCode  := 200;
    Response.Content     := Ergebnis.ToJSON;
  finally
    Ergebnis.Free;   // gibt UrlObj + BodyObj rekursiv mit frei
  end;
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
  FILTER        = 'gruppe = :gruppe';
  FILTER_PARAMS: array[0..0] of string = ('gruppe');
begin
  DoSelectFiltered('ADRESSEN', ALLOWED, FILTER, FILTER_PARAMS);
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

end.
