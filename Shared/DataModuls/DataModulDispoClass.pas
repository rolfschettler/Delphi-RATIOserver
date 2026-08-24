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
    procedure updatepersonalstamm;
    procedure deletepersonalstamm;
    procedure geteinsatzarten;
    procedure getnextEinsatzkey;
    procedure insertEinsatz;
    procedure updateEinsatz;
    procedure deleteEinsatz;
    procedure getFreiesPersonal;
    procedure getFis_Log;
    procedure getFis_LogFiltered;
    procedure getFis_LogById;
    procedure getFis_LogKey;
    procedure insertFis_Log;
    procedure updateFis_Log;
    procedure deleteFis_Log;
    procedure getZeitraum;
    procedure getZeitraumFiltered;
    procedure getZeitraumById;
    procedure getUrlaubsantrag;
    procedure getUrlaubsantragFiltered;
    procedure getUrlaubsantragById;
    procedure getUrlaubsantragKey;
    procedure insertUrlaubsantrag;
    procedure updateUrlaubsantrag;
    procedure deleteUrlaubsantrag;
    procedure getFahrtablauf;
    procedure getFahrtablaufFiltered;
    procedure getFahrtablaufById;
    procedure getFahrtablaufKey;
    procedure insertFahrtablauf;
    procedure updateFahrtablauf;
    procedure deleteFahrtablauf;
    procedure getLiniewegeobjekte;
    procedure getLiniewegeobjekteFiltered;
    procedure getLiniewegeobjekteById;
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
  ALLOWED: array[0..64] of string = (
    'nr','anrede','name1','name2','zeichen','strasse','land','plz','ort',
    'telefon1','telefon2','fsnummer','pbs_gueltig_bis','verwendung','geburtstag',
    'bemerkung','angestellt_seit','urlaubgesamt','resturlaub','gesperrt','fahrzeug',
    'sortierung','stundenlohn','stundenlohn2','zuschlag','kostenstelle','urlaubsjahr',
    'alterurlaub','altefreietage','freietagegesamt','restfreietage','betrieb','profil',
    'feiertagsberechtigt','zulageberechtigt','mindestregelungsberechtigt',
    'arbeitsvertragsart','urlaubsstunden','krankheitsstunden','durchschnittsstunden',
    'ausgeschieden_am','sprache','versicherungsnummer','zusatzinfo',
    'kennziffer','versuche','zeitsperre','freistunden','pushid',
    'wochenende','abteilung','kostelle1','personalnummer','urlaubsgruppe',
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

// Route: /dispo/updatepersonalstamm  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.updatepersonalstamm;
// Body: { "nr": 42, "name1": "...", ... }
const
  ALLOWED: array[0..64] of string = (
    'nr','anrede','name1','name2','zeichen','strasse','land','plz','ort',
    'telefon1','telefon2','fsnummer','pbs_gueltig_bis','verwendung','geburtstag',
    'bemerkung','angestellt_seit','urlaubgesamt','resturlaub','gesperrt','fahrzeug',
    'sortierung','stundenlohn','stundenlohn2','zuschlag','kostenstelle','urlaubsjahr',
    'alterurlaub','altefreietage','freietagegesamt','restfreietage','betrieb','profil',
    'feiertagsberechtigt','zulageberechtigt','mindestregelungsberechtigt',
    'arbeitsvertragsart','urlaubsstunden','krankheitsstunden','durchschnittsstunden',
    'ausgeschieden_am','sprache','versicherungsnummer','zusatzinfo',
    'kennziffer','versuche','zeitsperre','freistunden','pushid',
    'wochenende','abteilung','kostelle1','personalnummer','urlaubsgruppe',
    'vertretung','resturlaub_aktuell','altefreietage2','alterurlaub2','nation',
    'xkoord','ykoord','koords_erfasst_am','pushid_fis','pushid_dispo','pushid_tickets'
  );
begin
  DoUpdate('PERSONALSTAMM', ALLOWED, 'nr');
end;

// Route: /dispo/deletepersonalstamm  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.deletepersonalstamm;
// Body: { "nr": 42 }
begin
  DoDelete('PERSONALSTAMM', 'nr');
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

// Route: /dispo/getfis_log  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.getFis_Log;
const
  ALLOWED: array[0..29] of string = (
    'nr','datum','xkoord','ykoord','status','einsatznr','taetigkeit','herkunft',
    'fahrer','fahrzeug','zusatzfeld1','zusatzfeld2','kmstand','distance','dauer',
    'fremdnr','text','standort','zeitpunkt','sortierung','loginname','art',
    'textfeld1','textfeld2','textfeld3','datumfeld1','datumfeld2','datumfeld3',
    'wert','erledigt_am'
  );
begin
  DoSelect('FIS_LOG', ALLOWED);
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

// Route: /dispo/getfis_logbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.getFis_LogById;
const
  ALLOWED: array[0..29] of string = (
    'nr','datum','xkoord','ykoord','status','einsatznr','taetigkeit','herkunft',
    'fahrer','fahrzeug','zusatzfeld1','zusatzfeld2','kmstand','distance','dauer',
    'fremdnr','text','standort','zeitpunkt','sortierung','loginname','art',
    'textfeld1','textfeld2','textfeld3','datumfeld1','datumfeld2','datumfeld3',
    'wert','erledigt_am'
  );
begin
  DoSelectOne('FIS_LOG', ALLOWED, 'nr');
end;

// Route: /dispo/getfis_logkey  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.getFis_LogKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(FIS_LOG_NR_GEN,1) AS NR FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /dispo/insertfis_log  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.insertFis_Log;
const
  ALLOWED: array[0..29] of string = (
    'nr','datum','xkoord','ykoord','status','einsatznr','taetigkeit','herkunft',
    'fahrer','fahrzeug','zusatzfeld1','zusatzfeld2','kmstand','distance','dauer',
    'fremdnr','text','standort','zeitpunkt','sortierung','loginname','art',
    'textfeld1','textfeld2','textfeld3','datumfeld1','datumfeld2','datumfeld3',
    'wert','erledigt_am'
  );
begin
  DoInsert('FIS_LOG', ALLOWED);
end;

// Route: /dispo/updatefis_log  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.updateFis_Log;
const
  ALLOWED: array[0..29] of string = (
    'nr','datum','xkoord','ykoord','status','einsatznr','taetigkeit','herkunft',
    'fahrer','fahrzeug','zusatzfeld1','zusatzfeld2','kmstand','distance','dauer',
    'fremdnr','text','standort','zeitpunkt','sortierung','loginname','art',
    'textfeld1','textfeld2','textfeld3','datumfeld1','datumfeld2','datumfeld3',
    'wert','erledigt_am'
  );
begin
  DoUpdate('FIS_LOG', ALLOWED, 'nr');
end;

// Route: /dispo/deletefis_log  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.deleteFis_Log;
begin
  DoDelete('FIS_LOG', 'nr');
end;

// Route: /dispo/getzeitraum  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.getZeitraum;
// Body: { "fields": ["nr","von",...] | "*", "orderby": "nr" }
const
  ALLOWED: array[0..8] of string = (
    'nr','von','bis','bezeichnung','farbe',
    'art','code','gueltig_bis','gueltig_von'
  );
begin
  DoSelect('ZEITRAUM', ALLOWED);
end;

// Route: /dispo/getzeitraumfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.getZeitraumFiltered;
// Body: { "fields": [...] | "*", "nr": 1, "art": "U", "orderby": "von" }
// Alle Filter-Parameter sind optional - nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..8] of string = (
    'nr','von','bis','bezeichnung','farbe',
    'art','code','gueltig_bis','gueltig_von'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS uebereinstimmen).
  CONDITIONS: array[0..8] of string = (
    'nr = :nr',
    'von = :von',
    'bis = :bis',
    'bezeichnung = :bezeichnung',
    'farbe = :farbe',
    'art = :art',
    'code = :code',
    'gueltig_bis = :gueltig_bis',
    'gueltig_von = :gueltig_von'
  );
  FILTER_PARAMS: array[0..8] of string = (
    'nr','von','bis','bezeichnung','farbe',
    'art','code','gueltig_bis','gueltig_von'
  );
begin
  DoSelectFilteredDynamic('ZEITRAUM', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /dispo/getzeitraumbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.getZeitraumById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..8] of string = (
    'nr','von','bis','bezeichnung','farbe',
    'art','code','gueltig_bis','gueltig_von'
  );
begin
  DoSelectOne('ZEITRAUM', ALLOWED, 'nr');
end;

// Route: /dispo/geturlaubsantrag  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.getUrlaubsantrag;
// Body: { "fields": [...] | "*", "orderby": "von" }
const
  ALLOWED: array[0..14] of string = (
    'nr','mitarbeiter','von','bis','beantragtam','genehmigtam','genehmigtvon',
    'bemerkung','text1','text2','text3','status','statusam','statusvon','vertretung'
  );
begin
  DoSelect('URLAUBSANTRAG', ALLOWED);
end;

// Route: /dispo/geturlaubsantragfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.getUrlaubsantragFiltered;
// Body: { "fields": [...] | "*", "nr": 1, "mitarbeiter": "MM", "orderby": "von" }
// Alle Filter-Parameter sind optional - nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
// bemerkung ist ein Blob-Feld und daher nur in ALLOWED, nicht in CONDITIONS/FILTER_PARAMS.
const
  ALLOWED: array[0..14] of string = (
    'nr','mitarbeiter','von','bis','beantragtam','genehmigtam','genehmigtvon',
    'bemerkung','text1','text2','text3','status','statusam','statusvon','vertretung'
  );
  CONDITIONS: array[0..13] of string = (
    'nr = :nr',
    'mitarbeiter = :mitarbeiter',
    'von = :von',
    'bis = :bis',
    'beantragtam = :beantragtam',
    'genehmigtam = :genehmigtam',
    'genehmigtvon = :genehmigtvon',
    'text1 = :text1',
    'text2 = :text2',
    'text3 = :text3',
    'status = :status',
    'statusam = :statusam',
    'statusvon = :statusvon',
    'vertretung = :vertretung'
  );
  FILTER_PARAMS: array[0..13] of string = (
    'nr','mitarbeiter','von','bis','beantragtam','genehmigtam','genehmigtvon',
    'text1','text2','text3','status','statusam','statusvon','vertretung'
  );
begin
  DoSelectFilteredDynamic('URLAUBSANTRAG', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /dispo/geturlaubsantragbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.getUrlaubsantragById;
const
  ALLOWED: array[0..14] of string = (
    'nr','mitarbeiter','von','bis','beantragtam','genehmigtam','genehmigtvon',
    'bemerkung','text1','text2','text3','status','statusam','statusvon','vertretung'
  );
begin
  DoSelectOne('URLAUBSANTRAG', ALLOWED, 'nr');
end;

// Route: /dispo/geturlaubsantragkey  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.getUrlaubsantragKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(NEXT_EINSATZ_NR,1) as NR FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /dispo/inserturlaubsantrag  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.insertUrlaubsantrag;
const
  ALLOWED: array[0..14] of string = (
    'nr','mitarbeiter','von','bis','beantragtam','genehmigtam','genehmigtvon',
    'bemerkung','text1','text2','text3','status','statusam','statusvon','vertretung'
  );
begin
  DoInsert('URLAUBSANTRAG', ALLOWED);
end;

// Route: /dispo/updateurlaubsantrag  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.updateUrlaubsantrag;
const
  ALLOWED: array[0..14] of string = (
    'nr','mitarbeiter','von','bis','beantragtam','genehmigtam','genehmigtvon',
    'bemerkung','text1','text2','text3','status','statusam','statusvon','vertretung'
  );
begin
  DoUpdate('URLAUBSANTRAG', ALLOWED, 'nr');
end;

// Route: /dispo/deleteurlaubsantrag  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.deleteUrlaubsantrag;
begin
  DoDelete('URLAUBSANTRAG', 'nr');
end;

// Route: /dispo/getfahrtablauf  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.getFahrtablauf;
// Body: { "fields": [...] | "*", "orderby": "nr" }
const
  ALLOWED: array[0..69] of string = (
    'nr','datum','von_soll','von_ist','bis_soll','bis_ist','bereich','art','xkoord','ykoord',
    'sortierung','disponr','zeichen','kennzeichen','eart','dienstelementnr','dienstelementart',
    'bemerkung','zusatzfeld1','zusatzfeld2','zusatzfeld3','datumfeld1','datumfeld2','datumfeld3',
    'zustiege_soll','zustiege_ist','ausstiege_soll','ausstiege_ist','reftable','refnr','hinweis',
    'typ','einsatznr','haltnr','bezeichnung','sv_tournummer','sv_fahrtnummer','sv_abrechnungsstatus',
    'geprueft','einsatznr_ist','disponr_ist','tag','von_kalk','bis_kalk','strasse','plz','ort',
    'ortsteil','region','land','meter_soll','meter_ist','meter_kalk','sekunden_soll','sekunden_ist',
    'sekunden_kalk','fahrzeugprofil','anzahl_fahrer','kosten','leerfahrt','wochenende','feiertag',
    'dienstnr','umlaufnr','sv_teilnehmernr','sv_typ','sv_abrechenbar','sv_streckenpreis','freigabe',
    'umlauf'
  );
begin
  DoSelect('FAHRTABLAUF', ALLOWED);
end;

// Route: /dispo/getfahrtablauffiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.getFahrtablaufFiltered;
// Body: { "fields": [...] | "*", "nr": 1, "einsatznr": 42, "orderby": "datum" }
// Alle Filter-Parameter sind optional - nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..69] of string = (
    'nr','datum','von_soll','von_ist','bis_soll','bis_ist','bereich','art','xkoord','ykoord',
    'sortierung','disponr','zeichen','kennzeichen','eart','dienstelementnr','dienstelementart',
    'bemerkung','zusatzfeld1','zusatzfeld2','zusatzfeld3','datumfeld1','datumfeld2','datumfeld3',
    'zustiege_soll','zustiege_ist','ausstiege_soll','ausstiege_ist','reftable','refnr','hinweis',
    'typ','einsatznr','haltnr','bezeichnung','sv_tournummer','sv_fahrtnummer','sv_abrechnungsstatus',
    'geprueft','einsatznr_ist','disponr_ist','tag','von_kalk','bis_kalk','strasse','plz','ort',
    'ortsteil','region','land','meter_soll','meter_ist','meter_kalk','sekunden_soll','sekunden_ist',
    'sekunden_kalk','fahrzeugprofil','anzahl_fahrer','kosten','leerfahrt','wochenende','feiertag',
    'dienstnr','umlaufnr','sv_teilnehmernr','sv_typ','sv_abrechenbar','sv_streckenpreis','freigabe',
    'umlauf'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS uebereinstimmen).
  CONDITIONS: array[0..69] of string = (
    'nr = :nr','datum = :datum','von_soll = :von_soll','von_ist = :von_ist',
    'bis_soll = :bis_soll','bis_ist = :bis_ist','bereich = :bereich','art = :art',
    'xkoord = :xkoord','ykoord = :ykoord','sortierung = :sortierung','disponr = :disponr',
    'zeichen = :zeichen','kennzeichen = :kennzeichen','eart = :eart',
    'dienstelementnr = :dienstelementnr','dienstelementart = :dienstelementart',
    'bemerkung = :bemerkung','zusatzfeld1 = :zusatzfeld1','zusatzfeld2 = :zusatzfeld2',
    'zusatzfeld3 = :zusatzfeld3','datumfeld1 = :datumfeld1','datumfeld2 = :datumfeld2',
    'datumfeld3 = :datumfeld3','zustiege_soll = :zustiege_soll','zustiege_ist = :zustiege_ist',
    'ausstiege_soll = :ausstiege_soll','ausstiege_ist = :ausstiege_ist','reftable = :reftable',
    'refnr = :refnr','hinweis = :hinweis','typ = :typ','einsatznr = :einsatznr',
    'haltnr = :haltnr','bezeichnung = :bezeichnung','sv_tournummer = :sv_tournummer',
    'sv_fahrtnummer = :sv_fahrtnummer','sv_abrechnungsstatus = :sv_abrechnungsstatus',
    'geprueft = :geprueft','einsatznr_ist = :einsatznr_ist','disponr_ist = :disponr_ist',
    'tag = :tag','von_kalk = :von_kalk','bis_kalk = :bis_kalk','strasse = :strasse',
    'plz = :plz','ort = :ort','ortsteil = :ortsteil','region = :region','land = :land',
    'meter_soll = :meter_soll','meter_ist = :meter_ist','meter_kalk = :meter_kalk',
    'sekunden_soll = :sekunden_soll','sekunden_ist = :sekunden_ist','sekunden_kalk = :sekunden_kalk',
    'fahrzeugprofil = :fahrzeugprofil','anzahl_fahrer = :anzahl_fahrer','kosten = :kosten',
    'leerfahrt = :leerfahrt','wochenende = :wochenende','feiertag = :feiertag',
    'dienstnr = :dienstnr','umlaufnr = :umlaufnr','sv_teilnehmernr = :sv_teilnehmernr',
    'sv_typ = :sv_typ','sv_abrechenbar = :sv_abrechenbar','sv_streckenpreis = :sv_streckenpreis',
    'freigabe = :freigabe','umlauf = :umlauf'
  );
  FILTER_PARAMS: array[0..69] of string = (
    'nr','datum','von_soll','von_ist','bis_soll','bis_ist','bereich','art','xkoord','ykoord',
    'sortierung','disponr','zeichen','kennzeichen','eart','dienstelementnr','dienstelementart',
    'bemerkung','zusatzfeld1','zusatzfeld2','zusatzfeld3','datumfeld1','datumfeld2','datumfeld3',
    'zustiege_soll','zustiege_ist','ausstiege_soll','ausstiege_ist','reftable','refnr','hinweis',
    'typ','einsatznr','haltnr','bezeichnung','sv_tournummer','sv_fahrtnummer','sv_abrechnungsstatus',
    'geprueft','einsatznr_ist','disponr_ist','tag','von_kalk','bis_kalk','strasse','plz','ort',
    'ortsteil','region','land','meter_soll','meter_ist','meter_kalk','sekunden_soll','sekunden_ist',
    'sekunden_kalk','fahrzeugprofil','anzahl_fahrer','kosten','leerfahrt','wochenende','feiertag',
    'dienstnr','umlaufnr','sv_teilnehmernr','sv_typ','sv_abrechenbar','sv_streckenpreis','freigabe',
    'umlauf'
  );
begin
  DoSelectFilteredDynamic('FAHRTABLAUF', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /dispo/getfahrtablaufbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.getFahrtablaufById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..69] of string = (
    'nr','datum','von_soll','von_ist','bis_soll','bis_ist','bereich','art','xkoord','ykoord',
    'sortierung','disponr','zeichen','kennzeichen','eart','dienstelementnr','dienstelementart',
    'bemerkung','zusatzfeld1','zusatzfeld2','zusatzfeld3','datumfeld1','datumfeld2','datumfeld3',
    'zustiege_soll','zustiege_ist','ausstiege_soll','ausstiege_ist','reftable','refnr','hinweis',
    'typ','einsatznr','haltnr','bezeichnung','sv_tournummer','sv_fahrtnummer','sv_abrechnungsstatus',
    'geprueft','einsatznr_ist','disponr_ist','tag','von_kalk','bis_kalk','strasse','plz','ort',
    'ortsteil','region','land','meter_soll','meter_ist','meter_kalk','sekunden_soll','sekunden_ist',
    'sekunden_kalk','fahrzeugprofil','anzahl_fahrer','kosten','leerfahrt','wochenende','feiertag',
    'dienstnr','umlaufnr','sv_teilnehmernr','sv_typ','sv_abrechenbar','sv_streckenpreis','freigabe',
    'umlauf'
  );
begin
  DoSelectOne('FAHRTABLAUF', ALLOWED, 'nr');
end;

// Route: /dispo/getfahrtablaufkey  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.getFahrtablaufKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(FAHRTABLAUF_NR_GEN,1) AS NR FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /dispo/insertfahrtablauf  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.insertFahrtablauf;
// Body: { "nr": 42, "datum": "...", ... }
const
  ALLOWED: array[0..69] of string = (
    'nr','datum','von_soll','von_ist','bis_soll','bis_ist','bereich','art','xkoord','ykoord',
    'sortierung','disponr','zeichen','kennzeichen','eart','dienstelementnr','dienstelementart',
    'bemerkung','zusatzfeld1','zusatzfeld2','zusatzfeld3','datumfeld1','datumfeld2','datumfeld3',
    'zustiege_soll','zustiege_ist','ausstiege_soll','ausstiege_ist','reftable','refnr','hinweis',
    'typ','einsatznr','haltnr','bezeichnung','sv_tournummer','sv_fahrtnummer','sv_abrechnungsstatus',
    'geprueft','einsatznr_ist','disponr_ist','tag','von_kalk','bis_kalk','strasse','plz','ort',
    'ortsteil','region','land','meter_soll','meter_ist','meter_kalk','sekunden_soll','sekunden_ist',
    'sekunden_kalk','fahrzeugprofil','anzahl_fahrer','kosten','leerfahrt','wochenende','feiertag',
    'dienstnr','umlaufnr','sv_teilnehmernr','sv_typ','sv_abrechenbar','sv_streckenpreis','freigabe',
    'umlauf'
  );
begin
  DoInsert('FAHRTABLAUF', ALLOWED);
end;

// Route: /dispo/updatefahrtablauf  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.updateFahrtablauf;
// Body: { "nr": 42, "datum": "...", ... }
const
  ALLOWED: array[0..69] of string = (
    'nr','datum','von_soll','von_ist','bis_soll','bis_ist','bereich','art','xkoord','ykoord',
    'sortierung','disponr','zeichen','kennzeichen','eart','dienstelementnr','dienstelementart',
    'bemerkung','zusatzfeld1','zusatzfeld2','zusatzfeld3','datumfeld1','datumfeld2','datumfeld3',
    'zustiege_soll','zustiege_ist','ausstiege_soll','ausstiege_ist','reftable','refnr','hinweis',
    'typ','einsatznr','haltnr','bezeichnung','sv_tournummer','sv_fahrtnummer','sv_abrechnungsstatus',
    'geprueft','einsatznr_ist','disponr_ist','tag','von_kalk','bis_kalk','strasse','plz','ort',
    'ortsteil','region','land','meter_soll','meter_ist','meter_kalk','sekunden_soll','sekunden_ist',
    'sekunden_kalk','fahrzeugprofil','anzahl_fahrer','kosten','leerfahrt','wochenende','feiertag',
    'dienstnr','umlaufnr','sv_teilnehmernr','sv_typ','sv_abrechenbar','sv_streckenpreis','freigabe',
    'umlauf'
  );
begin
  DoUpdate('FAHRTABLAUF', ALLOWED, 'nr');
end;

// Route: /dispo/deletefahrtablauf  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.deleteFahrtablauf;
begin
  DoDelete('FAHRTABLAUF', 'nr');
end;

// Route: /dispo/getliniewegeobjekte  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.getLiniewegeobjekte;
// Body: { "fields": ["nr","art",...] | "*", "orderby": "nr" }
const
  ALLOWED: array[0..13] of string = (
    'nr','art','beschreibung','imageindex','dauer','farbe','fahrerkostenkm',
    'fahrerkostenstd','fahrzeugkostenkm','fahrzeugkostenstd','profil','system',
    'eart','lohnart'
  );
begin
  DoSelect('LINIEWEGEOBJEKTE', ALLOWED);
end;

// Route: /dispo/getliniewegeobjektefiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.getLiniewegeobjekteFiltered;
// Body: { "fields": [...] | "*", "art": "HALT", "profil": 1, "orderby": "nr" }
// Alle Filter-Parameter sind optional - nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..13] of string = (
    'nr','art','beschreibung','imageindex','dauer','farbe','fahrerkostenkm',
    'fahrerkostenstd','fahrzeugkostenkm','fahrzeugkostenstd','profil','system',
    'eart','lohnart'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS uebereinstimmen).
  CONDITIONS: array[0..13] of string = (
    'nr = :nr',
    'art = :art',
    'beschreibung = :beschreibung',
    'imageindex = :imageindex',
    'dauer = :dauer',
    'farbe = :farbe',
    'fahrerkostenkm = :fahrerkostenkm',
    'fahrerkostenstd = :fahrerkostenstd',
    'fahrzeugkostenkm = :fahrzeugkostenkm',
    'fahrzeugkostenstd = :fahrzeugkostenstd',
    'profil = :profil',
    'system = :system',
    'eart = :eart',
    'lohnart = :lohnart'
  );
  FILTER_PARAMS: array[0..13] of string = (
    'nr','art','beschreibung','imageindex','dauer','farbe','fahrerkostenkm',
    'fahrerkostenstd','fahrzeugkostenkm','fahrzeugkostenstd','profil','system',
    'eart','lohnart'
  );
begin
  DoSelectFilteredDynamic('LINIEWEGEOBJEKTE', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /dispo/getliniewegeobjektebyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.getLiniewegeobjekteById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..13] of string = (
    'nr','art','beschreibung','imageindex','dauer','farbe','fahrerkostenkm',
    'fahrerkostenstd','fahrzeugkostenkm','fahrzeugkostenstd','profil','system',
    'eart','lohnart'
  );
begin
  DoSelectOne('LINIEWEGEOBJEKTE', ALLOWED, 'nr');
end;

end.
