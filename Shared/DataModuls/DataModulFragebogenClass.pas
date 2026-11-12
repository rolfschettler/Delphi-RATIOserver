unit DataModulFragebogenClass;

interface

uses
  Web.HTTPApp,   System.JSON,
  DataModulTableBaseClass,
  System.SysUtils, System.Classes, DataModulBaseClass, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt, FireDAC.UI.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Phys, FireDAC.Phys.IB, FireDAC.Phys.IBDef, FireDAC.VCLUI.Wait, Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet;

type
  // ═══════════════════════════════════════════════════════════════════════════
  //  Fragebogen / Kartei-Konfiguration
  //
  //  Pflege der Formular-Definitionen: FORM_KARTEI (die Karteien selbst) und
  //  FORM_PAT_PROPERTY (die Felder einer Kartei). Aufrufer ist die interne
  //  Angular-Anwendung mit Bearer-Token (Auth=true, LocalOnly=false).
  //
  //  Das AUSFÜLLEN durch einen Gast liegt NICHT hier, sondern in
  //  DataModulPublicClass (getFormularByToken ...): dort sitzt
  //  ValidatePublicToken, und die Token-Prüfung gibt es genau einmal.
  //
  //  Neue Schlüssel kommen aus dem Generator, bevor eingefügt wird - nicht
  //  über SELECT MAX(id) danach, das wäre bei gleichzeitigen Aufrufen falsch.
  // ═══════════════════════════════════════════════════════════════════════════
  TDataModulFragebogen = class(TDataModulTableBase)
  private
    // Fehlerantwort {"status":"ERROR","message":"..."} - dasselbe Format wie
    // in DataModulPublicClass; Angular liest err.error.message.
    procedure SendFehler(const AMessage: string; AStatusCode: Integer = 400);
    // {"status":"OK","id":<AId>}
    procedure SendOkMitId(AId: Integer);
    procedure SendOk;

    // Nächster Wert des Generators. AGenerator kommt immer aus einer
    // Konstanten dieser Unit, nie aus dem Request.
    function NeueId(const AGenerator: string): Integer;

    // Führt Query.SQL in einer eigenen Transaktion aus.
    procedure ExecInTransaktion;

    function KarteiExistiert(AId: Integer): Boolean;

    // Ganze Zahl aus dem Body. Fehlt der Schlüssel oder ist er null, gilt
    // ADefault. Steht dort etwas, das keine ganze Zahl ist, ist das ein
    // Fehler und kein stiller Standardwert.
    function GanzzahlAusBody(const AKey: string; ADefault: Integer;
      out AWert: Integer): Boolean;

    // Prüft die Feld-Eigenschaften aus dem Body. ANeu=True: Pflichtfelder
    // müssen da sein. Fehlende Werte beim Update werden aus AAlt ergänzt,
    // damit z.B. "Optionen nötig" auch bei einer Teil-Änderung greift.
    function PruefeProperty(ANeu: Boolean; const AAltProptyp, AAltOptions: string;
      out AFehler: string): Boolean;
  public
    { Public-Deklarationen }
     procedure Demo;

    // Karteien
    procedure getKartei;
    procedure insertKartei;
    procedure updateKartei;
    procedure deleteKartei;
    procedure copyKartei;

    // Felder einer Kartei
    procedure getPropertiesForKartei;
    procedure insertProperty;
    procedure updateProperty;
    procedure deleteProperty;
  end;


function CreateDataModulFragebogen(Request: TWebRequest; Response: TWebResponse): TObject;

implementation
uses webutils;

const
  // Erlaubte Feldtypen. Bedeutung: Text, Zahl, Datum, Checkbox,
  // Optionsfeld, Auswahlliste einfach, Auswahlliste mehrfach.
  PROPTYPEN: array[0..6] of string = ('TXT','NUM','DAT','CHK','RDO','SEL','MUL');

  // Typen, die eine kommagetrennte Optionsliste brauchen.
  PROPTYPEN_MIT_OPTIONEN: array[0..2] of string = ('RDO','SEL','MUL');

  // Lesbare Spalten von FORM_KARTEI.
  KARTEI_LESEN: array[0..2] of string = ('id','karteiname','beschreibung');

  // Schreibbare Spalten von FORM_KARTEI (ohne Schlüssel).
  KARTEI_SCHREIBEN: array[0..1] of string = ('karteiname','beschreibung');

  // Schreibbare Spalten von FORM_PAT_PROPERTY. Bewusst OHNE 'system' (ein
  // Systemfeld darf über die API weder entstehen noch verschwinden) und ohne
  // 'kartei_id' (ein Feld wandert nicht in eine andere Kartei; beim Anlegen
  // wird sie fest gesetzt).
  PROPERTY_SCHREIBEN: array[0..4] of string = ('label','proptyp','options','bereich','sortierung');

  MAX_KARTEINAME    = 80;
  MAX_BESCHREIBUNG  = 255;
  MAX_LABEL         = 255;
  MAX_BEREICH       = 60;
  KOPIE_SUFFIX      = ' (Kopie)';

function CreateDataModulFragebogen(Request: TWebRequest; Response: TWebResponse): TObject;
begin
  Result := TDataModulFragebogen.Create(Request, Response);
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


procedure TDataModulFragebogen.Demo;
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


// ═══════════════════════════════════════════════════════════════════════════
//  Hilfsfunktionen
// ═══════════════════════════════════════════════════════════════════════════

procedure TDataModulFragebogen.SendFehler(const AMessage: string;
  AStatusCode: Integer);
var
  Obj: TJSONObject;
begin
  Obj := TJSONObject.Create;
  Obj.AddPair('status',  'ERROR');
  Obj.AddPair('message', AMessage);
  SendJson(Obj, AStatusCode);
end;

procedure TDataModulFragebogen.SendOkMitId(AId: Integer);
var
  Obj: TJSONObject;
begin
  Obj := TJSONObject.Create;
  Obj.AddPair('status', 'OK');
  Obj.AddPair('id',     TJSONNumber.Create(AId));
  SendJson(Obj);
end;

procedure TDataModulFragebogen.SendOk;
var
  Obj: TJSONObject;
begin
  Obj := TJSONObject.Create;
  Obj.AddPair('status', 'OK');
  SendJson(Obj);
end;

function TDataModulFragebogen.NeueId(const AGenerator: string): Integer;
begin
  Query.Close;
  Query.SQL.Text := 'SELECT GEN_ID(' + AGenerator + ', 1) AS NEUE_ID FROM RDB$DATABASE';
  Query.Open;
  try
    Result := Query.Fields[0].AsInteger;
  finally
    Query.Close;
  end;
end;

procedure TDataModulFragebogen.ExecInTransaktion;
begin
  Connection.StartTransaction;
  try
    Query.ExecSQL;
    Connection.Commit;
  except
    if Connection.InTransaction then
      Connection.Rollback;
    raise;
  end;
  Query.Close;
end;

function TDataModulFragebogen.KarteiExistiert(AId: Integer): Boolean;
begin
  Query.Close;
  Query.SQL.Text := 'SELECT ID FROM FORM_KARTEI WHERE ID = :id';
  Query.ParamByName('id').AsInteger := AId;
  Query.Open;
  try
    Result := not Query.IsEmpty;
  finally
    Query.Close;
  end;
end;

function TDataModulFragebogen.GanzzahlAusBody(const AKey: string;
  ADefault: Integer; out AWert: Integer): Boolean;
var
  Text: string;
begin
  AWert := ADefault;
  if not isParamFromBody(AKey) then
    Exit(True);
  Text := Trim(getParamFromBody(AKey));
  if Text = '' then
    Exit(True);
  Result := TryStrToInt(Text, AWert);
end;

function TDataModulFragebogen.PruefeProperty(ANeu: Boolean;
  const AAltProptyp, AAltOptions: string; out AFehler: string): Boolean;
var
  Proptyp, Options: string;
  Sortierung:       Integer;
begin
  Result  := False;
  AFehler := '';

  if ANeu or isKeyInBody('label') then
  begin
    if Trim(getParamFromBody('label')) = '' then
    begin
      AFehler := 'Beschriftung ist ein Pflichtfeld.';
      Exit;
    end;
    if Length(Trim(getParamFromBody('label'))) > MAX_LABEL then
    begin
      AFehler := Format('Die Beschriftung darf höchstens %d Zeichen lang sein.', [MAX_LABEL]);
      Exit;
    end;
  end;

  if ANeu or isKeyInBody('proptyp') then
    Proptyp := UpperCase(Trim(getParamFromBody('proptyp')))
  else
    Proptyp := UpperCase(Trim(AAltProptyp));

  if not IsAllowed(Proptyp, PROPTYPEN) then
  begin
    AFehler := 'Unbekannte Art des Feldes: "' + Proptyp + '".';
    Exit;
  end;

  if ANeu or isKeyInBody('options') then
    Options := Trim(getParamFromBody('options'))
  else
    Options := Trim(AAltOptions);

  if IsAllowed(Proptyp, PROPTYPEN_MIT_OPTIONEN) and (Options = '') then
  begin
    AFehler := 'Für diese Art des Feldes ist mindestens eine Option nötig.';
    Exit;
  end;

  if isKeyInBody('bereich')
     and (Length(Trim(getParamFromBody('bereich'))) > MAX_BEREICH) then
  begin
    AFehler := Format('Der Bereich darf höchstens %d Zeichen lang sein.', [MAX_BEREICH]);
    Exit;
  end;

  if not GanzzahlAusBody('sortierung', 0, Sortierung) then
  begin
    AFehler := 'Die Sortierung muss eine ganze Zahl sein.';
    Exit;
  end;

  Result := True;
end;


// ═══════════════════════════════════════════════════════════════════════════
//  Karteien
// ═══════════════════════════════════════════════════════════════════════════

// Route: /fragebogen/getkartei  |  Auth: true  |  LocalOnly: false
// Body:  { "fields": "*", "orderby": "karteiname" }
procedure TDataModulFragebogen.getKartei;
begin
  DoSelect('FORM_KARTEI', KARTEI_LESEN);
end;

// Route: /fragebogen/insertkartei  |  Auth: true  |  LocalOnly: false
// Body:  { "karteiname": "...", "beschreibung": "..." | null }
// Antwort: { "status": "OK", "id": <neue ID> }
procedure TDataModulFragebogen.insertKartei;
var
  Name, Beschreibung: string;
  Id:                 Integer;
begin
  Name         := Trim(getParamFromBody('karteiname'));
  Beschreibung := Trim(getParamFromBody('beschreibung'));

  if Name = '' then
  begin
    SendFehler('Name ist ein Pflichtfeld.');
    Exit;
  end;
  if Length(Name) > MAX_KARTEINAME then
  begin
    SendFehler(Format('Der Name darf höchstens %d Zeichen lang sein.', [MAX_KARTEINAME]));
    Exit;
  end;
  if Length(Beschreibung) > MAX_BESCHREIBUNG then
  begin
    SendFehler(Format('Die Beschreibung darf höchstens %d Zeichen lang sein.', [MAX_BESCHREIBUNG]));
    Exit;
  end;

  Id := NeueId('FORM_KARTEI_ID_GEN');

  Query.Close;
  Query.SQL.Text :=
    'INSERT INTO FORM_KARTEI (ID, KARTEINAME, BESCHREIBUNG) ' +
    'VALUES (:id, :karteiname, :beschreibung)';
  Query.ParamByName('id').AsInteger         := Id;
  Query.ParamByName('karteiname').AsString  := Name;
  if Beschreibung = '' then
  begin
    Query.ParamByName('beschreibung').DataType := ftString;
    Query.ParamByName('beschreibung').Clear;
  end
  else
    Query.ParamByName('beschreibung').AsString := Beschreibung;
  ExecInTransaktion;

  SendOkMitId(Id);
end;

// Route: /fragebogen/updatekartei  |  Auth: true  |  LocalOnly: false
// Body:  { "id": 3, "karteiname": "...", "beschreibung": "..." | null }
procedure TDataModulFragebogen.updateKartei;
var
  Id: Integer;
begin
  if not GanzzahlAusBody('id', 0, Id) or (Id <= 0) then
  begin
    SendFehler('"id" fehlt oder ist keine Zahl.');
    Exit;
  end;
  if isKeyInBody('karteiname') then
  begin
    if Trim(getParamFromBody('karteiname')) = '' then
    begin
      SendFehler('Name ist ein Pflichtfeld.');
      Exit;
    end;
    if Length(Trim(getParamFromBody('karteiname'))) > MAX_KARTEINAME then
    begin
      SendFehler(Format('Der Name darf höchstens %d Zeichen lang sein.', [MAX_KARTEINAME]));
      Exit;
    end;
  end;
  if Length(Trim(getParamFromBody('beschreibung'))) > MAX_BESCHREIBUNG then
  begin
    SendFehler(Format('Die Beschreibung darf höchstens %d Zeichen lang sein.', [MAX_BESCHREIBUNG]));
    Exit;
  end;
  if not KarteiExistiert(Id) then
  begin
    SendFehler('Kartei nicht gefunden.', 404);
    Exit;
  end;

  DoUpdate('FORM_KARTEI', KARTEI_SCHREIBEN, 'id');
end;

// Route: /fragebogen/deletekartei  |  Auth: true  |  LocalOnly: false
// Body:  { "id": 3 }
// Felder (FORM_PAT_PROPERTY), ausgestellte Formulare (FORM_KARTEI_HISTORY)
// und deren Werte (FORM_KARTEI_CONTENT) löscht die Datenbank per
// ON DELETE CASCADE mit.
procedure TDataModulFragebogen.deleteKartei;
begin
  DoDelete('FORM_KARTEI', 'id');
end;

// Route: /fragebogen/copykartei  |  Auth: true  |  LocalOnly: false
// Body:  { "id": 3 }
// Antwort: { "status": "OK", "id": <ID der Kopie> }
//
// Kartei und alle ihre Felder in EINER Transaktion: entweder ist die Kopie
// vollständig da oder gar nicht. Ausgefüllte Formulare werden nicht kopiert.
procedure TDataModulFragebogen.copyKartei;
var
  AltId, NeuId:       Integer;
  Name, Beschreibung: string;
  BeschreibungNull:   Boolean;
begin
  if not GanzzahlAusBody('id', 0, AltId) or (AltId <= 0) then
  begin
    SendFehler('"id" fehlt oder ist keine Zahl.');
    Exit;
  end;

  Query.Close;
  Query.SQL.Text := 'SELECT KARTEINAME, BESCHREIBUNG FROM FORM_KARTEI WHERE ID = :id';
  Query.ParamByName('id').AsInteger := AltId;
  Query.Open;
  try
    if Query.IsEmpty then
    begin
      SendFehler('Kartei nicht gefunden.', 404);
      Exit;
    end;
    Name             := Trim(Query.FieldByName('KARTEINAME').AsString);
    BeschreibungNull := Query.FieldByName('BESCHREIBUNG').IsNull;
    Beschreibung     := Query.FieldByName('BESCHREIBUNG').AsString;
  finally
    Query.Close;
  end;

  // Der Name muss mit Zusatz in VARCHAR(80) passen.
  Name  := Copy(Name, 1, MAX_KARTEINAME - Length(KOPIE_SUFFIX)) + KOPIE_SUFFIX;
  NeuId := NeueId('FORM_KARTEI_ID_GEN');

  Connection.StartTransaction;
  try
    Query.Close;
    Query.SQL.Text :=
      'INSERT INTO FORM_KARTEI (ID, KARTEINAME, BESCHREIBUNG) ' +
      'VALUES (:id, :karteiname, :beschreibung)';
    Query.ParamByName('id').AsInteger        := NeuId;
    Query.ParamByName('karteiname').AsString := Name;
    if BeschreibungNull then
    begin
      Query.ParamByName('beschreibung').DataType := ftString;
      Query.ParamByName('beschreibung').Clear;
    end
    else
      Query.ParamByName('beschreibung').AsString := Beschreibung;
    Query.ExecSQL;

    // Die neue Kartei-ID steht direkt im SQL: sie stammt aus dem Generator,
    // nicht aus dem Request, und ein Parameter in der SELECT-Liste eines
    // INSERT ... SELECT ist unter InterBase nicht typisierbar.
    // Die Feld-IDs vergibt der Trigger TI_FORM_PAT_PROPERTY.
    Query.Close;
    Query.SQL.Text :=
      'INSERT INTO FORM_PAT_PROPERTY ' +
      '  (LABEL, PROPTYP, OPTIONS, MAXWIDTH, BEREICH, SORTIERUNG, SYSTEM, KARTEI_ID) ' +
      'SELECT LABEL, PROPTYP, OPTIONS, MAXWIDTH, BEREICH, SORTIERUNG, SYSTEM, ' +
      IntToStr(NeuId) + ' ' +
      'FROM FORM_PAT_PROPERTY WHERE KARTEI_ID = :alt';
    Query.ParamByName('alt').AsInteger := AltId;
    Query.ExecSQL;

    Connection.Commit;
  except
    if Connection.InTransaction then
      Connection.Rollback;
    raise;
  end;
  Query.Close;

  SendOkMitId(NeuId);
end;


// ═══════════════════════════════════════════════════════════════════════════
//  Felder einer Kartei
// ═══════════════════════════════════════════════════════════════════════════

// Route: /fragebogen/getpropertiesforkartei  |  Auth: true  |  LocalOnly: false
// Body:  { "kartei_id": 3 }
// Antwort: { "header": {...}, "data": [ {id, label, proptyp, options, maxwidth,
//            bereich, sortierung, system, kartei_id, inuse}, ... ] }
//
// "inuse" ist die Anzahl gespeicherter Werte zu diesem Feld (0 = unbenutzt).
// Die Oberfläche warnt damit vor dem Löschen.
procedure TDataModulFragebogen.getPropertiesForKartei;
var
  KarteiId: Integer;
begin
  if not GanzzahlAusBody('kartei_id', 0, KarteiId) or (KarteiId <= 0) then
  begin
    SendFehler('"kartei_id" fehlt oder ist keine Zahl.');
    Exit;
  end;

  Query.Close;
  Query.SQL.Text :=
    'SELECT p.id, p.label, p.proptyp, p.options, p.maxwidth, p.bereich, ' +
    '       p.sortierung, p.system, p.kartei_id, ' +
    '       (SELECT COUNT(*) FROM FORM_KARTEI_CONTENT c ' +
    '         WHERE c.kartei_property_id = p.id) AS inuse ' +
    'FROM FORM_PAT_PROPERTY p ' +
    'WHERE p.kartei_id = :kartei_id ' +
    'ORDER BY p.sortierung, p.id';
  Query.ParamByName('kartei_id').AsInteger := KarteiId;
  Query.Open;
  try
    Response.ContentType := 'application/json';
    Response.StatusCode  := 200;
    Response.Content     := SerializeQuery(Query);
  finally
    Query.Close;
  end;
end;

// Route: /fragebogen/insertproperty  |  Auth: true  |  LocalOnly: false
// Body:  { "kartei_id": 3, "label": "...", "proptyp": "SEL",
//          "options": "a,b,c" | null, "bereich": "..." | null, "sortierung": 10 }
// Antwort: { "status": "OK", "id": <neue ID> }
procedure TDataModulFragebogen.insertProperty;
var
  KarteiId, Id, Sortierung: Integer;
  Fehler, Proptyp:          string;
  Options, Bereich:         string;
begin
  if not GanzzahlAusBody('kartei_id', 0, KarteiId) or (KarteiId <= 0) then
  begin
    SendFehler('"kartei_id" fehlt oder ist keine Zahl.');
    Exit;
  end;
  if not PruefeProperty(True, '', '', Fehler) then
  begin
    SendFehler(Fehler);
    Exit;
  end;
  if not KarteiExistiert(KarteiId) then
  begin
    SendFehler('Kartei nicht gefunden.', 404);
    Exit;
  end;

  Proptyp := UpperCase(Trim(getParamFromBody('proptyp')));
  Options := Trim(getParamFromBody('options'));
  Bereich := Trim(getParamFromBody('bereich'));
  GanzzahlAusBody('sortierung', 0, Sortierung);   // in PruefeProperty geprüft

  // Optionen nur bei Typen, die sie brauchen - sonst blieben bei einem
  // Textfeld Reste einer früheren Auswahlliste stehen.
  if not IsAllowed(Proptyp, PROPTYPEN_MIT_OPTIONEN) then
    Options := '';

  Id := NeueId('FORM_PAT_PROPERTY_ID_GEN');

  Query.Close;
  Query.SQL.Text :=
    'INSERT INTO FORM_PAT_PROPERTY ' +
    '  (ID, LABEL, PROPTYP, OPTIONS, BEREICH, SORTIERUNG, SYSTEM, KARTEI_ID) ' +
    'VALUES (:id, :label, :proptyp, :options, :bereich, :sortierung, 0, :kartei_id)';
  Query.ParamByName('id').AsInteger        := Id;
  Query.ParamByName('label').AsString      := Trim(getParamFromBody('label'));
  Query.ParamByName('proptyp').AsString    := Proptyp;
  if Options = '' then
  begin
    Query.ParamByName('options').DataType := ftWideMemo;
    Query.ParamByName('options').Clear;
  end
  else
    Query.ParamByName('options').AsWideMemo := Options;
  if Bereich = '' then
  begin
    Query.ParamByName('bereich').DataType := ftString;
    Query.ParamByName('bereich').Clear;
  end
  else
    Query.ParamByName('bereich').AsString := Bereich;
  Query.ParamByName('sortierung').AsInteger := Sortierung;
  Query.ParamByName('kartei_id').AsInteger  := KarteiId;
  ExecInTransaktion;

  SendOkMitId(Id);
end;

// Route: /fragebogen/updateproperty  |  Auth: true  |  LocalOnly: false
// Body:  { "id": 7, <beliebige Teilmenge von label, proptyp, options,
//          bereich, sortierung> }
// Nur die mitgeschickten Spalten werden geschrieben (Schnellbearbeitung von
// Bereich/Sortierung schickt z.B. nur eines davon). Ein leerer Bereich oder
// leere Optionen werden zu NULL.
procedure TDataModulFragebogen.updateProperty;
var
  Id, Sortierung:            Integer;
  AltProptyp, AltOptions:    string;
  Fehler, Feld, SetKlausel:  string;
  NeuProptyp, Wert:          string;
  I:                         Integer;
begin
  if not GanzzahlAusBody('id', 0, Id) or (Id <= 0) then
  begin
    SendFehler('"id" fehlt oder ist keine Zahl.');
    Exit;
  end;

  Query.Close;
  Query.SQL.Text := 'SELECT PROPTYP, OPTIONS, SYSTEM FROM FORM_PAT_PROPERTY WHERE ID = :id';
  Query.ParamByName('id').AsInteger := Id;
  Query.Open;
  try
    if Query.IsEmpty then
    begin
      SendFehler('Feld nicht gefunden.', 404);
      Exit;
    end;
    // Systemfelder sind geschützt - die Oberfläche sperrt sie nur optisch,
    // verbindlich ist diese Prüfung.
    if Query.FieldByName('SYSTEM').AsInteger = 1 then
    begin
      SendFehler('Systemfeld - geschützt.', 403);
      Exit;
    end;
    AltProptyp := Query.FieldByName('PROPTYP').AsString;
    AltOptions := Query.FieldByName('OPTIONS').AsString;
  finally
    Query.Close;
  end;

  if not PruefeProperty(False, AltProptyp, AltOptions, Fehler) then
  begin
    SendFehler(Fehler);
    Exit;
  end;

  SetKlausel := '';
  for I := Low(PROPERTY_SCHREIBEN) to High(PROPERTY_SCHREIBEN) do
  begin
    Feld := PROPERTY_SCHREIBEN[I];
    if not isKeyInBody(Feld) then
      Continue;
    if SetKlausel <> '' then
      SetKlausel := SetKlausel + ', ';
    SetKlausel := SetKlausel + Feld + ' = :' + Feld;
  end;

  if SetKlausel = '' then
  begin
    SendFehler('Keine gültigen Felder übergeben.');
    Exit;
  end;

  Query.Close;
  Query.SQL.Text := 'UPDATE FORM_PAT_PROPERTY SET ' + SetKlausel + ' WHERE ID = :id';

  if isKeyInBody('proptyp') then
    NeuProptyp := UpperCase(Trim(getParamFromBody('proptyp')))
  else
    NeuProptyp := UpperCase(Trim(AltProptyp));

  for I := Low(PROPERTY_SCHREIBEN) to High(PROPERTY_SCHREIBEN) do
  begin
    Feld := PROPERTY_SCHREIBEN[I];
    if not isKeyInBody(Feld) then
      Continue;
    Wert := Trim(getParamFromBody(Feld));

    if Feld = 'sortierung' then
    begin
      GanzzahlAusBody('sortierung', 0, Sortierung);   // in PruefeProperty geprüft
      Query.ParamByName(Feld).AsInteger := Sortierung;
    end
    else if Feld = 'proptyp' then
      Query.ParamByName(Feld).AsString := NeuProptyp
    else if Feld = 'options' then
    begin
      if (Wert = '') or not IsAllowed(NeuProptyp, PROPTYPEN_MIT_OPTIONEN) then
      begin
        Query.ParamByName(Feld).DataType := ftWideMemo;
        Query.ParamByName(Feld).Clear;
      end
      else
        Query.ParamByName(Feld).AsWideMemo := Wert;
    end
    else if Wert = '' then
    begin
      // nur 'bereich' kann hier leer sein - 'label' hat PruefeProperty abgewiesen
      Query.ParamByName(Feld).DataType := ftString;
      Query.ParamByName(Feld).Clear;
    end
    else
      Query.ParamByName(Feld).AsString := Wert;
  end;

  Query.ParamByName('id').AsInteger := Id;
  ExecInTransaktion;

  SendOk;
end;

// Route: /fragebogen/deleteproperty  |  Auth: true  |  LocalOnly: false
// Body:  { "id": 7 }
// Gespeicherte Werte zu diesem Feld löscht die Datenbank per CASCADE mit.
procedure TDataModulFragebogen.deleteProperty;
var
  Id: Integer;
begin
  if not GanzzahlAusBody('id', 0, Id) or (Id <= 0) then
  begin
    SendFehler('"id" fehlt oder ist keine Zahl.');
    Exit;
  end;

  Query.Close;
  Query.SQL.Text := 'SELECT SYSTEM FROM FORM_PAT_PROPERTY WHERE ID = :id';
  Query.ParamByName('id').AsInteger := Id;
  Query.Open;
  try
    if Query.IsEmpty then
    begin
      SendFehler('Feld nicht gefunden.', 404);
      Exit;
    end;
    if Query.FieldByName('SYSTEM').AsInteger = 1 then
    begin
      SendFehler('Systemfeld - geschützt.', 403);
      Exit;
    end;
  finally
    Query.Close;
  end;

  Query.Close;
  Query.SQL.Text := 'DELETE FROM FORM_PAT_PROPERTY WHERE ID = :id';
  Query.ParamByName('id').AsInteger := Id;
  ExecInTransaktion;

  SendOk;
end;


end.
