unit DataModulAnmietClass;

interface

uses
  Web.HTTPApp,   System.JSON,
  DataModulTableBaseClass,
  System.SysUtils, System.Classes, DataModulBaseClass, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt, FireDAC.UI.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Phys, FireDAC.Phys.IB, FireDAC.Phys.IBDef, FireDAC.VCLUI.Wait, Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet;

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

end.
