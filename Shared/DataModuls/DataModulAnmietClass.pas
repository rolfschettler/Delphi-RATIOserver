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
    2) JSON-Body          -> ParseJSONObject        (Beispiel-Parameter: name, menge)

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
