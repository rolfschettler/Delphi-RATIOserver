unit DataModulDispoClass;

interface

uses
  Web.HTTPApp,   System.JSON,
  System.SysUtils, System.Classes, DataModulTableBaseClass, FireDAC.Stan.Intf,
  FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS,
  FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt,
  FireDAC.UI.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Phys,
  FireDAC.Phys.IB, FireDAC.Phys.IBDef, FireDAC.VCLUI.Wait, Data.DB,
  FireDAC.Comp.Client, FireDAC.Comp.DataSet;

type
  TDataModulDispo = class(TDataModulTableBase)
  private
    { Private-Deklarationen }
  public
    { Public-Deklarationen }
    procedure Demo;
    procedure getEinsatz;
    procedure getEinsatzFiltered;
    procedure getEinsatzById;
    procedure getfahrergruppen;
    procedure getpersonalstamm;
    procedure getpersonalstammfiltered;
    procedure geteinsatzarten;
    procedure getnextEinsatzkey;
    procedure insertEinsatz;
    procedure updateEinsatz;
    procedure deleteEinsatz;
    procedure getFreiesPersonal;
    procedure getFis_LogFiltered;
  end;

function CreateDataModulDispo(Request: TWebRequest; Response: TWebResponse): TObject;

implementation
uses webutils;

function CreateDataModulDispo(Request: TWebRequest; Response: TWebResponse): TObject;
begin
  Result := TDataModulDispo.Create(Request, Response);
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
    URL     : http://localhost:<port>/ibapi/dispo/demo?id=42&filter=Mueller
    Header  : Authorization: Bearer <JWT-Token>     (Route verlangt Auth)
              Content-Type : application/json
    Body    : (raw / JSON, optional)
              { "name": "Helga", "menge": 5 }

    Test-Kombinationen:
      - nur URL   : POST /dispo/demo?id=42&filter=Mueller   (Body leer lassen)
      - nur Body  : POST /dispo/demo   Body { "name":"Helga","menge":5 }
      - gemischt  : beide Quellen gleichzeitig
      - nichts    : POST /dispo/demo ohne Parameter -> alle Felder als null
    Fehlende Werte erzeugen KEINEN Fehler, sondern erscheinen im Ergebnis als null.
  ----------------------------------------------------------------------------

  Harry

  *)


procedure TDataModulDispo.Demo;
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

// Route: /dispo/geteinsatz  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.getEinsatz;
const
  ALLOWED: array[0..102] of string = (
    'nr','von','bis','bezeichnung','typ','hinweis','auftragnr',
    'fahrzeug','fahrer1','fahrer2','fahrzeugstatus','fahrer1status','fahrer2status',
    'gruppe','lognr','bemerkung','km','stunden','abfahrtsort','abfahrtszeit',
    'firma','dienstnr','einsatznr','linie','tournr','toureinsatznr','disponentinfo',
    'geprueft','bereich','liniedienstplannr','dienstobjektnr','abrechnungstd',
    'fahrtenplan','stationid','dispostatus','markiert','angemeldet','liniemappenr',
    'ausdienst','betrieb','fahrzeugprofil','fahrerprofil','standort','betreiber',
    'telematikorderid','telematiksendtime','telematikchangetime','telematikfreigabe',
    'durchgefuehrt_von','ivuorderid','ivusendtime','ivustatus','gsbetrag',
    'nachauftragnehmer','minuten','rueckkehrort','maxfislognr','angemeldet1',
    'angemeldet2','maxfislog1','maxfislog2','einsatzstatus','stornogrund',
    'perszahl','personen','sv_tournr','sv_tournummer','sv_fahrtnummer','sv_fahrtnr',
    'sv_fahrtbezeichnung','sv_sammeleinzel_auftragnr','sv_gutschrift_auftragnr',
    'sv_begleit_auftragnr','sv_tourbezeichnung','xkoord_start','ykoord_start',
    'xkoord_ende','ykoord_ende','erledigt_am','storniert_am','umlauf','anhaenger',
    'begleiter','fahrer3','fahrer3status','fis_abgelehnt','fis_abgelehnt_fahrer2',
    'fis_abgelehnt_fahrer3','fis_abgeschlossen','fis_abgeschlossen_fahrer2',
    'fis_abgeschlossen_fahrer3','fis_bestaetigt','fis_bestaetigt_fahrer2',
    'fis_bestaetigt_fahrer3','fis_geaendert','fis_geaendert_fahrer2',
    'fis_geaendert_fahrer3','fis_gelesen','fis_gelesen_fahrer2','fis_gelesen_fahrer3',
    'geaendert','geaendertvon','zielort'
  );
begin
  DoSelect('EINSATZ', ALLOWED);
end;

// Route: /dispo/geteinsatzfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.getEinsatzFiltered;
// Body: { "fields": [...] | "*", "von": "2024-01-01 00:00:00", "bis": "2024-12-31 23:59:59", "orderby": "von" }
var
  timemodeVal : TJSONValue;
  timemode    : string;
  Filter      : string;
  ParsedVal   : TJSONValue;
  Body        : TJSONObject;
const
  ALLOWED: array[0..102] of string = (
    'nr','von','bis','bezeichnung','typ','hinweis','auftragnr',
    'fahrzeug','fahrer1','fahrer2','fahrzeugstatus','fahrer1status','fahrer2status',
    'gruppe','lognr','bemerkung','km','stunden','abfahrtsort','abfahrtszeit',
    'firma','dienstnr','einsatznr','linie','tournr','toureinsatznr','disponentinfo',
    'geprueft','bereich','liniedienstplannr','dienstobjektnr','abrechnungstd',
    'fahrtenplan','stationid','dispostatus','markiert','angemeldet','liniemappenr',
    'ausdienst','betrieb','fahrzeugprofil','fahrerprofil','standort','betreiber',
    'telematikorderid','telematiksendtime','telematikchangetime','telematikfreigabe',
    'durchgefuehrt_von','ivuorderid','ivusendtime','ivustatus','gsbetrag',
    'nachauftragnehmer','minuten','rueckkehrort','maxfislognr','angemeldet1',
    'angemeldet2','maxfislog1','maxfislog2','einsatzstatus','stornogrund',
    'perszahl','personen','sv_tournr','sv_tournummer','sv_fahrtnummer','sv_fahrtnr',
    'sv_fahrtbezeichnung','sv_sammeleinzel_auftragnr','sv_gutschrift_auftragnr',
    'sv_begleit_auftragnr','sv_tourbezeichnung','xkoord_start','ykoord_start',
    'xkoord_ende','ykoord_ende','erledigt_am','storniert_am','umlauf','anhaenger',
    'begleiter','fahrer3','fahrer3status','fis_abgelehnt','fis_abgelehnt_fahrer2',
    'fis_abgelehnt_fahrer3','fis_abgeschlossen','fis_abgeschlossen_fahrer2',
    'fis_abgeschlossen_fahrer3','fis_bestaetigt','fis_bestaetigt_fahrer2',
    'fis_bestaetigt_fahrer3','fis_geaendert','fis_geaendert_fahrer2',
    'fis_geaendert_fahrer3','fis_gelesen','fis_gelesen_fahrer2','fis_gelesen_fahrer3',
    'geaendert','geaendertvon','zielort'
  );
  FILTER_PARAMS: array[0..1] of string = ('von', 'bis');
begin
  // 1. Erst aus QueryString versuchen
  timemode := Request.QueryFields.Values['timemode'];

  // 2. Falls nicht im QueryString → aus JSON-Body lesen
  if timemode = '' then
  begin
    if Request.Content <> '' then
    begin
      ParsedVal := TJSONObject.ParseJSONValue(Request.Content);
      if ParsedVal is TJSONObject then
        Body := TJSONObject(ParsedVal)
      else
      begin
        FreeAndNil(ParsedVal);
        Body := nil;
      end;

      if Assigned(Body) then
      try
        timemodeVal := Body.GetValue('timemode');
        if Assigned(timemodeVal) and not timemodeVal.Null then
          timemode := LowerCase(timemodeVal.Value);
      finally
        Body.Free;
      end;
    end;
  end;

  // 3. Filter bestimmen
  if timemode = 'overlaps_range' then
    Filter := 'bis >= :von AND von <= :bis'
  else
    Filter := 'von >= :von AND von <= :bis';

  // 4. Query ausführen
  DoSelectFiltered('EINSATZ', ALLOWED, Filter, FILTER_PARAMS);
end;

procedure TDataModulDispo.getfahrergruppen;
begin
  Try
    Connection.StartTransaction;
    with Query do
    Begin
      close;
      sql.text := 'Select nr,name,cast(content as varchar(20000)) As ids from KONFIGURATION where art=''G_R_P'' and art2=''PERSON'' order by name';
      open;
      Response.ContentType := 'application/json';
      Response.StatusCode  := 200;
      Response.Content     := SerializeQuery(Query);
      Connection.Commit;
    End;
  Except
    on e: Exception do
    Begin
      Connection.Rollback;
      raise;
    End;
  End;
end;

procedure TDataModulDispo.getFreiesPersonal;
// Body: { "von": "2024-01-01 00:00:00", "bis": "2024-12-31 23:59:59"}
var
  ParsedVal   : TJSONValue;
  vonval,
  bisval      : TJSONValue;
  s, VON, BIS : String;
  Body        : TJSONObject;
begin
  s := ' SELECT pe.nr, pe.zeichen, pe.Anrede, pe.Name1, pe.name2 FROM Personalstamm pe ';
  s := s + ' WHERE pe.zeichen NOT IN ';
  s := s + ' ( ';
  s := s + '   SELECT DISTINCT d.objekt ';
  s := s + '   FROM DISPO D ';
  s := s + '   JOIN personalstamm P ON d.objekt = p.zeichen ';
  s := s + '   WHERE D.BIS > :von ';
  s := s + '   AND D.VON < :bis ';
  s := s + ' ) ORDER BY pe.name2,pe.name1 ';

  Try
    ParsedVal := TJSONObject.ParseJSONValue(Request.Content);
    if ParsedVal is TJSONObject then
      Body := TJSONObject(ParsedVal)
    else
    begin
      FreeAndNil(ParsedVal);
      Body := nil;
    end;

    if Assigned(Body) then
    try
      vonval := Body.GetValue('von');
      if Assigned(vonval) and not vonval.Null then
        von := vonval.Value
      else
        von := '1900-01-01 00:00:00';

      bisval := Body.GetValue('bis');
      if Assigned(bisval) and not bisval.Null then
        bis := bisval.Value
      else
        bis := '1900-02-01 00:00:00';
    finally
      Body.Free;
    end
    else
    begin
      von := '1900-01-01 00:00:00';
      bis := '1900-02-01 00:00:00';
    end;

    Connection.StartTransaction;
    with Query do
    begin
      Close;
      SQL.Clear;
      SQL.Text := s;
      ParamByName('von').AsString := von;
      ParamByName('bis').AsString := bis;
      Open;
      Response.ContentType := 'application/json';
      Response.StatusCode  := 200;
      Response.Content     := SerializeQuery(Query);
      Connection.Commit;
    end;

  Except
    on E: Exception do
    begin
      Connection.Rollback;
      raise;
    end;
  End;
end;

procedure TDataModulDispo.getpersonalstamm;
begin
  Try
    Connection.StartTransaction;
    with Query do
    Begin
      close;
      sql.text := 'Select nr,name1,name2,zeichen from PERSONALSTAMM order by name2';
      open;
      Response.ContentType := 'application/json';
      Response.StatusCode  := 200;
      Response.Content     := SerializeQuery(Query);
      Connection.Commit;
    End;
  Except
    on e: Exception do
    Begin
      Connection.Rollback;
      raise;
    End;
  End;
end;

// Route: /dispo/getpersonalstammfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.getpersonalstammfiltered;
// Body: { "fields": [...] | "*", "zeichen": "MU", "orderby": "name2" }
const
  ALLOWED: array[0..67] of string = (
    'nr','anrede','name1','name2','zeichen','strasse','land','plz','ort',
    'telefon1','telefon2','fsnummer','pbs_gueltig_bis','verwendung','geburtstag',
    'bemerkung','angestellt_seit','urlaubgesamt','resturlaub','gesperrt','fahrzeug',
    'sortierung','stundenlohn','stundenlohn2','zuschlag','kostenstelle','urlaubsjahr',
    'alterurlaub','altefreietage','freietagegesamt','restfreietage','betrieb','profil',
    'feiertagsberechtigt','zulageberechtigt','mindestregelungsberechtigt',
    'arbeitsvertragsart','urlaubsstunden','krankheitsstunden','durchschnittsstunden',
    'ausgeschieden_am','sprache','versicherungsnummer','passwort','zusatzinfo',
    'kennziffer','passwort2','versuche','zeitsperre','freistunden','pushid',
    'wochenende','abteilung','kostelle1','personalnummer','apikey','urlaubsgruppe',
    'vertretung','resturlaub_aktuell','altefreietage2','alterurlaub2','nation',
    'xkoord','ykoord','koords_erfasst_am','pushid_fis','pushid_dispo','pushid_tickets'
  );
  CONDITIONS: array[0..0] of string = (
    'zeichen = :zeichen'
  );
  FILTER_PARAMS: array[0..0] of string = ('zeichen');
begin
  DoSelectFilteredDynamic('PERSONALSTAMM', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

procedure TDataModulDispo.geteinsatzarten;
begin
  Try
    Connection.StartTransaction;
    with Query do
    Begin
      close;
      sql.text := 'Select nr,code,beschreibung,farbe from einsatzarten order by code';
      open;
      Response.ContentType := 'application/json';
      Response.StatusCode  := 200;
      Response.Content     := SerializeQuery(Query);
      Connection.Commit;
    End;
  Except
    on e: Exception do
    Begin
      Connection.Rollback;
      raise;
    End;
  End;
end;

// Route: /dispo/geteinsatzbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.getEinsatzById;
const
  ALLOWED: array[0..102] of string = (
    'nr','von','bis','bezeichnung','typ','hinweis','auftragnr',
    'fahrzeug','fahrer1','fahrer2','fahrzeugstatus','fahrer1status','fahrer2status',
    'gruppe','lognr','bemerkung','km','stunden','abfahrtsort','abfahrtszeit',
    'firma','dienstnr','einsatznr','linie','tournr','toureinsatznr','disponentinfo',
    'geprueft','bereich','liniedienstplannr','dienstobjektnr','abrechnungstd',
    'fahrtenplan','stationid','dispostatus','markiert','angemeldet','liniemappenr',
    'ausdienst','betrieb','fahrzeugprofil','fahrerprofil','standort','betreiber',
    'telematikorderid','telematiksendtime','telematikchangetime','telematikfreigabe',
    'durchgefuehrt_von','ivuorderid','ivusendtime','ivustatus','gsbetrag',
    'nachauftragnehmer','minuten','rueckkehrort','maxfislognr','angemeldet1',
    'angemeldet2','maxfislog1','maxfislog2','einsatzstatus','stornogrund',
    'perszahl','personen','sv_tournr','sv_tournummer','sv_fahrtnummer','sv_fahrtnr',
    'sv_fahrtbezeichnung','sv_sammeleinzel_auftragnr','sv_gutschrift_auftragnr',
    'sv_begleit_auftragnr','sv_tourbezeichnung','xkoord_start','ykoord_start',
    'xkoord_ende','ykoord_ende','erledigt_am','storniert_am','umlauf','anhaenger',
    'begleiter','fahrer3','fahrer3status','fis_abgelehnt','fis_abgelehnt_fahrer2',
    'fis_abgelehnt_fahrer3','fis_abgeschlossen','fis_abgeschlossen_fahrer2',
    'fis_abgeschlossen_fahrer3','fis_bestaetigt','fis_bestaetigt_fahrer2',
    'fis_bestaetigt_fahrer3','fis_geaendert','fis_geaendert_fahrer2',
    'fis_geaendert_fahrer3','fis_gelesen','fis_gelesen_fahrer2','fis_gelesen_fahrer3',
    'geaendert','geaendertvon','zielort'
  );
begin
  DoSelectOne('EINSATZ', ALLOWED, 'nr');
end;

// Route: /dispo/getnextkey  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.getnextEinsatzkey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(NEXT_EINSATZ_NR,1) as NR FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /dispo/inserteinsatz  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.insertEinsatz;
const
  ALLOWED: array[0..102] of string = (
    'nr','von','bis','bezeichnung','typ','hinweis','auftragnr',
    'fahrzeug','fahrer1','fahrer2','fahrzeugstatus','fahrer1status','fahrer2status',
    'gruppe','lognr','bemerkung','km','stunden','abfahrtsort','abfahrtszeit',
    'firma','dienstnr','einsatznr','linie','tournr','toureinsatznr','disponentinfo',
    'geprueft','bereich','liniedienstplannr','dienstobjektnr','abrechnungstd',
    'fahrtenplan','stationid','dispostatus','markiert','angemeldet','liniemappenr',
    'ausdienst','betrieb','fahrzeugprofil','fahrerprofil','standort','betreiber',
    'telematikorderid','telematiksendtime','telematikchangetime','telematikfreigabe',
    'durchgefuehrt_von','ivuorderid','ivusendtime','ivustatus','gsbetrag',
    'nachauftragnehmer','minuten','rueckkehrort','maxfislognr','angemeldet1',
    'angemeldet2','maxfislog1','maxfislog2','einsatzstatus','stornogrund',
    'perszahl','personen','sv_tournr','sv_tournummer','sv_fahrtnummer','sv_fahrtnr',
    'sv_fahrtbezeichnung','sv_sammeleinzel_auftragnr','sv_gutschrift_auftragnr',
    'sv_begleit_auftragnr','sv_tourbezeichnung','xkoord_start','ykoord_start',
    'xkoord_ende','ykoord_ende','erledigt_am','storniert_am','umlauf','anhaenger',
    'begleiter','fahrer3','fahrer3status','fis_abgelehnt','fis_abgelehnt_fahrer2',
    'fis_abgelehnt_fahrer3','fis_abgeschlossen','fis_abgeschlossen_fahrer2',
    'fis_abgeschlossen_fahrer3','fis_bestaetigt','fis_bestaetigt_fahrer2',
    'fis_bestaetigt_fahrer3','fis_geaendert','fis_geaendert_fahrer2',
    'fis_geaendert_fahrer3','fis_gelesen','fis_gelesen_fahrer2','fis_gelesen_fahrer3',
    'geaendert','geaendertvon','zielort'
  );
begin
  DoInsert('EINSATZ', ALLOWED);
end;

// Route: /dispo/updateeinsatz  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.updateEinsatz;
const
  ALLOWED: array[0..102] of string = (
    'nr','von','bis','bezeichnung','typ','hinweis','auftragnr',
    'fahrzeug','fahrer1','fahrer2','fahrzeugstatus','fahrer1status','fahrer2status',
    'gruppe','lognr','bemerkung','km','stunden','abfahrtsort','abfahrtszeit',
    'firma','dienstnr','einsatznr','linie','tournr','toureinsatznr','disponentinfo',
    'geprueft','bereich','liniedienstplannr','dienstobjektnr','abrechnungstd',
    'fahrtenplan','stationid','dispostatus','markiert','angemeldet','liniemappenr',
    'ausdienst','betrieb','fahrzeugprofil','fahrerprofil','standort','betreiber',
    'telematikorderid','telematiksendtime','telematikchangetime','telematikfreigabe',
    'durchgefuehrt_von','ivuorderid','ivusendtime','ivustatus','gsbetrag',
    'nachauftragnehmer','minuten','rueckkehrort','maxfislognr','angemeldet1',
    'angemeldet2','maxfislog1','maxfislog2','einsatzstatus','stornogrund',
    'perszahl','personen','sv_tournr','sv_tournummer','sv_fahrtnummer','sv_fahrtnr',
    'sv_fahrtbezeichnung','sv_sammeleinzel_auftragnr','sv_gutschrift_auftragnr',
    'sv_begleit_auftragnr','sv_tourbezeichnung','xkoord_start','ykoord_start',
    'xkoord_ende','ykoord_ende','erledigt_am','storniert_am','umlauf','anhaenger',
    'begleiter','fahrer3','fahrer3status','fis_abgelehnt','fis_abgelehnt_fahrer2',
    'fis_abgelehnt_fahrer3','fis_abgeschlossen','fis_abgeschlossen_fahrer2',
    'fis_abgeschlossen_fahrer3','fis_bestaetigt','fis_bestaetigt_fahrer2',
    'fis_bestaetigt_fahrer3','fis_geaendert','fis_geaendert_fahrer2',
    'fis_geaendert_fahrer3','fis_gelesen','fis_gelesen_fahrer2','fis_gelesen_fahrer3',
    'geaendert','geaendertvon','zielort'
  );
begin
  DoUpdate('EINSATZ', ALLOWED, 'nr');
end;

// Route: /dispo/deleteeinsatz  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.deleteEinsatz;
begin
  DoDelete('EINSATZ', 'nr');
end;

// Route: /dispo/getfis_logfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.getFis_LogFiltered;
// Body: { "fields": [...] | "*", "einsatznr": 42, "fahrer": "Mustermann", "orderby": "datum" }
const
  ALLOWED: array[0..29] of string = (
    'nr','datum','xkoord','ykoord','status','einsatznr','taetigkeit','herkunft',
    'fahrer','fahrzeug','zusatzfeld1','zusatzfeld2','kmstand','distance','dauer',
    'fremdnr','text','standort','zeitpunkt','sortierung','loginname','art',
    'textfeld1','textfeld2','textfeld3','datumfeld1','datumfeld2','datumfeld3',
    'wert','erledigt_am'
  );
  // Pro Filterparameter genau eine Bedingung (parallel zu FILTER_PARAMS).
  // Die WHERE-Klausel wird dynamisch nur aus den im Body gesetzten Parametern
  // gebaut -> kein NULL-Hack, kein untypisiertes NULL, keine Mehrfachbindung.
  CONDITIONS: array[0..2] of string = (
    'einsatznr = :einsatznr',
    'cast(datum as date) = :datum',
    'fahrer = :fahrer'
  );

  FILTER_PARAMS: array[0..2] of string = ('einsatznr', 'datum', 'fahrer');
begin
  DoSelectFilteredDynamic('FIS_LOG', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

end.
