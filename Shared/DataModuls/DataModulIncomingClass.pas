unit DataModulIncomingClass;

interface

uses
  Web.HTTPApp, System.JSON, System.SysUtils, System.Classes,
  DataModulTableBaseClass,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param,
  FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf,
  FireDAC.Stan.Async, FireDAC.DApt, FireDAC.UI.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Phys, FireDAC.Phys.IB,
  FireDAC.Phys.IBDef, FireDAC.VCLUI.Wait, Data.DB,
  FireDAC.Comp.Client, FireDAC.Comp.DataSet, DataModulBaseClass;

type
  TDataModulIncoming = class(TDataModulTableBase)
  public
    procedure Demo;
    procedure getTeilnehmer;
    procedure getTeilnehmerFiltered;
    procedure getTeilnehmerById;
    procedure getT_TeilnehmerNextNr;
    procedure insertT_Teilnehmer;
    procedure updateT_Teilnehmer;
    procedure deleteT_Teilnehmer;
  end;

function CreateDataModulIncoming(Request: TWebRequest; Response: TWebResponse): TObject;

implementation

uses webutils;

function CreateDataModulIncoming(Request: TWebRequest; Response: TWebResponse): TObject;
begin
  Result := TDataModulIncoming.Create(Request, Response);
end;

{%CLASSGROUP 'Vcl.Controls.TControl'}
{$R *.dfm}

{ TDataModulIncoming }

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
    URL     : http://localhost:<port>/ibapi/incoming/demo?id=42&filter=Mueller
    Header  : Authorization: Bearer <JWT-Token>     (Route verlangt Auth)
              Content-Type : application/json
    Body    : (raw / JSON, optional)
              { "name": "Helga", "menge": 5 }

    Test-Kombinationen:
      - nur URL   : POST /incoming/demo?id=42&filter=Mueller   (Body leer lassen)
      - nur Body  : POST /incoming/demo   Body { "name":"Helga","menge":5 }
      - gemischt  : beide Quellen gleichzeitig
      - nichts    : POST /incoming/demo ohne Parameter -> alle Felder als null
    Fehlende Werte erzeugen KEINEN Fehler, sondern erscheinen im Ergebnis als null.
  ----------------------------------------------------------------------------
*)
procedure TDataModulIncoming.Demo;
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

// Route: /incoming/getteilnehmer  |  Auth: true  |  LocalOnly: false
procedure TDataModulIncoming.getTeilnehmer;
// Body: { "fields": ["nr","name",...] | "*", "orderby": "name" }
const
  ALLOWED: array[0..57] of string = (
    'nr','vorgangnr','anrede','name','kennziffer','geburtstag','jahre',
    'shuttle','info1','info2','ref1','ref2','gruppe','sitzfest',
    'hininfo','rueckinfo','ausstiegrueck','profil','status',
    'reservierungsnr','kabinengruppe','infofaehre','zustieghin',
    'ausstieghin','zustiegrueck','ausstieg_rueck','sitzhin','sitzrueck',
    'leistungen','passnummer','ausgestellt_in','ausgestellt_am',
    'gueltig_bis','passinfo','passid','nation','geburtsort',
    'name1','name2','name3','namenszusatz','titel','email',
    'land','ort','ortsteil','plz','region','strasse',
    'telefon1','telefon2','telefon3','xkoord','ykoord',
    'heimatort','pass_name1','pass_name2','zusatzdaten'
  );
begin
  DoSelect('T_TEILNEHMER', ALLOWED);
end;

// Route: /incoming/getteilnehmerfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulIncoming.getTeilnehmerFiltered;
// Body: { "fields": [...] | "*", "vorgangnr": 42, "orderby": "name" }
const
  ALLOWED: array[0..57] of string = (
    'nr','vorgangnr','anrede','name','kennziffer','geburtstag','jahre',
    'shuttle','info1','info2','ref1','ref2','gruppe','sitzfest',
    'hininfo','rueckinfo','ausstiegrueck','profil','status',
    'reservierungsnr','kabinengruppe','infofaehre','zustieghin',
    'ausstieghin','zustiegrueck','ausstieg_rueck','sitzhin','sitzrueck',
    'leistungen','passnummer','ausgestellt_in','ausgestellt_am',
    'gueltig_bis','passinfo','passid','nation','geburtsort',
    'name1','name2','name3','namenszusatz','titel','email',
    'land','ort','ortsteil','plz','region','strasse',
    'telefon1','telefon2','telefon3','xkoord','ykoord',
    'heimatort','pass_name1','pass_name2','zusatzdaten'
  );
  CONDITIONS: array[0..0] of string = (
    'vorgangnr = :vorgangnr'
  );
  FILTER_PARAMS: array[0..0] of string = ('vorgangnr');
begin
  DoSelectFilteredDynamic('T_TEILNEHMER', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /incoming/getteilnehmerbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulIncoming.getTeilnehmerById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..57] of string = (
    'nr','vorgangnr','anrede','name','kennziffer','geburtstag','jahre',
    'shuttle','info1','info2','ref1','ref2','gruppe','sitzfest',
    'hininfo','rueckinfo','ausstiegrueck','profil','status',
    'reservierungsnr','kabinengruppe','infofaehre','zustieghin',
    'ausstieghin','zustiegrueck','ausstieg_rueck','sitzhin','sitzrueck',
    'leistungen','passnummer','ausgestellt_in','ausgestellt_am',
    'gueltig_bis','passinfo','passid','nation','geburtsort',
    'name1','name2','name3','namenszusatz','titel','email',
    'land','ort','ortsteil','plz','region','strasse',
    'telefon1','telefon2','telefon3','xkoord','ykoord',
    'heimatort','pass_name1','pass_name2','zusatzdaten'
  );
begin
  DoSelectOne('T_TEILNEHMER', ALLOWED, 'nr');
end;

// Route: /incoming/insertt_teilnehmer  |  Auth: true  |  LocalOnly: false
procedure TDataModulIncoming.insertT_Teilnehmer;
// Body: { "nr": 42, "vorgangnr": 1, "name": "...", ... }
const
  ALLOWED: array[0..57] of string = (
    'nr','vorgangnr','anrede','name','kennziffer','geburtstag','jahre',
    'shuttle','info1','info2','ref1','ref2','gruppe','sitzfest',
    'hininfo','rueckinfo','ausstiegrueck','profil','status',
    'reservierungsnr','kabinengruppe','infofaehre','zustieghin',
    'ausstieghin','zustiegrueck','ausstieg_rueck','sitzhin','sitzrueck',
    'leistungen','passnummer','ausgestellt_in','ausgestellt_am',
    'gueltig_bis','passinfo','passid','nation','geburtsort',
    'name1','name2','name3','namenszusatz','titel','email',
    'land','ort','ortsteil','plz','region','strasse',
    'telefon1','telefon2','telefon3','xkoord','ykoord',
    'heimatort','pass_name1','pass_name2','zusatzdaten'
  );
begin
  DoInsert('T_TEILNEHMER', ALLOWED);
end;

// Route: /incoming/updatet_teilnehmer  |  Auth: true  |  LocalOnly: false
procedure TDataModulIncoming.updateT_Teilnehmer;
// Body: { "nr": 42, "name": "...", ... }
const
  ALLOWED: array[0..56] of string = (
    'vorgangnr','anrede','name','kennziffer','geburtstag','jahre',
    'shuttle','info1','info2','ref1','ref2','gruppe','sitzfest',
    'hininfo','rueckinfo','ausstiegrueck','profil','status',
    'reservierungsnr','kabinengruppe','infofaehre','zustieghin',
    'ausstieghin','zustiegrueck','ausstieg_rueck','sitzhin','sitzrueck',
    'leistungen','passnummer','ausgestellt_in','ausgestellt_am',
    'gueltig_bis','passinfo','passid','nation','geburtsort',
    'name1','name2','name3','namenszusatz','titel','email',
    'land','ort','ortsteil','plz','region','strasse',
    'telefon1','telefon2','telefon3','xkoord','ykoord',
    'heimatort','pass_name1','pass_name2','zusatzdaten'
  );
begin
  DoUpdate('T_TEILNEHMER', ALLOWED, 'nr');
end;

// Route: /incoming/deletet_teilnehmer  |  Auth: true  |  LocalOnly: false
procedure TDataModulIncoming.deleteT_Teilnehmer;
// Body: { "nr": 42 }
begin
  DoDelete('T_TEILNEHMER', 'nr');
end;

// Route: /incoming/gett_teilnehmernextnr  |  Auth: true  |  LocalOnly: false
procedure TDataModulIncoming.getT_TeilnehmerNextNr;
begin
  Query.SQL.Text := 'SELECT GEN_ID(T_TEILNEHMER_NR_GEN,1) FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

end.

