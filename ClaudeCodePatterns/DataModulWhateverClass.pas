unit DataModulAdressenClass;

interface

uses
  Web.HTTPApp, System.SysUtils, System.Classes,
  DataModulTableBaseClass, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt, FireDAC.UI.Intf, FireDAC.Stan.Def,
  FireDAC.Stan.Pool, FireDAC.Phys, FireDAC.Phys.IB, FireDAC.Phys.IBDef, FireDAC.VCLUI.Wait, Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet;

type
  TDataModulAdressen = class(TDataModulTableBase)
  public
    procedure getTablename;
    procedure getTablenameFiltered;
    procedure getTablenameById;
    procedure getTablenameKey;
    procedure insertTablename;
    procedure updateTablename;
    procedure deleteTablename;
  end;

function CreateDataModulAdressen(Request: TWebRequest; Response: TWebResponse): TObject;

implementation

uses webutils;

function CreateDataModulAdressen(Request: TWebRequest; Response: TWebResponse): TObject;
begin
  Result := TDataModulAdressen.Create(Request, Response);
end;

{%CLASSGROUP 'Vcl.Controls.TControl'}
{$R *.dfm}

{ TDataModulAdressen }

// Route: /getTablename  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getTablename;
// Body: { "fields": ["Field1","Field2",...] | "*", "orderby": "Field" }
const
  ALLOWED: array[0..12] of string = (
    'Field1','Field2','Field3','Field4'
  );
begin
  DoSelect('TABLENAME', ALLOWED);
end;

// Route: /getTablenamefiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getTablenameFiltered;
// Body: { "fields": [...] | "*", "Field1": "Field1", "orderby": "name1" }
const
  ALLOWED: array[0..12] of string = (
    'Field1','Field2','Field3'
  );
  FILTER        = 'Field1 = :Field1';
  FILTER_PARAMS: array[0..0] of string = ('value1');
begin
  DoSelectFiltered('TABLENAME', ALLOWED, FILTER, FILTER_PARAMS);
end;

// Route: /getTablenamebyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getTablenameById;
// Body: { "primarykeyfield": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..10] of string = (
    'Field1','Field3','Field4'
  );
begin
  DoSelectOne('TABLENAME', ALLOWED, 'primarykeyfield');
end;

// Route: /getTablenameKey  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getTablenameKey;
begin
  Query.SQL.Text := 'SELECT * FROM ##ASK ME FOR NAME OF GENERATOR##';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;



// Route: /insertTablename  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.insertTablename;
// Body: { "name1": "...", "ort": "...", ... }
const
  ALLOWED: array[0..10] of string = (
    'Field1','Field2','Field3'
  );
begin
  DoInsert('TABLENAME', ALLOWED);
end;

// Route: /updateTablename  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.updateTablename;
// Body: { "primarykeyfield": 42, "name1": "...", ... }
const
  ALLOWED: array[0..9] of string = (
    'Field1','Field2','Field3'
  );
begin
  DoUpdate('TABLENAME', ALLOWED, 'primarykeyfield');
end;

// Route: /deleteTablename  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.deleteTablename;
// Body: { "primarykeyfield": 42 }
begin
  DoDelete('TABLENAME', 'primarykeyfield');
end;

end.
