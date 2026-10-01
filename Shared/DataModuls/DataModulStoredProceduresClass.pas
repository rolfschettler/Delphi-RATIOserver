unit DataModulStoredProceduresClass;

interface

uses
  Web.HTTPApp,   System.JSON,
  DataModulTableBaseClass,
  System.SysUtils, System.Classes, DataModulBaseClass, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt, FireDAC.UI.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Phys, FireDAC.Phys.IB, FireDAC.Phys.IBDef, FireDAC.VCLUI.Wait, Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet;

type
  TDataModulStoredProcedures = class(TDataModulTableBase)
  private

    { Private-Deklarationen }
  public
    { Public-Deklarationen }
     procedure Demo;
     procedure SP_Zahlungen;
  end;


function CreateDataModulStoredProcedures(Request: TWebRequest; Response: TWebResponse): TObject;

implementation
uses webutils;

function CreateDataModulStoredProcedures(Request: TWebRequest; Response: TWebResponse): TObject;
begin
  Result := TDataModulStoredProcedures.Create(Request, Response);
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


procedure TDataModulStoredProcedures.Demo;
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


(*
  ===========================  SP_ZAHLUNGEN  ===========================
  Kapselt die Stored Procedure SP_ZAHLUNGEN(VORGANG, BEREICH, SELART).

  Die Prozedur ist SELECTABLE (enthaelt SUSPEND), liefert also ein
  Result-Set und wird per SELECT * FROM ... aufgerufen -- NICHT per
  EXECUTE PROCEDURE.

  ------------------------------- Eingabe -------------------------------
  Body (JSON):
    vorgang  CHAR(20)   PFLICHT. Rechnungsnummer = Belegfeld1 der FIBU.
                        Bei leerem Wert liefert die Prozedur nichts, daher
                        wird ein fehlender Parameter hier abgewiesen.
                        ACHTUNG: Bei bereich='TOUPAC' vergleicht die Prozedur
                        intern gegen T_VORGANG.RECHNUNGSNR (numerisch). Ein
                        nicht-numerischer Wert (z.B. 'GS18576') fuehrt dort zu
                        einem InterBase-Konversionsfehler -> HTTP 400.
                        Gutschein-Belege gehoeren nach bereich='GUTSCHEIN'.
    bereich  CHAR(20)   Optional. Von der Prozedur ausgewertet werden
                        'TOUPAC', 'TPSAMMEL' und 'GUTSCHEIN'. Bei anderen
                        Werten bleibt das Debitor-/Kreditorkonto intern
                        unbestimmt -- SELART 0 und 3 liefern dann leer.
    selart   INTEGER    Optional, Default 0.
                          0 = nur Zahlungen des Debitors
                          1 = alle Zahlungen
                          2 = Summe aller Zahlungen             (eine Zeile)
                          3 = Summe aller Zahlungen des Debitors(eine Zeile)

  ------------------------------ Rueckgabe ------------------------------
  Result-Set mit 14 Spalten im Standardformat von SerializeQuery
  (Objekt mit "header" und "data"):
    betrag, belegdatum, konto, text, debitor, erfasstdurch, erfasst_am,
    bezeichnung, kostelle1, kostelle2, vorlaufnr, journalisierungsnr,
    uebertragung, nr
  Bei SELART 2 und 3 ist nur betrag gefuellt, die uebrigen Spalten sind null.

  ----------------------------- Aufruf (Postman) ------------------------
    Methode : POST
    URL     : http://localhost/ibapi/storedprocedures/sp_zahlungen
    Header  : Authorization: Bearer <JWT-Token>
              Content-Type : application/json
    Body    : { "vorgang": "25000123", "bereich": "TOUPAC", "selart": 0 }
  ------------------------------------------------------------------------
*)

// Route: /storedprocedures/sp_zahlungen  |  Auth: true  |  LocalOnly: false
procedure TDataModulStoredProcedures.SP_Zahlungen;
// Body: { "vorgang": "25000123", "bereich": "TOUPAC", "selart": 0 }
var
  vorgang: string;
  bereich: string;
  selart:  Integer;
begin
  if not isParamFromBody('vorgang') then
    raise exception.Create('Parameter "vorgang" fehlt');

  vorgang := getParamFromBody('vorgang');
  bereich := getParamFromBody('bereich');
  selart  := StrToIntDef(getParamFromBody('selart'), 0);

  Query.Close;
  Query.SQL.Text := 'SELECT * FROM SP_ZAHLUNGEN(:vorgang, :bereich, :selart)';
  Query.ParamByName('vorgang').AsString := vorgang;
  Query.ParamByName('bereich').AsString := bereich;
  Query.ParamByName('selart').AsInteger := selart;
  Query.Open;

  // Kein Commit: reiner SELECT, es wurde keine Transaktion explizit gestartet
  // (StartTransaction/Commit nur bei schreibenden Operationen).
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;




end.
