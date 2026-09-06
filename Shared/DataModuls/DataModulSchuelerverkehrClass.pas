unit DataModulSchuelerverkehrClass;

interface

uses
  Web.HTTPApp,   System.JSON,
  DataModulTableBaseClass,
  System.SysUtils, System.Classes, DataModulBaseClass, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt, FireDAC.UI.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Phys, FireDAC.Phys.IB, FireDAC.Phys.IBDef, FireDAC.VCLUI.Wait, Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet;

type
  TDataModulSchuelerverkehr = class(TDataModulTableBase)
  private

    { Private-Deklarationen }
  public
    { Public-Deklarationen }
     procedure Demo;

     procedure getSV_Teilnehmer;
     procedure getSV_TeilnehmerFiltered;
     procedure getSV_TeilnehmerById;
  end;


function CreateDataModulSchuelerverkehr(Request: TWebRequest; Response: TWebResponse): TObject;

implementation
uses webutils;

function CreateDataModulSchuelerverkehr(Request: TWebRequest; Response: TWebResponse): TObject;
begin
  Result := TDataModulSchuelerverkehr.Create(Request, Response);
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


procedure TDataModulSchuelerverkehr.Demo;
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

// Route: /schuelerverkehr/getsv_teilnehmer  |  Auth: true  |  LocalOnly: false
procedure TDataModulSchuelerverkehr.getSV_Teilnehmer;
// Body: { "fields": ["Field1","Field2",...] | "*", "orderby": "Field" }
const
  ALLOWED: array[0..59] of string = (
    'nr','persnr','los','einrichtungnr_fk','kennziffer_fk','kostentraeger_fk','tourbereich','berufsverkehr',
    'anrede','vorname','nachname','strasse','land','plz','ort','ortsteil',
    'bezirk','email','xkoord','ykoord','haltepunktnr_fk','ansprech1','ansprech1_tel','ansprech2',
    'ansprech2_tel','hinweis','importhinweis1','rolli','einzelbefoerderung','begleitperson','begleitpersonname','hilfsmittel',
    'hilfsmittelhinweis','sv_fahrzeugprofil','abrechnungstarif_fk','gruppe','geburtstag','geprueft','inaktiv','erfasstvon',
    'erfasstam','geaendertvon','geaendertam','ansprech1_email','ansprech1_vorname','ansprech1_nachname','ansprech2_email','ansprech2_vorname',
    'ansprech2_nachname','pushid','pwd','datumfeld1','datumfeld2','datumfeld3','datumfeld4','textfeld1',
    'textfeld2','textfeld3','textfeld4','textfeld5'
  );
begin
  DoSelect('SV_TEILNEHMER', ALLOWED);
end;

// Route: /schuelerverkehr/getsv_teilnehmerfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulSchuelerverkehr.getSV_TeilnehmerFiltered;
// Body: { "fields": [...] | "*", "nachname": "Muster", "orderby": "nachname" }
// Alle Filter-Parameter sind optional – nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..59] of string = (
    'nr','persnr','los','einrichtungnr_fk','kennziffer_fk','kostentraeger_fk','tourbereich','berufsverkehr',
    'anrede','vorname','nachname','strasse','land','plz','ort','ortsteil',
    'bezirk','email','xkoord','ykoord','haltepunktnr_fk','ansprech1','ansprech1_tel','ansprech2',
    'ansprech2_tel','hinweis','importhinweis1','rolli','einzelbefoerderung','begleitperson','begleitpersonname','hilfsmittel',
    'hilfsmittelhinweis','sv_fahrzeugprofil','abrechnungstarif_fk','gruppe','geburtstag','geprueft','inaktiv','erfasstvon',
    'erfasstam','geaendertvon','geaendertam','ansprech1_email','ansprech1_vorname','ansprech1_nachname','ansprech2_email','ansprech2_vorname',
    'ansprech2_nachname','pushid','pwd','datumfeld1','datumfeld2','datumfeld3','datumfeld4','textfeld1',
    'textfeld2','textfeld3','textfeld4','textfeld5'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS übereinstimmen).
  CONDITIONS: array[0..59] of string = (
    'nr = :nr',
    'persnr = :persnr',
    'los = :los',
    'einrichtungnr_fk = :einrichtungnr_fk',
    'kennziffer_fk = :kennziffer_fk',
    'kostentraeger_fk = :kostentraeger_fk',
    'tourbereich = :tourbereich',
    'berufsverkehr = :berufsverkehr',
    'anrede = :anrede',
    'vorname = :vorname',
    'nachname = :nachname',
    'strasse = :strasse',
    'land = :land',
    'plz = :plz',
    'ort = :ort',
    'ortsteil = :ortsteil',
    'bezirk = :bezirk',
    'email = :email',
    'xkoord = :xkoord',
    'ykoord = :ykoord',
    'haltepunktnr_fk = :haltepunktnr_fk',
    'ansprech1 = :ansprech1',
    'ansprech1_tel = :ansprech1_tel',
    'ansprech2 = :ansprech2',
    'ansprech2_tel = :ansprech2_tel',
    'hinweis = :hinweis',
    'importhinweis1 = :importhinweis1',
    'rolli = :rolli',
    'einzelbefoerderung = :einzelbefoerderung',
    'begleitperson = :begleitperson',
    'begleitpersonname = :begleitpersonname',
    'hilfsmittel = :hilfsmittel',
    'hilfsmittelhinweis = :hilfsmittelhinweis',
    'sv_fahrzeugprofil = :sv_fahrzeugprofil',
    'abrechnungstarif_fk = :abrechnungstarif_fk',
    'gruppe = :gruppe',
    'geburtstag = :geburtstag',
    'geprueft = :geprueft',
    'inaktiv = :inaktiv',
    'erfasstvon = :erfasstvon',
    'erfasstam = :erfasstam',
    'geaendertvon = :geaendertvon',
    'geaendertam = :geaendertam',
    'ansprech1_email = :ansprech1_email',
    'ansprech1_vorname = :ansprech1_vorname',
    'ansprech1_nachname = :ansprech1_nachname',
    'ansprech2_email = :ansprech2_email',
    'ansprech2_vorname = :ansprech2_vorname',
    'ansprech2_nachname = :ansprech2_nachname',
    'pushid = :pushid',
    'pwd = :pwd',
    'datumfeld1 = :datumfeld1',
    'datumfeld2 = :datumfeld2',
    'datumfeld3 = :datumfeld3',
    'datumfeld4 = :datumfeld4',
    'textfeld1 = :textfeld1',
    'textfeld2 = :textfeld2',
    'textfeld3 = :textfeld3',
    'textfeld4 = :textfeld4',
    'textfeld5 = :textfeld5'
  );
  FILTER_PARAMS: array[0..59] of string = (
    'nr','persnr','los','einrichtungnr_fk','kennziffer_fk','kostentraeger_fk','tourbereich','berufsverkehr',
    'anrede','vorname','nachname','strasse','land','plz','ort','ortsteil',
    'bezirk','email','xkoord','ykoord','haltepunktnr_fk','ansprech1','ansprech1_tel','ansprech2',
    'ansprech2_tel','hinweis','importhinweis1','rolli','einzelbefoerderung','begleitperson','begleitpersonname','hilfsmittel',
    'hilfsmittelhinweis','sv_fahrzeugprofil','abrechnungstarif_fk','gruppe','geburtstag','geprueft','inaktiv','erfasstvon',
    'erfasstam','geaendertvon','geaendertam','ansprech1_email','ansprech1_vorname','ansprech1_nachname','ansprech2_email','ansprech2_vorname',
    'ansprech2_nachname','pushid','pwd','datumfeld1','datumfeld2','datumfeld3','datumfeld4','textfeld1',
    'textfeld2','textfeld3','textfeld4','textfeld5'
  );
begin
  DoSelectFilteredDynamic('SV_TEILNEHMER', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /schuelerverkehr/getsv_teilnehmerbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulSchuelerverkehr.getSV_TeilnehmerById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..59] of string = (
    'nr','persnr','los','einrichtungnr_fk','kennziffer_fk','kostentraeger_fk','tourbereich','berufsverkehr',
    'anrede','vorname','nachname','strasse','land','plz','ort','ortsteil',
    'bezirk','email','xkoord','ykoord','haltepunktnr_fk','ansprech1','ansprech1_tel','ansprech2',
    'ansprech2_tel','hinweis','importhinweis1','rolli','einzelbefoerderung','begleitperson','begleitpersonname','hilfsmittel',
    'hilfsmittelhinweis','sv_fahrzeugprofil','abrechnungstarif_fk','gruppe','geburtstag','geprueft','inaktiv','erfasstvon',
    'erfasstam','geaendertvon','geaendertam','ansprech1_email','ansprech1_vorname','ansprech1_nachname','ansprech2_email','ansprech2_vorname',
    'ansprech2_nachname','pushid','pwd','datumfeld1','datumfeld2','datumfeld3','datumfeld4','textfeld1',
    'textfeld2','textfeld3','textfeld4','textfeld5'
  );
begin
  DoSelectOne('SV_TEILNEHMER', ALLOWED, 'nr');
end;

end.
