unit DataModulIncomingClass;

interface

uses
  Web.HTTPApp, System.JSON, System.SysUtils, System.Classes,
  DataModulTableBaseClass,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param,
  FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf,
  FireDAC.Stan.Async, FireDAC.DApt, FireDAC.UI.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Phys, FireDAC.Phys.IB,
  FireDAC.Phys.IBDef, FireDAC.VCLUI.Wait, Data.DB,
  FireDAC.Comp.Client, FireDAC.Comp.DataSet, DataModulBaseClass;

type
  TDataModulIncoming = class(TDataModulTableBase)
  public
    procedure Demo;
    procedure getTeilnehmer;
    procedure getTeilnehmerFiltered;
    procedure getTeilnehmerById;
    procedure getT_TeilnehmerNextNr;
    procedure insertT_Teilnehmer;
    procedure updateT_Teilnehmer;
    procedure deleteT_Teilnehmer;
  end;

function CreateDataModulIncoming(Request: TWebRequest; Response: TWebResponse): TObject;

implementation

uses webutils;

function CreateDataModulIncoming(Request: TWebRequest; Response: TWebResponse): TObject;
begin
  Result := TDataModulIncoming.Create(Request, Response);
end;

{%CLASSGROUP 'Vcl.Controls.TControl'}
{$R *.dfm}

{ TDataModulIncoming }

// DEMO - Vorlage für neue Endpunkte, vor Produktivbetrieb entfernen
// Zeigt: URL-Parameter lesen, JSON-Body verarbeiten, Response aufbauen
// Route: /incoming/demo  |  Auth: true  |  LocalOnly: false
procedure TDataModulIncoming.Demo;
var
  ID: string;
  Body: TJSONObject;
begin
  // URL-Parameter "ID" lesen, z.B. /incoming/demo?ID=42
  ID := Request.QueryFields.Values['ID'];

  // Request-Body einlesen, falls vorhanden
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

// Route: /incoming/getteilnehmer  |  Auth: true  |  LocalOnly: false
procedure TDataModulIncoming.getTeilnehmer;
// Body: { "fields": ["nr","name",...] | "*", "orderby": "name" }
const
  ALLOWED: array[0..57] of string = (
    'nr','vorgangnr','anrede','name','kennziffer','geburtstag','jahre',
    'shuttle','info1','info2','ref1','ref2','gruppe','sitzfest',
    'hininfo','rueckinfo','ausstiegrueck','profil','status',
    'reservierungsnr','kabinengruppe','infofaehre','zustieghin',
    'ausstieghin','zustiegrueck','ausstieg_rueck','sitzhin','sitzrueck',
    'leistungen','passnummer','ausgestellt_in','ausgestellt_am',
    'gueltig_bis','passinfo','passid','nation','geburtsort',
    'name1','name2','name3','namenszusatz','titel','email',
    'land','ort','ortsteil','plz','region','strasse',
    'telefon1','telefon2','telefon3','xkoord','ykoord',
    'heimatort','pass_name1','pass_name2','zusatzdaten'
  );
begin
  DoSelect('T_TEILNEHMER', ALLOWED);
end;

// Route: /incoming/getteilnehmerfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulIncoming.getTeilnehmerFiltered;
// Body: { "fields": [...] | "*", "vorgangnr": 42, "orderby": "name" }
const
  ALLOWED: array[0..57] of string = (
    'nr','vorgangnr','anrede','name','kennziffer','geburtstag','jahre',
    'shuttle','info1','info2','ref1','ref2','gruppe','sitzfest',
    'hininfo','rueckinfo','ausstiegrueck','profil','status',
    'reservierungsnr','kabinengruppe','infofaehre','zustieghin',
    'ausstieghin','zustiegrueck','ausstieg_rueck','sitzhin','sitzrueck',
    'leistungen','passnummer','ausgestellt_in','ausgestellt_am',
    'gueltig_bis','passinfo','passid','nation','geburtsort',
    'name1','name2','name3','namenszusatz','titel','email',
    'land','ort','ortsteil','plz','region','strasse',
    'telefon1','telefon2','telefon3','xkoord','ykoord',
    'heimatort','pass_name1','pass_name2','zusatzdaten'
  );
  FILTER       = 'vorgangnr = :vorgangnr';
  FILTER_PARAMS: array[0..0] of string = ('vorgangnr');
begin
  DoSelectFiltered('T_TEILNEHMER', ALLOWED, FILTER, FILTER_PARAMS);
end;

// Route: /incoming/getteilnehmerbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulIncoming.getTeilnehmerById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..57] of string = (
    'nr','vorgangnr','anrede','name','kennziffer','geburtstag','jahre',
    'shuttle','info1','info2','ref1','ref2','gruppe','sitzfest',
    'hininfo','rueckinfo','ausstiegrueck','profil','status',
    'reservierungsnr','kabinengruppe','infofaehre','zustieghin',
    'ausstieghin','zustiegrueck','ausstieg_rueck','sitzhin','sitzrueck',
    'leistungen','passnummer','ausgestellt_in','ausgestellt_am',
    'gueltig_bis','passinfo','passid','nation','geburtsort',
    'name1','name2','name3','namenszusatz','titel','email',
    'land','ort','ortsteil','plz','region','strasse',
    'telefon1','telefon2','telefon3','xkoord','ykoord',
    'heimatort','pass_name1','pass_name2','zusatzdaten'
  );
begin
  DoSelectOne('T_TEILNEHMER', ALLOWED, 'nr');
end;

// Route: /incoming/insertt_teilnehmer  |  Auth: true  |  LocalOnly: false
procedure TDataModulIncoming.insertT_Teilnehmer;
// Body: { "nr": 42, "vorgangnr": 1, "name": "...", ... }
const
  ALLOWED: array[0..57] of string = (
    'nr','vorgangnr','anrede','name','kennziffer','geburtstag','jahre',
    'shuttle','info1','info2','ref1','ref2','gruppe','sitzfest',
    'hininfo','rueckinfo','ausstiegrueck','profil','status',
    'reservierungsnr','kabinengruppe','infofaehre','zustieghin',
    'ausstieghin','zustiegrueck','ausstieg_rueck','sitzhin','sitzrueck',
    'leistungen','passnummer','ausgestellt_in','ausgestellt_am',
    'gueltig_bis','passinfo','passid','nation','geburtsort',
    'name1','name2','name3','namenszusatz','titel','email',
    'land','ort','ortsteil','plz','region','strasse',
    'telefon1','telefon2','telefon3','xkoord','ykoord',
    'heimatort','pass_name1','pass_name2','zusatzdaten'
  );
begin
  DoInsert('T_TEILNEHMER', ALLOWED);
end;

// Route: /incoming/updatet_teilnehmer  |  Auth: true  |  LocalOnly: false
procedure TDataModulIncoming.updateT_Teilnehmer;
// Body: { "nr": 42, "name": "...", ... }
const
  ALLOWED: array[0..56] of string = (
    'vorgangnr','anrede','name','kennziffer','geburtstag','jahre',
    'shuttle','info1','info2','ref1','ref2','gruppe','sitzfest',
    'hininfo','rueckinfo','ausstiegrueck','profil','status',
    'reservierungsnr','kabinengruppe','infofaehre','zustieghin',
    'ausstieghin','zustiegrueck','ausstieg_rueck','sitzhin','sitzrueck',
    'leistungen','passnummer','ausgestellt_in','ausgestellt_am',
    'gueltig_bis','passinfo','passid','nation','geburtsort',
    'name1','name2','name3','namenszusatz','titel','email',
    'land','ort','ortsteil','plz','region','strasse',
    'telefon1','telefon2','telefon3','xkoord','ykoord',
    'heimatort','pass_name1','pass_name2','zusatzdaten'
  );
begin
  DoUpdate('T_TEILNEHMER', ALLOWED, 'nr');
end;

// Route: /incoming/deletet_teilnehmer  |  Auth: true  |  LocalOnly: false
procedure TDataModulIncoming.deleteT_Teilnehmer;
// Body: { "nr": 42 }
begin
  DoDelete('T_TEILNEHMER', 'nr');
end;

// Route: /incoming/gett_teilnehmernextnr  |  Auth: true  |  LocalOnly: false
procedure TDataModulIncoming.getT_TeilnehmerNextNr;
begin
  Query.SQL.Text := 'SELECT GEN_ID(T_TEILNEHMER_NR_GEN,1) FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

end.

