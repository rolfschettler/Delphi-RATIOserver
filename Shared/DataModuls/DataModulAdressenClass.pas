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
    procedure getCodestabelle;
    procedure getCodestabelleFiltered;
    procedure getCodestabelleById;
    procedure getKonfiguration;
    procedure getKonfigurationFiltered;
    procedure getKonfigurationById;
    procedure getT_Konfiguration;
    procedure getT_KonfigurationFiltered;
    procedure getT_KonfigurationById;
    procedure getAdrtochter;
    procedure getAdrtochterFiltered;
    procedure getAdrtochterById;
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
  ALLOWED: array[0..14] of string = (
    'kennziffer','gruppe','anrede','titel','name1','name2','name3','namenszusatz',
    'strasse','plz','ort','telefon1','email','matchcode','lvorgang'
  );
begin
  DoSelect('ADRESSEN', ALLOWED);
end;

// Route: /getadressenfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getAdressenFiltered;
// Body: { "fields": [...] | "*", "gruppe": "K", "orderby": "name1" }
const
  ALLOWED: array[0..14] of string = (
    'kennziffer','gruppe','anrede','titel','name1','name2','name3','namenszusatz',
    'strasse','plz','ort','telefon1','email','matchcode','lvorgang'
  );
  // Alle Tabellenspalten sind optional filterbar -- ausgenommen Blob-Felder bemerkung, adressenbaum.
  CONDITIONS: array[0..186] of string = (
    'gruppe = :gruppe',
    'name1 = :name1',
    'name2 = :name2',
    'name3 = :name3',
    'namenszusatz = :namenszusatz',
    'strasse = :strasse',
    'ort = :ort',
    'email = :email',
    'kennziffer = :kennziffer',
    'code = :code',
    'anrede = :anrede',
    'titel = :titel',
    'land = :land',
    'plz = :plz',
    'ansprech = :ansprech',
    'briefanrede = :briefanrede',
    'ntermin = :ntermin',
    'lvorgang = :lvorgang',
    'lmailing = :lmailing',
    'bearbeitet = :bearbeitet',
    'kontostand = :kontostand',
    'rabatt = :rabatt',
    'skonto = :skonto',
    'provision1 = :provision1',
    'provision2 = :provision2',
    'provision3 = :provision3',
    'zahltage = :zahltage',
    'telefon1 = :telefon1',
    'telefon2 = :telefon2',
    'fax = :fax',
    'subadresse = :subadresse',
    'substrasse = :substrasse',
    'subland = :subland',
    'subplz = :subplz',
    'subort = :subort',
    'berechnung = :berechnung',
    'mahnkennung = :mahnkennung',
    'kreditlimit = :kreditlimit',
    'sammelrechnung = :sammelrechnung',
    'kdnreigen = :kdnreigen',
    'preisgruppe = :preisgruppe',
    'betreuer = :betreuer',
    'rechmpfaenger = :rechmpfaenger',
    'skonto2 = :skonto2',
    'skonto3 = :skonto3',
    'zahltage2 = :zahltage2',
    'zahltage3 = :zahltage3',
    'ustid = :ustid',
    'ustpflichtig = :ustpflichtig',
    'kat1 = :kat1',
    'kat2 = :kat2',
    'kat3 = :kat3',
    'kat4 = :kat4',
    'kat5 = :kat5',
    'kat6 = :kat6',
    'kat7 = :kat7',
    'kat8 = :kat8',
    'kat9 = :kat9',
    'kat10 = :kat10',
    'kat11 = :kat11',
    'kat12 = :kat12',
    'rename = :rename',
    'rename2 = :rename2',
    'reland = :reland',
    'replz = :replz',
    'restrasse = :restrasse',
    'reort = :reort',
    'erfasst_am = :erfasst_am',
    'datevkto = :datevkto',
    'zahlungsart = :zahlungsart',
    'zahlungper = :zahlungper',
    'matchcode = :matchcode',
    'gebtag = :gebtag',
    'gebmonat = :gebmonat',
    'gebjahr = :gebjahr',
    'geburtstag = :geburtstag',
    'zugriffe = :zugriffe',
    'phonetic = :phonetic',
    'vermittler = :vermittler',
    'vertreter = :vertreter',
    'status = :status',
    'gesperrt = :gesperrt',
    'bank = :bank',
    'blz = :blz',
    'ktonr = :ktonr',
    'inet = :inet',
    'textfeld1 = :textfeld1',
    'textfeld2 = :textfeld2',
    'textfeld3 = :textfeld3',
    'textfeld4 = :textfeld4',
    'textfeld5 = :textfeld5',
    'textfeld6 = :textfeld6',
    'textfeld7 = :textfeld7',
    'textfeld8 = :textfeld8',
    'datumfeld1 = :datumfeld1',
    'datumfeld2 = :datumfeld2',
    'hinweis = :hinweis',
    'region = :region',
    'lzugriff = :lzugriff',
    'bearbeitetvon = :bearbeitetvon',
    'lastlock = :lastlock',
    'erfasst_von = :erfasst_von',
    'geaendert_von = :geaendert_von',
    'iban = :iban',
    'swift = :swift',
    'iban2 = :iban2',
    'xkoord = :xkoord',
    'ykoord = :ykoord',
    'adrinfibu = :adrinfibu',
    'kundenart = :kundenart',
    'sammelkonto = :sammelkonto',
    'passnummer = :passnummer',
    'pass_gueltig_bis = :pass_gueltig_bis',
    'pass_aussgestelltin = :pass_aussgestelltin',
    'pass_aussgestelltam = :pass_aussgestelltam',
    'pass_info = :pass_info',
    'nation = :nation',
    'uebertragung = :uebertragung',
    'kontoinhaber = :kontoinhaber',
    'iban3 = :iban3',
    'strasse2 = :strasse2',
    'referenznr = :referenznr',
    'geburtsort = :geburtsort',
    'freigabe = :freigabe',
    'adresszeile1 = :adresszeile1',
    'adresszeile2 = :adresszeile2',
    'adresszeile3 = :adresszeile3',
    'ort2 = :ort2',
    'newsletter = :newsletter',
    'einverstaendnis__erhalten_am = :einverstaendnis__erhalten_am',
    'namenszusatz2 = :namenszusatz2',
    'dse_am = :dse_am',
    'dse_per = :dse_per',
    'textfeld9 = :textfeld9',
    'textfeld10 = :textfeld10',
    'textfeld11 = :textfeld11',
    'textfeld12 = :textfeld12',
    'textfeld13 = :textfeld13',
    'textfeld14 = :textfeld14',
    'textfeld15 = :textfeld15',
    'textfeld16 = :textfeld16',
    'textfeld17 = :textfeld17',
    'textfeld18 = :textfeld18',
    'datumfeld3 = :datumfeld3',
    'datumfeld4 = :datumfeld4',
    'anschrift = :anschrift',
    'teilnehmerinfo1 = :teilnehmerinfo1',
    'teilnehmerinfo2 = :teilnehmerinfo2',
    'dsgvo1 = :dsgvo1',
    'dsgvo2 = :dsgvo2',
    'dsgvo3 = :dsgvo3',
    'dsgvo4 = :dsgvo4',
    'dsgvo5 = :dsgvo5',
    'dsgvo6 = :dsgvo6',
    'dsgvo_lock = :dsgvo_lock',
    'dsgvo_letzte_pruefung = :dsgvo_letzte_pruefung',
    'leitid = :leitid',
    'passid = :passid',
    'haltnr = :haltnr',
    'haltnr_tages = :haltnr_tages',
    'ortsteil = :ortsteil',
    'versandart = :versandart',
    'kat13 = :kat13',
    'kat14 = :kat14',
    'kat15 = :kat15',
    'kat16 = :kat16',
    'kat17 = :kat17',
    'kat18 = :kat18',
    'kat19 = :kat19',
    'kat20 = :kat20',
    'kat21 = :kat21',
    'kat22 = :kat22',
    'kat23 = :kat23',
    'kat24 = :kat24',
    'tourkuerzel_kostentraeger = :tourkuerzel_kostentraeger',
    'telefon3 = :telefon3',
    'heimatort = :heimatort',
    'pass_name1 = :pass_name1',
    'pass_name2 = :pass_name2',
    'steuernummer = :steuernummer',
    'mandant = :mandant',
    'ustid_absender = :ustid_absender',
    'rechemail = :rechemail',
    'rechnamenszusatz = :rechnamenszusatz',
    'hr_nummer = :hr_nummer',
    'hr_registergericht = :hr_registergericht',
    'erechnung_format = :erechnung_format'
  );
  FILTER_PARAMS: array[0..186] of string = (
    'gruppe','name1','name2','name3','namenszusatz','strasse',
    'ort','email','kennziffer','code','anrede','titel',
    'land','plz','ansprech','briefanrede','ntermin','lvorgang',
    'lmailing','bearbeitet','kontostand','rabatt','skonto','provision1',
    'provision2','provision3','zahltage','telefon1','telefon2','fax',
    'subadresse','substrasse','subland','subplz','subort','berechnung',
    'mahnkennung','kreditlimit','sammelrechnung','kdnreigen','preisgruppe','betreuer',
    'rechmpfaenger','skonto2','skonto3','zahltage2','zahltage3','ustid',
    'ustpflichtig','kat1','kat2','kat3','kat4','kat5',
    'kat6','kat7','kat8','kat9','kat10','kat11',
    'kat12','rename','rename2','reland','replz','restrasse',
    'reort','erfasst_am','datevkto','zahlungsart','zahlungper','matchcode',
    'gebtag','gebmonat','gebjahr','geburtstag','zugriffe','phonetic',
    'vermittler','vertreter','status','gesperrt','bank','blz',
    'ktonr','inet','textfeld1','textfeld2','textfeld3','textfeld4',
    'textfeld5','textfeld6','textfeld7','textfeld8','datumfeld1','datumfeld2',
    'hinweis','region','lzugriff','bearbeitetvon','lastlock','erfasst_von',
    'geaendert_von','iban','swift','iban2','xkoord','ykoord',
    'adrinfibu','kundenart','sammelkonto','passnummer','pass_gueltig_bis','pass_aussgestelltin',
    'pass_aussgestelltam','pass_info','nation','uebertragung','kontoinhaber','iban3',
    'strasse2','referenznr','geburtsort','freigabe','adresszeile1','adresszeile2',
    'adresszeile3','ort2','newsletter','einverstaendnis__erhalten_am','namenszusatz2','dse_am',
    'dse_per','textfeld9','textfeld10','textfeld11','textfeld12','textfeld13',
    'textfeld14','textfeld15','textfeld16','textfeld17','textfeld18','datumfeld3',
    'datumfeld4','anschrift','teilnehmerinfo1','teilnehmerinfo2','dsgvo1','dsgvo2',
    'dsgvo3','dsgvo4','dsgvo5','dsgvo6','dsgvo_lock','dsgvo_letzte_pruefung',
    'leitid','passid','haltnr','haltnr_tages','ortsteil','versandart',
    'kat13','kat14','kat15','kat16','kat17','kat18',
    'kat19','kat20','kat21','kat22','kat23','kat24',
    'tourkuerzel_kostentraeger','telefon3','heimatort','pass_name1','pass_name2','steuernummer',
    'mandant',
    'ustid_absender', 'rechemail', 'rechnamenszusatz', 'hr_nummer', 'hr_registergericht', 'erechnung_format'
  );
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
  ALLOWED: array[0..12] of string = (
    'kennziffer','gruppe','anrede','titel','name1','name2','name3','namenszusatz',
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

// Route: /adressen/getcodestabelle  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getCodestabelle;
// Body: { "fields": ["nr","bezeichnung",...] | "*", "orderby": "bezeichnung" }
const
  ALLOWED: array[0..3] of string = (
    'nr','bezeichnung','code','bereich'
  );
begin
  DoSelect('CODESTABELLE', ALLOWED);
end;

// Route: /adressen/getcodestabellefiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getCodestabelleFiltered;
// Body: { "fields": [...] | "*", "nr": 1, "bezeichnung": "...", "code": "...", "bereich": "...", "orderby": "bezeichnung" }
// Alle Filter-Parameter sind optional - nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..3] of string = (
    'nr','bezeichnung','code','bereich'
  );
  CONDITIONS: array[0..3] of string = (
    'nr = :nr',
    'bezeichnung = :bezeichnung',
    'code = :code',
    'bereich = :bereich'
  );
  FILTER_PARAMS: array[0..3] of string = ('nr','bezeichnung','code','bereich');
begin
  DoSelectFilteredDynamic('CODESTABELLE', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /adressen/getcodestabellebyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getCodestabelleById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..3] of string = (
    'nr','bezeichnung','code','bereich'
  );
begin
  DoSelectOne('CODESTABELLE', ALLOWED, 'nr');
end;

// Route: /adressen/getkonfiguration  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getKonfiguration;
// Body: { "fields": ["nr","name",...] | "*", "orderby": "name" }
const
  ALLOWED: array[0..5] of string = (
    'nr','name','art','id','content','art2'
  );
begin
  DoSelect('KONFIGURATION', ALLOWED);
end;

// Route: /adressen/getkonfigurationfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getKonfigurationFiltered;
// Body: { "fields": [...] | "*", "nr": 1, "name": "...", "art": "...", "id": 1, "art2": "...", "orderby": "name" }
// Alle Filter-Parameter sind optional - nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
// content ist ein Blob-Feld und daher nur in ALLOWED, nicht in CONDITIONS/FILTER_PARAMS.
const
  ALLOWED: array[0..5] of string = (
    'nr','name','art','id','content','art2'
  );
  CONDITIONS: array[0..4] of string = (
    'nr = :nr',
    'name = :name',
    'art = :art',
    'id = :id',
    'art2 = :art2'
  );
  FILTER_PARAMS: array[0..4] of string = ('nr','name','art','id','art2');
begin
  DoSelectFilteredDynamic('KONFIGURATION', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /adressen/getkonfigurationbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getKonfigurationById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..5] of string = (
    'nr','name','art','id','content','art2'
  );
begin
  DoSelectOne('KONFIGURATION', ALLOWED, 'nr');
end;

// Route: /adressen/gett_konfiguration  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getT_Konfiguration;
// Body: { "fields": ["nr","bezeichnung",...] | "*", "orderby": "bezeichnung" }
const
  ALLOWED: array[0..8] of string = (
    'nr','bezeichnung','wert','werttyp','kategorie','bereich','vorgabe','bereich2','beschreibung'
  );
begin
  DoSelect('T_KONFIGURATION', ALLOWED);
end;

// Route: /adressen/gett_konfigurationfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getT_KonfigurationFiltered;
// Body: { "fields": [...] | "*", "nr": 1, "bezeichnung": "...", "wert": "...", "werttyp": "...",
//         "kategorie": "...", "bereich": "...", "vorgabe": "...", "bereich2": "...",
//         "beschreibung": "...", "orderby": "bezeichnung" }
// Alle Filter-Parameter sind optional – nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..8] of string = (
    'nr','bezeichnung','wert','werttyp','kategorie','bereich','vorgabe','bereich2','beschreibung'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS übereinstimmen).
  CONDITIONS: array[0..8] of string = (
    'nr = :nr',
    'bezeichnung = :bezeichnung',
    'wert = :wert',
    'werttyp = :werttyp',
    'kategorie = :kategorie',
    'bereich = :bereich',
    'vorgabe = :vorgabe',
    'bereich2 = :bereich2',
    'beschreibung = :beschreibung'
  );
  FILTER_PARAMS: array[0..8] of string = (
    'nr','bezeichnung','wert','werttyp','kategorie','bereich','vorgabe','bereich2','beschreibung'
  );
begin
  DoSelectFilteredDynamic('T_KONFIGURATION', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /adressen/gett_konfigurationbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getT_KonfigurationById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..8] of string = (
    'nr','bezeichnung','wert','werttyp','kategorie','bereich','vorgabe','bereich2','beschreibung'
  );
begin
  DoSelectOne('T_KONFIGURATION', ALLOWED, 'nr');
end;

// Route: /adressen/getadrtochter  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getAdrtochter;
// Body: { "fields": ["nr","hauptadresse",...] | "*", "orderby": "nr" }
const
  ALLOWED: array[0..3] of string = (
    'nr','hauptadresse','kennziffer','bemerkung'
  );
begin
  DoSelect('ADRTOCHTER', ALLOWED);
end;

// Route: /adressen/getadrtochterfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getAdrtochterFiltered;
// Body: { "fields": [...] | "*", "nr": 1, "hauptadresse": 1, "kennziffer": 1,
//         "bemerkung": "...", "orderby": "nr" }
// Alle Filter-Parameter sind optional – nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..3] of string = (
    'nr','hauptadresse','kennziffer','bemerkung'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS übereinstimmen).
  CONDITIONS: array[0..3] of string = (
    'nr = :nr',
    'hauptadresse = :hauptadresse',
    'kennziffer = :kennziffer',
    'bemerkung = :bemerkung'
  );
  FILTER_PARAMS: array[0..3] of string = (
    'nr','hauptadresse','kennziffer','bemerkung'
  );
begin
  DoSelectFilteredDynamic('ADRTOCHTER', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /adressen/getadrtochterbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getAdrtochterById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..3] of string = (
    'nr','hauptadresse','kennziffer','bemerkung'
  );
begin
  DoSelectOne('ADRTOCHTER', ALLOWED, 'nr');
end;

end.
