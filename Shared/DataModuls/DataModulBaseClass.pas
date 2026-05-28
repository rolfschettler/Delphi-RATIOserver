unit DataModulBaseClass;

interface

uses
  JOSE.Core.JWT,
  uJWTUtils,
  Web.HTTPApp, System.JSON,
  System.SysUtils, System.Classes, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys, FireDAC.Phys.IB, FireDAC.Phys.IBDef,
  FireDAC.Stan.Param, FireDAC.DatS, FireDAC.DApt.Intf, FireDAC.DApt, Data.DB, FireDAC.Comp.DataSet, FireDAC.Comp.Client, FireDAC.VCLUI.Wait;

type
  TUserInfo = record
    LoginName: string;
    UserName: string;
    Passwort: string;
    Gruppe: string;
    Zugruppe: string;
    AgenturCode: string;
    Kennziffer: string;
    Filiale: string;
    Abteilung: string;
  end;

  TDataModulBaseClass = class(TDataModule)
    Query: TFDQuery;
    Connection: TFDConnection;
    procedure DataModuleCreate(Sender: TObject);
    procedure DataModuleDestroy(Sender: TObject);
  private
    FRequest: TWebRequest;
    FResponse: TWebResponse;
    //function GetServerPort: Integer;

    // function GetDocumentRootFromCgi: string;
    { Private-Deklarationen }
  public
    { Public-Deklarationen }
    paths: TArray<string>;
    last_pathInfo: string;
    first_pathInfo: string;
    function GetUserInfo(): TUserInfo;
    function GetAuthToken(): string;

    constructor Create(ARequest: TWebRequest; AResponse: TWebResponse); reintroduce;
    procedure initConnection;
//    procedure RunLogic;
//    procedure DoSomething; virtual;
    property Request: TWebRequest read FRequest;
    property Response: TWebResponse read FResponse;
  end;

function CreateDataModulBaseClass(Request: TWebRequest; Response: TWebResponse): TObject;

implementation

uses WebReq, webUtils, router;

{%CLASSGROUP 'Vcl.Controls.TControl'}
{$R *.dfm}

function CreateDataModulBaseClass(Request: TWebRequest; Response: TWebResponse): TObject;
begin
  Result := TDataModulBaseClass.Create(Request, Response);
end;

constructor TDataModulBaseClass.Create(ARequest: TWebRequest; AResponse: TWebResponse);

begin
  inherited Create(nil);
  FRequest := ARequest;
  FResponse := AResponse;

  paths := [];
  first_pathInfo := '';
  last_pathInfo := '';
  if (Request.PathInfo <> '') then
  begin
    paths := ExcludeLastSlash(Request.PathInfo).split(['/']);
    first_pathInfo := LowerCase(ExcludeLastSlash(paths[1]));
    last_pathInfo := LowerCase((paths[Length(paths) - 1]));
  end;
end;

(*
function TDataModulBaseClass.GetServerPort: Integer;
var
  sPort, sHost: string;
  ColonPos: Integer;
begin
  //Ermittelt den Port der für den Request zuständig ist
  // SERVER_PORT: funktioniert bei CGI und Apache-Modul
  sPort := Trim(Request.GetFieldByName('SERVER_PORT'));
  Result := StrToIntDef(sPort, 0);
  if Result > 0 then Exit;

  // Fallback: Port aus HTTP_HOST extrahieren (z.B. "myserver.com:8080")
  sHost := Request.GetFieldByName('HTTP_HOST');
  ColonPos := Pos(':', sHost);
  if ColonPos > 0 then
  begin
    Result := StrToIntDef(Copy(sHost, ColonPos + 1, MaxInt), 0);
    if Result > 0 then Exit;
  end;

  // Letzter Fallback über HTTPS
  if (Request.GetFieldByName('HTTPS') = 'on') or
     (Request.GetFieldByName('HTTPS') = '1') then
    Result := 443
  else
    Result := 80;
end;
*)






procedure TDataModulBaseClass.DataModuleCreate(Sender: TObject);
begin
  initConnection;
  try

    Connection.Connected := true;

  except
    on E: Exception do
      raise Exception.Create('Verbindung zur Datenbank nicht möglich:' + E.Message);

  end;

end;

procedure TDataModulBaseClass.DataModuleDestroy(Sender: TObject);
begin
  if Connection.Connected then
    Connection.Connected := false;
end;

function TDataModulBaseClass.GetAuthToken: string;
(*
  Liest den JWT-Bearer-Token aus dem Authorization-Header des eingehenden Requests.
  Gibt den reinen Token-String zurück (ohne "Bearer "-Präfix).
  Gibt einen leeren String zurück, wenn kein Token vorhanden ist.

  Verwendung in abgeleiteten Klassen:
    // Token an PHP-Adapter weitergeben
    Result := PHP_Call('meinEndpunkt', Params, GetAuthToken);

    // Token für eigene Verarbeitung
    var Token := GetAuthToken;
    if Token = '' then
      raise Exception.Create('Kein Token vorhanden');
*)
var
  AuthHeader: string;
begin
  AuthHeader := Request.GetFieldByName('Authorization');
  if AuthHeader.StartsWith('Bearer ', true) then
    Result := AuthHeader.Substring(7)
  else
    Result := '';
end;

function TDataModulBaseClass.GetUserInfo: TUserInfo;
var
  JSONObject: TJSONObject;

  AuthHeader, Token: string;
  Claims: TJWT;

begin
  JSONObject := nil;
  Claims := nil;
  try
    AuthHeader := Request.GetFieldByName('Authorization');
    if AuthHeader.StartsWith('Bearer ', true) then
      Token := AuthHeader.Substring(7)
    else
      Token := Request.QueryFields.Values['token'];
    if Token = '' then
      exit;
    if TJWTUtils.VerifyToken(Token, Claims) then
    begin
      JSONObject := TJSONObject.ParseJSONValue(Claims.Claims.JSON.Values['role'].Value) as TJSONObject;
      if Assigned(JSONObject) then
      begin
        Result.LoginName := JSONObject.GetValue<string>('loginname', '');
        Result.UserName := JSONObject.GetValue<string>('username', '');
        Result.Passwort := JSONObject.GetValue<string>('passwort', '');
        Result.Gruppe := JSONObject.GetValue<string>('gruppe', '');
        Result.Zugruppe := JSONObject.GetValue<string>('zugruppe', '');
        Result.AgenturCode := JSONObject.GetValue<string>('agenturcode', '');
        Result.Kennziffer := JSONObject.GetValue<string>('kennziffer', '');
        Result.Filiale := JSONObject.GetValue<string>('filiale', '');
        Result.Abteilung := JSONObject.GetValue<string>('abteilung', '');
      end;
    end;
  finally
    JSONObject.free;
    Claims.free;
  end;

end;

{
procedure TDataModulBaseClass.DoSomething;
begin
  Response.content := 'RunLogic';
end;
}

(*
  function TDataModulBaseClass.GetDocumentRootFromCgi: string;
  var
  ExePath: string;
  RelScriptName: string;
  SlashCount: Integer;
  I: Integer;
  begin
  ExePath := ExcludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  RelScriptName := Request.ScriptName;

  SlashCount := 0;
  for I := 1 to Length(RelScriptName) do
  if RelScriptName[I] = '/' then
  Inc(SlashCount);

  for I := 1 to SlashCount - 1 do
  ExePath := ExtractFilePath(ExcludeTrailingPathDelimiter(ExePath));

  Result := IncludeTrailingPathDelimiter(ExePath);
  end;
*)

procedure TDataModulBaseClass.initConnection;
begin
  TConfigFile.init(Request); // Wird schon im Webmodul aufgerufen, hier zur Sicherheit nochmal
  Connection.Params.UserName := TConfigFile.GetConfigValue('DB', 'username');
  Connection.Params.Password := TConfigFile.GetConfigValue('DB', 'password');
  Connection.Params.database := TConfigFile.GetConfigValue('DB', 'database');
  Connection.Params.Values['server'] := TConfigFile.GetConfigValue('DB', 'server');
  Connection.Params.Values['port'] := TConfigFile.GetConfigValue('DB', 'port');

  if Connection.Params.database = '' then
    raise Exception.Create('Der Parameter [database] fehlt');
  if Connection.Params.UserName = '' then
    raise Exception.Create('Der Parameter [UserName] fehlt');
  if Connection.Params.Password = '' then
    raise Exception.Create('Der Parameter [Password] fehlt');
  if Connection.Params.Values['server'] = '' then
    raise Exception.Create('Der Parameter [server] fehlt');
  if Connection.Params.Values['port'] = '0' then
    raise Exception.Create('Der Parameter [port] fehlt');

end;

{
procedure TDataModulBaseClass.RunLogic;
begin
  DoSomething;

end;
 }
end.
