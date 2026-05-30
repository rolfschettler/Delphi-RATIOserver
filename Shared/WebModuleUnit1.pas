unit WebModuleUnit1;

interface

uses

  ReqMulti,
  web.cgihttp,
  JOSE.Core.JWT,
  JOSE.Core.Builder,
  JOSE.Core.JWK,
  JOSE.Types.JSON,
  uJWTUtils,

  router,

  System.IniFiles,
  System.SysUtils, System.Classes, web.HTTPApp,
  FireDAC.Comp.Client, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Phys.Intf,
  FireDAC.Phys.IB, FireDAC.Phys.IBDef, FireDAC.Phys.IBWrapper,
  FireDAC.UI.Intf, FireDAC.Comp.UI,
  FireDAC.DApt, System.JSON, FireDAC.Stan.Param, System.DateUtils,
  FireDAC.Stan.Async, FireDAC.DApt.Intf, Data.FireDACJsonReflect,

  System.Generics.Collections,

  FireDAC.Comp.DataSet, FireDAC.Stan.Error, FireDAC.Phys, FireDAC.DatS, Data.DB, web.HTTPProd;

type

  TDocEntry = record
    Path: string;
    Markdown: string;
    Method: string;
  end;

  TParsedSQL = record
    SQL: string;
    Params: TDictionary<string, string>;
  end;

  TWebModule1 = class(TWebModule)
    HelpPageProducer: TPageProducer;
    TitlePageProducer: TPageProducer;
    procedure WebModuleException(Sender: TObject; E: Exception; var Handled: Boolean);
    procedure WebModuleBeforeDispatch(Sender: TObject; Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
    procedure WebModuleCreate(Sender: TObject);
    procedure DefActionHandler(Sender: TObject; Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
    procedure WebModuleDestroy(Sender: TObject);
    procedure WebModule1WebActionItem1Action(Sender: TObject; Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
    procedure WebModule1WebActionItem2Action(Sender: TObject; Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
    procedure WebModule1WebActionItem3Action(Sender: TObject; Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
    procedure WebModule1WebActionItem4Action(Sender: TObject; Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
    procedure TitlePageProducerHTMLTag(Sender: TObject; Tag: TTag; const TagString: string; TagParams: TStrings; var ReplaceText: string);

  private
    FRouter: TRouter; // Objectvariable. Wird im  Webmodul erzeugt, und kann so von jedem anderen Modul des Projekts erreicht werden.

    procedure DoCreateToken(Request: TWebRequest; Response: TWebResponse);
    function DoVerifyToken(Request: TWebRequest; Response: TWebResponse): string;
    procedure DoLogin(Request: TWebRequest; Response: TWebResponse);

    function LoadMarkdownDocs(): TList<TDocEntry>;
    function IsLocalRequest(Request: TWebRequest): Boolean;
    { Private-Deklarationen }
  public
    { Public-Deklarationen }
  end;

var
  WebModuleClass: TComponentClass = TWebModule1;

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}

uses
plugin,
webUtils,
DataModulBaseClass,
DataModulSQLClass,
DataModulAddOnClass,
DataModulLoginClass,
DataModulPrintClass,
DataModulAdressenClass,
DataModulTouristikClass,
DataModulAnmietClass,
DataModulDispoClass,
DataModulIncomingClass,
DataModulPublicClass;


{$R *.dfm}

function TWebModule1.LoadMarkdownDocs(): TList<TDocEntry>;
var
  Lines: TStringList;
  I: Integer;
  Current: TDocEntry;
begin
  Result := TList<TDocEntry>.Create;
  // if not FileExists(FileName) then Exit;

  Lines := TStringList.Create;
  try
    Lines.text := HelpPageProducer.HTMLDoc.text;
    // LoadFromFile(FileName, TEncoding.UTF8);

    Current.Path := '';
    Current.Markdown := '';

    for I := 0 to Lines.Count - 1 do
    begin
      if Lines[I].Trim.StartsWith('#') then
      begin
        if (Current.Path <> '') and (Current.Markdown <> '') then
          Result.Add(Current);
        Current.Path := Lines[I].Trim.Substring(1).Trim;
        Current.Markdown := '';
      end
      else
      begin
        if Current.Markdown <> '' then
          Current.Markdown := Current.Markdown + sLineBreak;
        Current.Markdown := Current.Markdown + Lines[I];
      end;
    end;

    if (Current.Path <> '') and (Current.Markdown <> '') then
      Result.Add(Current);
  finally
    Lines.Free;
  end;
end;

procedure TWebModule1.TitlePageProducerHTMLTag(Sender: TObject; Tag: TTag; const TagString: string; TagParams: TStrings; var ReplaceText: string);
begin

end;

// sehr einfacher Markdown HTML Konverter
function SimpleMarkdownToHTML(const Markdown: string): string;
begin
  Result := Markdown;
  Result := StringReplace(Result, '[*', '<b>', [rfReplaceAll]);
  Result := StringReplace(Result, '*]', '</b>', [rfReplaceAll]);
  Result := StringReplace(Result, '(*', '<span class="sample">', [rfReplaceAll]);
  Result := StringReplace(Result, '*)', '</span>', [rfReplaceAll]);

  Result := StringReplace(Result, '{*', '<div class="codeblock">', [rfReplaceAll]);
  Result := StringReplace(Result, '*}', '</div>', [rfReplaceAll]);

  Result := StringReplace(Result, '<<', '<div class="method">', [rfReplaceAll]);
  Result := StringReplace(Result, '>>', '</div>', [rfReplaceAll]);

  Result := StringReplace(Result, sLineBreak, '<br>', [rfReplaceAll]);
end;

(* *********************************** JWT TOKEN ************************************************************************ *)

procedure TWebModule1.DoCreateToken(Request: TWebRequest; Response: TWebResponse);
var
  User, Role, Token: string;
  minutes_valid: Integer;
begin
  minutes_valid := 900;
  /// ////////////////////Max:: 900 Minuten (15Std.) !!!
  User := Request.QueryFields.Values['user'];
  Role := Request.QueryFields.Values['role'];

  // Wenn Keine "Expire" Minuten ( minutes_valid) in der Configuration hinterlegt, dann wird als default der Wert der variablen  "minutes_valid" verwendet:
  minutes_valid := strToInt(TConfigFile.GetConfigValue('security', 'minutes_valid', intTostr(minutes_valid)));

  Token := TJWTUtils.CreateToken(User, Role, minutes_valid);

  Response.StatusCode := 200;
  Response.Content := Format('{"token":"%s"}', [Token]);
end;

function TWebModule1.DoVerifyToken(Request: TWebRequest; Response: TWebResponse): string;
var
  AuthHeader, Token: string;
  Claims: TJWT;

begin

  Response.ContentType := 'application/json; charset=utf-8';
  try
    Result := '';
    AuthHeader := Request.GetFieldByName('Authorization');
    if AuthHeader.StartsWith('Bearer ', True) then
      Token := AuthHeader.Substring(7)
    else
      Token := Request.QueryFields.Values['token'];

    if Trim(Token) = '' then
    begin
      Response.StatusCode := 401;
      raise Exception.Create('Keine Anmeldedaten verfügbar. Bitte neu anmelden.');
    end;

    if TJWTUtils.VerifyToken(Token, Claims) then
      try
        Result := Format('{"status":"OK","valid":true,"user":"%s","role":%s}', [Claims.Claims.Subject, Claims.Claims.JSON.Values['role'].Value]);
        exit;
      finally
        Claims.Free;
      end
    else
    begin
      Response.StatusCode := 401;
      raise Exception.Create('Anmeldung ungültig oder abgelaufen. Bitte neu anmelden');
    end;
  except
    on E: Exception do
    begin
      Response.StatusCode := 401;
      raise Exception.Create(E.message);

    end;

  end;
end;

procedure TWebModule1.DoLogin(Request: TWebRequest; Response: TWebResponse);
var
  User, Role, Token: string;
  minutes_valid: Integer;
  DataModulLoginClass: TDataModulLoginClass;
  sl: TStringList;
  loginOK: Boolean;
var
  Obj: TJSONObject;
begin
  DataModulLoginClass := TDataModulLoginClass.Create(Request, Response);
  sl := TStringList.Create;
  sl.StrictDelimiter := True;
  Obj := TJSONObject.Create;

  try
    // Alle zur Bildung der "Role"  Felder:
    loginOK := DataModulLoginClass.login(sl);

    if not loginOK then
    begin
      Response.StatusCode := 401;
      Response.Content := sl.text;
      exit;

    end;

    for var I := 0 to sl.Count - 1 do
      Obj.AddPair(sl.Names[I], sl.ValueFromIndex[I]);
    Role := Obj.ToJSON;

    // Alle zur bildung des Tokens wichtige Felder:
    minutes_valid := 900;
    /// ////////////////////Max:: 900 Minuten (15Std.) !!!
    User := Request.QueryFields.Values['user'];
    // Wenn Keine "Expire" Minuten ( minutes_valid) in der Configuration hinterlegt, dann wird als default der Wert der variablen  "minutes_valid" verwendet:
    minutes_valid := strToInt(TConfigFile.GetConfigValue('security', 'minutes_valid', intTostr(minutes_valid)));
    Token := TJWTUtils.CreateToken(User, Role, minutes_valid);
    Response.StatusCode := 200;

    Response.Content := Format('{"token":"%s"}', [Token]);
  finally
    DataModulLoginClass.Free;
    sl.Free;
    Obj.Free;
  end;

end;

(* *********************************** JWT TOKEN ************************************************************************ *)

procedure TWebModule1.WebModule1WebActionItem1Action(Sender: TObject; Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
begin
  DoCreateToken(Request, Response);

end;

procedure TWebModule1.WebModule1WebActionItem2Action(Sender: TObject; Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
var
  msg: string;
begin
  msg := DoVerifyToken(Request, Response);

  Response.StatusCode := 200;
  Response.ContentType := 'application/json; charset=utf-8';
  Response.Content := msg;
  Handled := True;

end;

procedure TWebModule1.WebModule1WebActionItem3Action(Sender: TObject; Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
begin
  DoLogin(Request, Response)
end;

procedure TWebModule1.WebModule1WebActionItem4Action(Sender: TObject; Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
var
  Docs: TList<TDocEntry>;
  Entry: TDocEntry;
  sb: TStringBuilder;
begin
  Docs := LoadMarkdownDocs();
  sb := TStringBuilder.Create;

  try
    sb.append('<html><head><title>API Dokumentation</title></head><body>');
    sb.append('<h1>API  bersicht</h1>');
    sb.append(StringReplace(FRouter.ListRoutes(), sLineBreak, '<br>', [rfReplaceAll]));
    for Entry in Docs do
    begin
      sb.AppendFormat('<h2>%s</h2><div>%s</div>', [SimpleMarkdownToHTML(Entry.Path), SimpleMarkdownToHTML(Entry.Markdown)]);
    end;

    sb.append('</body></html>');

    sb.append('    <style>');
    sb.append('body {background-color: white; font-family:arial}');
    sb.append('h1   {color: blue;}');
    sb.append('h2   {background-color:#27CCF5; color: white;font-weight:normal;padding-left:12px;}');
    sb.append('h5   {color: blue;font-weight:bold;font-size:20px}');
    sb.append('.codeblock   {background-color: #dedede;margin:6px;padding:6px; font-family:Courier;font-size:smaller}');

    sb.append('.method{color: green;margin-top:12px;}');
    sb.append('.sample{color: gray;font-style: italic;font-size:smaller;}');

    sb.append('.method::before {content: "METHOD:"; font-weight: bold; color: black;}');

    sb.append('</style>');

    Response.ContentType := 'text/html; charset=utf-8';
    Response.Content := sb.ToString;
    Handled := True;
  finally
    Docs.Free;
    sb.Free;
  end;
end;

procedure TWebModule1.WebModuleBeforeDispatch(Sender: TObject; Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
begin
  try
    // An dieser Stelle wird die TConfigFile-Class initialisiert und ist dammit für alle eingebundenen Module verwendbar.
    TConfigFile.init(Request);
  except
    on E: Exception do
    begin
      Response.StatusCode := 400;
      Response.ReasonString := 'Bad Request';
      Response.ContentType := 'application/json; charset=utf-8';
      Response.Content := CreateJsonResponse('error', E.message);
      Handled := True;
    end;
  end;

  (*
    ******************* Wichtig um bei der Entwicklung CORS- bzw. Preflight Fehler zu verhindern:
  *)


  (* CORS-Header - KORRIGIERT *)
  Response.SetCustomHeader('Access-Control-Allow-Origin', '*');
  Response.SetCustomHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  Response.SetCustomHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With, Accept, Accept-Language');
  Response.SetCustomHeader('Access-Control-Allow-Credentials', 'false');
  Response.SetCustomHeader('Access-Control-Max-Age', '86400');
  Response.SetCustomHeader('Vary', 'Origin');



  if SameText(Request.Method, 'OPTIONS') then
  begin
    Response.StatusCode := 200;
    Response.Content := '';
    Handled := True;
  end;
end;

procedure TWebModule1.WebModuleCreate(Sender: TObject);
begin
  FRouter := TRouter.Create;
  (*
    ******************************************************************************
    Hier ist der zentrale Punkt für die Erweiterung des Moduls
    ******************************************************************************

    AddRoute(route, TInstanceFactory, Methode,Auth.required);

    route:            Die bezeichnung der Route, beginnt immer mit /
    TInstanceFactory: Die Function zum Erzeugen der Klasse (globale Function inder datei der entsprechenden Klasse)
    Methode:          Die Methode aus dieser Klasse, die aufgerufen wird
    Auth.required: OPTIONAL Hier wird festgelegt, ob eine Authentifizierung vor der Ausführung der Methode durchgeführt wird. (true wenn erforderlich, false wenn ohne..). Default:true
    LocalOnly:     OPTIONAL Wenn true, ist die Route nur vom localhost erreichbar. Default:false


  *)

   //API-NUR LOCAL ZUGRIFF
     FRouter.AddRoute('/readteilnehmer', CreateDataModulAddOn, TDataModulAddOn(nil).ReadTeilnehmer); // TODO: LocalOnly=true ergänzen

  FRouter.AddRoute('/getparams*', CreateDataModulSQL, TDataModulSQL(nil).getparams, false,true);
  FRouter.AddRoute('/getparams/dbonly', CreateDataModulSQL, TDataModulSQL(nil).getparams,false,true);

  FRouter.AddRoute('/select', CreateDataModulSQL, TDataModulSQL(nil).select,true,true);
  FRouter.AddRoute('/select/withblob', CreateDataModulSQL, TDataModulSQL(nil).select,true,true);
  FRouter.AddRoute('/execsql', CreateDataModulSQL, TDataModulSQL(nil).select,true,true);

  FRouter.AddRoute('/update', CreateDataModulSQL, TDataModulSQL(nil).update,true,true);
  FRouter.AddRoute('/filetoblob', CreateDataModulSQL, TDataModulSQL(nil).filetoblob,true,true);
  FRouter.AddRoute('/base64toblob', CreateDataModulSQL, TDataModulSQL(nil).base64toblob,true,true);

  FRouter.AddRoute('/insert', CreateDataModulSQL, TDataModulSQL(nil).insert,true,true);

  FRouter.AddRoute('/delete', CreateDataModulSQL, TDataModulSQL(nil).delete,true,true);

  FRouter.AddRoute('/execute', CreateDataModulSQL, TDataModulSQL(nil).execute,true,true);

  FRouter.AddRoute('/tablestructure', CreateDataModulSQL, TDataModulSQL(nil).TableStructure,true,true);

  FRouter.AddRoute('/print', CreateDataModulPrint, TDataModulPrint(nil).Print,true,false);

  FRouter.AddRoute('/adddemo', CreateDataModulAddOn, TDataModulAddOn(nil).adddemo); // TODO: LocalOnly=true ergänzen
  FRouter.AddRoute('/getjson', CreateDataModulAddOn, TDataModulAddOn(nil).readjson); // TODO: LocalOnly=true ergänzen

  FRouter.AddRoute('/showroute', CreateDataModulAddOn, TDataModulAddOn(nil).showhtml, false); // TODO: LocalOnly=true ergänzen


  FRouter.AddRoute('/calculatedistance', CreateDataModulAddOn, TDataModulAddOn(nil).calculatedistance); // TODO: LocalOnly=true ergänzen
  FRouter.AddRoute('/travelroute',        CreateDataModulAddOn, TDataModulAddOn(nil).travelroute,   false); // TODO: LocalOnly=true ergänzen
  FRouter.AddRoute('/calculateroute',     CreateDataModulAddOn, TDataModulAddOn(nil).calculateroute); // TODO: LocalOnly=true ergänzen
  FRouter.AddRoute('/ki_getteilnehmer',   CreateDataModulAddOn, TDataModulAddOn(nil).KI_GetTeilnehmer);
  FRouter.AddRoute('/teilnehmerfromcsv', CreateDataModulAddOn, TDataModulAddOn(nil).teilnehmerformcsv);

  //PUBLIC API: Diese Api können auch von außerhalb des localhost aufgerufen werden

  //ADRESSEN
  FRouter.AddRoute('/adressen/getadressen',         CreateDataModulAdressen, TDataModulAdressen(nil).getAdressen);
  FRouter.AddRoute('/adressen/getadressenfiltered', CreateDataModulAdressen, TDataModulAdressen(nil).getAdressenFiltered);
    FRouter.AddRoute('/adressen/getjoin', CreateDataModulAdressen, TDataModulAdressen(nil).getAdressenJoinedQuery);

  FRouter.AddRoute('/adressen/getadressebyid',      CreateDataModulAdressen, TDataModulAdressen(nil).getAdresseById);
  FRouter.AddRoute('/adressen/getnextkennziffer',   CreateDataModulAdressen, TDataModulAdressen(nil).getNextKennziffer);
  FRouter.AddRoute('/adressen/insertadresse',       CreateDataModulAdressen, TDataModulAdressen(nil).insertAdresse);
  FRouter.AddRoute('/adressen/updateadresse',       CreateDataModulAdressen, TDataModulAdressen(nil).updateAdresse);
  FRouter.AddRoute('/adressen/deleteadresse',       CreateDataModulAdressen, TDataModulAdressen(nil).deleteAdresse);

  FRouter.AddRoute('/adressen/getkategorien',       CreateDataModulAdressen, TDataModulAdressen(nil).getKategorien);
  FRouter.AddRoute('/adressen/getkategoriebyid',    CreateDataModulAdressen, TDataModulAdressen(nil).getKategorieById);
  FRouter.AddRoute('/adressen/insertkategorie',     CreateDataModulAdressen, TDataModulAdressen(nil).insertKategorie);
  FRouter.AddRoute('/adressen/updatekategorie',     CreateDataModulAdressen, TDataModulAdressen(nil).updateKategorie);
  FRouter.AddRoute('/adressen/deletekategorie',     CreateDataModulAdressen, TDataModulAdressen(nil).deleteKategorie);

  //PUBLIC
  FRouter.AddRoute('/public/checkmailtoken',     CreateDataModulPublic, TDataModulPublic(nil).checkmailtoken,false,true); //Auth=false,LocalOnly=true


  //TOURISTIK
  FRouter.AddRoute('/touristik/demo',             CreateDataModulTouristik, TDataModulTouristik(nil).Demo);


  //ANMIET
  FRouter.AddRoute('/anmiet/demo', CreateDataModulAnmiet, TDataModulAnmiet(nil).Demo);

  //DISPO
  FRouter.AddRoute('/dispo/demo', CreateDataModulDispo, TDataModulDispo(nil).Demo);
  FRouter.AddRoute('/dispo/geteinsatz', CreateDataModulDispo, TDataModulDispo(nil).getEinsatz,true,false);
  FRouter.AddRoute('/dispo/geteinsatzfiltered', CreateDataModulDispo, TDataModulDispo(nil).getEinsatzFiltered,true,false);
  FRouter.AddRoute('/dispo/geteinsatzbyid', CreateDataModulDispo, TDataModulDispo(nil).getEinsatzById,true,false);
  FRouter.AddRoute('/dispo/getfahrergruppen', CreateDataModulDispo, TDataModulDispo(nil).getfahrergruppen,true,false);
  FRouter.AddRoute('/dispo/getpersonalstamm', CreateDataModulDispo, TDataModulDispo(nil).getpersonalstamm,true,false);



  //INCOMING
  FRouter.AddRoute('/incoming/demo',           CreateDataModulIncoming, TDataModulIncoming(nil).Demo);
  FRouter.AddRoute('/incoming/getteilnehmer',         CreateDataModulIncoming, TDataModulIncoming(nil).getTeilnehmer);
  FRouter.AddRoute('/incoming/getteilnehmerfiltered', CreateDataModulIncoming, TDataModulIncoming(nil).getTeilnehmerFiltered);
  FRouter.AddRoute('/incoming/getteilnehmerbyid',     CreateDataModulIncoming, TDataModulIncoming(nil).getTeilnehmerById);
  FRouter.AddRoute('/incoming/gett_teilnehmernextnr', CreateDataModulIncoming, TDataModulIncoming(nil).getT_TeilnehmerNextNr);
  FRouter.AddRoute('/incoming/insertt_teilnehmer',    CreateDataModulIncoming, TDataModulIncoming(nil).insertT_Teilnehmer);
  FRouter.AddRoute('/incoming/updatet_teilnehmer',    CreateDataModulIncoming, TDataModulIncoming(nil).updateT_Teilnehmer);
  FRouter.AddRoute('/incoming/deletet_teilnehmer',    CreateDataModulIncoming, TDataModulIncoming(nil).deleteT_Teilnehmer);




end;

procedure TWebModule1.WebModuleDestroy(Sender: TObject);
begin
  FRouter.Free;
end;

procedure TWebModule1.WebModuleException(Sender: TObject; E: Exception; var Handled: Boolean);
begin
  Response.ContentType := 'application/json;';
  if (E is EFDDBEngineException) then
    Response.StatusCode := 400;

  Response.Content := CreateJsonResponse('error', E.message);
  Handled := True; // verhindert Standardfehlermeldung
end;

function TWebModule1.IsLocalRequest(Request: TWebRequest): Boolean;
var
  sAddr: string;
begin
  sAddr := Trim(Request.RemoteAddr);

  Response.SetCustomHeader('X-Debug-RemoteAddr', sAddr);

  Result := (sAddr = '127.0.0.1') or      // IPv4
            (sAddr = '::1') or              // IPv6
            (sAddr = '0:0:0:0:0:0:0:1') or        // IPv6 (Langform, Standalone-CGI)
            (sAddr = '::ffff:127.0.0.1');   // IPv4-mapped IPv6
end;

procedure TWebModule1.DefActionHandler(Sender: TObject; Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
var
  Factory:    TInstanceFactory;
  MethodCode: Pointer;
  Obj:        TObject;
  H:          TRouteHandler;
  PathInfo:   string;
begin
  PathInfo := Request.PathInfo;

  if (Trim(PathInfo) = '') or (Trim(PathInfo) = '/') then
  begin
    Response.ContentType := 'text/html; charset=utf-8';
    Response.Content := TitlePageProducer.HTMLDoc.text;
    exit;

  end;

  Response.ContentType := 'application/json; charset=utf-8';
  try

    if FRouter.IsAuthRequired(ExcludeLastSlash(lowercase(PathInfo))) then
      DoVerifyToken(Request, Response) // Prüfen auf gültige Authentifizierung

  except
    on E: Exception do
    begin
      Response.ContentType := 'application/json; charset=utf-8';
      Response.Content := CreateJsonResponse('error', E.message);
      exit;
    end;
  end;

  // Localhost-Prüfung
  if FRouter.IsLocalOnly(ExcludeLastSlash(lowercase(PathInfo))) then
    if not IsLocalRequest(Request) then
    begin
      Response.StatusCode := 403;
      Response.Content := CreateJsonResponse('error', 'Zugriff nur vom lokalen Server erlaubt.');
      Handled := True;
      exit;
    end;

  if FRouter.FindRoute(PathInfo, Factory, MethodCode) then
  begin
    Obj := Factory(Request, Response); // DataModule erzeugen
    try
      // Handler dynamisch binden
      TMethod(H).Code := MethodCode;
      TMethod(H).Data := Obj;
      H(); // Parameterloser Aufruf
    finally
      Obj.Free;
    end;
    Handled := True;
  end
  else
  begin
    Response.StatusCode := 404;
    Response.Content := CreateJsonResponse('error', 'Dieser Pfad (' + PathInfo + ') wurde nicht gefunden.');
    Handled := True;
  end;
end;

end.

