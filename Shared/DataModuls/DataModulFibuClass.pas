unit DataModulFibuClass;

interface

uses
  Web.HTTPApp,   System.JSON,
  DataModulTableBaseClass,
  System.SysUtils, System.Classes, DataModulBaseClass, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt, FireDAC.UI.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Phys, FireDAC.Phys.IB, FireDAC.Phys.IBDef, FireDAC.VCLUI.Wait, Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet;

type
  TDataModulFibu = class(TDataModulTableBase)
  private

    { Private-Deklarationen }
  public
    { Public-Deklarationen }
     procedure Demo;
     procedure getBruttolohn;
     procedure getBruttolohnFiltered;
     procedure getBruttolohnById;
     procedure getBruttolohnKey;
     procedure insertBruttolohn;
     procedure updateBruttolohn;
     procedure deleteBruttolohn;
     procedure getGutschein;
     procedure getGutscheinFiltered;
     procedure getGutscheinById;
     procedure getGutscheinKey;
     procedure insertGutschein;
     procedure updateGutschein;
     procedure deleteGutschein;
     procedure getDevisenkasse;
     procedure getDevisenkasseFiltered;
     procedure getDevisenkasseById;
     procedure getDevisenkasseKey;
     procedure insertDevisenkasse;
     procedure updateDevisenkasse;
     procedure deleteDevisenkasse;
     procedure getLohnart;
     procedure getLohnartFiltered;
     procedure getLohnartById;
     procedure getFibu;
     procedure getFibuFiltered;
     procedure getFibuById;
     procedure getFibuKey;
     procedure insertFibu;
     procedure updateFibu;
     procedure deleteFibu;
     procedure getKonten;
     procedure getKontenFiltered;
     procedure getKontenById;
  end;


function CreateDataModulFibu(Request: TWebRequest; Response: TWebResponse): TObject;

implementation
uses webutils;

function CreateDataModulFibu(Request: TWebRequest; Response: TWebResponse): TObject;
begin
  Result := TDataModulFibu.Create(Request, Response);
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


procedure TDataModulFibu.Demo;
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

// Route: /fibu/getbruttolohn  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.getBruttolohn;
// Body: { "fields": ["nr","monteurzeichen",...] | "*", "orderby": "datum" }
const
  ALLOWED: array[0..27] of string = (
    'nr','monteurzeichen','lohnart','datum','einheit','satz','gesamtbetrag',
    'auftragnr','kostenstelle','positionsnr','extauftragnr','extpos',
    'positiosnr','zuschlag','herkunft','faktor','bezeichnung','fahrzeug',
    'kostenstelle1','kostenstelle2','vonzeit','biszeit','kmanfang','kmende',
    'kmgesamt','zusatzfeld1','zusatzfeld2','kommentar'
  );
begin
  DoSelect('BRUTTOLOHN', ALLOWED);
end;

// Route: /fibu/getbruttolohnfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.getBruttolohnFiltered;
// Body: { "fields": [...] | "*", "monteurzeichen": "MZ01", "datum": "2026-07-17", "orderby": "datum" }
// Alle Filter-Parameter sind optional – nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..27] of string = (
    'nr','monteurzeichen','lohnart','datum','einheit','satz','gesamtbetrag',
    'auftragnr','kostenstelle','positionsnr','extauftragnr','extpos',
    'positiosnr','zuschlag','herkunft','faktor','bezeichnung','fahrzeug',
    'kostenstelle1','kostenstelle2','vonzeit','biszeit','kmanfang','kmende',
    'kmgesamt','zusatzfeld1','zusatzfeld2','kommentar'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS übereinstimmen).
  CONDITIONS: array[0..27] of string = (
    'nr = :nr',
    'monteurzeichen = :monteurzeichen',
    'lohnart = :lohnart',
    'datum = :datum',
    'einheit = :einheit',
    'satz = :satz',
    'gesamtbetrag = :gesamtbetrag',
    'auftragnr = :auftragnr',
    'kostenstelle = :kostenstelle',
    'positionsnr = :positionsnr',
    'extauftragnr = :extauftragnr',
    'extpos = :extpos',
    'positiosnr = :positiosnr',
    'zuschlag = :zuschlag',
    'herkunft = :herkunft',
    'faktor = :faktor',
    'bezeichnung = :bezeichnung',
    'fahrzeug = :fahrzeug',
    'kostenstelle1 = :kostenstelle1',
    'kostenstelle2 = :kostenstelle2',
    'vonzeit = :vonzeit',
    'biszeit = :biszeit',
    'kmanfang = :kmanfang',
    'kmende = :kmende',
    'kmgesamt = :kmgesamt',
    'zusatzfeld1 = :zusatzfeld1',
    'zusatzfeld2 = :zusatzfeld2',
    'kommentar = :kommentar'
  );
  FILTER_PARAMS: array[0..27] of string = (
    'nr','monteurzeichen','lohnart','datum','einheit','satz','gesamtbetrag',
    'auftragnr','kostenstelle','positionsnr','extauftragnr','extpos',
    'positiosnr','zuschlag','herkunft','faktor','bezeichnung','fahrzeug',
    'kostenstelle1','kostenstelle2','vonzeit','biszeit','kmanfang','kmende',
    'kmgesamt','zusatzfeld1','zusatzfeld2','kommentar'
  );
begin
  DoSelectFilteredDynamic('BRUTTOLOHN', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /fibu/getbruttolohnbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.getBruttolohnById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..27] of string = (
    'nr','monteurzeichen','lohnart','datum','einheit','satz','gesamtbetrag',
    'auftragnr','kostenstelle','positionsnr','extauftragnr','extpos',
    'positiosnr','zuschlag','herkunft','faktor','bezeichnung','fahrzeug',
    'kostenstelle1','kostenstelle2','vonzeit','biszeit','kmanfang','kmende',
    'kmgesamt','zusatzfeld1','zusatzfeld2','kommentar'
  );
begin
  DoSelectOne('BRUTTOLOHN', ALLOWED, 'nr');
end;

// Route: /fibu/getbruttolohnkey  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.getBruttolohnKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(BRUTTOLOHN, 1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /fibu/insertbruttolohn  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.insertBruttolohn;
// Body: { "monteurzeichen": "MZ01", "lohnart": 1, "datum": "2026-07-17", ... }
const
  ALLOWED: array[0..26] of string = (
    'monteurzeichen','lohnart','datum','einheit','satz','gesamtbetrag',
    'auftragnr','kostenstelle','positionsnr','extauftragnr','extpos',
    'positiosnr','zuschlag','herkunft','faktor','bezeichnung','fahrzeug',
    'kostenstelle1','kostenstelle2','vonzeit','biszeit','kmanfang','kmende',
    'kmgesamt','zusatzfeld1','zusatzfeld2','kommentar'
  );
begin
  DoInsert('BRUTTOLOHN', ALLOWED);
end;

// Route: /fibu/updatebruttolohn  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.updateBruttolohn;
// Body: { "nr": 42, "satz": 15.5, "gesamtbetrag": 620.00, ... }
const
  ALLOWED: array[0..26] of string = (
    'monteurzeichen','lohnart','datum','einheit','satz','gesamtbetrag',
    'auftragnr','kostenstelle','positionsnr','extauftragnr','extpos',
    'positiosnr','zuschlag','herkunft','faktor','bezeichnung','fahrzeug',
    'kostenstelle1','kostenstelle2','vonzeit','biszeit','kmanfang','kmende',
    'kmgesamt','zusatzfeld1','zusatzfeld2','kommentar'
  );
begin
  DoUpdate('BRUTTOLOHN', ALLOWED, 'nr');
end;

// Route: /fibu/deletebruttolohn  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.deleteBruttolohn;
// Body: { "nr": 42 }
begin
  DoDelete('BRUTTOLOHN', 'nr');
end;

// Route: /fibu/getgutschein  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.getGutschein;
// Body: { "fields": ["nr","vorgang",...] | "*", "orderby": "erfasst" }
const
  ALLOWED: array[0..30] of string = (
    'nr','vorgang','bearbeiter','geaendert_am','geaendert_von','erfasst',
    'faellig','kennziffer','gutscheinkonto','kurzbemerkung','bemerkung',
    'betrag','gueltig_bis','erledigt','storniert','storniert_am',
    'stornogrund','fuerkunde','zusatzfeld1','zusatzfeld2','zusatzfeld3',
    'fibukto','kulanz','kostelle1','kostelle2','code','motivnr',
    'fibu_archiv_am','nrkreis','entstehung','zahlungsart'
  );
begin
  DoSelect('GUTSCHEIN', ALLOWED);
end;

// Route: /fibu/getgutscheinfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.getGutscheinFiltered;
// Body: { "fields": [...] | "*", "vorgang": "V001", "erledigt": "N", "orderby": "erfasst" }
// Alle Filter-Parameter sind optional – nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..30] of string = (
    'nr','vorgang','bearbeiter','geaendert_am','geaendert_von','erfasst',
    'faellig','kennziffer','gutscheinkonto','kurzbemerkung','bemerkung',
    'betrag','gueltig_bis','erledigt','storniert','storniert_am',
    'stornogrund','fuerkunde','zusatzfeld1','zusatzfeld2','zusatzfeld3',
    'fibukto','kulanz','kostelle1','kostelle2','code','motivnr',
    'fibu_archiv_am','nrkreis','entstehung','zahlungsart'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS übereinstimmen).
  CONDITIONS: array[0..30] of string = (
    'nr = :nr',
    'vorgang = :vorgang',
    'bearbeiter = :bearbeiter',
    'geaendert_am = :geaendert_am',
    'geaendert_von = :geaendert_von',
    'erfasst = :erfasst',
    'faellig = :faellig',
    'kennziffer = :kennziffer',
    'gutscheinkonto = :gutscheinkonto',
    'kurzbemerkung = :kurzbemerkung',
    'bemerkung = :bemerkung',
    'betrag = :betrag',
    'gueltig_bis = :gueltig_bis',
    'erledigt = :erledigt',
    'storniert = :storniert',
    'storniert_am = :storniert_am',
    'stornogrund = :stornogrund',
    'fuerkunde = :fuerkunde',
    'zusatzfeld1 = :zusatzfeld1',
    'zusatzfeld2 = :zusatzfeld2',
    'zusatzfeld3 = :zusatzfeld3',
    'fibukto = :fibukto',
    'kulanz = :kulanz',
    'kostelle1 = :kostelle1',
    'kostelle2 = :kostelle2',
    'code = :code',
    'motivnr = :motivnr',
    'fibu_archiv_am = :fibu_archiv_am',
    'nrkreis = :nrkreis',
    'entstehung = :entstehung',
    'zahlungsart = :zahlungsart'
  );
  FILTER_PARAMS: array[0..30] of string = (
    'nr','vorgang','bearbeiter','geaendert_am','geaendert_von','erfasst',
    'faellig','kennziffer','gutscheinkonto','kurzbemerkung','bemerkung',
    'betrag','gueltig_bis','erledigt','storniert','storniert_am',
    'stornogrund','fuerkunde','zusatzfeld1','zusatzfeld2','zusatzfeld3',
    'fibukto','kulanz','kostelle1','kostelle2','code','motivnr',
    'fibu_archiv_am','nrkreis','entstehung','zahlungsart'
  );
begin
  DoSelectFilteredDynamic('GUTSCHEIN', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /fibu/getgutscheinbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.getGutscheinById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..30] of string = (
    'nr','vorgang','bearbeiter','geaendert_am','geaendert_von','erfasst',
    'faellig','kennziffer','gutscheinkonto','kurzbemerkung','bemerkung',
    'betrag','gueltig_bis','erledigt','storniert','storniert_am',
    'stornogrund','fuerkunde','zusatzfeld1','zusatzfeld2','zusatzfeld3',
    'fibukto','kulanz','kostelle1','kostelle2','code','motivnr',
    'fibu_archiv_am','nrkreis','entstehung','zahlungsart'
  );
begin
  DoSelectOne('GUTSCHEIN', ALLOWED, 'nr');
end;

// Route: /fibu/getgutscheinkey  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.getGutscheinKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(GUTSCHEIN_NR_GEN, 1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /fibu/insertgutschein  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.insertGutschein;
// Body: { "vorgang": "V001", "bearbeiter": "SUPERVISOR", "betrag": 50.00, ... }
// Insert und BUILDGSFIBU(nr) laufen in einer gemeinsamen Transaktion. RETURNING
// wird von InterBase nicht unterstuetzt, daher wird die Primaernummer vorab
// wie in getGutscheinKey per GEN_ID(GUTSCHEIN_NR_GEN,1) ermittelt.
const
  ALLOWED: array[0..29] of string = (
    'vorgang','bearbeiter','geaendert_am','geaendert_von','erfasst',
    'faellig','kennziffer','gutscheinkonto','kurzbemerkung','bemerkung',
    'betrag','gueltig_bis','erledigt','storniert','storniert_am',
    'stornogrund','fuerkunde','zusatzfeld1','zusatzfeld2','zusatzfeld3',
    'fibukto','kulanz','kostelle1','kostelle2','code','motivnr',
    'fibu_archiv_am','nrkreis','entstehung','zahlungsart'
  );
var
  Cols, Vals, Field, Vorgang: string;
  i, NewNr, NrKreisVal: Integer;
  ResultObj: TJSONObject;

  // Migriert aus TGutscheinmaskeform.NextRechnungsNr (Desktop-Anwendung) auf FireDAC.
  // Ermittelt den naechsten Wert des zum NRKreis gehoerenden Generators
  // (Generatorname GS_NRKREIS<NRKreis>, Fallback GS_NRKREIS1, falls nicht vorhanden).
  function NextRechnungsNr(NRKreis: Integer): Integer;
  var
    genName: string;
    TmpQuery: TFDQuery;
  begin
    genName := 'GS_NRKREIS1';
    TmpQuery := TFDQuery.Create(nil);
    try
      TmpQuery.Connection := Connection;

      TmpQuery.SQL.Text := 'SELECT RDB$GENERATOR_NAME AS GENERATORNAME FROM RDB$GENERATORS ' +
        'WHERE RDB$GENERATOR_NAME = ''GS_NRKREIS' + IntToStr(NRKreis) + '''';
      TmpQuery.Open;

      if TmpQuery.Eof then
        raise Exception.Create('Generator nicht vorhanden.');

      genName := TmpQuery.FieldByName('generatorname').AsString;

      TmpQuery.Close;
      TmpQuery.SQL.Text := 'SELECT GEN_ID(' + genName + ', 1) AS NR FROM RDB$DATABASE';
      TmpQuery.Open;
      Result := TmpQuery.FieldByName('nr').AsInteger;
    finally
      TmpQuery.Free;
    end;
  end;

begin
  // 'vorgang' wird nicht aus dem Body uebernommen, sondern immer serverseitig
  // erzeugt (siehe Ermittlung von Vorgang weiter unten) und daher hier uebersprungen.
  Cols := 'nr,vorgang'; Vals := ':nr,:vorgang';
  for i := Low(ALLOWED) to High(ALLOWED) do
  begin
    Field := ALLOWED[i];
    if Field = 'vorgang' then Continue;
    if not isParamFromBody(Field) then Continue;
    Cols := Cols + ',' + Field;
    Vals := Vals + ',:' + Field;
  end;

  Connection.StartTransaction;
  try
    Query.Close;
    Query.SQL.Text := 'SELECT GEN_ID(GUTSCHEIN_NR_GEN, 1) AS nr FROM RDB$DATABASE';
    Query.Open;
    NewNr := Query.FieldByName('nr').AsInteger;
    Query.Close;

    // Migriert aus TGutscheinmaskeform: ist ein Nummernkreis (nrkreis > 0) angegeben,
    // wird die Rechnungsnr. ueber dessen Generator (NextRechnungsNr) ermittelt,
    // andernfalls ueber den Standardgenerator GUTSCHEIN_VORGANG_GEN.
    NrKreisVal := StrToIntDef(getParamFromBody('nrkreis', '0'), 0);
    if NrKreisVal > 0 then
      Vorgang := 'GS' + IntToStr(NextRechnungsNr(NrKreisVal))
    else
    begin
      Query.Close;
      Query.SQL.Text := 'SELECT GEN_ID(GUTSCHEIN_VORGANG_GEN, 1) AS nr FROM RDB$DATABASE';
      Query.Open;
      Vorgang := 'GS' + Query.FieldByName('nr').AsString;
      Query.Close;
    end;

    Query.SQL.Text := 'INSERT INTO GUTSCHEIN (' + Cols + ') VALUES (' + Vals + ')';
    Query.ParamByName('nr').AsInteger := NewNr;
    Query.ParamByName('vorgang').AsString := Vorgang;
    for i := Low(ALLOWED) to High(ALLOWED) do
    begin
      Field := ALLOWED[i];
      if Field = 'vorgang' then Continue;
      if isParamFromBody(Field) then
        Query.ParamByName(Field).AsString := getParamFromBody(Field);
    end;
    Query.ExecSQL;

    Query.SQL.Text := 'EXECUTE PROCEDURE BUILDGSFIBU(:nr)';
    Query.ParamByName('nr').AsInteger := NewNr;
    Query.ExecSQL;

    Connection.Commit;
  except
    on E: Exception do
    begin
      if Connection.InTransaction then Connection.Rollback;
      raise;
    end;
  end;

  ResultObj := TJSONObject.Create;
  ResultObj.AddPair('status', 'OK');
  ResultObj.AddPair('nr', TJSONNumber.Create(NewNr));
  ResultObj.AddPair('vorgang', Vorgang);
  SendJson(ResultObj);
end;

// Route: /fibu/updategutschein  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.updateGutschein;
// Body: { "nr": 42, "erledigt": "J", "storniert": "N", ... }
// Update und BUILDGSFIBU(nr) laufen in einer gemeinsamen Transaktion.
const
  ALLOWED: array[0..29] of string = (
    'vorgang','bearbeiter','geaendert_am','geaendert_von','erfasst',
    'faellig','kennziffer','gutscheinkonto','kurzbemerkung','bemerkung',
    'betrag','gueltig_bis','erledigt','storniert','storniert_am',
    'stornogrund','fuerkunde','zusatzfeld1','zusatzfeld2','zusatzfeld3',
    'fibukto','kulanz','kostelle1','kostelle2','code','motivnr',
    'fibu_archiv_am','nrkreis','entstehung','zahlungsart'
  );
var
  SetClause, Field: string;
  i, Count, NewNr: Integer;
  ResultObj: TJSONObject;
begin
  if not isParamFromBody('nr') then
    raise Exception.Create('"nr" fehlt.');
  if not TryStrToInt(getParamFromBody('nr'), NewNr) then
    raise Exception.CreateFmt('"nr" ist keine gueltige Zahl: %s', [getParamFromBody('nr')]);

  SetClause := ''; Count := 0;
  for i := Low(ALLOWED) to High(ALLOWED) do
  begin
    Field := ALLOWED[i];
    if not isKeyInBody(Field) then Continue;
    if Count > 0 then SetClause := SetClause + ',';
    SetClause := SetClause + Field + '=:' + Field;
    Inc(Count);
  end;

  if Count = 0 then
    raise Exception.Create('Keine gueltigen Felder uebergeben.');

  Connection.StartTransaction;
  try
    Query.Close;
    Query.SQL.Text := 'UPDATE GUTSCHEIN SET ' + SetClause + ' WHERE nr=:nr';
    Query.ParamByName('nr').AsInteger := NewNr;
    for i := Low(ALLOWED) to High(ALLOWED) do
    begin
      Field := ALLOWED[i];
      if isKeyInBody(Field) then
      begin
        if isParamFromBody(Field) then
          Query.ParamByName(Field).AsString := getParamFromBody(Field)
        else
          Query.ParamByName(Field).Clear;   // Body-Wert war explizit null -> Spalte auf NULL setzen
      end;
    end;
    Query.ExecSQL;

    Query.SQL.Text := 'EXECUTE PROCEDURE BUILDGSFIBU(:nr)';
    Query.ParamByName('nr').AsInteger := NewNr;
    Query.ExecSQL;

    Connection.Commit;
  except
    on E: Exception do
    begin
      if Connection.InTransaction then Connection.Rollback;
      raise;
    end;
  end;

  ResultObj := TJSONObject.Create;
  ResultObj.AddPair('status', 'OK');
  ResultObj.AddPair('nr', TJSONNumber.Create(NewNr));
  SendJson(ResultObj);
end;

// Route: /fibu/deletegutschein  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.deleteGutschein;
// Body: { "nr": 42 }
// Delete und BUILDGSFIBU(nr) laufen in einer gemeinsamen Transaktion.
var
  NewNr: Integer;
  ResultObj: TJSONObject;
begin
  if not isParamFromBody('nr') then
    raise Exception.Create('"nr" fehlt.');
  if not TryStrToInt(getParamFromBody('nr'), NewNr) then
    raise Exception.CreateFmt('"nr" ist keine gueltige Zahl: %s', [getParamFromBody('nr')]);

  Connection.StartTransaction;
  try
    Query.Close;
    Query.SQL.Text := 'DELETE FROM GUTSCHEIN WHERE nr=:nr';
    Query.ParamByName('nr').AsInteger := NewNr;
    Query.ExecSQL;

    Query.SQL.Text := 'EXECUTE PROCEDURE BUILDGSFIBU(:nr)';
    Query.ParamByName('nr').AsInteger := NewNr;
    Query.ExecSQL;

    Connection.Commit;
  except
    on E: Exception do
    begin
      if Connection.InTransaction then Connection.Rollback;
      raise;
    end;
  end;

  ResultObj := TJSONObject.Create;
  ResultObj.AddPair('status', 'OK');
  ResultObj.AddPair('nr', TJSONNumber.Create(NewNr));
  SendJson(ResultObj);
end;

// Route: /fibu/getdevisenkasse  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.getDevisenkasse;
// Body: { "fields": ["nr","belegnr",...] | "*", "orderby": "bdatum" }
const
  ALLOWED: array[0..21] of string = (
    'nr','belegnr','bdatum','expedient','waehrung','betrag','referenznr',
    'bereich','kostelle1','kostelle2','gesperrt','konto','gegenkonto',
    'belegart','art','leistung','zusatzfeld1','bemerkung','wechselkurs',
    'anmietnr','anmiet_uebertragung','fibu_uebertragung'
  );
begin
  DoSelect('DEVISENKASSE', ALLOWED);
end;

// Route: /fibu/getdevisenkassefiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.getDevisenkasseFiltered;
// Body: { "fields": [...] | "*", "waehrung": "USD", "expedient": "MZ01", "orderby": "bdatum" }
// Alle Filter-Parameter sind optional – nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..21] of string = (
    'nr','belegnr','bdatum','expedient','waehrung','betrag','referenznr',
    'bereich','kostelle1','kostelle2','gesperrt','konto','gegenkonto',
    'belegart','art','leistung','zusatzfeld1','bemerkung','wechselkurs',
    'anmietnr','anmiet_uebertragung','fibu_uebertragung'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS übereinstimmen).
  CONDITIONS: array[0..21] of string = (
    'nr = :nr',
    'belegnr = :belegnr',
    'bdatum = :bdatum',
    'expedient = :expedient',
    'waehrung = :waehrung',
    'betrag = :betrag',
    'referenznr = :referenznr',
    'bereich = :bereich',
    'kostelle1 = :kostelle1',
    'kostelle2 = :kostelle2',
    'gesperrt = :gesperrt',
    'konto = :konto',
    'gegenkonto = :gegenkonto',
    'belegart = :belegart',
    'art = :art',
    'leistung = :leistung',
    'zusatzfeld1 = :zusatzfeld1',
    'bemerkung = :bemerkung',
    'wechselkurs = :wechselkurs',
    'anmietnr = :anmietnr',
    'anmiet_uebertragung = :anmiet_uebertragung',
    'fibu_uebertragung = :fibu_uebertragung'
  );
  FILTER_PARAMS: array[0..21] of string = (
    'nr','belegnr','bdatum','expedient','waehrung','betrag','referenznr',
    'bereich','kostelle1','kostelle2','gesperrt','konto','gegenkonto',
    'belegart','art','leistung','zusatzfeld1','bemerkung','wechselkurs',
    'anmietnr','anmiet_uebertragung','fibu_uebertragung'
  );
begin
  DoSelectFilteredDynamic('DEVISENKASSE', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /fibu/getdevisenkassebyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.getDevisenkasseById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..21] of string = (
    'nr','belegnr','bdatum','expedient','waehrung','betrag','referenznr',
    'bereich','kostelle1','kostelle2','gesperrt','konto','gegenkonto',
    'belegart','art','leistung','zusatzfeld1','bemerkung','wechselkurs',
    'anmietnr','anmiet_uebertragung','fibu_uebertragung'
  );
begin
  DoSelectOne('DEVISENKASSE', ALLOWED, 'nr');
end;

// Route: /fibu/getdevisenkassekey  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.getDevisenkasseKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(DEVISENKASSE_NR_GEN, 1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /fibu/insertdevisenkasse  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.insertDevisenkasse;
// Body: { "belegnr": 100, "bdatum": "2026-07-24", "waehrung": "USD", "betrag": 250.00, ... }
const
  ALLOWED: array[0..20] of string = (
    'belegnr','bdatum','expedient','waehrung','betrag','referenznr',
    'bereich','kostelle1','kostelle2','gesperrt','konto','gegenkonto',
    'belegart','art','leistung','zusatzfeld1','bemerkung','wechselkurs',
    'anmietnr','anmiet_uebertragung','fibu_uebertragung'
  );
begin
  DoInsert('DEVISENKASSE', ALLOWED);
end;

// Route: /fibu/updatedevisenkasse  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.updateDevisenkasse;
// Body: { "nr": 42, "betrag": 300.00, "waehrung": "EUR", ... }
const
  ALLOWED: array[0..20] of string = (
    'belegnr','bdatum','expedient','waehrung','betrag','referenznr',
    'bereich','kostelle1','kostelle2','gesperrt','konto','gegenkonto',
    'belegart','art','leistung','zusatzfeld1','bemerkung','wechselkurs',
    'anmietnr','anmiet_uebertragung','fibu_uebertragung'
  );
begin
  DoUpdate('DEVISENKASSE', ALLOWED, 'nr');
end;

// Route: /fibu/deletedevisenkasse  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.deleteDevisenkasse;
// Body: { "nr": 42 }
begin
  DoDelete('DEVISENKASSE', 'nr');
end;

// Route: /fibu/getlohnart  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.getLohnart;
// Body: { "fields": ["lohnart","bezeichnung",...] | "*", "orderby": "reihenfolge" }
const
  ALLOWED: array[0..9] of string = (
    'lohnart','bezeichnung','stdlohn','vorgabe','zuschlag','fest',
    'kalkuliertauf','faktor','reihenfolge','saldouebernahme'
  );
begin
  DoSelect('LOHNART', ALLOWED);
end;

// Route: /fibu/getlohnartfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.getLohnartFiltered;
// Body: { "fields": [...] | "*", "lohnart": 10, "fest": "J", "orderby": "reihenfolge" }
// Alle Filter-Parameter sind optional - nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..9] of string = (
    'lohnart','bezeichnung','stdlohn','vorgabe','zuschlag','fest',
    'kalkuliertauf','faktor','reihenfolge','saldouebernahme'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS uebereinstimmen).
  CONDITIONS: array[0..9] of string = (
    'lohnart = :lohnart',
    'bezeichnung = :bezeichnung',
    'stdlohn = :stdlohn',
    'vorgabe = :vorgabe',
    'zuschlag = :zuschlag',
    'fest = :fest',
    'kalkuliertauf = :kalkuliertauf',
    'faktor = :faktor',
    'reihenfolge = :reihenfolge',
    'saldouebernahme = :saldouebernahme'
  );
  FILTER_PARAMS: array[0..9] of string = (
    'lohnart','bezeichnung','stdlohn','vorgabe','zuschlag','fest',
    'kalkuliertauf','faktor','reihenfolge','saldouebernahme'
  );
begin
  DoSelectFilteredDynamic('LOHNART', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /fibu/getlohnartbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.getLohnartById;
// Body: { "lohnart": 10, "fields": [...] | "*" }
const
  ALLOWED: array[0..9] of string = (
    'lohnart','bezeichnung','stdlohn','vorgabe','zuschlag','fest',
    'kalkuliertauf','faktor','reihenfolge','saldouebernahme'
  );
begin
  DoSelectOne('LOHNART', ALLOWED, 'lohnart');
end;

// Route: /fibu/getfibu  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.getFibu;
// Body: { "fields": ["nr","betrag",...] | "*", "orderby": "belegdatum" }
const
  ALLOWED: array[0..43] of string = (
    'nr','betrag','soll','haben','belegfeld1','belegfeld2','belegdatum',
    'kostelle1','kostelle2','skonto','text','gebucht','art','rechnungnr',
    'stschl','ustbetrag','steuerkonto','stkontotyp','stsatz','stapel','opos',
    'journalnr','erfasstdurch','vorlaufnr','archiv','text2','freigabe',
    'uebertragung','fwbetrag','waehrung','kurs','zugeordnetzu','erfasst_am',
    'laufnummer','belegart','journalisierungsnr','stand',
    'fortlaufnr_provorgang','pkguid','leistungsdatum','iban','swift',
    'kontoinhaber','mandant'
  );
begin
  DoSelect('FIBU', ALLOWED);
end;

// Route: /fibu/getfibufiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.getFibuFiltered;
// Body: { "fields": [...] | "*", "belegfeld1": "RE1001", "gebucht": "N", "orderby": "belegdatum" }
// Alle Filter-Parameter sind optional - nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..43] of string = (
    'nr','betrag','soll','haben','belegfeld1','belegfeld2','belegdatum',
    'kostelle1','kostelle2','skonto','text','gebucht','art','rechnungnr',
    'stschl','ustbetrag','steuerkonto','stkontotyp','stsatz','stapel','opos',
    'journalnr','erfasstdurch','vorlaufnr','archiv','text2','freigabe',
    'uebertragung','fwbetrag','waehrung','kurs','zugeordnetzu','erfasst_am',
    'laufnummer','belegart','journalisierungsnr','stand',
    'fortlaufnr_provorgang','pkguid','leistungsdatum','iban','swift',
    'kontoinhaber','mandant'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS uebereinstimmen).
  CONDITIONS: array[0..43] of string = (
    'nr = :nr',
    'betrag = :betrag',
    'soll = :soll',
    'haben = :haben',
    'belegfeld1 = :belegfeld1',
    'belegfeld2 = :belegfeld2',
    'belegdatum = :belegdatum',
    'kostelle1 = :kostelle1',
    'kostelle2 = :kostelle2',
    'skonto = :skonto',
    'text = :text',
    'gebucht = :gebucht',
    'art = :art',
    'rechnungnr = :rechnungnr',
    'stschl = :stschl',
    'ustbetrag = :ustbetrag',
    'steuerkonto = :steuerkonto',
    'stkontotyp = :stkontotyp',
    'stsatz = :stsatz',
    'stapel = :stapel',
    'opos = :opos',
    'journalnr = :journalnr',
    'erfasstdurch = :erfasstdurch',
    'vorlaufnr = :vorlaufnr',
    'archiv = :archiv',
    'text2 = :text2',
    'freigabe = :freigabe',
    'uebertragung = :uebertragung',
    'fwbetrag = :fwbetrag',
    'waehrung = :waehrung',
    'kurs = :kurs',
    'zugeordnetzu = :zugeordnetzu',
    'erfasst_am = :erfasst_am',
    'laufnummer = :laufnummer',
    'belegart = :belegart',
    'journalisierungsnr = :journalisierungsnr',
    'stand = :stand',
    'fortlaufnr_provorgang = :fortlaufnr_provorgang',
    'pkguid = :pkguid',
    'leistungsdatum = :leistungsdatum',
    'iban = :iban',
    'swift = :swift',
    'kontoinhaber = :kontoinhaber',
    'mandant = :mandant'
  );
  FILTER_PARAMS: array[0..43] of string = (
    'nr','betrag','soll','haben','belegfeld1','belegfeld2','belegdatum',
    'kostelle1','kostelle2','skonto','text','gebucht','art','rechnungnr',
    'stschl','ustbetrag','steuerkonto','stkontotyp','stsatz','stapel','opos',
    'journalnr','erfasstdurch','vorlaufnr','archiv','text2','freigabe',
    'uebertragung','fwbetrag','waehrung','kurs','zugeordnetzu','erfasst_am',
    'laufnummer','belegart','journalisierungsnr','stand',
    'fortlaufnr_provorgang','pkguid','leistungsdatum','iban','swift',
    'kontoinhaber','mandant'
  );
begin
  DoSelectFilteredDynamic('FIBU', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /fibu/getfibubyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.getFibuById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..43] of string = (
    'nr','betrag','soll','haben','belegfeld1','belegfeld2','belegdatum',
    'kostelle1','kostelle2','skonto','text','gebucht','art','rechnungnr',
    'stschl','ustbetrag','steuerkonto','stkontotyp','stsatz','stapel','opos',
    'journalnr','erfasstdurch','vorlaufnr','archiv','text2','freigabe',
    'uebertragung','fwbetrag','waehrung','kurs','zugeordnetzu','erfasst_am',
    'laufnummer','belegart','journalisierungsnr','stand',
    'fortlaufnr_provorgang','pkguid','leistungsdatum','iban','swift',
    'kontoinhaber','mandant'
  );
begin
  DoSelectOne('FIBU', ALLOWED, 'nr');
end;

// Route: /fibu/getfibukey  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.getFibuKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(FIBU_NR_GEN, 1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /fibu/insertfibu  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.insertFibu;
// Body: { "betrag": 100.00, "soll": "1000", "haben": "8400", ... }
const
  ALLOWED: array[0..42] of string = (
    'betrag','soll','haben','belegfeld1','belegfeld2','belegdatum',
    'kostelle1','kostelle2','skonto','text','gebucht','art','rechnungnr',
    'stschl','ustbetrag','steuerkonto','stkontotyp','stsatz','stapel','opos',
    'journalnr','erfasstdurch','vorlaufnr','archiv','text2','freigabe',
    'uebertragung','fwbetrag','waehrung','kurs','zugeordnetzu','erfasst_am',
    'laufnummer','belegart','journalisierungsnr','stand',
    'fortlaufnr_provorgang','pkguid','leistungsdatum','iban','swift',
    'kontoinhaber','mandant'
  );
begin
  DoInsert('FIBU', ALLOWED);
end;

// Route: /fibu/updatefibu  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.updateFibu;
// Body: { "nr": 42, "gebucht": "J", "betrag": 120.00, ... }
const
  ALLOWED: array[0..42] of string = (
    'betrag','soll','haben','belegfeld1','belegfeld2','belegdatum',
    'kostelle1','kostelle2','skonto','text','gebucht','art','rechnungnr',
    'stschl','ustbetrag','steuerkonto','stkontotyp','stsatz','stapel','opos',
    'journalnr','erfasstdurch','vorlaufnr','archiv','text2','freigabe',
    'uebertragung','fwbetrag','waehrung','kurs','zugeordnetzu','erfasst_am',
    'laufnummer','belegart','journalisierungsnr','stand',
    'fortlaufnr_provorgang','pkguid','leistungsdatum','iban','swift',
    'kontoinhaber','mandant'
  );
begin
  DoUpdate('FIBU', ALLOWED, 'nr');
end;

// Route: /fibu/deletefibu  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.deleteFibu;
// Body: { "nr": 42 }
begin
  DoDelete('FIBU', 'nr');
end;

// Route: /fibu/getkonten  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.getKonten;
// Body: { "fields": ["konto","bezeichnung",...] | "*", "orderby": "konto" }
const
  ALLOWED: array[0..20] of string = (
    'konto','bezeichnung','stschluessel','steuer','kontenart','kontengruppe',
    'automatik','steuerkonto','ustpos','klasse','zahlung','gutscheinkonto',
    'aktiva','passiva','eu','waehrung','op','babzuordnung','ebvortragskonto',
    'gesperrt','mandant'
  );
begin
  DoSelect('KONTEN', ALLOWED);
end;

// Route: /fibu/getkontenfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.getKontenFiltered;
// Body: { "fields": [...] | "*", "konto": "1000", "kontenart": 1, "orderby": "konto" }
// Alle Filter-Parameter sind optional - nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..20] of string = (
    'konto','bezeichnung','stschluessel','steuer','kontenart','kontengruppe',
    'automatik','steuerkonto','ustpos','klasse','zahlung','gutscheinkonto',
    'aktiva','passiva','eu','waehrung','op','babzuordnung','ebvortragskonto',
    'gesperrt','mandant'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS uebereinstimmen).
  CONDITIONS: array[0..20] of string = (
    'konto = :konto',
    'bezeichnung = :bezeichnung',
    'stschluessel = :stschluessel',
    'steuer = :steuer',
    'kontenart = :kontenart',
    'kontengruppe = :kontengruppe',
    'automatik = :automatik',
    'steuerkonto = :steuerkonto',
    'ustpos = :ustpos',
    'klasse = :klasse',
    'zahlung = :zahlung',
    'gutscheinkonto = :gutscheinkonto',
    'aktiva = :aktiva',
    'passiva = :passiva',
    'eu = :eu',
    'waehrung = :waehrung',
    'op = :op',
    'babzuordnung = :babzuordnung',
    'ebvortragskonto = :ebvortragskonto',
    'gesperrt = :gesperrt',
    'mandant = :mandant'
  );
  FILTER_PARAMS: array[0..20] of string = (
    'konto','bezeichnung','stschluessel','steuer','kontenart','kontengruppe',
    'automatik','steuerkonto','ustpos','klasse','zahlung','gutscheinkonto',
    'aktiva','passiva','eu','waehrung','op','babzuordnung','ebvortragskonto',
    'gesperrt','mandant'
  );
begin
  DoSelectFilteredDynamic('KONTEN', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /fibu/getkontenbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulFibu.getKontenById;
// Body: { "konto": "1000", "fields": [...] | "*" }
const
  ALLOWED: array[0..20] of string = (
    'konto','bezeichnung','stschluessel','steuer','kontenart','kontengruppe',
    'automatik','steuerkonto','ustpos','klasse','zahlung','gutscheinkonto',
    'aktiva','passiva','eu','waehrung','op','babzuordnung','ebvortragskonto',
    'gesperrt','mandant'
  );
begin
  DoSelectOne('KONTEN', ALLOWED, 'konto');
end;

end.
