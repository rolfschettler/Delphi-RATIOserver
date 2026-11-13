unit DataModulToupacClass;

interface

uses
  Web.HTTPApp,   System.JSON,
  DataModulTableBaseClass,
  System.SysUtils, System.Classes, DataModulBaseClass, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt, FireDAC.UI.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Phys, FireDAC.Phys.IB, FireDAC.Phys.IBDef, FireDAC.VCLUI.Wait, Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet;

type
  TDataModulToupac = class(TDataModulTableBase)
  private

    { Private-Deklarationen }
  public
    { Public-Deklarationen }
     procedure Demo;
     procedure getT_Vorgang;
     procedure getT_VorgangFiltered;
     procedure getT_VorgangById;
     procedure getT_VorgangKey;
     procedure insertT_Vorgang;
     procedure updateT_Vorgang;
     procedure deleteT_Vorgang;
     procedure getF_Fahrtauftrag;
     procedure getF_FahrtauftragFiltered;
     procedure getF_FahrtauftragById;
     procedure getF_FahrtauftragKey;
     procedure insertF_Fahrtauftrag;
     procedure updateF_Fahrtauftrag;
     procedure deleteF_Fahrtauftrag;
     procedure getT_Kalender;
     procedure getT_KalenderFiltered;
     procedure getT_KalenderById;
     procedure getT_KalenderKey;
     procedure insertT_Kalender;
     procedure updateT_Kalender;
     procedure deleteT_Kalender;
     procedure getT_Positionen;
     procedure getT_PositionenFiltered;
     procedure getT_PositionenById;
     procedure getT_Ticketdaten;
     procedure getT_TicketdatenFiltered;
     procedure getT_TicketdatenById;
     procedure getT_Ltraeger;
     procedure getT_LtraegerFiltered;
     procedure getT_LtraegerById;
     procedure getT_LtraegerKey;
     procedure insertT_Ltraeger;
     procedure updateT_Ltraeger;
     procedure deleteT_Ltraeger;
     procedure getT_Katalogreise;
     procedure getT_KatalogreiseFiltered;
     procedure getT_KatalogreiseById;
     procedure getT_KatalogreiseKey;
     procedure insertT_Katalogreise;
     procedure updateT_Katalogreise;
     procedure getT_Reise;
     procedure getT_ReiseFiltered;
     procedure getT_ReiseById;
     procedure getT_ReiseKey;
     procedure insertT_Reise;
     procedure updateT_Reise;
     procedure getT_Reiseleistungen;
     procedure getT_ReiseleistungenFiltered;
     procedure getT_ReiseleistungenById;
     procedure getT_ReiseleistungenKey;
     procedure insertT_Reiseleistungen;
     procedure updateT_Reiseleistungen;
     procedure deleteT_Reiseleistungen;
     procedure getT_Leistung;
     procedure getT_LeistungFiltered;
     procedure getT_LeistungById;
     procedure getT_LeistungKey;
     procedure insertT_Leistung;
     procedure updateT_Leistung;
     procedure deleteT_Leistung;
     procedure getT_Termine;
     procedure getT_TermineFiltered;
     procedure getT_TermineById;
     procedure getT_TermineKey;
     procedure insertT_Termine;
     procedure updateT_Termine;
     procedure deleteT_Termine;
     procedure getT_Reisedetail;
     procedure getT_ReisedetailFiltered;
     procedure getT_ReisedetailById;
     procedure getT_ReisedetailKey;
     procedure insertT_Reisedetail;
     procedure updateT_Reisedetail;
     procedure deleteT_Reisedetail;
  end;


function CreateDataModulToupac(Request: TWebRequest; Response: TWebResponse): TObject;

implementation
uses webutils;

function CreateDataModulToupac(Request: TWebRequest; Response: TWebResponse): TObject;
begin
  Result := TDataModulToupac.Create(Request, Response);
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
    URL     : http://localhost:<port>/ibapi/toupac/demo?id=42&filter=Mueller
    Header  : Authorization: Bearer <JWT-Token>     (Route verlangt Auth)
              Content-Type : application/json
    Body    : (raw / JSON, optional)
              { "name": "Helga", "menge": 5 }

    Test-Kombinationen:
      - nur URL   : POST /toupac/demo?id=42&filter=Mueller   (Body leer lassen)
      - nur Body  : POST /toupac/demo   Body { "name":"Helga","menge":5 }
      - gemischt  : beide Quellen gleichzeitig
      - nichts    : POST /toupac/demo ohne Parameter -> alle Felder als null
    Fehlende Werte erzeugen KEINEN Fehler, sondern erscheinen im Ergebnis als null.
  ----------------------------------------------------------------------------

  *)


procedure TDataModulToupac.Demo;
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
  idText    := Trim(Request.QueryFields.Values['id']);
  idGesetzt := idText <> '';
  id        := StrToIntDef(idText, 0);

  filter := Trim(Request.QueryFields.Values['filter']);

  // ===== 2) Parameter aus dem JSON-Body =====
  // Fuer JEDEN Body-Parameter dasselbe Muster:
  //   isParamFromBody('x')  -> ist 'x' im Body vorhanden?
  //   getParamFromBody('x') -> sein Wert (kommt immer als String)
  // Der Body wird intern einmal geparst und automatisch freigegeben:
  // kein ParseJSONObject, kein try/finally, kein Leak.

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
  Ergebnis.AddPair('url',  UrlObj);
  Ergebnis.AddPair('body', BodyObj);
  SendJson(Ergebnis);
end;





// Route: /toupac/gett_vorgang  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_Vorgang;
// Body: { "fields": ["nr","vorgangsnr",...] | "*", "orderby": "nr" }
const
  ALLOWED: array[0..80] of string = (
    'nr','agenturnr','buchender','vorgangsnr','erstellt','geaendert','personen',
    'datum_von','datum_bis','endpreis','status','agenturcode','katalogreisenr',
    'reisebezeichnung','optionsdatum','expedient','bemerkung','fibukontokunde',
    'fibukontoagentur','sachkontoreise','buchungsdatum','faelligam','veranstalter',
    'sammelrechnung','nrkreis','rechnungsnr','stand','direktinkasso','anzahlung',
    'anzfaelligam','erstelltvon','geaendertvon','ansprechpartner','entstehung',
    'bereich','zusatzinfo','reisegruppe','zahlungsart','ausreise','kontaktentstehung',
    'reiseart','ziel','filiale','zugeordnetzu','abteilung','hauptkategorie',
    'vgedruckt','bgedruckt','auftrag_erteilt_am','auftrag_erteilt_von','stornogrund',
    'lastmaxstatus','sammelrechnungnr','originalreisedatum','terminnr','terminnr_rueck',
    'knotenhin','knotenrueck','statusinfo','vorgangsstatus','vertretung','lastgeaendert',
    'fibu_archiv_am','stornodatum','aufteilung','abrechnungsart','hotelkategorie',
    'versandart','unterschrift','untertitel','app','festbuchung_am','schnittstelle_sendtime',
    'sprache','aktion','bank','externe_nummer','rechnungsart','stornotermin',
    'vk_waehrung','mandant'
  );
begin
  DoSelect('T_VORGANG', ALLOWED);
end;

// Route: /toupac/gett_vorgangfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_VorgangFiltered;
// Body: { "fields": [...] | "*", "agenturnr": 42, "orderby": "nr" }
const
  ALLOWED: array[0..80] of string = (
    'nr','agenturnr','buchender','vorgangsnr','erstellt','geaendert','personen',
    'datum_von','datum_bis','endpreis','status','agenturcode','katalogreisenr',
    'reisebezeichnung','optionsdatum','expedient','bemerkung','fibukontokunde',
    'fibukontoagentur','sachkontoreise','buchungsdatum','faelligam','veranstalter',
    'sammelrechnung','nrkreis','rechnungsnr','stand','direktinkasso','anzahlung',
    'anzfaelligam','erstelltvon','geaendertvon','ansprechpartner','entstehung',
    'bereich','zusatzinfo','reisegruppe','zahlungsart','ausreise','kontaktentstehung',
    'reiseart','ziel','filiale','zugeordnetzu','abteilung','hauptkategorie',
    'vgedruckt','bgedruckt','auftrag_erteilt_am','auftrag_erteilt_von','stornogrund',
    'lastmaxstatus','sammelrechnungnr','originalreisedatum','terminnr','terminnr_rueck',
    'knotenhin','knotenrueck','statusinfo','vorgangsstatus','vertretung','lastgeaendert',
    'fibu_archiv_am','stornodatum','aufteilung','abrechnungsart','hotelkategorie',
    'versandart','unterschrift','untertitel','app','festbuchung_am','schnittstelle_sendtime',
    'sprache','aktion','bank','externe_nummer','rechnungsart','stornotermin',
    'vk_waehrung','mandant'
  );
  // Alle Tabellenspalten sind optional filterbar -- ausgenommen Blob-Felder bemerkung, unterschrift.
  CONDITIONS: array[0..93] of string = (
    'agenturnr = :agenturnr',
    'ansprechpartner = :ansprechpartner',
    'buchender = :buchender',
    'vorgangsnr = :vorgangsnr',
    'nr = :nr',
    'erstellt = :erstellt',
    'geaendert = :geaendert',
    'personen = :personen',
    'datum_von = :datum_von',
    'datum_bis = :datum_bis',
    'endpreis = :endpreis',
    'status = :status',
    'agenturcode = :agenturcode',
    'katalogreisenr = :katalogreisenr',
    'reisebezeichnung = :reisebezeichnung',
    'optionsdatum = :optionsdatum',
    'expedient = :expedient',
    'fibukontokunde = :fibukontokunde',
    'fibukontoagentur = :fibukontoagentur',
    'sachkontoreise = :sachkontoreise',
    'buchungsdatum = :buchungsdatum',
    'faelligam = :faelligam',
    'veranstalter = :veranstalter',
    'sammelrechnung = :sammelrechnung',
    'nrkreis = :nrkreis',
    'rechnungsnr = :rechnungsnr',
    'stand = :stand',
    'direktinkasso = :direktinkasso',
    'anzahlung = :anzahlung',
    'anzfaelligam = :anzfaelligam',
    'erstelltvon = :erstelltvon',
    'geaendertvon = :geaendertvon',
    'entstehung = :entstehung',
    'bereich = :bereich',
    'zusatzinfo = :zusatzinfo',
    'reisegruppe = :reisegruppe',
    'zahlungsart = :zahlungsart',
    'ausreise = :ausreise',
    'kontaktentstehung = :kontaktentstehung',
    'reiseart = :reiseart',
    'ziel = :ziel',
    'filiale = :filiale',
    'zugeordnetzu = :zugeordnetzu',
    'abteilung = :abteilung',
    'hauptkategorie = :hauptkategorie',
    'vgedruckt = :vgedruckt',
    'bgedruckt = :bgedruckt',
    'auftrag_erteilt_am = :auftrag_erteilt_am',
    'auftrag_erteilt_von = :auftrag_erteilt_von',
    'stornogrund = :stornogrund',
    'lastmaxstatus = :lastmaxstatus',
    'sammelrechnungnr = :sammelrechnungnr',
    'originalreisedatum = :originalreisedatum',
    'terminnr = :terminnr',
    'terminnr_rueck = :terminnr_rueck',
    'knotenhin = :knotenhin',
    'knotenrueck = :knotenrueck',
    'statusinfo = :statusinfo',
    'vorgangsstatus = :vorgangsstatus',
    'vertretung = :vertretung',
    'lastgeaendert = :lastgeaendert',
    'fibu_archiv_am = :fibu_archiv_am',
    'stornodatum = :stornodatum',
    'aufteilung = :aufteilung',
    'abrechnungsart = :abrechnungsart',
    'hotelkategorie = :hotelkategorie',
    'versandart = :versandart',
    'untertitel = :untertitel',
    'app = :app',
    'festbuchung_am = :festbuchung_am',
    'schnittstelle_sendtime = :schnittstelle_sendtime',
    'sprache = :sprache',
    'aktion = :aktion',
    'bank = :bank',
    'externe_nummer = :externe_nummer',
    'rechnungsart = :rechnungsart',
    'stornotermin = :stornotermin',
    'vk_waehrung = :vk_waehrung',
    'mandant = :mandant',
    'logo = :logo',
    'anrede = :anrede',
    'titel = :titel',
    'name1 = :name1',
    'name2 = :name2',
    'namenszusatz = :namenszusatz',
    'name3 = :name3',
    'strasse = :strasse',
    'land = :land',
    'plz = :plz',
    'ort = :ort',
    'telefon = :telefon',
    'email = :email',
    'registrierung_nr = :registrierung_nr',
    'gastbuchung = :gastbuchung'
  );
  FILTER_PARAMS: array[0..93] of string = (
    'agenturnr','ansprechpartner','buchender','vorgangsnr','nr','erstellt',
    'geaendert','personen','datum_von','datum_bis','endpreis','status',
    'agenturcode','katalogreisenr','reisebezeichnung','optionsdatum','expedient','fibukontokunde',
    'fibukontoagentur','sachkontoreise','buchungsdatum','faelligam','veranstalter','sammelrechnung',
    'nrkreis','rechnungsnr','stand','direktinkasso','anzahlung','anzfaelligam',
    'erstelltvon','geaendertvon','entstehung','bereich','zusatzinfo','reisegruppe',
    'zahlungsart','ausreise','kontaktentstehung','reiseart','ziel','filiale',
    'zugeordnetzu','abteilung','hauptkategorie','vgedruckt','bgedruckt','auftrag_erteilt_am',
    'auftrag_erteilt_von','stornogrund','lastmaxstatus','sammelrechnungnr','originalreisedatum','terminnr',
    'terminnr_rueck','knotenhin','knotenrueck','statusinfo','vorgangsstatus','vertretung',
    'lastgeaendert','fibu_archiv_am','stornodatum','aufteilung','abrechnungsart','hotelkategorie',
    'versandart','untertitel','app','festbuchung_am','schnittstelle_sendtime','sprache',
    'aktion','bank','externe_nummer','rechnungsart','stornotermin','vk_waehrung',
    'mandant',
    'logo', 'anrede', 'titel', 'name1', 'name2', 'namenszusatz',
    'name3', 'strasse', 'land', 'plz', 'ort', 'telefon',
    'email', 'registrierung_nr', 'gastbuchung'
  );
begin
  DoSelectFilteredDynamic('T_VORGANG', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /toupac/gett_vorgangbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_VorgangById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..80] of string = (
    'nr','agenturnr','buchender','vorgangsnr','erstellt','geaendert','personen',
    'datum_von','datum_bis','endpreis','status','agenturcode','katalogreisenr',
    'reisebezeichnung','optionsdatum','expedient','bemerkung','fibukontokunde',
    'fibukontoagentur','sachkontoreise','buchungsdatum','faelligam','veranstalter',
    'sammelrechnung','nrkreis','rechnungsnr','stand','direktinkasso','anzahlung',
    'anzfaelligam','erstelltvon','geaendertvon','ansprechpartner','entstehung',
    'bereich','zusatzinfo','reisegruppe','zahlungsart','ausreise','kontaktentstehung',
    'reiseart','ziel','filiale','zugeordnetzu','abteilung','hauptkategorie',
    'vgedruckt','bgedruckt','auftrag_erteilt_am','auftrag_erteilt_von','stornogrund',
    'lastmaxstatus','sammelrechnungnr','originalreisedatum','terminnr','terminnr_rueck',
    'knotenhin','knotenrueck','statusinfo','vorgangsstatus','vertretung','lastgeaendert',
    'fibu_archiv_am','stornodatum','aufteilung','abrechnungsart','hotelkategorie',
    'versandart','unterschrift','untertitel','app','festbuchung_am','schnittstelle_sendtime',
    'sprache','aktion','bank','externe_nummer','rechnungsart','stornotermin',
    'vk_waehrung','mandant'
  );
begin
  DoSelectOne('T_VORGANG', ALLOWED, 'nr');
end;

// Route: /toupac/gett_vorgangkey  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_VorgangKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(T_VORGANG_NR_GEN,1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /toupac/insertt_vorgang  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.insertT_Vorgang;
// Body: { "nr": 1, "agenturnr": 1, "vorgangsnr": "...", ... }
const
  ALLOWED: array[0..80] of string = (
    'nr','agenturnr','buchender','vorgangsnr','erstellt','geaendert','personen',
    'datum_von','datum_bis','endpreis','status','agenturcode','katalogreisenr',
    'reisebezeichnung','optionsdatum','expedient','bemerkung','fibukontokunde',
    'fibukontoagentur','sachkontoreise','buchungsdatum','faelligam','veranstalter',
    'sammelrechnung','nrkreis','rechnungsnr','stand','direktinkasso','anzahlung',
    'anzfaelligam','erstelltvon','geaendertvon','ansprechpartner','entstehung',
    'bereich','zusatzinfo','reisegruppe','zahlungsart','ausreise','kontaktentstehung',
    'reiseart','ziel','filiale','zugeordnetzu','abteilung','hauptkategorie',
    'vgedruckt','bgedruckt','auftrag_erteilt_am','auftrag_erteilt_von','stornogrund',
    'lastmaxstatus','sammelrechnungnr','originalreisedatum','terminnr','terminnr_rueck',
    'knotenhin','knotenrueck','statusinfo','vorgangsstatus','vertretung','lastgeaendert',
    'fibu_archiv_am','stornodatum','aufteilung','abrechnungsart','hotelkategorie',
    'versandart','unterschrift','untertitel','app','festbuchung_am','schnittstelle_sendtime',
    'sprache','aktion','bank','externe_nummer','rechnungsart','stornotermin',
    'vk_waehrung','mandant'
  );
begin
  DoInsert('T_VORGANG', ALLOWED);
end;

// Route: /toupac/updatet_vorgang  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.updateT_Vorgang;
// Body: { "nr": 42, "agenturnr": 1, "vorgangsnr": "...", ... }
const
  ALLOWED: array[0..79] of string = (
    'agenturnr','buchender','vorgangsnr','erstellt','geaendert','personen',
    'datum_von','datum_bis','endpreis','status','agenturcode','katalogreisenr',
    'reisebezeichnung','optionsdatum','expedient','bemerkung','fibukontokunde',
    'fibukontoagentur','sachkontoreise','buchungsdatum','faelligam','veranstalter',
    'sammelrechnung','nrkreis','rechnungsnr','stand','direktinkasso','anzahlung',
    'anzfaelligam','erstelltvon','geaendertvon','ansprechpartner','entstehung',
    'bereich','zusatzinfo','reisegruppe','zahlungsart','ausreise','kontaktentstehung',
    'reiseart','ziel','filiale','zugeordnetzu','abteilung','hauptkategorie',
    'vgedruckt','bgedruckt','auftrag_erteilt_am','auftrag_erteilt_von','stornogrund',
    'lastmaxstatus','sammelrechnungnr','originalreisedatum','terminnr','terminnr_rueck',
    'knotenhin','knotenrueck','statusinfo','vorgangsstatus','vertretung','lastgeaendert',
    'fibu_archiv_am','stornodatum','aufteilung','abrechnungsart','hotelkategorie',
    'versandart','unterschrift','untertitel','app','festbuchung_am','schnittstelle_sendtime',
    'sprache','aktion','bank','externe_nummer','rechnungsart','stornotermin',
    'vk_waehrung','mandant'
  );
begin
  DoUpdate('T_VORGANG', ALLOWED, 'nr');
end;

// Route: /toupac/deletet_vorgang  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.deleteT_Vorgang;
// Body: { "nr": 42 }
begin
  DoDelete('T_VORGANG', 'nr');
end;

// Route: /toupac/getf_fahrtauftrag  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getF_Fahrtauftrag;
// Body: { "fields": ["nr","fahrtnr",...] | "*", "orderby": "nr" }
const
  ALLOWED: array[0..20] of string = (
    'nr','fahrtnr','einsatznr','fahrtabrechnungsnr','fahrtenbuchnr','auftragsart',
    'personenzahl','fahrzeugprofil','fahrerprofil','status','filiale','gedruckt',
    'erledigt','angelegt_am','geaendert_am','erstelltvon','geaendertvon',
    'zusatzinfo','fahrtenplan','reftable','refnr'
  );
begin
  DoSelect('F_FAHRTAUFTRAG', ALLOWED);
end;

// Route: /toupac/getf_fahrtauftragfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getF_FahrtauftragFiltered;
// Body: { "fields": [...] | "*", "einsatznr": 42, "orderby": "nr" }
const
  ALLOWED: array[0..20] of string = (
    'nr','fahrtnr','einsatznr','fahrtabrechnungsnr','fahrtenbuchnr','auftragsart',
    'personenzahl','fahrzeugprofil','fahrerprofil','status','filiale','gedruckt',
    'erledigt','angelegt_am','geaendert_am','erstelltvon','geaendertvon',
    'zusatzinfo','fahrtenplan','reftable','refnr'
  );
  // Alle Tabellenspalten sind optional filterbar -- ausgenommen Blob-Felder fahrzeugprofil, fahrerprofil, zusatzinfo, fahrtenplan.
  CONDITIONS: array[0..17] of string = (
    'einsatznr = :einsatznr',
    'nr = :nr',
    'fahrtnr = :fahrtnr',
    'fahrtabrechnungsnr = :fahrtabrechnungsnr',
    'fahrtenbuchnr = :fahrtenbuchnr',
    'auftragsart = :auftragsart',
    'personenzahl = :personenzahl',
    'status = :status',
    'filiale = :filiale',
    'gedruckt = :gedruckt',
    'erledigt = :erledigt',
    'angelegt_am = :angelegt_am',
    'geaendert_am = :geaendert_am',
    'erstelltvon = :erstelltvon',
    'geaendertvon = :geaendertvon',
    'reftable = :reftable',
    'refnr = :refnr',
    'logo = :logo'
  );
  FILTER_PARAMS: array[0..17] of string = (
    'einsatznr','nr','fahrtnr','fahrtabrechnungsnr','fahrtenbuchnr','auftragsart',
    'personenzahl','status','filiale','gedruckt','erledigt','angelegt_am',
    'geaendert_am','erstelltvon','geaendertvon','reftable','refnr',
    'logo'
  );
begin
  DoSelectFilteredDynamic('F_FAHRTAUFTRAG', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /toupac/getf_fahrtauftragbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getF_FahrtauftragById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..20] of string = (
    'nr','fahrtnr','einsatznr','fahrtabrechnungsnr','fahrtenbuchnr','auftragsart',
    'personenzahl','fahrzeugprofil','fahrerprofil','status','filiale','gedruckt',
    'erledigt','angelegt_am','geaendert_am','erstelltvon','geaendertvon',
    'zusatzinfo','fahrtenplan','reftable','refnr'
  );
begin
  DoSelectOne('F_FAHRTAUFTRAG', ALLOWED, 'nr');
end;

// Route: /toupac/getf_fahrtauftragkey  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getF_FahrtauftragKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(F_FAHRTAUFTRAG_NR_GEN,1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /toupac/insertf_fahrtauftrag  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.insertF_Fahrtauftrag;
// Body: { "nr": 1, "fahrtnr": "...", "einsatznr": 1, ... }
const
  ALLOWED: array[0..20] of string = (
    'nr','fahrtnr','einsatznr','fahrtabrechnungsnr','fahrtenbuchnr','auftragsart',
    'personenzahl','fahrzeugprofil','fahrerprofil','status','filiale','gedruckt',
    'erledigt','angelegt_am','geaendert_am','erstelltvon','geaendertvon',
    'zusatzinfo','fahrtenplan','reftable','refnr'
  );
begin
  DoInsert('F_FAHRTAUFTRAG', ALLOWED);
end;

// Route: /toupac/updatef_fahrtauftrag  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.updateF_Fahrtauftrag;
// Body: { "nr": 42, "fahrtnr": "...", "einsatznr": 1, ... }
const
  ALLOWED: array[0..19] of string = (
    'fahrtnr','einsatznr','fahrtabrechnungsnr','fahrtenbuchnr','auftragsart',
    'personenzahl','fahrzeugprofil','fahrerprofil','status','filiale','gedruckt',
    'erledigt','angelegt_am','geaendert_am','erstelltvon','geaendertvon',
    'zusatzinfo','fahrtenplan','reftable','refnr'
  );
begin
  DoUpdate('F_FAHRTAUFTRAG', ALLOWED, 'nr');
end;

// Route: /toupac/deletef_fahrtauftrag  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.deleteF_Fahrtauftrag;
// Body: { "nr": 42 }
begin
  DoDelete('F_FAHRTAUFTRAG', 'nr');
end;

// Route: /toupac/gett_kalender  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_Kalender;
// Body: { "fields": ["nr","aufgabe",...] | "*", "orderby": "nr" }
const
  ALLOWED: array[0..19] of string = (
    'nr','aufgabe','erstellt','terminam','vorlaufzeit','text','bereich',
    'reftable','refnr','benutzer','benutzergruppe','status','von_name',
    'an_name','suchbegriff','prio','typ','zusatzfeld1','zusatzfeld2',
    'erstelltvon'
  );
begin
  DoSelect('T_KALENDER', ALLOWED);
end;

// Route: /toupac/gett_kalenderfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_KalenderFiltered;
// Body: { "fields": [...] | "*", "nr": 42, "bereich": "...", "orderby": "nr" }
// Alle Filter-Parameter sind optional - nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..19] of string = (
    'nr','aufgabe','erstellt','terminam','vorlaufzeit','text','bereich',
    'reftable','refnr','benutzer','benutzergruppe','status','von_name',
    'an_name','suchbegriff','prio','typ','zusatzfeld1','zusatzfeld2',
    'erstelltvon'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS uebereinstimmen).
  CONDITIONS: array[0..19] of string = (
    'nr = :nr',
    'aufgabe = :aufgabe',
    'erstellt = :erstellt',
    'terminam = :terminam',
    'vorlaufzeit = :vorlaufzeit',
    'text = :text',
    'bereich = :bereich',
    'reftable = :reftable',
    'refnr = :refnr',
    'benutzer = :benutzer',
    'benutzergruppe = :benutzergruppe',
    'status = :status',
    'von_name = :von_name',
    'an_name = :an_name',
    'suchbegriff = :suchbegriff',
    'prio = :prio',
    'typ = :typ',
    'zusatzfeld1 = :zusatzfeld1',
    'zusatzfeld2 = :zusatzfeld2',
    'erstelltvon = :erstelltvon'
  );
  FILTER_PARAMS: array[0..19] of string = (
    'nr','aufgabe','erstellt','terminam','vorlaufzeit','text','bereich',
    'reftable','refnr','benutzer','benutzergruppe','status','von_name',
    'an_name','suchbegriff','prio','typ','zusatzfeld1','zusatzfeld2',
    'erstelltvon'
  );
begin
  DoSelectFilteredDynamic('T_KALENDER', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /toupac/gett_kalenderbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_KalenderById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..19] of string = (
    'nr','aufgabe','erstellt','terminam','vorlaufzeit','text','bereich',
    'reftable','refnr','benutzer','benutzergruppe','status','von_name',
    'an_name','suchbegriff','prio','typ','zusatzfeld1','zusatzfeld2',
    'erstelltvon'
  );
begin
  DoSelectOne('T_KALENDER', ALLOWED, 'nr');
end;

// Route: /toupac/gett_kalenderkey  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_KalenderKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(T_KALENDER_NR_GEN,1) AS NR FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /toupac/insertt_kalender  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.insertT_Kalender;
// Body: { "nr": 42, "aufgabe": "...", ... }
const
  ALLOWED: array[0..19] of string = (
    'nr','aufgabe','erstellt','terminam','vorlaufzeit','text','bereich',
    'reftable','refnr','benutzer','benutzergruppe','status','von_name',
    'an_name','suchbegriff','prio','typ','zusatzfeld1','zusatzfeld2',
    'erstelltvon'
  );
begin
  DoInsert('T_KALENDER', ALLOWED);
end;

// Route: /toupac/updatet_kalender  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.updateT_Kalender;
// Body: { "nr": 42, "aufgabe": "...", ... }
const
  ALLOWED: array[0..19] of string = (
    'nr','aufgabe','erstellt','terminam','vorlaufzeit','text','bereich',
    'reftable','refnr','benutzer','benutzergruppe','status','von_name',
    'an_name','suchbegriff','prio','typ','zusatzfeld1','zusatzfeld2',
    'erstelltvon'
  );
begin
  DoUpdate('T_KALENDER', ALLOWED, 'nr');
end;

// Route: /toupac/deletet_kalender  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.deleteT_Kalender;
// Body: { "nr": 42 }
begin
  DoDelete('T_KALENDER', 'nr');
end;


// Route: /toupac/gett_positionen  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_Positionen;
// Body: { "fields": ["nr","vorgangnr",...] | "*", "orderby": "nr" }
const
  ALLOWED: array[0..100] of string = (
    'nr','masterpos','postyp','erstellt','geaendert','vorgangnr','agenturnr','menge','personen',
    'leistungscode','kontingentcode','kostelle1','kostelle2','ltraeger','datum_von','datum_bis',
    'leistungnr','provklasse','prov','prov_betrag','provust','ustpflichtig','sachkonto',
    'maxcapacity','mincapacity','capacity','rabatterlaubt','stornierbar','typ','zahlbarsofort',
    'geraet','leistungsgeber','belegt_nr','einzelpreis','gesamtpreis','endpreis','optionstage',
    'regel_mitltyp','katalogreisenr','direktinkasso','ltbezeichnung','reisebezeichnung',
    'alter_von','alter_bis','bemerkung','erm','ermdatum','status','provisionskonto',
    'stornostaffel','sachkontostorno','zeitvon','zeitbis','params','preisschema',
    'leistungsgruppe','inklusiv','preisoption','marge','packagenr','leistungsstatus',
    'ltraegerkennziffer','personenpreis','preisberechnet','kurs','sortierung','rundungsoption',
    'ek_tats','ek_kalk','freiplatz_lt','freiplatz_kunde','termin','referenz1','referenz2',
    'waehrung','ek_kalk1','ek_kalk2','ek_kalk3','ek_kalk4','bezeichnung2','optionsdatum',
    'teilnehmernr','rabatt','externenr1','externenr2','buchungsdatum','stornodatum','referenz3',
    'referenz4','gruppe','internet','onlinebuchung','app','vk_preis_fremdwaehrung',
    'kurs_vk_fremdwaehrung','waehrung_ek','lcode','menge_alt','auskatalogreise',
    'mindestnaechte','bezeichnung'
  );
begin
  DoSelect('T_POSITIONEN', ALLOWED);
end;

// Route: /toupac/gett_positionenfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_PositionenFiltered;
// Body: { "fields": [...] | "*", "vorgangnr": 42, "postyp": "..", "orderby": "nr" }
// Alle Filter-Parameter sind optional - nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..100] of string = (
    'nr','masterpos','postyp','erstellt','geaendert','vorgangnr','agenturnr','menge','personen',
    'leistungscode','kontingentcode','kostelle1','kostelle2','ltraeger','datum_von','datum_bis',
    'leistungnr','provklasse','prov','prov_betrag','provust','ustpflichtig','sachkonto',
    'maxcapacity','mincapacity','capacity','rabatterlaubt','stornierbar','typ','zahlbarsofort',
    'geraet','leistungsgeber','belegt_nr','einzelpreis','gesamtpreis','endpreis','optionstage',
    'regel_mitltyp','katalogreisenr','direktinkasso','ltbezeichnung','reisebezeichnung',
    'alter_von','alter_bis','bemerkung','erm','ermdatum','status','provisionskonto',
    'stornostaffel','sachkontostorno','zeitvon','zeitbis','params','preisschema',
    'leistungsgruppe','inklusiv','preisoption','marge','packagenr','leistungsstatus',
    'ltraegerkennziffer','personenpreis','preisberechnet','kurs','sortierung','rundungsoption',
    'ek_tats','ek_kalk','freiplatz_lt','freiplatz_kunde','termin','referenz1','referenz2',
    'waehrung','ek_kalk1','ek_kalk2','ek_kalk3','ek_kalk4','bezeichnung2','optionsdatum',
    'teilnehmernr','rabatt','externenr1','externenr2','buchungsdatum','stornodatum','referenz3',
    'referenz4','gruppe','internet','onlinebuchung','app','vk_preis_fremdwaehrung',
    'kurs_vk_fremdwaehrung','waehrung_ek','lcode','menge_alt','auskatalogreise',
    'mindestnaechte','bezeichnung'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS uebereinstimmen).
  // Alle Tabellenspalten sind optional filterbar -- ausgenommen Blob-Felder bemerkung.
  CONDITIONS: array[0..101] of string = (
    'nr = :nr',
    'masterpos = :masterpos',
    'vorgangnr = :vorgangnr',
    'postyp = :postyp',
    'agenturnr = :agenturnr',
    'leistungnr = :leistungnr',
    'ltraeger = :ltraeger',
    'teilnehmernr = :teilnehmernr',
    'packagenr = :packagenr',
    'katalogreisenr = :katalogreisenr',
    'status = :status',
    'leistungsstatus = :leistungsstatus',
    'erstellt = :erstellt',
    'geaendert = :geaendert',
    'menge = :menge',
    'personen = :personen',
    'leistungscode = :leistungscode',
    'kontingentcode = :kontingentcode',
    'kostelle1 = :kostelle1',
    'kostelle2 = :kostelle2',
    'datum_von = :datum_von',
    'datum_bis = :datum_bis',
    'provklasse = :provklasse',
    'prov = :prov',
    'prov_betrag = :prov_betrag',
    'provust = :provust',
    'ustpflichtig = :ustpflichtig',
    'sachkonto = :sachkonto',
    'maxcapacity = :maxcapacity',
    'mincapacity = :mincapacity',
    'capacity = :capacity',
    'rabatterlaubt = :rabatterlaubt',
    'stornierbar = :stornierbar',
    'typ = :typ',
    'zahlbarsofort = :zahlbarsofort',
    'geraet = :geraet',
    'leistungsgeber = :leistungsgeber',
    'belegt_nr = :belegt_nr',
    'einzelpreis = :einzelpreis',
    'gesamtpreis = :gesamtpreis',
    'endpreis = :endpreis',
    'optionstage = :optionstage',
    'regel_mitltyp = :regel_mitltyp',
    'direktinkasso = :direktinkasso',
    'ltbezeichnung = :ltbezeichnung',
    'reisebezeichnung = :reisebezeichnung',
    'alter_von = :alter_von',
    'alter_bis = :alter_bis',
    'erm = :erm',
    'ermdatum = :ermdatum',
    'provisionskonto = :provisionskonto',
    'stornostaffel = :stornostaffel',
    'sachkontostorno = :sachkontostorno',
    'zeitvon = :zeitvon',
    'zeitbis = :zeitbis',
    'params = :params',
    'preisschema = :preisschema',
    'leistungsgruppe = :leistungsgruppe',
    'inklusiv = :inklusiv',
    'preisoption = :preisoption',
    'marge = :marge',
    'ltraegerkennziffer = :ltraegerkennziffer',
    'personenpreis = :personenpreis',
    'preisberechnet = :preisberechnet',
    'kurs = :kurs',
    'sortierung = :sortierung',
    'rundungsoption = :rundungsoption',
    'ek_tats = :ek_tats',
    'ek_kalk = :ek_kalk',
    'freiplatz_lt = :freiplatz_lt',
    'freiplatz_kunde = :freiplatz_kunde',
    'termin = :termin',
    'referenz1 = :referenz1',
    'referenz2 = :referenz2',
    'waehrung = :waehrung',
    'ek_kalk1 = :ek_kalk1',
    'ek_kalk2 = :ek_kalk2',
    'ek_kalk3 = :ek_kalk3',
    'ek_kalk4 = :ek_kalk4',
    'bezeichnung2 = :bezeichnung2',
    'optionsdatum = :optionsdatum',
    'rabatt = :rabatt',
    'externenr1 = :externenr1',
    'externenr2 = :externenr2',
    'buchungsdatum = :buchungsdatum',
    'stornodatum = :stornodatum',
    'referenz3 = :referenz3',
    'referenz4 = :referenz4',
    'gruppe = :gruppe',
    'internet = :internet',
    'onlinebuchung = :onlinebuchung',
    'app = :app',
    'vk_preis_fremdwaehrung = :vk_preis_fremdwaehrung',
    'kurs_vk_fremdwaehrung = :kurs_vk_fremdwaehrung',
    'waehrung_ek = :waehrung_ek',
    'lcode = :lcode',
    'menge_alt = :menge_alt',
    'auskatalogreise = :auskatalogreise',
    'mindestnaechte = :mindestnaechte',
    'bezeichnung = :bezeichnung',
    'dauer = :dauer',
    'kurs_ek = :kurs_ek'
  );
  FILTER_PARAMS: array[0..101] of string = (
    'nr','masterpos','vorgangnr','postyp','agenturnr','leistungnr',
    'ltraeger','teilnehmernr','packagenr','katalogreisenr','status','leistungsstatus',
    'erstellt','geaendert','menge','personen','leistungscode','kontingentcode',
    'kostelle1','kostelle2','datum_von','datum_bis','provklasse','prov',
    'prov_betrag','provust','ustpflichtig','sachkonto','maxcapacity','mincapacity',
    'capacity','rabatterlaubt','stornierbar','typ','zahlbarsofort','geraet',
    'leistungsgeber','belegt_nr','einzelpreis','gesamtpreis','endpreis','optionstage',
    'regel_mitltyp','direktinkasso','ltbezeichnung','reisebezeichnung','alter_von','alter_bis',
    'erm','ermdatum','provisionskonto','stornostaffel','sachkontostorno','zeitvon',
    'zeitbis','params','preisschema','leistungsgruppe','inklusiv','preisoption',
    'marge','ltraegerkennziffer','personenpreis','preisberechnet','kurs','sortierung',
    'rundungsoption','ek_tats','ek_kalk','freiplatz_lt','freiplatz_kunde','termin',
    'referenz1','referenz2','waehrung','ek_kalk1','ek_kalk2','ek_kalk3',
    'ek_kalk4','bezeichnung2','optionsdatum','rabatt','externenr1','externenr2',
    'buchungsdatum','stornodatum','referenz3','referenz4','gruppe','internet',
    'onlinebuchung','app','vk_preis_fremdwaehrung','kurs_vk_fremdwaehrung','waehrung_ek','lcode',
    'menge_alt','auskatalogreise','mindestnaechte','bezeichnung',
    'dauer', 'kurs_ek'
  );
begin
  DoSelectFilteredDynamic('T_POSITIONEN', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /toupac/gett_positionenbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_PositionenById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..100] of string = (
    'nr','masterpos','postyp','erstellt','geaendert','vorgangnr','agenturnr','menge','personen',
    'leistungscode','kontingentcode','kostelle1','kostelle2','ltraeger','datum_von','datum_bis',
    'leistungnr','provklasse','prov','prov_betrag','provust','ustpflichtig','sachkonto',
    'maxcapacity','mincapacity','capacity','rabatterlaubt','stornierbar','typ','zahlbarsofort',
    'geraet','leistungsgeber','belegt_nr','einzelpreis','gesamtpreis','endpreis','optionstage',
    'regel_mitltyp','katalogreisenr','direktinkasso','ltbezeichnung','reisebezeichnung',
    'alter_von','alter_bis','bemerkung','erm','ermdatum','status','provisionskonto',
    'stornostaffel','sachkontostorno','zeitvon','zeitbis','params','preisschema',
    'leistungsgruppe','inklusiv','preisoption','marge','packagenr','leistungsstatus',
    'ltraegerkennziffer','personenpreis','preisberechnet','kurs','sortierung','rundungsoption',
    'ek_tats','ek_kalk','freiplatz_lt','freiplatz_kunde','termin','referenz1','referenz2',
    'waehrung','ek_kalk1','ek_kalk2','ek_kalk3','ek_kalk4','bezeichnung2','optionsdatum',
    'teilnehmernr','rabatt','externenr1','externenr2','buchungsdatum','stornodatum','referenz3',
    'referenz4','gruppe','internet','onlinebuchung','app','vk_preis_fremdwaehrung',
    'kurs_vk_fremdwaehrung','waehrung_ek','lcode','menge_alt','auskatalogreise',
    'mindestnaechte','bezeichnung'
  );
begin
  DoSelectOne('T_POSITIONEN', ALLOWED, 'nr');
end;


// Route: /toupac/gett_ticketdaten  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_Ticketdaten;
// Body: { "fields": ["nr","art",...] | "*", "orderby": "nr" }
const
  ALLOWED: array[0..12] of string = (
    'nr','gueltigvon','gueltigbis','daten','reftable','refnr','art','bezeichnung',
    'datum1','datum2','datum3','datum4','wtag'
  );
begin
  DoSelect('T_TICKETDATEN', ALLOWED);
end;

// Route: /toupac/gett_ticketdatenfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_TicketdatenFiltered;
// Body: { "fields": [...] | "*", "reftable": "...", "refnr": 42, "art": "...", "orderby": "nr" }
// Alle Filter-Parameter sind optional - nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..12] of string = (
    'nr','gueltigvon','gueltigbis','daten','reftable','refnr','art','bezeichnung',
    'datum1','datum2','datum3','datum4','wtag'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS uebereinstimmen).
  // Alle Tabellenspalten sind optional filterbar.
  CONDITIONS: array[0..12] of string = (
    'nr = :nr',
    'reftable = :reftable',
    'refnr = :refnr',
    'art = :art',
    'bezeichnung = :bezeichnung',
    'wtag = :wtag',
    'gueltigvon = :gueltigvon',
    'gueltigbis = :gueltigbis',
    'daten = :daten',
    'datum1 = :datum1',
    'datum2 = :datum2',
    'datum3 = :datum3',
    'datum4 = :datum4'
  );
  FILTER_PARAMS: array[0..12] of string = (
    'nr','reftable','refnr','art','bezeichnung','wtag',
    'gueltigvon','gueltigbis','daten','datum1','datum2','datum3',
    'datum4'
  );
begin
  DoSelectFilteredDynamic('T_TICKETDATEN', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /toupac/gett_ticketdatenbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_TicketdatenById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..12] of string = (
    'nr','gueltigvon','gueltigbis','daten','reftable','refnr','art','bezeichnung',
    'datum1','datum2','datum3','datum4','wtag'
  );
begin
  DoSelectOne('T_TICKETDATEN', ALLOWED, 'nr');
end;


// Route: /toupac/gett_ltraeger  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_Ltraeger;
// Body: { "fields": ["nr","code",...] | "*", "orderby": "nr" }
const
  ALLOWED: array[0..17] of string = (
    'nr','kennziffer','code','bezeichnung','land','ort','typ','sachkonto','kostelle1',
    'kostelle2','optionstage','klasse','stornostaffel','suchbegriff','kategorie','waehrung',
    'gesperrt','bemerkung_intern'
  );
begin
  DoSelect('T_LTRAEGER', ALLOWED);
end;

// Route: /toupac/gett_ltraegerfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_LtraegerFiltered;
// Body: { "fields": [...] | "*", "code": "...", "land": "...", "orderby": "nr" }
// Alle Filter-Parameter sind optional - nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..17] of string = (
    'nr','kennziffer','code','bezeichnung','land','ort','typ','sachkonto','kostelle1',
    'kostelle2','optionstage','klasse','stornostaffel','suchbegriff','kategorie','waehrung',
    'gesperrt','bemerkung_intern'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS uebereinstimmen).
  CONDITIONS: array[0..16] of string = (
    'nr = :nr',
    'kennziffer = :kennziffer',
    'code = :code',
    'bezeichnung = :bezeichnung',
    'land = :land',
    'ort = :ort',
    'typ = :typ',
    'sachkonto = :sachkonto',
    'kostelle1 = :kostelle1',
    'kostelle2 = :kostelle2',
    'optionstage = :optionstage',
    'klasse = :klasse',
    'stornostaffel = :stornostaffel',
    'suchbegriff = :suchbegriff',
    'waehrung = :waehrung',
    'gesperrt = :gesperrt',
    'bemerkung_intern = :bemerkung_intern'
  );
  FILTER_PARAMS: array[0..16] of string = (
    'nr', 'kennziffer', 'code', 'bezeichnung', 'land', 'ort', 'typ', 'sachkonto',
    'kostelle1', 'kostelle2', 'optionstage', 'klasse', 'stornostaffel', 'suchbegriff',
    'waehrung', 'gesperrt', 'bemerkung_intern'
  );
begin
  DoSelectFilteredDynamic('T_LTRAEGER', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /toupac/gett_ltraegerbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_LtraegerById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..17] of string = (
    'nr','kennziffer','code','bezeichnung','land','ort','typ','sachkonto','kostelle1',
    'kostelle2','optionstage','klasse','stornostaffel','suchbegriff','kategorie','waehrung',
    'gesperrt','bemerkung_intern'
  );
begin
  DoSelectOne('T_LTRAEGER', ALLOWED, 'nr');
end;

// Route: /toupac/gett_ltraegerkey  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_LtraegerKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(T_LTRAEGER_NR_GEN,1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /toupac/insertt_ltraeger  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.insertT_Ltraeger;
// Body: { "nr": 42, "code": "...", "bezeichnung": "...", ... }
const
  ALLOWED: array[0..17] of string = (
    'nr','kennziffer','code','bezeichnung','land','ort','typ','sachkonto','kostelle1',
    'kostelle2','optionstage','klasse','stornostaffel','suchbegriff','kategorie','waehrung',
    'gesperrt','bemerkung_intern'
  );
begin
  DoInsert('T_LTRAEGER', ALLOWED);
end;

// Route: /toupac/updatet_ltraeger  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.updateT_Ltraeger;
// Body: { "nr": 42, "code": "...", "bezeichnung": "...", ... }
const
  ALLOWED: array[0..17] of string = (
    'nr','kennziffer','code','bezeichnung','land','ort','typ','sachkonto','kostelle1',
    'kostelle2','optionstage','klasse','stornostaffel','suchbegriff','kategorie','waehrung',
    'gesperrt','bemerkung_intern'
  );
begin
  DoUpdate('T_LTRAEGER', ALLOWED, 'nr');
end;

// Route: /toupac/deletet_ltraeger  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.deleteT_Ltraeger;
// Body: { "nr": 42 }
begin
  DoDelete('T_LTRAEGER', 'nr');
end;


// Route: /toupac/gett_katalogreise  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_Katalogreise;
// Body: { "fields": ["nr","code",...] | "*", "orderby": "nr" }
const
  ALLOWED: array[0..46] of string = (
    'nr','reisenr','reisethema','code','katalognr','terminschema','internet','befkategorie',
    'sachkonto','sachkontostorno','sachkontoprov','kostelle1','kostelle2','kostelle1storno',
    'kostelle2storno','kostelle1prov','kostelle2prov','erstelltam','fbrabatt','fbbis','angebot',
    'status','url1','url2','url3','url4','xkoord','ykoord','maximumpers','minimumpers',
    'bemerkung','kategorie','anzahlungsbetrag','anzahlungsart','nrkreis','stornostaffel',
    'zusatzinfo','katalogseite','veranstalter','hauptkategorie','pauschalierungsfaktor',
    'versicherungsart','geaendertam','geaendertvon','erstelltvon','untertitel','mandant'
  );
begin
  DoSelect('T_KATALOGREISE', ALLOWED);
end;

// Route: /toupac/gett_katalogreisefiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_KatalogreiseFiltered;
// Body: { "fields": [...] | "*", "code": "...", "katalognr": 42, "orderby": "nr" }
// Alle Filter-Parameter sind optional - nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..46] of string = (
    'nr','reisenr','reisethema','code','katalognr','terminschema','internet','befkategorie',
    'sachkonto','sachkontostorno','sachkontoprov','kostelle1','kostelle2','kostelle1storno',
    'kostelle2storno','kostelle1prov','kostelle2prov','erstelltam','fbrabatt','fbbis','angebot',
    'status','url1','url2','url3','url4','xkoord','ykoord','maximumpers','minimumpers',
    'bemerkung','kategorie','anzahlungsbetrag','anzahlungsart','nrkreis','stornostaffel',
    'zusatzinfo','katalogseite','veranstalter','hauptkategorie','pauschalierungsfaktor',
    'versicherungsart','geaendertam','geaendertvon','erstelltvon','untertitel','mandant'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS uebereinstimmen).
  CONDITIONS: array[0..44] of string = (
    'nr = :nr',
    'reisenr = :reisenr',
    'reisethema = :reisethema',
    'code = :code',
    'katalognr = :katalognr',
    'terminschema = :terminschema',
    'internet = :internet',
    'befkategorie = :befkategorie',
    'sachkonto = :sachkonto',
    'sachkontostorno = :sachkontostorno',
    'sachkontoprov = :sachkontoprov',
    'kostelle1 = :kostelle1',
    'kostelle2 = :kostelle2',
    'kostelle1storno = :kostelle1storno',
    'kostelle2storno = :kostelle2storno',
    'kostelle1prov = :kostelle1prov',
    'kostelle2prov = :kostelle2prov',
    'erstelltam = :erstelltam',
    'fbrabatt = :fbrabatt',
    'fbbis = :fbbis',
    'angebot = :angebot',
    'status = :status',
    'url1 = :url1',
    'url2 = :url2',
    'url3 = :url3',
    'url4 = :url4',
    'xkoord = :xkoord',
    'ykoord = :ykoord',
    'maximumpers = :maximumpers',
    'minimumpers = :minimumpers',
    'anzahlungsbetrag = :anzahlungsbetrag',
    'anzahlungsart = :anzahlungsart',
    'nrkreis = :nrkreis',
    'stornostaffel = :stornostaffel',
    'zusatzinfo = :zusatzinfo',
    'katalogseite = :katalogseite',
    'veranstalter = :veranstalter',
    'hauptkategorie = :hauptkategorie',
    'pauschalierungsfaktor = :pauschalierungsfaktor',
    'versicherungsart = :versicherungsart',
    'geaendertam = :geaendertam',
    'geaendertvon = :geaendertvon',
    'erstelltvon = :erstelltvon',
    'untertitel = :untertitel',
    'mandant = :mandant'
  );
  FILTER_PARAMS: array[0..44] of string = (
    'nr', 'reisenr', 'reisethema', 'code', 'katalognr', 'terminschema', 'internet',
    'befkategorie', 'sachkonto', 'sachkontostorno', 'sachkontoprov', 'kostelle1',
    'kostelle2', 'kostelle1storno', 'kostelle2storno', 'kostelle1prov', 'kostelle2prov',
    'erstelltam', 'fbrabatt', 'fbbis', 'angebot', 'status', 'url1', 'url2', 'url3', 'url4',
    'xkoord', 'ykoord', 'maximumpers', 'minimumpers', 'anzahlungsbetrag', 'anzahlungsart',
    'nrkreis', 'stornostaffel', 'zusatzinfo', 'katalogseite', 'veranstalter',
    'hauptkategorie', 'pauschalierungsfaktor', 'versicherungsart', 'geaendertam',
    'geaendertvon', 'erstelltvon', 'untertitel', 'mandant'
  );
begin
  DoSelectFilteredDynamic('T_KATALOGREISE', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /toupac/gett_katalogreisebyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_KatalogreiseById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..46] of string = (
    'nr','reisenr','reisethema','code','katalognr','terminschema','internet','befkategorie',
    'sachkonto','sachkontostorno','sachkontoprov','kostelle1','kostelle2','kostelle1storno',
    'kostelle2storno','kostelle1prov','kostelle2prov','erstelltam','fbrabatt','fbbis','angebot',
    'status','url1','url2','url3','url4','xkoord','ykoord','maximumpers','minimumpers',
    'bemerkung','kategorie','anzahlungsbetrag','anzahlungsart','nrkreis','stornostaffel',
    'zusatzinfo','katalogseite','veranstalter','hauptkategorie','pauschalierungsfaktor',
    'versicherungsart','geaendertam','geaendertvon','erstelltvon','untertitel','mandant'
  );
begin
  DoSelectOne('T_KATALOGREISE', ALLOWED, 'nr');
end;

// Route: /toupac/gett_katalogreisekey  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_KatalogreiseKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(T_KATALOGREISE_NR_GEN,1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /toupac/insertt_katalogreise  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.insertT_Katalogreise;
// Body: { "nr": 42, "code": "...", "reisethema": "...", ... }
const
  ALLOWED: array[0..46] of string = (
    'nr','reisenr','reisethema','code','katalognr','terminschema','internet','befkategorie',
    'sachkonto','sachkontostorno','sachkontoprov','kostelle1','kostelle2','kostelle1storno',
    'kostelle2storno','kostelle1prov','kostelle2prov','erstelltam','fbrabatt','fbbis','angebot',
    'status','url1','url2','url3','url4','xkoord','ykoord','maximumpers','minimumpers',
    'bemerkung','kategorie','anzahlungsbetrag','anzahlungsart','nrkreis','stornostaffel',
    'zusatzinfo','katalogseite','veranstalter','hauptkategorie','pauschalierungsfaktor',
    'versicherungsart','geaendertam','geaendertvon','erstelltvon','untertitel','mandant'
  );
begin
  DoInsert('T_KATALOGREISE', ALLOWED);
end;

// Route: /toupac/updatet_katalogreise  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.updateT_Katalogreise;
// Body: { "nr": 42, "code": "...", "reisethema": "...", ... }
const
  ALLOWED: array[0..46] of string = (
    'nr','reisenr','reisethema','code','katalognr','terminschema','internet','befkategorie',
    'sachkonto','sachkontostorno','sachkontoprov','kostelle1','kostelle2','kostelle1storno',
    'kostelle2storno','kostelle1prov','kostelle2prov','erstelltam','fbrabatt','fbbis','angebot',
    'status','url1','url2','url3','url4','xkoord','ykoord','maximumpers','minimumpers',
    'bemerkung','kategorie','anzahlungsbetrag','anzahlungsart','nrkreis','stornostaffel',
    'zusatzinfo','katalogseite','veranstalter','hauptkategorie','pauschalierungsfaktor',
    'versicherungsart','geaendertam','geaendertvon','erstelltvon','untertitel','mandant'
  );
begin
  DoUpdate('T_KATALOGREISE', ALLOWED, 'nr');
end;


// Route: /toupac/gett_reise  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_Reise;
// Body: { "fields": ["nr","code",...] | "*", "orderby": "nr" }
const
  ALLOWED: array[0..7] of string = (
    'nr','bezeichnung','code','land','region','suchbegriff','gesperrt','kategorie'
  );
begin
  DoSelect('T_REISE', ALLOWED);
end;

// Route: /toupac/gett_reisefiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_ReiseFiltered;
// Body: { "fields": [...] | "*", "code": "...", "land": "...", "orderby": "nr" }
// Alle Filter-Parameter sind optional - nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..7] of string = (
    'nr','bezeichnung','code','land','region','suchbegriff','gesperrt','kategorie'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS uebereinstimmen).
  CONDITIONS: array[0..6] of string = (
    'nr = :nr',
    'bezeichnung = :bezeichnung',
    'code = :code',
    'land = :land',
    'region = :region',
    'suchbegriff = :suchbegriff',
    'gesperrt = :gesperrt'
  );
  FILTER_PARAMS: array[0..6] of string = (
    'nr', 'bezeichnung', 'code', 'land', 'region', 'suchbegriff', 'gesperrt'
  );
begin
  DoSelectFilteredDynamic('T_REISE', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /toupac/gett_reisebyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_ReiseById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..7] of string = (
    'nr','bezeichnung','code','land','region','suchbegriff','gesperrt','kategorie'
  );
begin
  DoSelectOne('T_REISE', ALLOWED, 'nr');
end;

// Route: /toupac/gett_reisekey  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_ReiseKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(T_REISE_NR_GEN,1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /toupac/insertt_reise  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.insertT_Reise;
// Body: { "nr": 42, "bezeichnung": "...", "code": "...", ... }
const
  ALLOWED: array[0..7] of string = (
    'nr','bezeichnung','code','land','region','suchbegriff','gesperrt','kategorie'
  );
begin
  DoInsert('T_REISE', ALLOWED);
end;

// Route: /toupac/updatet_reise  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.updateT_Reise;
// Body: { "nr": 42, "bezeichnung": "...", "code": "...", ... }
const
  ALLOWED: array[0..7] of string = (
    'nr','bezeichnung','code','land','region','suchbegriff','gesperrt','kategorie'
  );
begin
  DoUpdate('T_REISE', ALLOWED, 'nr');
end;


// Route: /toupac/gett_reiseleistungen  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_Reiseleistungen;
// Body: { "fields": ["nr","code",...] | "*", "orderby": "nr" }
const
  ALLOWED: array[0..47] of string = (
    'nr','katalogreisenr','leistungnr','rabatterlaubt','standard','leistungsgeber','code',
    'geraet','von','bis','internet','vontag','bistag','zeitvon','zeitbis','bemerkung','params',
    'status','inklusiv','leistungsgruppe','preisoption','marge','adresskennziffer','vontagref',
    'rundungsoption','sortierung','ek_tats','ek_kalk','freiplatz_lt','freiplatz_kunde',
    'gesperrt','kopiertaus','ek_kalk1','ek_kalk2','ek_kalk3','ek_kalk4','bezeichnung2',
    'provklasse','referenz1','referenz2','preis_steuerfrei','sachkonto_steuerfrei',
    'onlinebuchung','app','termin','optionsdatum','referenz3','referenz4'
  );
begin
  DoSelect('T_REISELEISTUNGEN', ALLOWED);
end;

// Route: /toupac/gett_reiseleistungenfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_ReiseleistungenFiltered;
// Body: { "fields": [...] | "*", "katalogreisenr": 42, "code": "...", "orderby": "nr" }
// Alle Filter-Parameter sind optional - nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..47] of string = (
    'nr','katalogreisenr','leistungnr','rabatterlaubt','standard','leistungsgeber','code',
    'geraet','von','bis','internet','vontag','bistag','zeitvon','zeitbis','bemerkung','params',
    'status','inklusiv','leistungsgruppe','preisoption','marge','adresskennziffer','vontagref',
    'rundungsoption','sortierung','ek_tats','ek_kalk','freiplatz_lt','freiplatz_kunde',
    'gesperrt','kopiertaus','ek_kalk1','ek_kalk2','ek_kalk3','ek_kalk4','bezeichnung2',
    'provklasse','referenz1','referenz2','preis_steuerfrei','sachkonto_steuerfrei',
    'onlinebuchung','app','termin','optionsdatum','referenz3','referenz4'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS uebereinstimmen).
  CONDITIONS: array[0..47] of string = (
    'nr = :nr',
    'katalogreisenr = :katalogreisenr',
    'leistungnr = :leistungnr',
    'rabatterlaubt = :rabatterlaubt',
    'standard = :standard',
    'leistungsgeber = :leistungsgeber',
    'code = :code',
    'geraet = :geraet',
    'von = :von',
    'bis = :bis',
    'internet = :internet',
    'vontag = :vontag',
    'bistag = :bistag',
    'zeitvon = :zeitvon',
    'zeitbis = :zeitbis',
    'params = :params',
    'status = :status',
    'inklusiv = :inklusiv',
    'leistungsgruppe = :leistungsgruppe',
    'preisoption = :preisoption',
    'marge = :marge',
    'adresskennziffer = :adresskennziffer',
    'vontagref = :vontagref',
    'rundungsoption = :rundungsoption',
    'sortierung = :sortierung',
    'ek_tats = :ek_tats',
    'ek_kalk = :ek_kalk',
    'freiplatz_lt = :freiplatz_lt',
    'freiplatz_kunde = :freiplatz_kunde',
    'gesperrt = :gesperrt',
    'kopiertaus = :kopiertaus',
    'ek_kalk1 = :ek_kalk1',
    'ek_kalk2 = :ek_kalk2',
    'ek_kalk3 = :ek_kalk3',
    'ek_kalk4 = :ek_kalk4',
    'bezeichnung2 = :bezeichnung2',
    'provklasse = :provklasse',
    'referenz1 = :referenz1',
    'referenz2 = :referenz2',
    'preis_steuerfrei = :preis_steuerfrei',
    'sachkonto_steuerfrei = :sachkonto_steuerfrei',
    'onlinebuchung = :onlinebuchung',
    'app = :app',
    'termin = :termin',
    'optionsdatum = :optionsdatum',
    'referenz3 = :referenz3',
    'referenz4 = :referenz4',
    'dauer = :dauer'
  );
  FILTER_PARAMS: array[0..47] of string = (
    'nr', 'katalogreisenr', 'leistungnr', 'rabatterlaubt', 'standard', 'leistungsgeber',
    'code', 'geraet', 'von', 'bis', 'internet', 'vontag', 'bistag', 'zeitvon', 'zeitbis',
    'params', 'status', 'inklusiv', 'leistungsgruppe', 'preisoption', 'marge',
    'adresskennziffer', 'vontagref', 'rundungsoption', 'sortierung', 'ek_tats', 'ek_kalk',
    'freiplatz_lt', 'freiplatz_kunde', 'gesperrt', 'kopiertaus', 'ek_kalk1', 'ek_kalk2',
    'ek_kalk3', 'ek_kalk4', 'bezeichnung2', 'provklasse', 'referenz1', 'referenz2',
    'preis_steuerfrei', 'sachkonto_steuerfrei', 'onlinebuchung', 'app', 'termin',
    'optionsdatum', 'referenz3', 'referenz4',
    'dauer'
  );
begin
  DoSelectFilteredDynamic('T_REISELEISTUNGEN', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /toupac/gett_reiseleistungenbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_ReiseleistungenById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..47] of string = (
    'nr','katalogreisenr','leistungnr','rabatterlaubt','standard','leistungsgeber','code',
    'geraet','von','bis','internet','vontag','bistag','zeitvon','zeitbis','bemerkung','params',
    'status','inklusiv','leistungsgruppe','preisoption','marge','adresskennziffer','vontagref',
    'rundungsoption','sortierung','ek_tats','ek_kalk','freiplatz_lt','freiplatz_kunde',
    'gesperrt','kopiertaus','ek_kalk1','ek_kalk2','ek_kalk3','ek_kalk4','bezeichnung2',
    'provklasse','referenz1','referenz2','preis_steuerfrei','sachkonto_steuerfrei',
    'onlinebuchung','app','termin','optionsdatum','referenz3','referenz4'
  );
begin
  DoSelectOne('T_REISELEISTUNGEN', ALLOWED, 'nr');
end;

// Route: /toupac/gett_reiseleistungenkey  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_ReiseleistungenKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(T_REISELEISTUNGEN_NR_GEN,1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /toupac/insertt_reiseleistungen  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.insertT_Reiseleistungen;
// Body: { "nr": 42, "katalogreisenr": 1, "leistungnr": 1, ... }
const
  ALLOWED: array[0..47] of string = (
    'nr','katalogreisenr','leistungnr','rabatterlaubt','standard','leistungsgeber','code',
    'geraet','von','bis','internet','vontag','bistag','zeitvon','zeitbis','bemerkung','params',
    'status','inklusiv','leistungsgruppe','preisoption','marge','adresskennziffer','vontagref',
    'rundungsoption','sortierung','ek_tats','ek_kalk','freiplatz_lt','freiplatz_kunde',
    'gesperrt','kopiertaus','ek_kalk1','ek_kalk2','ek_kalk3','ek_kalk4','bezeichnung2',
    'provklasse','referenz1','referenz2','preis_steuerfrei','sachkonto_steuerfrei',
    'onlinebuchung','app','termin','optionsdatum','referenz3','referenz4'
  );
begin
  DoInsert('T_REISELEISTUNGEN', ALLOWED);
end;

// Route: /toupac/updatet_reiseleistungen  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.updateT_Reiseleistungen;
// Body: { "nr": 42, "katalogreisenr": 1, "leistungnr": 1, ... }
const
  ALLOWED: array[0..47] of string = (
    'nr','katalogreisenr','leistungnr','rabatterlaubt','standard','leistungsgeber','code',
    'geraet','von','bis','internet','vontag','bistag','zeitvon','zeitbis','bemerkung','params',
    'status','inklusiv','leistungsgruppe','preisoption','marge','adresskennziffer','vontagref',
    'rundungsoption','sortierung','ek_tats','ek_kalk','freiplatz_lt','freiplatz_kunde',
    'gesperrt','kopiertaus','ek_kalk1','ek_kalk2','ek_kalk3','ek_kalk4','bezeichnung2',
    'provklasse','referenz1','referenz2','preis_steuerfrei','sachkonto_steuerfrei',
    'onlinebuchung','app','termin','optionsdatum','referenz3','referenz4'
  );
begin
  DoUpdate('T_REISELEISTUNGEN', ALLOWED, 'nr');
end;

// Route: /toupac/deletet_reiseleistungen  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.deleteT_Reiseleistungen;
// Body: { "nr": 42 }
begin
  DoDelete('T_REISELEISTUNGEN', 'nr');
end;


// Route: /toupac/gett_leistung  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_Leistung;
// Body: { "fields": ["nr","code",...] | "*", "orderby": "nr" }
const
  ALLOWED: array[0..36] of string = (
    'nr','code','kontingentcode','ltraeger','buchungsinfo','altervon','alterbis','preisvon',
    'preisbis','dauerbis','dauervon','stornierbar','provklasse','ustpflicht','zahlbarsofort',
    'rabatterlaubt','typ','subtyp','sachkonto','kostelle1','kostelle2','capacity','maxcapacity',
    'mincapacity','internet','suchbegriff','stornostaffel','params','preisoption','tarifcode',
    'versicherungsart','onlinebuchung','kennziffer','app','gesperrt','bezeichnung','optionstage'
  );
begin
  DoSelect('T_LEISTUNG', ALLOWED);
end;

// Route: /toupac/gett_leistungfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_LeistungFiltered;
// Body: { "fields": [...] | "*", "code": "...", "ltraeger": 42, "orderby": "nr" }
// Alle Filter-Parameter sind optional - nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..36] of string = (
    'nr','code','kontingentcode','ltraeger','buchungsinfo','altervon','alterbis','preisvon',
    'preisbis','dauerbis','dauervon','stornierbar','provklasse','ustpflicht','zahlbarsofort',
    'rabatterlaubt','typ','subtyp','sachkonto','kostelle1','kostelle2','capacity','maxcapacity',
    'mincapacity','internet','suchbegriff','stornostaffel','params','preisoption','tarifcode',
    'versicherungsart','onlinebuchung','kennziffer','app','gesperrt','bezeichnung','optionstage'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS uebereinstimmen).
  CONDITIONS: array[0..36] of string = (
    'nr = :nr',
    'code = :code',
    'kontingentcode = :kontingentcode',
    'ltraeger = :ltraeger',
    'altervon = :altervon',
    'alterbis = :alterbis',
    'preisvon = :preisvon',
    'preisbis = :preisbis',
    'dauerbis = :dauerbis',
    'dauervon = :dauervon',
    'stornierbar = :stornierbar',
    'provklasse = :provklasse',
    'ustpflicht = :ustpflicht',
    'zahlbarsofort = :zahlbarsofort',
    'rabatterlaubt = :rabatterlaubt',
    'typ = :typ',
    'subtyp = :subtyp',
    'sachkonto = :sachkonto',
    'kostelle1 = :kostelle1',
    'kostelle2 = :kostelle2',
    'capacity = :capacity',
    'maxcapacity = :maxcapacity',
    'mincapacity = :mincapacity',
    'internet = :internet',
    'suchbegriff = :suchbegriff',
    'stornostaffel = :stornostaffel',
    'params = :params',
    'preisoption = :preisoption',
    'tarifcode = :tarifcode',
    'versicherungsart = :versicherungsart',
    'onlinebuchung = :onlinebuchung',
    'kennziffer = :kennziffer',
    'app = :app',
    'gesperrt = :gesperrt',
    'bezeichnung = :bezeichnung',
    'optionstage = :optionstage',
    'dauer = :dauer'
  );
  FILTER_PARAMS: array[0..36] of string = (
    'nr', 'code', 'kontingentcode', 'ltraeger', 'altervon', 'alterbis', 'preisvon',
    'preisbis', 'dauerbis', 'dauervon', 'stornierbar', 'provklasse', 'ustpflicht',
    'zahlbarsofort', 'rabatterlaubt', 'typ', 'subtyp', 'sachkonto', 'kostelle1',
    'kostelle2', 'capacity', 'maxcapacity', 'mincapacity', 'internet', 'suchbegriff',
    'stornostaffel', 'params', 'preisoption', 'tarifcode', 'versicherungsart',
    'onlinebuchung', 'kennziffer', 'app', 'gesperrt', 'bezeichnung', 'optionstage',
    'dauer'
  );
begin
  DoSelectFilteredDynamic('T_LEISTUNG', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /toupac/gett_leistungbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_LeistungById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..36] of string = (
    'nr','code','kontingentcode','ltraeger','buchungsinfo','altervon','alterbis','preisvon',
    'preisbis','dauerbis','dauervon','stornierbar','provklasse','ustpflicht','zahlbarsofort',
    'rabatterlaubt','typ','subtyp','sachkonto','kostelle1','kostelle2','capacity','maxcapacity',
    'mincapacity','internet','suchbegriff','stornostaffel','params','preisoption','tarifcode',
    'versicherungsart','onlinebuchung','kennziffer','app','gesperrt','bezeichnung','optionstage'
  );
begin
  DoSelectOne('T_LEISTUNG', ALLOWED, 'nr');
end;

// Route: /toupac/gett_leistungkey  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_LeistungKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(T_LEISTUNG_NR_GEN,1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /toupac/insertt_leistung  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.insertT_Leistung;
// Body: { "nr": 42, "code": "...", "bezeichnung": "...", ... }
const
  ALLOWED: array[0..36] of string = (
    'nr','code','kontingentcode','ltraeger','buchungsinfo','altervon','alterbis','preisvon',
    'preisbis','dauerbis','dauervon','stornierbar','provklasse','ustpflicht','zahlbarsofort',
    'rabatterlaubt','typ','subtyp','sachkonto','kostelle1','kostelle2','capacity','maxcapacity',
    'mincapacity','internet','suchbegriff','stornostaffel','params','preisoption','tarifcode',
    'versicherungsart','onlinebuchung','kennziffer','app','gesperrt','bezeichnung','optionstage'
  );
begin
  DoInsert('T_LEISTUNG', ALLOWED);
end;

// Route: /toupac/updatet_leistung  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.updateT_Leistung;
// Body: { "nr": 42, "code": "...", "bezeichnung": "...", ... }
const
  ALLOWED: array[0..36] of string = (
    'nr','code','kontingentcode','ltraeger','buchungsinfo','altervon','alterbis','preisvon',
    'preisbis','dauerbis','dauervon','stornierbar','provklasse','ustpflicht','zahlbarsofort',
    'rabatterlaubt','typ','subtyp','sachkonto','kostelle1','kostelle2','capacity','maxcapacity',
    'mincapacity','internet','suchbegriff','stornostaffel','params','preisoption','tarifcode',
    'versicherungsart','onlinebuchung','kennziffer','app','gesperrt','bezeichnung','optionstage'
  );
begin
  DoUpdate('T_LEISTUNG', ALLOWED, 'nr');
end;

// Route: /toupac/deletet_leistung  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.deleteT_Leistung;
// Body: { "nr": 42 }
begin
  DoDelete('T_LEISTUNG', 'nr');
end;


// Route: /toupac/gett_termine  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_Termine;
// Body: { "fields": ["nr","katalogreisenr",...] | "*", "orderby": "nr" }
const
  ALLOWED: array[0..20] of string = (
    'nr','katalogreisenr','von','bis','vw','vtage','bemerkung','storniert','gesperrt',
    'sonderangebot','internet','sachkonto','kostelle1','kostelle2','minimumpers','maximumpers',
    'provisionskonto','sachkontostorno','bemerkung_intern','abgesagt_am',
    'schnittstelle_sendtime'
  );
begin
  DoSelect('T_TERMINE', ALLOWED);
end;

// Route: /toupac/gett_terminefiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_TermineFiltered;
// Body: { "fields": [...] | "*", "katalogreisenr": 42, "gesperrt": "N", "orderby": "von" }
// Alle Filter-Parameter sind optional - nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..20] of string = (
    'nr','katalogreisenr','von','bis','vw','vtage','bemerkung','storniert','gesperrt',
    'sonderangebot','internet','sachkonto','kostelle1','kostelle2','minimumpers','maximumpers',
    'provisionskonto','sachkontostorno','bemerkung_intern','abgesagt_am',
    'schnittstelle_sendtime'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS uebereinstimmen).
  CONDITIONS: array[0..18] of string = (
    'nr = :nr',
    'katalogreisenr = :katalogreisenr',
    'von = :von',
    'bis = :bis',
    'vw = :vw',
    'vtage = :vtage',
    'storniert = :storniert',
    'gesperrt = :gesperrt',
    'sonderangebot = :sonderangebot',
    'internet = :internet',
    'sachkonto = :sachkonto',
    'kostelle1 = :kostelle1',
    'kostelle2 = :kostelle2',
    'minimumpers = :minimumpers',
    'maximumpers = :maximumpers',
    'provisionskonto = :provisionskonto',
    'sachkontostorno = :sachkontostorno',
    'abgesagt_am = :abgesagt_am',
    'schnittstelle_sendtime = :schnittstelle_sendtime'
  );
  FILTER_PARAMS: array[0..18] of string = (
    'nr', 'katalogreisenr', 'von', 'bis', 'vw', 'vtage', 'storniert', 'gesperrt',
    'sonderangebot', 'internet', 'sachkonto', 'kostelle1', 'kostelle2', 'minimumpers',
    'maximumpers', 'provisionskonto', 'sachkontostorno', 'abgesagt_am',
    'schnittstelle_sendtime'
  );
begin
  DoSelectFilteredDynamic('T_TERMINE', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /toupac/gett_terminebyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_TermineById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..20] of string = (
    'nr','katalogreisenr','von','bis','vw','vtage','bemerkung','storniert','gesperrt',
    'sonderangebot','internet','sachkonto','kostelle1','kostelle2','minimumpers','maximumpers',
    'provisionskonto','sachkontostorno','bemerkung_intern','abgesagt_am',
    'schnittstelle_sendtime'
  );
begin
  DoSelectOne('T_TERMINE', ALLOWED, 'nr');
end;

// Route: /toupac/gett_terminekey  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_TermineKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(T_TERMINE_NR_GEN,1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /toupac/insertt_termine  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.insertT_Termine;
// Body: { "nr": 42, "katalogreisenr": 1, "von": "...", ... }
const
  ALLOWED: array[0..20] of string = (
    'nr','katalogreisenr','von','bis','vw','vtage','bemerkung','storniert','gesperrt',
    'sonderangebot','internet','sachkonto','kostelle1','kostelle2','minimumpers','maximumpers',
    'provisionskonto','sachkontostorno','bemerkung_intern','abgesagt_am',
    'schnittstelle_sendtime'
  );
begin
  DoInsert('T_TERMINE', ALLOWED);
end;

// Route: /toupac/updatet_termine  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.updateT_Termine;
// Body: { "nr": 42, "katalogreisenr": 1, "von": "...", ... }
const
  ALLOWED: array[0..20] of string = (
    'nr','katalogreisenr','von','bis','vw','vtage','bemerkung','storniert','gesperrt',
    'sonderangebot','internet','sachkonto','kostelle1','kostelle2','minimumpers','maximumpers',
    'provisionskonto','sachkontostorno','bemerkung_intern','abgesagt_am',
    'schnittstelle_sendtime'
  );
begin
  DoUpdate('T_TERMINE', ALLOWED, 'nr');
end;

// Route: /toupac/deletet_termine  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.deleteT_Termine;
// Body: { "nr": 42 }
begin
  DoDelete('T_TERMINE', 'nr');
end;

// Route: /toupac/gett_reisedetail  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_Reisedetail;
// Body: { "fields": ["nr","reisenr",...] | "*", "orderby": "nr" }
const
  ALLOWED: array[0..3] of string = (
    'nr','reisenr','sprache','bezeichnung'
  );
begin
  DoSelect('T_REISEDETAIL', ALLOWED);
end;

// Route: /toupac/gett_reisedetailfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_ReisedetailFiltered;
// Body: { "fields": [...] | "*", "reisenr": 42, "sprache": "DEU", "orderby": "nr" }
// Alle Filter-Parameter sind optional – nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..3] of string = (
    'nr','reisenr','sprache','bezeichnung'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS übereinstimmen).
  CONDITIONS: array[0..3] of string = (
    'nr = :nr',
    'reisenr = :reisenr',
    'sprache = :sprache',
    'bezeichnung = :bezeichnung'
  );
  FILTER_PARAMS: array[0..3] of string = ('nr', 'reisenr', 'sprache', 'bezeichnung');
begin
  DoSelectFilteredDynamic('T_REISEDETAIL', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /toupac/gett_reisedetailbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_ReisedetailById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..3] of string = (
    'nr','reisenr','sprache','bezeichnung'
  );
begin
  DoSelectOne('T_REISEDETAIL', ALLOWED, 'nr');
end;

// Route: /toupac/gett_reisedetailkey  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.getT_ReisedetailKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(T_REISEDETAIL_NR_GEN,1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /toupac/insertt_reisedetail  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.insertT_Reisedetail;
// Body: { "nr": 42, "reisenr": 42, "sprache": "DEU", "bezeichnung": "..." }
const
  ALLOWED: array[0..3] of string = (
    'nr','reisenr','sprache','bezeichnung'
  );
begin
  DoInsert('T_REISEDETAIL', ALLOWED);
end;

// Route: /toupac/updatet_reisedetail  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.updateT_Reisedetail;
// Body: { "nr": 42, "bezeichnung": "...", ... }
const
  ALLOWED: array[0..3] of string = (
    'nr','reisenr','sprache','bezeichnung'
  );
begin
  DoUpdate('T_REISEDETAIL', ALLOWED, 'nr');
end;

// Route: /toupac/deletet_reisedetail  |  Auth: true  |  LocalOnly: false
procedure TDataModulToupac.deleteT_Reisedetail;
// Body: { "nr": 42 }
begin
  DoDelete('T_REISEDETAIL', 'nr');
end;

end.
