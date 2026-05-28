unit DataModulAnmietClass;

interface

uses
  Web.HTTPApp,   System.JSON,
  DataModulTableBaseClass,
  System.SysUtils, System.Classes, DataModulBaseClass, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt, FireDAC.UI.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Phys, FireDAC.Phys.IB, FireDAC.Phys.IBDef, FireDAC.VCLUI.Wait, Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet;

type
  TDataModulAnmiet = class(TDataModulTableBase)
  private

    { Private-Deklarationen }
  public
    { Public-Deklarationen }
     procedure Demo;
  end;


function CreateDataModulAnmiet(Request: TWebRequest; Response: TWebResponse): TObject;

implementation
uses webutils;

function CreateDataModulAnmiet(Request: TWebRequest; Response: TWebResponse): TObject;
begin
  Result := TDataModulAnmiet.Create(Request, Response);
end;

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}




// DEMO - Vorlage für neue Endpunkte, vor Produktivbetrieb entfernen
// Zeigt: URL-Parameter lesen, JSON-Body verarbeiten, Response aufbauen
// Route: /touristik/demo  |  Auth: true  |  LocalOnly: false
procedure TDataModulAnmiet.Demo;
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




end.
