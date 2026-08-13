unit DataModulAnmietClass;

interface

uses
  Web.HTTPApp,   System.JSON,
  DataModulTableBaseClass,
  System.SysUtils, System.Classes, DataModulBaseClass, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt, FireDAC.UI.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Phys, FireDAC.Phys.IB, FireDAC.Phys.IBDef, FireDAC.VCLUI.Wait, Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet,
  System.NetEncoding, System.RegularExpressions;

type
  TDataModulAnmiet = class(TDataModulTableBase)
  private

    { Private-Deklarationen }
  public
    { Public-Deklarationen }
     procedure Demo;

//     procedure getFahrtenbuch;
//     procedure getFahrtenbuchFiltered;
//     procedure getFahrtenbuchById;
//     procedure getFahrtenbuchKey;
//     procedure insertFahrtenbuch;
//     procedure updateFahrtenbuch;
//     procedure deleteFahrtenbuch;

     procedure getAnmiet;
     procedure getAnmietFiltered;
     procedure getAnmietById;
     procedure getAnmietKey;
     procedure insertAnmiet;
     procedure updateAnmiet;
     procedure deleteAnmiet;

     procedure getFundsachen;
     procedure getFundsachenFiltered;
     procedure getFundsachenById;
     procedure getFundsachenKey;
     procedure insertFundsachen;
     procedure insertFundsachenMitBildern;
     procedure updateFundsachen;
     procedure deleteFundsachen;
  end;


function CreateDataModulAnmiet(Request: TWebRequest; Response: TWebResponse): TObject;

implementation
uses webutils;

function CreateDataModulAnmiet(Request: TWebRequest; Response: TWebResponse): TObject;
begin
  Result := TDataModulAnmiet.Create(Request, Response);
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
    2) JSON-Body          -> isParamFromBody / getParamFromBody        (Beispiel-Parameter: name, menge)

  ----------------------------- Aufruf (Postman) -----------------------------
    Methode : POST   (GET reicht, wenn nur URL-Parameter genutzt werden)
    URL     : http://localhost:<port>/ibapi/anmiet/demo?id=42&filter=Mueller
    Header  : Authorization: Bearer <JWT-Token>     (Route verlangt Auth)
              Content-Type : application/json
    Body    : (raw / JSON, optional)
              { "name": "Helga", "menge": 5 }

    Test-Kombinationen:
      - nur URL   : POST /anmiet/demo?id=42&filter=Mueller   (Body leer lassen)
      - nur Body  : POST /anmiet/demo   Body { "name":"Helga","menge":5 }
      - gemischt  : beide Quellen gleichzeitig
      - nichts    : POST /anmiet/demo ohne Parameter -> alle Felder als null
    Fehlende Werte erzeugen KEINEN Fehler, sondern erscheinen im Ergebnis als null.
  ----------------------------------------------------------------------------
*)
procedure TDataModulAnmiet.Demo;
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






// Route: /anmiet/getanmiet  |  Auth: true  |  LocalOnly: false
procedure TDataModulAnmiet.getAnmiet;
// Body: { "fields": ["Field1","Field2",...] | "*", "orderby": "Field" }
const
  ALLOWED: array[0..134] of string = (
    'nr','vorgang','anrede','name1','name2','name3','land','plz',
    'ort','strasse','telefon','telefax','ziel','erstellt','kunde','preis',
    'status','von','bis','vonzeit','biszeit','vart','rueckort','stunden',
    'zustieg1','zustieg2','zustieg3','zustieg4','zustieg5','zustieg6',
    'zustiegzeit1','zustiegzeit2','zustiegzeit3','zustiegzeit4','zustiegzeit5','zustiegzeit6',
    'bearbeiter','perszahl','notiz','fahrerinfo','fahrtstrecke','optionsdatum','geaendert_am','kennzeichen',
    'fahrer','fahrer2','fahrtnr','kmleer','kmanfang','kmende','kmgesamt','personen',
    'buchungsdatum','datevkto','faellig','berechnung','gedruckt','erledigt','fest','uebernommen',
    'ausvorgang','haupttext','storniert','kalkulation','disponr','bereitstellung','bereitdatum','bereitzeiet',
    'basisvorgang','transferfahrt','symbol','eart','rueckzeit','abfahrtszeit','terminnr','bereich',
    'rueckzustieg','rueckabfahrt','rueckabzeit','fusstext','ansprechpartner','provsatz1','provsatz2','provsatz3',
    'provsteuer','transfehrnr','abfahrtsdatum','feld1','feld2','feld3','feld4','feld5',
    'feld6','feld7','feld8','datumfeld1','datumfeld2','ausstiegrueck','disponentinfo','kontaktentstehung',
    'reiseart','agentur','notiz2','azbis','rzbis','azbetrag','fahrtenplan','abrechnungsart',
    'nrkreis','ankunftort','ankunftdatum','ankunftzeit','fahrzeugprofil','fahrerprofil','filialnr','lzugriff',
    'lzugriff_von','stornogrund','sammelrechnung','anzahlung','anzfaelligam','zusatzinfo','stand','bereitstellung2',
    'ankunftort2','rueckort2','rueckzustieg2','fibu_archiv_am','bestellnummer','unterschrift','datumfeld3','datumfeld4',
    'schnittstelle_sendtime','geaendert_von','mandant'
  );
begin
  DoSelect('ANMIET', ALLOWED);
end;


      (*

// Route: /anmiet/getanmietfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulAnmiet.getAnmietFiltered;
// Body: { "fields": [...] | "*", "vorgang": "VG-2026-001", "orderby": "von" }
const
  ALLOWED: array[0..134] of string = (
    'nr','vorgang','anrede','name1','name2','name3','land','plz',
    'ort','strasse','telefon','telefax','ziel','erstellt','kunde','preis',
    'status','von','bis','vonzeit','biszeit','vart','rueckort','stunden',
    'zustieg1','zustieg2','zustieg3','zustieg4','zustieg5','zustieg6',
    'zustiegzeit1','zustiegzeit2','zustiegzeit3','zustiegzeit4','zustiegzeit5','zustiegzeit6',
    'bearbeiter','perszahl','notiz','fahrerinfo','fahrtstrecke','optionsdatum','geaendert_am','kennzeichen',
    'fahrer','fahrer2','fahrtnr','kmleer','kmanfang','kmende','kmgesamt','personen',
    'buchungsdatum','datevkto','faellig','berechnung','gedruckt','erledigt','fest','uebernommen',
    'ausvorgang','haupttext','storniert','kalkulation','disponr','bereitstellung','bereitdatum','bereitzeiet',
    'basisvorgang','transferfahrt','symbol','eart','rueckzeit','abfahrtszeit','terminnr','bereich',
    'rueckzustieg','rueckabfahrt','rueckabzeit','fusstext','ansprechpartner','provsatz1','provsatz2','provsatz3',
    'provsteuer','transfehrnr','abfahrtsdatum','feld1','feld2','feld3','feld4','feld5',
    'feld6','feld7','feld8','datumfeld1','datumfeld2','ausstiegrueck','disponentinfo','kontaktentstehung',
    'reiseart','agentur','notiz2','azbis','rzbis','azbetrag','fahrtenplan','abrechnungsart',
    'nrkreis','ankunftort','ankunftdatum','ankunftzeit','fahrzeugprofil','fahrerprofil','filialnr','lzugriff',
    'lzugriff_von','stornogrund','sammelrechnung','anzahlung','anzfaelligam','zusatzinfo','stand','bereitstellung2',
    'ankunftort2','rueckort2','rueckzustieg2','fibu_archiv_am','bestellnummer','unterschrift','datumfeld3','datumfeld4',
    'schnittstelle_sendtime','geaendert_von','mandant'
  );

//  FILTER        = 'vorgang = :vorgang';   //absoluter Filter
  FILTER        = '((vorgang = :vorgang) OR (cast(:vorgang as varchar(50)) is null))';           // Optionaler Filter
  FILTER_PARAMS: array[0..0] of string = ('vorgang');
begin
  DoSelectFiltered('ANMIET', ALLOWED, FILTER, FILTER_PARAMS);
end;


*)


// Route: /anmiet/getanmietfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulAnmiet.getAnmietFiltered;
// Body: { "fields": [...] | "*", "vorgang": "VG-2026-001", "orderby": "von" }
const
  ALLOWED: array[0..134] of string = (
    'nr','vorgang','anrede','name1','name2','name3','land','plz',
    'ort','strasse','telefon','telefax','ziel','erstellt','kunde','preis',
    'status','von','bis','vonzeit','biszeit','vart','rueckort','stunden',
    'zustieg1','zustieg2','zustieg3','zustieg4','zustieg5','zustieg6',
    'zustiegzeit1','zustiegzeit2','zustiegzeit3','zustiegzeit4','zustiegzeit5','zustiegzeit6',
    'bearbeiter','perszahl','notiz','fahrerinfo','fahrtstrecke','optionsdatum','geaendert_am','kennzeichen',
    'fahrer','fahrer2','fahrtnr','kmleer','kmanfang','kmende','kmgesamt','personen',
    'buchungsdatum','datevkto','faellig','berechnung','gedruckt','erledigt','fest','uebernommen',
    'ausvorgang','haupttext','storniert','kalkulation','disponr','bereitstellung','bereitdatum','bereitzeiet',
    'basisvorgang','transferfahrt','symbol','eart','rueckzeit','abfahrtszeit','terminnr','bereich',
    'rueckzustieg','rueckabfahrt','rueckabzeit','fusstext','ansprechpartner','provsatz1','provsatz2','provsatz3',
    'provsteuer','transfehrnr','abfahrtsdatum','feld1','feld2','feld3','feld4','feld5',
    'feld6','feld7','feld8','datumfeld1','datumfeld2','ausstiegrueck','disponentinfo','kontaktentstehung',
    'reiseart','agentur','notiz2','azbis','rzbis','azbetrag','fahrtenplan','abrechnungsart',
    'nrkreis','ankunftort','ankunftdatum','ankunftzeit','fahrzeugprofil','fahrerprofil','filialnr','lzugriff',
    'lzugriff_von','stornogrund','sammelrechnung','anzahlung','anzfaelligam','zusatzinfo','stand','bereitstellung2',
    'ankunftort2','rueckort2','rueckzustieg2','fibu_archiv_am','bestellnummer','unterschrift','datumfeld3','datumfeld4',
    'schnittstelle_sendtime','geaendert_von','mandant'
  );


    CONDITIONS: array[0..0] of string = (
    'vorgang = :vorgang'
     );

   FILTER_PARAMS: array[0..0] of string = ('vorgang');
begin
  DoSelectFilteredDynamic('ANMIET', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;



// Route: /anmiet/getanmietbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulAnmiet.getAnmietById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..134] of string = (
    'nr','vorgang','anrede','name1','name2','name3','land','plz',
    'ort','strasse','telefon','telefax','ziel','erstellt','kunde','preis',
    'status','von','bis','vonzeit','biszeit','vart','rueckort','stunden',
    'zustieg1','zustieg2','zustieg3','zustieg4','zustieg5','zustieg6',
    'zustiegzeit1','zustiegzeit2','zustiegzeit3','zustiegzeit4','zustiegzeit5','zustiegzeit6',
    'bearbeiter','perszahl','notiz','fahrerinfo','fahrtstrecke','optionsdatum','geaendert_am','kennzeichen',
    'fahrer','fahrer2','fahrtnr','kmleer','kmanfang','kmende','kmgesamt','personen',
    'buchungsdatum','datevkto','faellig','berechnung','gedruckt','erledigt','fest','uebernommen',
    'ausvorgang','haupttext','storniert','kalkulation','disponr','bereitstellung','bereitdatum','bereitzeiet',
    'basisvorgang','transferfahrt','symbol','eart','rueckzeit','abfahrtszeit','terminnr','bereich',
    'rueckzustieg','rueckabfahrt','rueckabzeit','fusstext','ansprechpartner','provsatz1','provsatz2','provsatz3',
    'provsteuer','transfehrnr','abfahrtsdatum','feld1','feld2','feld3','feld4','feld5',
    'feld6','feld7','feld8','datumfeld1','datumfeld2','ausstiegrueck','disponentinfo','kontaktentstehung',
    'reiseart','agentur','notiz2','azbis','rzbis','azbetrag','fahrtenplan','abrechnungsart',
    'nrkreis','ankunftort','ankunftdatum','ankunftzeit','fahrzeugprofil','fahrerprofil','filialnr','lzugriff',
    'lzugriff_von','stornogrund','sammelrechnung','anzahlung','anzfaelligam','zusatzinfo','stand','bereitstellung2',
    'ankunftort2','rueckort2','rueckzustieg2','fibu_archiv_am','bestellnummer','unterschrift','datumfeld3','datumfeld4',
    'schnittstelle_sendtime','geaendert_von','mandant'
  );
begin
  DoSelectOne('ANMIET', ALLOWED, 'nr');
end;

// Route: /anmiet/getanmietkey  |  Auth: true  |  LocalOnly: false
procedure TDataModulAnmiet.getAnmietKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(ANMIETNR, 1) FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /anmiet/insertanmiet  |  Auth: true  |  LocalOnly: false
procedure TDataModulAnmiet.insertAnmiet;
// Body: { "vorgang": "...", "name1": "...", ... }
const
  ALLOWED: array[0..133] of string = (
    'vorgang','anrede','name1','name2','name3','land','plz',
    'ort','strasse','telefon','telefax','ziel','erstellt','kunde','preis',
    'status','von','bis','vonzeit','biszeit','vart','rueckort','stunden',
    'zustieg1','zustieg2','zustieg3','zustieg4','zustieg5','zustieg6',
    'zustiegzeit1','zustiegzeit2','zustiegzeit3','zustiegzeit4','zustiegzeit5','zustiegzeit6',
    'bearbeiter','perszahl','notiz','fahrerinfo','fahrtstrecke','optionsdatum','geaendert_am','kennzeichen',
    'fahrer','fahrer2','fahrtnr','kmleer','kmanfang','kmende','kmgesamt','personen',
    'buchungsdatum','datevkto','faellig','berechnung','gedruckt','erledigt','fest','uebernommen',
    'ausvorgang','haupttext','storniert','kalkulation','disponr','bereitstellung','bereitdatum','bereitzeiet',
    'basisvorgang','transferfahrt','symbol','eart','rueckzeit','abfahrtszeit','terminnr','bereich',
    'rueckzustieg','rueckabfahrt','rueckabzeit','fusstext','ansprechpartner','provsatz1','provsatz2','provsatz3',
    'provsteuer','transfehrnr','abfahrtsdatum','feld1','feld2','feld3','feld4','feld5',
    'feld6','feld7','feld8','datumfeld1','datumfeld2','ausstiegrueck','disponentinfo','kontaktentstehung',
    'reiseart','agentur','notiz2','azbis','rzbis','azbetrag','fahrtenplan','abrechnungsart',
    'nrkreis','ankunftort','ankunftdatum','ankunftzeit','fahrzeugprofil','fahrerprofil','filialnr','lzugriff',
    'lzugriff_von','stornogrund','sammelrechnung','anzahlung','anzfaelligam','zusatzinfo','stand','bereitstellung2',
    'ankunftort2','rueckort2','rueckzustieg2','fibu_archiv_am','bestellnummer','unterschrift','datumfeld3','datumfeld4',
    'schnittstelle_sendtime','geaendert_von','mandant'
  );
begin
  DoInsert('ANMIET', ALLOWED);
end;

// Route: /anmiet/updateanmiet  |  Auth: true  |  LocalOnly: false
procedure TDataModulAnmiet.updateAnmiet;
// Body: { "nr": 42, "vorgang": "...", ... }
const
  ALLOWED: array[0..133] of string = (
    'vorgang','anrede','name1','name2','name3','land','plz',
    'ort','strasse','telefon','telefax','ziel','erstellt','kunde','preis',
    'status','von','bis','vonzeit','biszeit','vart','rueckort','stunden',
    'zustieg1','zustieg2','zustieg3','zustieg4','zustieg5','zustieg6',
    'zustiegzeit1','zustiegzeit2','zustiegzeit3','zustiegzeit4','zustiegzeit5','zustiegzeit6',
    'bearbeiter','perszahl','notiz','fahrerinfo','fahrtstrecke','optionsdatum','geaendert_am','kennzeichen',
    'fahrer','fahrer2','fahrtnr','kmleer','kmanfang','kmende','kmgesamt','personen',
    'buchungsdatum','datevkto','faellig','berechnung','gedruckt','erledigt','fest','uebernommen',
    'ausvorgang','haupttext','storniert','kalkulation','disponr','bereitstellung','bereitdatum','bereitzeiet',
    'basisvorgang','transferfahrt','symbol','eart','rueckzeit','abfahrtszeit','terminnr','bereich',
    'rueckzustieg','rueckabfahrt','rueckabzeit','fusstext','ansprechpartner','provsatz1','provsatz2','provsatz3',
    'provsteuer','transfehrnr','abfahrtsdatum','feld1','feld2','feld3','feld4','feld5',
    'feld6','feld7','feld8','datumfeld1','datumfeld2','ausstiegrueck','disponentinfo','kontaktentstehung',
    'reiseart','agentur','notiz2','azbis','rzbis','azbetrag','fahrtenplan','abrechnungsart',
    'nrkreis','ankunftort','ankunftdatum','ankunftzeit','fahrzeugprofil','fahrerprofil','filialnr','lzugriff',
    'lzugriff_von','stornogrund','sammelrechnung','anzahlung','anzfaelligam','zusatzinfo','stand','bereitstellung2',
    'ankunftort2','rueckort2','rueckzustieg2','fibu_archiv_am','bestellnummer','unterschrift','datumfeld3','datumfeld4',
    'schnittstelle_sendtime','geaendert_von','mandant'
  );
begin
  DoUpdate('ANMIET', ALLOWED, 'nr');
end;

// Route: /anmiet/deleteanmiet  |  Auth: true  |  LocalOnly: false
procedure TDataModulAnmiet.deleteAnmiet;
// Body: { "nr": 42 }
begin
  DoDelete('ANMIET', 'nr');
end;

// Route: /anmiet/getfundsachen  |  Auth: true  |  LocalOnly: false
procedure TDataModulAnmiet.getFundsachen;
// Body: { "fields": ["nr","abgeholt_am",...] | "*", "orderby": "erfasst_am" }
const
  ALLOWED: array[0..18] of string = (
    'nr','abgeholt_am','abgeholt_von','abholort','bearbeitet_am',
    'bearbeitet_von','beschreibung','bilder','bild_klein','erfasst_am',
    'erfasst_von','status','text_intern','unterschrift','verlustdatum',
    'verlustort','zusatzfeld1','zusatzfeld2','zusatzfeld3'
  );
begin
  DoSelect('FUNDSACHEN', ALLOWED);
end;

// Route: /anmiet/getfundsachenfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulAnmiet.getFundsachenFiltered;
// Body: { "fields": [...] | "*", "status": "offen", "verlustort": "Bahnhof", "orderby": "erfasst_am" }
// Alle Filter-Parameter sind optional – nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..18] of string = (
    'nr','abgeholt_am','abgeholt_von','abholort','bearbeitet_am',
    'bearbeitet_von','beschreibung','bilder','bild_klein','erfasst_am',
    'erfasst_von','status','text_intern','unterschrift','verlustdatum',
    'verlustort','zusatzfeld1','zusatzfeld2','zusatzfeld3'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS übereinstimmen).
  CONDITIONS: array[0..18] of string = (
    'nr = :nr',
    'abgeholt_am = :abgeholt_am',
    'abgeholt_von = :abgeholt_von',
    'abholort = :abholort',
    'bearbeitet_am = :bearbeitet_am',
    'bearbeitet_von = :bearbeitet_von',
    'beschreibung = :beschreibung',
    'bilder = :bilder',
    'bild_klein = :bild_klein',
    'erfasst_am = :erfasst_am',
    'erfasst_von = :erfasst_von',
    'status = :status',
    'text_intern = :text_intern',
    'unterschrift = :unterschrift',
    'verlustdatum = :verlustdatum',
    'verlustort = :verlustort',
    'zusatzfeld1 = :zusatzfeld1',
    'zusatzfeld2 = :zusatzfeld2',
    'zusatzfeld3 = :zusatzfeld3'
  );
  FILTER_PARAMS: array[0..15] of string = (
    'nr','abgeholt_am','abgeholt_von','abholort','bearbeitet_am',
    'bearbeitet_von','beschreibung','erfasst_am',
    'erfasst_von','status','text_intern','verlustdatum',
    'verlustort','zusatzfeld1','zusatzfeld2','zusatzfeld3'
  );
begin
  DoSelectFilteredDynamic('FUNDSACHEN', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /anmiet/getfundsachenbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulAnmiet.getFundsachenById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..18] of string = (
    'nr','abgeholt_am','abgeholt_von','abholort','bearbeitet_am',
    'bearbeitet_von','beschreibung','bilder','bild_klein','erfasst_am',
    'erfasst_von','status','text_intern','unterschrift','verlustdatum',
    'verlustort','zusatzfeld1','zusatzfeld2','zusatzfeld3'
  );
begin
  DoSelectOne('FUNDSACHEN', ALLOWED, 'nr');
end;

// Route: /anmiet/getfundsachenkey  |  Auth: true  |  LocalOnly: false
procedure TDataModulAnmiet.getFundsachenKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(FUNDSACHEN_NR_GEN, 1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /anmiet/insertfundsachen  |  Auth: true  |  LocalOnly: false
procedure TDataModulAnmiet.insertFundsachen;
// Body: { "beschreibung": "...", "verlustort": "...", "status": "offen", ... }
const
  ALLOWED: array[0..14] of string = (
    'abgeholt_am','abgeholt_von','abholort','bearbeitet_am',
    'bearbeitet_von','beschreibung','erfasst_am',
    'erfasst_von','status','text_intern','verlustdatum',
    'verlustort','zusatzfeld1','zusatzfeld2','zusatzfeld3'
  );
begin
  DoInsert('FUNDSACHEN', ALLOWED);
end;

// Prueft, ob AValue syntaktisch gueltiges Base64 ist (Zeichensatz + Laenge/Padding).
// Leerstring gilt als gueltig (entspricht einem leeren Blob).
function IsValidBase64Value(const AValue: string): Boolean;
begin
  Result := (AValue = '') or
    (((Length(AValue) mod 4) = 0) and
     TRegEx.IsMatch(AValue, '^[A-Za-z0-9+/]*={0,2}$'));
end;

// Route: /anmiet/insertfundsachenmitbildern  |  Auth: true  |  LocalOnly: false
procedure TDataModulAnmiet.insertFundsachenMitBildern;
// Body: { "beschreibung": "...", "verlustort": "...", "status": "offen", ...,
//         "bilder": "<Base64>", "bild_klein": "<Base64>", "unterschrift": "<Base64>" }
// Erweiterte WhiteList von insertFundsachen: dieselben Felder plus die drei
// Base64-codierten Blob-Felder. Alle Felder werden in einem einzigen INSERT
// geschrieben. Die Blob-Felder sind optional; JSON-null ist erlaubt (Blob
// bleibt dann NULL). Sind sie gesetzt, wird der Base64-Wert vor dem Schreiben
// auf syntaktische Gueltigkeit geprueft.
const
  ALLOWED: array[0..14] of string = (
    'abgeholt_am','abgeholt_von','abholort','bearbeitet_am',
    'bearbeitet_von','beschreibung','erfasst_am',
    'erfasst_von','status','text_intern','verlustdatum',
    'verlustort','zusatzfeld1','zusatzfeld2','zusatzfeld3'
  );
  BLOB_ALLOWED: array[0..2] of string = ('bilder','bild_klein','unterschrift');
var
  Q: TFDQuery;
  Cols, Vals, Field, Base64Value: string;
  Count, i: Integer;
  Bytes: TBytes;
  Stream: TMemoryStream;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := Connection;
    Cols := ''; Vals := ''; Count := 0;

    for i := Low(ALLOWED) to High(ALLOWED) do
      if isParamFromBody(ALLOWED[i]) then
      begin
        if Count > 0 then begin Cols := Cols + ','; Vals := Vals + ','; end;
        Cols := Cols + ALLOWED[i];
        Vals := Vals + ':' + ALLOWED[i];
        Inc(Count);
      end;

    for i := Low(BLOB_ALLOWED) to High(BLOB_ALLOWED) do
      if isKeyInBody(BLOB_ALLOWED[i]) then
      begin
        if Count > 0 then begin Cols := Cols + ','; Vals := Vals + ','; end;
        Cols := Cols + BLOB_ALLOWED[i];
        Vals := Vals + ':' + BLOB_ALLOWED[i];
        Inc(Count);
      end;

    if Count = 0 then
      raise Exception.Create('Keine gueltigen Felder uebergeben.');

    Q.SQL.Text := 'INSERT INTO FUNDSACHEN (' + Cols + ') VALUES (' + Vals + ')';

    for i := Low(ALLOWED) to High(ALLOWED) do
      if isParamFromBody(ALLOWED[i]) then
        Q.ParamByName(ALLOWED[i]).Value := getParamFromBody(ALLOWED[i]);

    for i := Low(BLOB_ALLOWED) to High(BLOB_ALLOWED) do
    begin
      Field := BLOB_ALLOWED[i];
      if not isKeyInBody(Field) then Continue;

      if not isParamFromBody(Field) then
      begin
        // Feld war im Body vorhanden, aber JSON-null -> Blob bleibt NULL.
        Q.ParamByName(Field).Clear;
        Continue;
      end;

      Base64Value := getParamFromBody(Field);
      if not IsValidBase64Value(Base64Value) then
        raise Exception.Create('Feld "' + Field + '": kein gueltiger Base64-Wert.');

      try
        Bytes := TNetEncoding.Base64.DecodeStringToBytes(Base64Value);
      except
        on E: Exception do
          raise Exception.Create('Feld "' + Field + '": Base64-Dekodierung fehlgeschlagen (' + E.Message + ').');
      end;

      Stream := TMemoryStream.Create;
      try
        if Length(Bytes) > 0 then
          Stream.WriteBuffer(Bytes[0], Length(Bytes));
        Stream.Position := 0;
        Q.ParamByName(Field).LoadFromStream(Stream, ftBlob);
      finally
        Stream.Free;
      end;
    end;

    Connection.StartTransaction;
    try
      Q.ExecSQL;
      Connection.Commit;
    except
      on E: Exception do
      begin
        if Connection.InTransaction then
          Connection.Rollback;
        raise;
      end;
    end;

    Response.ContentType := 'application/json';
    Response.StatusCode  := 200;
    Response.Content     := '{"status":"OK"}';
  finally
    Q.Free;
  end;
end;

// Route: /anmiet/updatefundsachen  |  Auth: true  |  LocalOnly: false
procedure TDataModulAnmiet.updateFundsachen;
// Body: { "nr": 42, "status": "abgeholt", "abgeholt_am": "2026-07-17", ... }
const
  ALLOWED: array[0..14] of string = (
    'abgeholt_am','abgeholt_von','abholort','bearbeitet_am',
    'bearbeitet_von','beschreibung','erfasst_am',
    'erfasst_von','status','text_intern','verlustdatum',
    'verlustort','zusatzfeld1','zusatzfeld2','zusatzfeld3'
  );
begin
  DoUpdate('FUNDSACHEN', ALLOWED, 'nr');
end;

// Route: /anmiet/deletefundsachen  |  Auth: true  |  LocalOnly: false
procedure TDataModulAnmiet.deleteFundsachen;
// Body: { "nr": 42 }
begin
  DoDelete('FUNDSACHEN', 'nr');
end;

end.
