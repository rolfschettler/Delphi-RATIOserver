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
    2) JSON-Body          -> ParseJSONObject        (Beispiel-Parameter: name, menge)

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
  idText    := Trim(Request.QueryFields.Values['id']);
  idGesetzt := idText <> '';
  id        := StrToIntDef(idText, 0);

  filter := Trim(Request.QueryFields.Values['filter']);

  // ===== 2) Parameter aus dem JSON-Body =====
  name         := '';
  nameGesetzt  := False;
  menge        := 0;
  mengeGesetzt := False;

  Body := ParseJSONObject(Request.Content);
  if Assigned(Body) then
  try
    name        := Trim(Body.GetValue<string>('name', ''));
    nameGesetzt := name <> '';

    mengeVal := Body.GetValue('menge');
    if Assigned(mengeVal) and not mengeVal.Null then
    begin
      menge        := StrToIntDef(mengeVal.Value, 0);
      mengeGesetzt := True;
    end;
  finally
    Body.Free;
  end;

  // ===== 3) Antwort aufbauen =====
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

    Ergebnis.AddPair('url',  UrlObj);
    Ergebnis.AddPair('body', BodyObj);

    Response.ContentType := 'application/json';
    Response.StatusCode  := 200;
    Response.Content     := Ergebnis.ToJSON;
  finally
    Ergebnis.Free;
  end;
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
  FILTER        = 'agenturnr = :agenturnr';
  FILTER_PARAMS: array[0..0] of string = ('agenturnr');
begin
  DoSelectFiltered('T_VORGANG', ALLOWED, FILTER, FILTER_PARAMS);
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

end.
