unit DataModulDispoClass;

interface

uses
  Web.HTTPApp,   System.JSON,
  System.SysUtils, System.Classes, DataModulTableBaseClass, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt,
  FireDAC.UI.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Phys, FireDAC.Phys.IB, FireDAC.Phys.IBDef, FireDAC.VCLUI.Wait, Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet;

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

// DEMO - Vorlage für neue Endpunkte, vor Produktivbetrieb entfernen
// Zeigt: URL-Parameter lesen, JSON-Body verarbeiten, Response aufbauen
// Route: /dispo/demo  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.Demo;
var
  ID: string;
  Body: TJSONObject;
begin
  ID := Request.QueryFields.Values['ID'];

  if Request.Content <> '' then
  begin
    Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
    if Assigned(Body) then
    try
      Response.ContentType := 'application/json';
      Response.StatusCode  := 200;
      Response.Content     := Body.ToJSON;
    finally
      Body.Free;
    end
    else
       raise Exception.Create('ungültiges Json im Request-Body');
  end
  else if ID <> '' then
  begin
    Response.ContentType := 'application/json';
    Response.StatusCode  := 200;
    Response.Content     := Format('{"ID":"%s"}', [ID]);
  end
  else
  begin
    Response.ContentType := 'application/json';
    Response.StatusCode  := 200;
    Response.Content     := '{"message":"Hallo Welt"}';
  end;
end;

// Route: /dispo/geteinsatz  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.getEinsatz;
// Body: { "fields": ["nr","von","bis",...] | "*", "orderby": "von" }
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
// Body: { "fields": [...] | "*", "von": "2024-01-01", "bis": "2024-12-31", "orderby": "von" }
VAR
  timemodeVal:  TJSONValue;
  timemode:   string;
  Filter:String;
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
  FILTER := 'von >= :von AND bis <= :bis';
  timemode := Request.QueryFields.Values['timemode'];

  if timemode = '' then
  begin
    var Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
    if Assigned(Body) then
    try
      timemodeVal := Body.GetValue('timemode');
      if Assigned(timemodeVal) and not timemodeVal.Null then
        timemode := LowerCase(timemodeVal.Value);
    finally
      Body.Free;
    end;
  end;

  if timemode = 'inside_range' then
    FILTER := 'bis >= :von AND von < :bis'
  else
    FILTER := 'von >= :von AND von < :bis';

  DoSelectFiltered('EINSATZ', ALLOWED, FILTER, FILTER_PARAMS);
end;

procedure TDataModulDispo.getfahrergruppen;
begin

  Try
    Connection.StartTransaction;
    with Query do
    Begin
      close;
      sql.text:='Select nr,name,cast(content as varchar(20000)) As ids from KONFIGURATION where art=''G_R_P'' and art2=''PERSON'' order by name';
      open;

      Response.ContentType := 'application/json';
      Response.StatusCode  := 200;
      Response.Content     := SerializeQuery(Query);
      Connection.Commit;
    End;
  Except
    on e:Exception do
    Begin
      Connection.Rollback;
      raise;
    End;
  End;
end;

procedure TDataModulDispo.getpersonalstamm;
begin

  Try
    Connection.StartTransaction;
    with Query do
    Begin
      close;
      sql.text:='Select nr,name1,name2,zeichen from PERSONALSTAMM order by name2';
      open;

      Response.ContentType := 'application/json';
      Response.StatusCode  := 200;
      Response.Content     := SerializeQuery(Query);
      Connection.Commit;
    End;
  Except
    on e:Exception do
    Begin
      Connection.Rollback;
      raise;
    End;
  End;
end;


// Route: /dispo/geteinsatzbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulDispo.getEinsatzById;
// Body: { "nr": 42, "fields": [...] | "*" }
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

end.
