unit DataModulWhateverClass;

interface

uses
  Web.HTTPApp, System.SysUtils, System.Classes,
  DataModulTableBaseClass, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt, FireDAC.UI.Intf, FireDAC.Stan.Def,
  FireDAC.Stan.Pool, FireDAC.Phys, FireDAC.Phys.IB, FireDAC.Phys.IBDef, FireDAC.VCLUI.Wait, Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet;

type
  TDataModulWhatever = class(TDataModulTableBase)
  public
    procedure getTablename;
    procedure getTablenameFiltered;
    procedure getTablenameById;
    procedure getTablenameKey;
    procedure insertTablename;
    procedure updateTablename;
    procedure deleteTablename;
  end;

function CreateDataModulWhatever(Request: TWebRequest; Response: TWebResponse): TObject;

implementation

uses webutils;

function CreateDataModulWhatever(Request: TWebRequest; Response: TWebResponse): TObject;
begin
  Result := TDataModulWhatever.Create(Request, Response);
end;

{%CLASSGROUP 'Vcl.Controls.TControl'}
{$R *.dfm}

{ TDataModulWhatever }

// Route: /getTablename  |  Auth: true  |  LocalOnly: false
procedure TDataModulWhatever.getTablename;
// Body: { "fields": ["Field1","Field2",...] | "*", "orderby": "Field" }
const
  ALLOWED: array[0..12] of string = (
    'Field1','Field2','Field3','Field4'
  );
begin
  DoSelect('TABLENAME', ALLOWED);
end;

// Route: /getTablenamefiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulWhatever.getTablenameFiltered;
// Body: { "fields": [...] | "*", "Field1": "value1", "Field2": "value2", "orderby": "Field1" }
// Alle Filter-Parameter sind optional – nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..2] of string = (
    'Field1','Field2','Field3'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS übereinstimmen).
  CONDITIONS: array[0..1] of string = (
    'Field1 = :Field1',
    'Field2 = :Field2'
  );
  FILTER_PARAMS: array[0..1] of string = ('Field1', 'Field2');
begin
  DoSelectFilteredDynamic('TABLENAME', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /getTablenamebyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulWhatever.getTablenameById;
// Body: { "primarykeyfield": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..10] of string = (
    'Field1','Field3','Field4'
  );
begin
  DoSelectOne('TABLENAME', ALLOWED, 'primarykeyfield');
end;

// Route: /getTablenameKey  |  Auth: true  |  LocalOnly: false
procedure TDataModulWhatever.getTablenameKey;
begin
  Query.SQL.Text := 'SELECT * FROM ##ASK ME FOR NAME OF GENERATOR##';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;



// Route: /insertTablename  |  Auth: true  |  LocalOnly: false
procedure TDataModulWhatever.insertTablename;
// Body: { "name1": "...", "ort": "...", ... }
const
  ALLOWED: array[0..10] of string = (
    'Field1','Field2','Field3'
  );
begin
  DoInsert('TABLENAME', ALLOWED);
end;

// Route: /updateTablename  |  Auth: true  |  LocalOnly: false
procedure TDataModulWhatever.updateTablename;
// Body: { "primarykeyfield": 42, "name1": "...", ... }
const
  ALLOWED: array[0..9] of string = (
    'Field1','Field2','Field3'
  );
begin
  DoUpdate('TABLENAME', ALLOWED, 'primarykeyfield');
end;

// Route: /deleteTablename  |  Auth: true  |  LocalOnly: false
procedure TDataModulWhatever.deleteTablename;
// Body: { "primarykeyfield": 42 }
begin
  DoDelete('TABLENAME', 'primarykeyfield');
end;

end.
