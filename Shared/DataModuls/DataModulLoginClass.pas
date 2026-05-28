unit DataModulLoginClass;

interface

uses
  Web.HTTPApp,

  System.SysUtils, System.Classes, DataModulBaseClass, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt, FireDAC.UI.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Phys, FireDAC.Phys.IB, FireDAC.Phys.IBDef,  Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet,  FireDAC.Comp.UI, FireDAC.VCLUI.Wait;

type
  TDataModulLoginClass = class(TDataModulBaseClass)
  private
    { Private-Deklarationen }

  public
    { Public-Deklarationen }
    function login(sl: TStringList): boolean;
  end;

function CreateDataModulLoginClass(Request: TWebRequest; Response: TWebResponse): TObject;

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}

uses rechtelib, webUtils, System.JSON;

{$R *.dfm}

function CreateDataModulLoginClass(Request: TWebRequest; Response: TWebResponse): TObject;
begin
  Result := TDataModulLoginClass.Create(Request, Response);
end;

{ TTDataModulLoginClass }

function TDataModulLoginClass.login(sl: TStringList): boolean;
(*
  Unterstützte Aufrufvarianten:
    1. POST JSON-Body:       {"user": "hans", "password": "xxx"}
    2. POST Form-encoded:    user=hans&password=xxx
    3. GET URL-Parameter:    ?user=hans&password=xxx
  Priorität: JSON → Form-encoded → URL-Parameter

  Hinweis URL-Encoding:
    Bei GET und POST Form-encoded dekodiert Delphi URL-Encoding automatisch,
    bevor der Wert an DeCodieren() übergeben wird.
    Ein "+" im Passwort wird dabei als Leerzeichen interpretiert —
    der Aufrufer muss in diesem Fall "+" als "%2B" kodieren.
    Bei JSON-Body kann "+" direkt verwendet werden.
*)
var
  username: string;
  password: string;
  JSONObject: TJSONObject;

  procedure ReadFromJson;
  begin
    if Request.Content = '' then Exit;
    JSONObject := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
    if not Assigned(JSONObject) then Exit;
    try
      username := JSONObject.GetValue<string>('user', '');
      password := JSONObject.GetValue<string>('password', '');
    finally
      JSONObject.Free;
    end;
  end;

begin
  username := '';
  password := '';

  // 1. JSON-Body (POST application/json)
  ReadFromJson;

  // 2. Form-encoded (POST application/x-www-form-urlencoded)
  if username = '' then
    username := Request.ContentFields.Values['user'];
  if password = '' then
    password := Request.ContentFields.Values['password'];

  // 3. URL-Parameter (GET ?user=...&password=...)
  if username = '' then
    username := Request.QueryFields.Values['user'];
  if password = '' then
    password := Request.QueryFields.Values['password'];
  Result := false;

  try
//  raise Exception.Create('Fehlermeldung');

    with query do
    begin
      close;
      sql.text := 'select loginname,username,passwort,gruppe,zugruppe,agenturcode,kennziffer,filiale,abteilung from users where loginname= :username and ((passwort= :password) or (passwort is null) or (passwort =''''))';
      ParamByName('username').AsString := username;
      ParamByName('password').AsString := DeCodieren(password);
      open;
      if (eof and bof) then
        raise Exception.Create('Benutzername oder Passwort sind falsch');
    end;

    for var i := 0 to query.FieldCount - 1 do
      sl.add(lowercase(query.fields[i].FieldName) + '=' + query.fields[i].AsString);
    result:=true;
  except
    on e: Exception do
     sl.text :=   CreateJsonResponse('error',e.message);
  end;
end;

end.


