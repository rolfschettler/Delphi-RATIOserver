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
    2) JSON-Body          -> ParseJSONObject        (Beispiel-Parameter: name, menge)

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

end.
