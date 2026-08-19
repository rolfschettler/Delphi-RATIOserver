unit DataModulRegistrierungClass;

interface

uses
  Web.HTTPApp,   System.JSON,
  DataModulTableBaseClass,
  System.SysUtils, System.Classes, DataModulBaseClass, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt, FireDAC.UI.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Phys, FireDAC.Phys.IB, FireDAC.Phys.IBDef, FireDAC.VCLUI.Wait, Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet;

type
  TDataModulRegistrierung = class(TDataModulTableBase)
  private

    { Private-Deklarationen }
  public
    { Public-Deklarationen }
    procedure getRegistrierung;
    procedure getRegistrierungFiltered;
    procedure getRegistrierungById;
    procedure getRegistrierungKey;
    procedure insertRegistrierung;
    procedure insertRegistrierungLocal;
    procedure updateRegistrierung;
    procedure deleteRegistrierung;
  end;


function CreateDataModulRegistrierung(Request: TWebRequest; Response: TWebResponse): TObject;

implementation
uses webutils;

function CreateDataModulRegistrierung(Request: TWebRequest; Response: TWebResponse): TObject;
begin
  Result := TDataModulRegistrierung.Create(Request, Response);
end;

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}

{ TDataModulRegistrierung }

// Route: /registrierung/getregistrierung  |  Auth: true  |  LocalOnly: false
procedure TDataModulRegistrierung.getRegistrierung;
// Body: { "fields": ["nr","kennziffer",...] | "*", "orderby": "nr" }
const
  ALLOWED: array[0..14] of string = (
    'nr','kennziffer','pwd','username','userkonfig',
    'erstellt','geaendert','gesperrt','pwd2','versuche',
    'zeitsperre','pushid','letzter_login','hauptregistrierung','typ'
  );
begin
  DoSelect('REGISTRIERUNG', ALLOWED);
end;

// Route: /registrierung/getregistrierungfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulRegistrierung.getRegistrierungFiltered;
// Body: { "fields": [...] | "*", "nr": 1, "kennziffer": 42, "username": "...", ..., "orderby": "nr" }
// Alle Filter-Parameter sind optional - nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..14] of string = (
    'nr','kennziffer','pwd','username','userkonfig',
    'erstellt','geaendert','gesperrt','pwd2','versuche',
    'zeitsperre','pushid','letzter_login','hauptregistrierung','typ'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS uebereinstimmen).
  // userkonfig (Blob) ist bewusst nicht filterbar.
  CONDITIONS: array[0..13] of string = (
    'nr = :nr',
    'kennziffer = :kennziffer',
    'pwd = :pwd',
    'username = :username',
    'erstellt = :erstellt',
    'geaendert = :geaendert',
    'gesperrt = :gesperrt',
    'pwd2 = :pwd2',
    'versuche = :versuche',
    'zeitsperre = :zeitsperre',
    'pushid = :pushid',
    'letzter_login = :letzter_login',
    'hauptregistrierung = :hauptregistrierung',
    'typ = :typ'
  );
  FILTER_PARAMS: array[0..13] of string = (
    'nr','kennziffer','pwd','username',
    'erstellt','geaendert','gesperrt','pwd2','versuche',
    'zeitsperre','pushid','letzter_login','hauptregistrierung','typ'
  );
begin
  DoSelectFilteredDynamic('REGISTRIERUNG', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /registrierung/getregistrierungbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulRegistrierung.getRegistrierungById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..14] of string = (
    'nr','kennziffer','pwd','username','userkonfig',
    'erstellt','geaendert','gesperrt','pwd2','versuche',
    'zeitsperre','pushid','letzter_login','hauptregistrierung','typ'
  );
begin
  DoSelectOne('REGISTRIERUNG', ALLOWED, 'nr');
end;

// Route: /registrierung/getregistrierungkey  |  Auth: true  |  LocalOnly: false
procedure TDataModulRegistrierung.getRegistrierungKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(REGISTRIERUNG_NR_GEN, 1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /registrierung/insertregistrierung  |  Auth: true  |  LocalOnly: false
procedure TDataModulRegistrierung.insertRegistrierung;
// Body: { "kennziffer": 42, "username": "...", ... }
const
  ALLOWED: array[0..13] of string = (
    'kennziffer','pwd','username','userkonfig',
    'erstellt','geaendert','gesperrt','pwd2','versuche',
    'zeitsperre','pushid','letzter_login','hauptregistrierung','typ'
  );
begin
  DoInsert('REGISTRIERUNG', ALLOWED);
end;

// Route: /registrierung/insertregistrierunglocal  |  Auth: false  |  LocalOnly: true
procedure TDataModulRegistrierung.insertRegistrierungLocal;
// Body: { "kennziffer": 42, "username": "...", ... }
const
  ALLOWED: array[0..1] of string = (
    'username','pwd2');
begin
  DoInsert('REGISTRIERUNG', ALLOWED);
end;

// Route: /registrierung/updateregistrierung  |  Auth: true  |  LocalOnly: false
procedure TDataModulRegistrierung.updateRegistrierung;
// Body: { "nr": 42, "username": "...", ... }
const
  ALLOWED: array[0..13] of string = (
    'kennziffer','pwd','username','userkonfig',
    'erstellt','geaendert','gesperrt','pwd2','versuche',
    'zeitsperre','pushid','letzter_login','hauptregistrierung','typ'
  );
begin
  DoUpdate('REGISTRIERUNG', ALLOWED, 'nr');
end;

// Route: /registrierung/deleteregistrierung  |  Auth: true  |  LocalOnly: false
procedure TDataModulRegistrierung.deleteRegistrierung;
// Body: { "nr": 42 }
begin
  DoDelete('REGISTRIERUNG', 'nr');
end;

end.
