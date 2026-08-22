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

uses rechtelib, webUtils, PHPSupport, System.JSON;

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

  Prüfung:
    Der Benutzer wird in der Tabelle REGISTRIERUNG über das Feld USERNAME gesucht
    (case-insensitiv per UPPER, da InterBase kein LOWER kennt).
    Das Passwort wird im Klartext erwartet (keine Codierung) und NICHT mehr in
    Delphi verglichen, sondern über den PHP-Endpunkt /checkcryptedpassword
    geprüft: dieser verifiziert das Passwort per password_verify() gegen den
    bcrypt-Hash aus REGISTRIERUNG.PWD2.

  Hinweis URL-Encoding:
    Bei GET und POST Form-encoded dekodiert Delphi URL-Encoding automatisch.
    Ein "+" im Passwort wird dabei als Leerzeichen interpretiert —
    der Aufrufer muss in diesem Fall "+" als "%2B" kodieren.
    Bei JSON-Body kann "+" direkt verwendet werden.
*)
var
  username: string;
  password: string;
  hash: string;
  JSONObject: TJSONObject;

  procedure ReadFromJson;
  begin
    if Request.Content = '' then Exit;
    JSONObject := ParseJSONObject(Request.Content);
    if not Assigned(JSONObject) then Exit;
    try
      username := JSONObject.GetValue<string>('user', '');
      password := JSONObject.GetValue<string>('password', '');
    finally
      JSONObject.Free;
    end;
  end;

  // Prüft das Klartext-Passwort über den PHP-Endpunkt /checkcryptedpassword
  // gegen den bcrypt-Hash. Erwartete Antwort: {"status":"OK","data":{"match":true}}
  function CheckPasswordViaPHP(const APlain, AHash: string): boolean;
  var
    Params: TJSONObject;
    ResponseObj: TJSONObject;
    DataValue: TJSONValue;
    MatchValue: TJSONValue;
    ResponseText: string;
  begin
    Result := false;

    Params := TJSONObject.Create;
    try
      Params.AddPair('password', APlain);
      Params.AddPair('hash', AHash);
      ResponseText := PHP_Call('checkcryptedpassword', Params);
    finally
      Params.Free;
    end;

    ResponseObj := ParseJSONObject(ResponseText);
    if not Assigned(ResponseObj) then Exit;
    try
      if not SameText(ResponseObj.GetValue<string>('status', ''), 'OK') then Exit;

      DataValue := ResponseObj.GetValue('data');
      if not (DataValue is TJSONObject) then Exit;

      MatchValue := TJSONObject(DataValue).GetValue('match');
      Result := Assigned(MatchValue) and (MatchValue is TJSONTrue);
    finally
      ResponseObj.Free;
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
      sql.text := 'select nr,kennziffer,username as loginname,username,gesperrt,typ,hauptregistrierung,pwd2 from registrierung where UPPER(username)= UPPER(:username)';
      ParamByName('username').AsString := username;
      open;
      if (eof and bof) then
        raise Exception.Create('Benutzername oder Passwort sind falsch');
      hash := trim(FieldByName('pwd2').AsString);
    end;

    if hash = '' then
      raise Exception.Create('Benutzername oder Passwort sind falsch');

    // Hashprüfung durch den PHP-Endpunkt /checkcryptedpassword
    if not CheckPasswordViaPHP(password, hash) then
      raise Exception.Create('Benutzername oder Passwort sind falsch');

    // pwd2 (Hash) gehört nicht in die Role bzw. in den Token
    for var i := 0 to query.FieldCount - 1 do
      if not SameText(query.fields[i].FieldName, 'pwd2') then
        sl.add(lowercase(query.fields[i].FieldName) + '=' + trim(query.fields[i].AsString));
    result:=true;
  except
    on e: Exception do
     sl.text :=   CreateJsonResponse('error',e.message);
  end;
end;

end.


