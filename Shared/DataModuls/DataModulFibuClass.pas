unit DataModulFibuClass;

interface

uses
  Web.HTTPApp,   System.JSON,
  DataModulTableBaseClass,
  System.SysUtils, System.Classes, DataModulBaseClass, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt, FireDAC.UI.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Phys, FireDAC.Phys.IB, FireDAC.Phys.IBDef, FireDAC.VCLUI.Wait, Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet;

type
  TDataModulFibu = class(TDataModulTableBase)
  private

    { Private-Deklarationen }
  public
    { Public-Deklarationen }
     procedure Demo;
     procedure getBruttolohn;
     procedure getBruttolohnFiltered;
     procedure getBruttolohnById;
     procedure getBruttolohnKey;
     procedure insertBruttolohn;
     procedure updateBruttolohn;
     procedure deleteBruttolohn;
     procedure getGutschein;
     procedure getGutscheinFiltered;
     procedure getGutscheinById;
     procedure getGutscheinKey;
     procedure insertGutschein;
     procedure updateGutschein;
     procedure deleteGutschein;
  end;


function CreateDataModulFibu(Request: TWebRequest; Response: TWebResponse): TObject;

implementation
uses webutils;

function CreateDataModulFibu(Request: TWebRequest; Response: TWebResponse): TObject;
begin
  Result := TDataModulFibu.Create(Request, Response);
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


procedure TDataModulFibu.Demo;
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

// Route: /fibu/getbruttolohn  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.getBruttolohn;
// Body: { "fields": ["nr","monteurzeichen",...] | "*", "orderby": "datum" }
const
  ALLOWED: array[0..27] of string = (
    'nr','monteurzeichen','lohnart','datum','einheit','satz','gesamtbetrag',
    'auftragnr','kostenstelle','positionsnr','extauftragnr','extpos',
    'positiosnr','zuschlag','herkunft','faktor','bezeichnung','fahrzeug',
    'kostenstelle1','kostenstelle2','vonzeit','biszeit','kmanfang','kmende',
    'kmgesamt','zusatzfeld1','zusatzfeld2','kommentar'
  );
begin
  DoSelect('BRUTTOLOHN', ALLOWED);
end;

// Route: /fibu/getbruttolohnfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.getBruttolohnFiltered;
// Body: { "fields": [...] | "*", "monteurzeichen": "MZ01", "datum": "2026-07-17", "orderby": "datum" }
// Alle Filter-Parameter sind optional – nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..27] of string = (
    'nr','monteurzeichen','lohnart','datum','einheit','satz','gesamtbetrag',
    'auftragnr','kostenstelle','positionsnr','extauftragnr','extpos',
    'positiosnr','zuschlag','herkunft','faktor','bezeichnung','fahrzeug',
    'kostenstelle1','kostenstelle2','vonzeit','biszeit','kmanfang','kmende',
    'kmgesamt','zusatzfeld1','zusatzfeld2','kommentar'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS übereinstimmen).
  CONDITIONS: array[0..27] of string = (
    'nr = :nr',
    'monteurzeichen = :monteurzeichen',
    'lohnart = :lohnart',
    'datum = :datum',
    'einheit = :einheit',
    'satz = :satz',
    'gesamtbetrag = :gesamtbetrag',
    'auftragnr = :auftragnr',
    'kostenstelle = :kostenstelle',
    'positionsnr = :positionsnr',
    'extauftragnr = :extauftragnr',
    'extpos = :extpos',
    'positiosnr = :positiosnr',
    'zuschlag = :zuschlag',
    'herkunft = :herkunft',
    'faktor = :faktor',
    'bezeichnung = :bezeichnung',
    'fahrzeug = :fahrzeug',
    'kostenstelle1 = :kostenstelle1',
    'kostenstelle2 = :kostenstelle2',
    'vonzeit = :vonzeit',
    'biszeit = :biszeit',
    'kmanfang = :kmanfang',
    'kmende = :kmende',
    'kmgesamt = :kmgesamt',
    'zusatzfeld1 = :zusatzfeld1',
    'zusatzfeld2 = :zusatzfeld2',
    'kommentar = :kommentar'
  );
  FILTER_PARAMS: array[0..27] of string = (
    'nr','monteurzeichen','lohnart','datum','einheit','satz','gesamtbetrag',
    'auftragnr','kostenstelle','positionsnr','extauftragnr','extpos',
    'positiosnr','zuschlag','herkunft','faktor','bezeichnung','fahrzeug',
    'kostenstelle1','kostenstelle2','vonzeit','biszeit','kmanfang','kmende',
    'kmgesamt','zusatzfeld1','zusatzfeld2','kommentar'
  );
begin
  DoSelectFilteredDynamic('BRUTTOLOHN', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /fibu/getbruttolohnbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.getBruttolohnById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..27] of string = (
    'nr','monteurzeichen','lohnart','datum','einheit','satz','gesamtbetrag',
    'auftragnr','kostenstelle','positionsnr','extauftragnr','extpos',
    'positiosnr','zuschlag','herkunft','faktor','bezeichnung','fahrzeug',
    'kostenstelle1','kostenstelle2','vonzeit','biszeit','kmanfang','kmende',
    'kmgesamt','zusatzfeld1','zusatzfeld2','kommentar'
  );
begin
  DoSelectOne('BRUTTOLOHN', ALLOWED, 'nr');
end;

// Route: /fibu/getbruttolohnkey  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.getBruttolohnKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(BRUTTOLOHN, 1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /fibu/insertbruttolohn  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.insertBruttolohn;
// Body: { "monteurzeichen": "MZ01", "lohnart": 1, "datum": "2026-07-17", ... }
const
  ALLOWED: array[0..26] of string = (
    'monteurzeichen','lohnart','datum','einheit','satz','gesamtbetrag',
    'auftragnr','kostenstelle','positionsnr','extauftragnr','extpos',
    'positiosnr','zuschlag','herkunft','faktor','bezeichnung','fahrzeug',
    'kostenstelle1','kostenstelle2','vonzeit','biszeit','kmanfang','kmende',
    'kmgesamt','zusatzfeld1','zusatzfeld2','kommentar'
  );
begin
  DoInsert('BRUTTOLOHN', ALLOWED);
end;

// Route: /fibu/updatebruttolohn  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.updateBruttolohn;
// Body: { "nr": 42, "satz": 15.5, "gesamtbetrag": 620.00, ... }
const
  ALLOWED: array[0..26] of string = (
    'monteurzeichen','lohnart','datum','einheit','satz','gesamtbetrag',
    'auftragnr','kostenstelle','positionsnr','extauftragnr','extpos',
    'positiosnr','zuschlag','herkunft','faktor','bezeichnung','fahrzeug',
    'kostenstelle1','kostenstelle2','vonzeit','biszeit','kmanfang','kmende',
    'kmgesamt','zusatzfeld1','zusatzfeld2','kommentar'
  );
begin
  DoUpdate('BRUTTOLOHN', ALLOWED, 'nr');
end;

// Route: /fibu/deletebruttolohn  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.deleteBruttolohn;
// Body: { "nr": 42 }
begin
  DoDelete('BRUTTOLOHN', 'nr');
end;

// Route: /fibu/getgutschein  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.getGutschein;
// Body: { "fields": ["nr","vorgang",...] | "*", "orderby": "erfasst" }
const
  ALLOWED: array[0..30] of string = (
    'nr','vorgang','bearbeiter','geaendert_am','geaendert_von','erfasst',
    'faellig','kennziffer','gutscheinkonto','kurzbemerkung','bemerkung',
    'betrag','gueltig_bis','erledigt','storniert','storniert_am',
    'stornogrund','fuerkunde','zusatzfeld1','zusatzfeld2','zusatzfeld3',
    'fibukto','kulanz','kostelle1','kostelle2','code','motivnr',
    'fibu_archiv_am','nrkreis','entstehung','zahlungsart'
  );
begin
  DoSelect('GUTSCHEIN', ALLOWED);
end;

// Route: /fibu/getgutscheinfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.getGutscheinFiltered;
// Body: { "fields": [...] | "*", "vorgang": "V001", "erledigt": "N", "orderby": "erfasst" }
// Alle Filter-Parameter sind optional – nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..30] of string = (
    'nr','vorgang','bearbeiter','geaendert_am','geaendert_von','erfasst',
    'faellig','kennziffer','gutscheinkonto','kurzbemerkung','bemerkung',
    'betrag','gueltig_bis','erledigt','storniert','storniert_am',
    'stornogrund','fuerkunde','zusatzfeld1','zusatzfeld2','zusatzfeld3',
    'fibukto','kulanz','kostelle1','kostelle2','code','motivnr',
    'fibu_archiv_am','nrkreis','entstehung','zahlungsart'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS übereinstimmen).
  CONDITIONS: array[0..30] of string = (
    'nr = :nr',
    'vorgang = :vorgang',
    'bearbeiter = :bearbeiter',
    'geaendert_am = :geaendert_am',
    'geaendert_von = :geaendert_von',
    'erfasst = :erfasst',
    'faellig = :faellig',
    'kennziffer = :kennziffer',
    'gutscheinkonto = :gutscheinkonto',
    'kurzbemerkung = :kurzbemerkung',
    'bemerkung = :bemerkung',
    'betrag = :betrag',
    'gueltig_bis = :gueltig_bis',
    'erledigt = :erledigt',
    'storniert = :storniert',
    'storniert_am = :storniert_am',
    'stornogrund = :stornogrund',
    'fuerkunde = :fuerkunde',
    'zusatzfeld1 = :zusatzfeld1',
    'zusatzfeld2 = :zusatzfeld2',
    'zusatzfeld3 = :zusatzfeld3',
    'fibukto = :fibukto',
    'kulanz = :kulanz',
    'kostelle1 = :kostelle1',
    'kostelle2 = :kostelle2',
    'code = :code',
    'motivnr = :motivnr',
    'fibu_archiv_am = :fibu_archiv_am',
    'nrkreis = :nrkreis',
    'entstehung = :entstehung',
    'zahlungsart = :zahlungsart'
  );
  FILTER_PARAMS: array[0..30] of string = (
    'nr','vorgang','bearbeiter','geaendert_am','geaendert_von','erfasst',
    'faellig','kennziffer','gutscheinkonto','kurzbemerkung','bemerkung',
    'betrag','gueltig_bis','erledigt','storniert','storniert_am',
    'stornogrund','fuerkunde','zusatzfeld1','zusatzfeld2','zusatzfeld3',
    'fibukto','kulanz','kostelle1','kostelle2','code','motivnr',
    'fibu_archiv_am','nrkreis','entstehung','zahlungsart'
  );
begin
  DoSelectFilteredDynamic('GUTSCHEIN', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /fibu/getgutscheinbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.getGutscheinById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..30] of string = (
    'nr','vorgang','bearbeiter','geaendert_am','geaendert_von','erfasst',
    'faellig','kennziffer','gutscheinkonto','kurzbemerkung','bemerkung',
    'betrag','gueltig_bis','erledigt','storniert','storniert_am',
    'stornogrund','fuerkunde','zusatzfeld1','zusatzfeld2','zusatzfeld3',
    'fibukto','kulanz','kostelle1','kostelle2','code','motivnr',
    'fibu_archiv_am','nrkreis','entstehung','zahlungsart'
  );
begin
  DoSelectOne('GUTSCHEIN', ALLOWED, 'nr');
end;

// Route: /fibu/getgutscheinkey  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.getGutscheinKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(GUTSCHEIN_NR_GEN, 1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /fibu/insertgutschein  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.insertGutschein;
// Body: { "vorgang": "V001", "bearbeiter": "SUPERVISOR", "betrag": 50.00, ... }
const
  ALLOWED: array[0..29] of string = (
    'vorgang','bearbeiter','geaendert_am','geaendert_von','erfasst',
    'faellig','kennziffer','gutscheinkonto','kurzbemerkung','bemerkung',
    'betrag','gueltig_bis','erledigt','storniert','storniert_am',
    'stornogrund','fuerkunde','zusatzfeld1','zusatzfeld2','zusatzfeld3',
    'fibukto','kulanz','kostelle1','kostelle2','code','motivnr',
    'fibu_archiv_am','nrkreis','entstehung','zahlungsart'
  );
begin
  DoInsert('GUTSCHEIN', ALLOWED);
end;

// Route: /fibu/updategutschein  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.updateGutschein;
// Body: { "nr": 42, "erledigt": "J", "storniert": "N", ... }
const
  ALLOWED: array[0..29] of string = (
    'vorgang','bearbeiter','geaendert_am','geaendert_von','erfasst',
    'faellig','kennziffer','gutscheinkonto','kurzbemerkung','bemerkung',
    'betrag','gueltig_bis','erledigt','storniert','storniert_am',
    'stornogrund','fuerkunde','zusatzfeld1','zusatzfeld2','zusatzfeld3',
    'fibukto','kulanz','kostelle1','kostelle2','code','motivnr',
    'fibu_archiv_am','nrkreis','entstehung','zahlungsart'
  );
begin
  DoUpdate('GUTSCHEIN', ALLOWED, 'nr');
end;

// Route: /fibu/deletegutschein  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.deleteGutschein;
// Body: { "nr": 42 }
begin
  DoDelete('GUTSCHEIN', 'nr');
end;

end.
