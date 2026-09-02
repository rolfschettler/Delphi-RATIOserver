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
    HandbuchPageProducer: TPageProducer;
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
    procedure WebModule1HandbuchActionAction(Sender: TObject; Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);

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
DataModulToupacClass,
DataModulFuhrparkClass,
DataModulIncomingClass,
DataModulPublicClass,
DataModulDokumenteClass,
DataModulFibuClass,
DataModulRegistrierungClass;


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
        var RoleVal := Claims.Claims.JSON.Values['role'];
        var RoleJson := 'null';
        if Assigned(RoleVal) and not RoleVal.Null then
          RoleJson := RoleVal.Value;
        Result := Format('{"status":"OK","valid":true,"user":"%s","role":%s}', [Claims.Claims.Subject, RoleJson]);
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

procedure TWebModule1.WebModule1HandbuchActionAction(Sender: TObject; Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
begin
    response.content:=HandbuchPageProducer.HTMLDoc.text
end;

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
    sb.append('<h1>API  Übersicht</h1>');

    sb.Append('<div style="margin: 30px;"> <span style="font-size:60px">📖</span>  <a  href="/ibapi/handbuch"> Entwickler Handbuch anzeigen<a></div>');

    sb.append(StringReplace(FRouter.ListRoutes(), sLineBreak, '<br>', [rfReplaceAll]));
    for Entry in Docs do
    begin
      sb.AppendFormat(' <h2>%s</h2><div>%s</div>', [SimpleMarkdownToHTML(Entry.Path), SimpleMarkdownToHTML(Entry.Markdown)]);
    end;


    sb.Append('<div style="margin: 30px"> <span style="font-size:60px">📖</span>  <a  href="/ibapi/handbuch"> Entwickler Handbuch anzeigen<a></div>');
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
  FRouter.AddRoute('/adddemopersonal', CreateDataModulAddOn, TDataModulAddOn(nil).adddemopersonal); // TODO: LocalOnly=true ergänzen


  //Nur als Beispiel für eine Weiterleitung an PHP: FRouter.AddRoute('/getjson', CreateDataModulAddOn, TDataModulAddOn(nil).readjson); // TODO: LocalOnly=true ergänzen

  FRouter.AddRoute('/showroute', CreateDataModulAddOn, TDataModulAddOn(nil).showhtml, false); // TODO: LocalOnly=true ergänzen


  FRouter.AddRoute('/calculatedistance', CreateDataModulAddOn, TDataModulAddOn(nil).calculatedistance); // TODO: LocalOnly=true ergänzen
  FRouter.AddRoute('/travelroute',        CreateDataModulAddOn, TDataModulAddOn(nil).travelroute,   false); // TODO: LocalOnly=true ergänzen
  FRouter.AddRoute('/calculateroute',     CreateDataModulAddOn, TDataModulAddOn(nil).calculateroute); // TODO: LocalOnly=true ergänzen
  FRouter.AddRoute('/ki_getteilnehmer',   CreateDataModulAddOn, TDataModulAddOn(nil).KI_GetTeilnehmer);
  FRouter.AddRoute('/teilnehmerfromcsv', CreateDataModulAddOn, TDataModulAddOn(nil).teilnehmerformcsv);
  FRouter.AddRoute('/getdokument', CreateDataModulAddOn, TDataModulAddOn(nil).getdokument);
  FRouter.AddRoute('/getgeneratorvalue', CreateDataModulAddOn, TDataModulAddOn(nil).getGeneratorValue);

  //PUBLIC API: Diese Api können auch von außerhalb des localhost aufgerufen werden

  //ADRESSEN
  FRouter.AddRoute('/adressen/getadressen',         CreateDataModulAdressen, TDataModulAdressen(nil).getAdressen);
  FRouter.AddRoute('/adressen/getadressenfiltered', CreateDataModulAdressen, TDataModulAdressen(nil).getAdressenFiltered);
    FRouter.AddRoute('/adressen/getjoin', CreateDataModulAdressen, TDataModulAdressen(nil).getAdressenJoinedQuery);

  FRouter.AddRoute('/adressen/getadressenbyid',      CreateDataModulAdressen, TDataModulAdressen(nil).getAdresseById);
  FRouter.AddRoute('/adressen/getadressenkey',   CreateDataModulAdressen, TDataModulAdressen(nil).getNextKennziffer);
  FRouter.AddRoute('/adressen/insertadressen',       CreateDataModulAdressen, TDataModulAdressen(nil).insertAdresse);
  FRouter.AddRoute('/adressen/updateadressen',       CreateDataModulAdressen, TDataModulAdressen(nil).updateAdresse);
  FRouter.AddRoute('/adressen/deleteadressen',       CreateDataModulAdressen, TDataModulAdressen(nil).deleteAdresse);

  FRouter.AddRoute('/adressen/getkategorien',       CreateDataModulAdressen, TDataModulAdressen(nil).getKategorien);
  FRouter.AddRoute('/adressen/getkategoriebyid',    CreateDataModulAdressen, TDataModulAdressen(nil).getKategorieById);
  FRouter.AddRoute('/adressen/insertkategorie',     CreateDataModulAdressen, TDataModulAdressen(nil).insertKategorie);
  FRouter.AddRoute('/adressen/updatekategorie',     CreateDataModulAdressen, TDataModulAdressen(nil).updateKategorie);
  FRouter.AddRoute('/adressen/deletekategorie',     CreateDataModulAdressen, TDataModulAdressen(nil).deleteKategorie);

  FRouter.AddRoute('/adressen/getzusatztabelle',         CreateDataModulAdressen, TDataModulAdressen(nil).getZusatztabelle);
  FRouter.AddRoute('/adressen/getzusatztabellefiltered', CreateDataModulAdressen, TDataModulAdressen(nil).getZusatztabelleFiltered);
  FRouter.AddRoute('/adressen/getzusatztabellebyid',     CreateDataModulAdressen, TDataModulAdressen(nil).getZusatztabelleById);
  FRouter.AddRoute('/adressen/getzusatztabellekey',      CreateDataModulAdressen, TDataModulAdressen(nil).getZusatztabelleKey);
  FRouter.AddRoute('/adressen/insertzusatztabelle',      CreateDataModulAdressen, TDataModulAdressen(nil).insertZusatztabelle);
  FRouter.AddRoute('/adressen/updatezusatztabelle',      CreateDataModulAdressen, TDataModulAdressen(nil).updateZusatztabelle);
  FRouter.AddRoute('/adressen/deletezusatztabelle',      CreateDataModulAdressen, TDataModulAdressen(nil).deleteZusatztabelle);

  //PUBLIC
  FRouter.AddRoute('/public/checkmailtoken',     CreateDataModulPublic, TDataModulPublic(nil).checkmailtoken,false,true); //Auth=false,LocalOnly=true

  // Token-autorisiert: der Gast ruft ohne Login direkt aus dem Browser auf.
  // Autorisierung steckt im Einladungs-Token, deshalb Auth=false; der Aufruf
  // kommt aus dem Internet, deshalb LocalOnly=false.
  FRouter.AddRoute('/public/getadresse',         CreateDataModulPublic, TDataModulPublic(nil).getAdresseByToken,false,false);    //Auth=false,LocalOnly=false
  FRouter.AddRoute('/public/updateadresse',      CreateDataModulPublic, TDataModulPublic(nil).updateAdresseByToken,false,false); //Auth=false,LocalOnly=false


  //TOURISTIK
  FRouter.AddRoute('/touristik/demo',             CreateDataModulTouristik, TDataModulTouristik(nil).Demo);


    //FUHRPARK
  FRouter.AddRoute('/fuhrpark/demo',                    CreateDataModulFuhrpark, TDataModulFuhrpark(nil).Demo);
  FRouter.AddRoute('/fuhrpark/getfahrtenbuch',          CreateDataModulFuhrpark, TDataModulFuhrpark(nil).getFahrtenbuch);
  FRouter.AddRoute('/fuhrpark/getfahrtenbuchfiltered',  CreateDataModulFuhrpark, TDataModulFuhrpark(nil).getFahrtenbuchFiltered);
  FRouter.AddRoute('/fuhrpark/getfahrtenbuchbyid',      CreateDataModulFuhrpark, TDataModulFuhrpark(nil).getFahrtenbuchById);
  FRouter.AddRoute('/fuhrpark/getfahrtenbuchkey',       CreateDataModulFuhrpark, TDataModulFuhrpark(nil).getFahrtenbuchKey);
  FRouter.AddRoute('/fuhrpark/insertfahrtenbuch',       CreateDataModulFuhrpark, TDataModulFuhrpark(nil).insertFahrtenbuch);
  FRouter.AddRoute('/fuhrpark/updatefahrtenbuch',       CreateDataModulFuhrpark, TDataModulFuhrpark(nil).updateFahrtenbuch);
  FRouter.AddRoute('/fuhrpark/deletefahrtenbuch',       CreateDataModulFuhrpark, TDataModulFuhrpark(nil).deleteFahrtenbuch);
  FRouter.AddRoute('/fuhrpark/getrepvorgang',           CreateDataModulFuhrpark, TDataModulFuhrpark(nil).getRepvorgang);
  FRouter.AddRoute('/fuhrpark/getrepvorgangfiltered',   CreateDataModulFuhrpark, TDataModulFuhrpark(nil).getRepvorgangFiltered);
  FRouter.AddRoute('/fuhrpark/getrepvorgangbyid',       CreateDataModulFuhrpark, TDataModulFuhrpark(nil).getRepvorgangById);
  FRouter.AddRoute('/fuhrpark/getrepvorgangkey',        CreateDataModulFuhrpark, TDataModulFuhrpark(nil).getRepvorgangKey);
  FRouter.AddRoute('/fuhrpark/insertrepvorgang',        CreateDataModulFuhrpark, TDataModulFuhrpark(nil).insertRepvorgang);
  FRouter.AddRoute('/fuhrpark/updaterepvorgang',        CreateDataModulFuhrpark, TDataModulFuhrpark(nil).updateRepvorgang);
  FRouter.AddRoute('/fuhrpark/deleterepvorgang',        CreateDataModulFuhrpark, TDataModulFuhrpark(nil).deleteRepvorgang);
  FRouter.AddRoute('/fuhrpark/gettankung',              CreateDataModulFuhrpark, TDataModulFuhrpark(nil).getTankung);
  FRouter.AddRoute('/fuhrpark/gettankungfiltered',      CreateDataModulFuhrpark, TDataModulFuhrpark(nil).getTankungFiltered);
  FRouter.AddRoute('/fuhrpark/gettankungbyid',          CreateDataModulFuhrpark, TDataModulFuhrpark(nil).getTankungById);
  FRouter.AddRoute('/fuhrpark/gettankungkey',           CreateDataModulFuhrpark, TDataModulFuhrpark(nil).getTankungKey);
  FRouter.AddRoute('/fuhrpark/inserttankung',           CreateDataModulFuhrpark, TDataModulFuhrpark(nil).insertTankung);
  FRouter.AddRoute('/fuhrpark/updatetankung',           CreateDataModulFuhrpark, TDataModulFuhrpark(nil).updateTankung);
  FRouter.AddRoute('/fuhrpark/deletetankung',           CreateDataModulFuhrpark, TDataModulFuhrpark(nil).deleteTankung);
  FRouter.AddRoute('/fuhrpark/getauslandfahrt',         CreateDataModulFuhrpark, TDataModulFuhrpark(nil).getAuslandfahrt);
  FRouter.AddRoute('/fuhrpark/getauslandfahrtfiltered', CreateDataModulFuhrpark, TDataModulFuhrpark(nil).getAuslandfahrtFiltered);
  FRouter.AddRoute('/fuhrpark/getauslandfahrtbyid',     CreateDataModulFuhrpark, TDataModulFuhrpark(nil).getAuslandfahrtById);
  FRouter.AddRoute('/fuhrpark/getauslandfahrtkey',      CreateDataModulFuhrpark, TDataModulFuhrpark(nil).getAuslandfahrtKey);
  FRouter.AddRoute('/fuhrpark/insertauslandfahrt',      CreateDataModulFuhrpark, TDataModulFuhrpark(nil).insertAuslandfahrt);
  FRouter.AddRoute('/fuhrpark/updateauslandfahrt',      CreateDataModulFuhrpark, TDataModulFuhrpark(nil).updateAuslandfahrt);
  FRouter.AddRoute('/fuhrpark/deleteauslandfahrt',      CreateDataModulFuhrpark, TDataModulFuhrpark(nil).deleteAuslandfahrt);
  FRouter.AddRoute('/fuhrpark/getfahrzeug',             CreateDataModulFuhrpark, TDataModulFuhrpark(nil).getFahrzeug);
  FRouter.AddRoute('/fuhrpark/getfahrzeugfiltered',     CreateDataModulFuhrpark, TDataModulFuhrpark(nil).getFahrzeugFiltered);
  FRouter.AddRoute('/fuhrpark/getfahrzeugbyid',         CreateDataModulFuhrpark, TDataModulFuhrpark(nil).getFahrzeugById);
  FRouter.AddRoute('/fuhrpark/updatefahrzeug',          CreateDataModulFuhrpark, TDataModulFuhrpark(nil).updateFahrzeug);
  FRouter.AddRoute('/fuhrpark/deletefahrzeug',          CreateDataModulFuhrpark, TDataModulFuhrpark(nil).deleteFahrzeug);
  FRouter.AddRoute('/fuhrpark/getland',                 CreateDataModulFuhrpark, TDataModulFuhrpark(nil).getLand);
  FRouter.AddRoute('/fuhrpark/getlandfiltered',         CreateDataModulFuhrpark, TDataModulFuhrpark(nil).getLandFiltered);
  FRouter.AddRoute('/fuhrpark/getlandbyid',             CreateDataModulFuhrpark, TDataModulFuhrpark(nil).getLandById);

    //FIBU
  FRouter.AddRoute('/fibu/demo',                        CreateDataModulFibu, TDataModulFibu(nil).Demo);
  FRouter.AddRoute('/fibu/getbruttolohn',                CreateDataModulFibu, TDataModulFibu(nil).getBruttolohn);
  FRouter.AddRoute('/fibu/getbruttolohnfiltered',        CreateDataModulFibu, TDataModulFibu(nil).getBruttolohnFiltered);
  FRouter.AddRoute('/fibu/getbruttolohnbyid',            CreateDataModulFibu, TDataModulFibu(nil).getBruttolohnById);
  FRouter.AddRoute('/fibu/getbruttolohnkey',             CreateDataModulFibu, TDataModulFibu(nil).getBruttolohnKey);
  FRouter.AddRoute('/fibu/insertbruttolohn',             CreateDataModulFibu, TDataModulFibu(nil).insertBruttolohn);
  FRouter.AddRoute('/fibu/updatebruttolohn',             CreateDataModulFibu, TDataModulFibu(nil).updateBruttolohn);
  FRouter.AddRoute('/fibu/deletebruttolohn',             CreateDataModulFibu, TDataModulFibu(nil).deleteBruttolohn);
  FRouter.AddRoute('/fibu/getgutschein',                 CreateDataModulFibu, TDataModulFibu(nil).getGutschein);
  FRouter.AddRoute('/fibu/getgutscheinfiltered',         CreateDataModulFibu, TDataModulFibu(nil).getGutscheinFiltered);
  FRouter.AddRoute('/fibu/getgutscheinbyid',             CreateDataModulFibu, TDataModulFibu(nil).getGutscheinById);
  FRouter.AddRoute('/fibu/getgutscheinkey',              CreateDataModulFibu, TDataModulFibu(nil).getGutscheinKey);
  FRouter.AddRoute('/fibu/insertgutschein',              CreateDataModulFibu, TDataModulFibu(nil).insertGutschein);
  FRouter.AddRoute('/fibu/updategutschein',              CreateDataModulFibu, TDataModulFibu(nil).updateGutschein);
  FRouter.AddRoute('/fibu/deletegutschein',              CreateDataModulFibu, TDataModulFibu(nil).deleteGutschein);
  FRouter.AddRoute('/fibu/getdevisenkasse',              CreateDataModulFibu, TDataModulFibu(nil).getDevisenkasse);
  FRouter.AddRoute('/fibu/getdevisenkassefiltered',      CreateDataModulFibu, TDataModulFibu(nil).getDevisenkasseFiltered);
  FRouter.AddRoute('/fibu/getdevisenkassebyid',          CreateDataModulFibu, TDataModulFibu(nil).getDevisenkasseById);
  FRouter.AddRoute('/fibu/getdevisenkassekey',           CreateDataModulFibu, TDataModulFibu(nil).getDevisenkasseKey);
  FRouter.AddRoute('/fibu/insertdevisenkasse',           CreateDataModulFibu, TDataModulFibu(nil).insertDevisenkasse);
  FRouter.AddRoute('/fibu/updatedevisenkasse',           CreateDataModulFibu, TDataModulFibu(nil).updateDevisenkasse);
  FRouter.AddRoute('/fibu/deletedevisenkasse',           CreateDataModulFibu, TDataModulFibu(nil).deleteDevisenkasse);
  FRouter.AddRoute('/fibu/getlohnart',                   CreateDataModulFibu, TDataModulFibu(nil).getLohnart);
  FRouter.AddRoute('/fibu/getlohnartfiltered',           CreateDataModulFibu, TDataModulFibu(nil).getLohnartFiltered);
  FRouter.AddRoute('/fibu/getlohnartbyid',               CreateDataModulFibu, TDataModulFibu(nil).getLohnartById);

  FRouter.AddRoute('/fibu/getfibu',                      CreateDataModulFibu, TDataModulFibu(nil).getFibu);
  FRouter.AddRoute('/fibu/getfibufiltered',              CreateDataModulFibu, TDataModulFibu(nil).getFibuFiltered);
  FRouter.AddRoute('/fibu/getfibubyid',                  CreateDataModulFibu, TDataModulFibu(nil).getFibuById);
  FRouter.AddRoute('/fibu/getfibukey',                   CreateDataModulFibu, TDataModulFibu(nil).getFibuKey);
  FRouter.AddRoute('/fibu/insertfibu',                   CreateDataModulFibu, TDataModulFibu(nil).insertFibu);
  FRouter.AddRoute('/fibu/updatefibu',                   CreateDataModulFibu, TDataModulFibu(nil).updateFibu);
  FRouter.AddRoute('/fibu/deletefibu',                   CreateDataModulFibu, TDataModulFibu(nil).deleteFibu);

  FRouter.AddRoute('/fibu/getkonten',                    CreateDataModulFibu, TDataModulFibu(nil).getKonten);
  FRouter.AddRoute('/fibu/getkontenfiltered',            CreateDataModulFibu, TDataModulFibu(nil).getKontenFiltered);
  FRouter.AddRoute('/fibu/getkontenbyid',                CreateDataModulFibu, TDataModulFibu(nil).getKontenById);


  //ANMIET
  FRouter.AddRoute('/anmiet/demo', CreateDataModulAnmiet, TDataModulAnmiet(nil).Demo);
  FRouter.AddRoute('/anmiet/getanmiet',         CreateDataModulAnmiet, TDataModulAnmiet(nil).getAnmiet);
  FRouter.AddRoute('/anmiet/getanmietfiltered',  CreateDataModulAnmiet, TDataModulAnmiet(nil).getAnmietFiltered);
  FRouter.AddRoute('/anmiet/getanmietbyid',      CreateDataModulAnmiet, TDataModulAnmiet(nil).getAnmietById);
  FRouter.AddRoute('/anmiet/getanmietkey',       CreateDataModulAnmiet, TDataModulAnmiet(nil).getAnmietKey);
  FRouter.AddRoute('/anmiet/insertanmiet',       CreateDataModulAnmiet, TDataModulAnmiet(nil).insertAnmiet);
  FRouter.AddRoute('/anmiet/updateanmiet',       CreateDataModulAnmiet, TDataModulAnmiet(nil).updateAnmiet);
  FRouter.AddRoute('/anmiet/deleteanmiet',       CreateDataModulAnmiet, TDataModulAnmiet(nil).deleteAnmiet);
  FRouter.AddRoute('/anmiet/getfundsachen',           CreateDataModulAnmiet, TDataModulAnmiet(nil).getFundsachen);
  FRouter.AddRoute('/anmiet/getfundsachenfiltered',   CreateDataModulAnmiet, TDataModulAnmiet(nil).getFundsachenFiltered);
  FRouter.AddRoute('/anmiet/getfundsachenbyid',       CreateDataModulAnmiet, TDataModulAnmiet(nil).getFundsachenById);
  FRouter.AddRoute('/anmiet/getfundsachenkey',        CreateDataModulAnmiet, TDataModulAnmiet(nil).getFundsachenKey);
  FRouter.AddRoute('/anmiet/insertfundsachen',        CreateDataModulAnmiet, TDataModulAnmiet(nil).insertFundsachen);
  FRouter.AddRoute('/anmiet/insertfundsachenmitbildern', CreateDataModulAnmiet, TDataModulAnmiet(nil).insertFundsachenMitBildern);
  FRouter.AddRoute('/anmiet/updatefundsachen',        CreateDataModulAnmiet, TDataModulAnmiet(nil).updateFundsachen);
  FRouter.AddRoute('/anmiet/deletefundsachen',        CreateDataModulAnmiet, TDataModulAnmiet(nil).deleteFundsachen);

  //REGISTRIERUNG
  FRouter.AddRoute('/registrierung/getregistrierung',         CreateDataModulRegistrierung, TDataModulRegistrierung(nil).getRegistrierung);
  FRouter.AddRoute('/registrierung/getregistrierungfiltered', CreateDataModulRegistrierung, TDataModulRegistrierung(nil).getRegistrierungFiltered);
  FRouter.AddRoute('/registrierung/getregistrierungbyid',     CreateDataModulRegistrierung, TDataModulRegistrierung(nil).getRegistrierungById);
  FRouter.AddRoute('/registrierung/getregistrierungkey',      CreateDataModulRegistrierung, TDataModulRegistrierung(nil).getRegistrierungKey);
  FRouter.AddRoute('/registrierung/insertregistrierung',      CreateDataModulRegistrierung, TDataModulRegistrierung(nil).insertRegistrierung);
  FRouter.AddRoute('/registrierung/insertregistrierunglocal', CreateDataModulRegistrierung, TDataModulRegistrierung(nil).insertRegistrierungLocal, false, true); //Auth=false,LocalOnly=true
  FRouter.AddRoute('/registrierung/checkusernamelocal',       CreateDataModulRegistrierung, TDataModulRegistrierung(nil).checkUsernameLocal, false, true); //Auth=false,LocalOnly=true
  FRouter.AddRoute('/users/getuserlocal',                     CreateDataModulRegistrierung, TDataModulRegistrierung(nil).getUserLocal, false, true); //Auth=false,LocalOnly=true
  FRouter.AddRoute('/registrierung/updateregistrierung',      CreateDataModulRegistrierung, TDataModulRegistrierung(nil).updateRegistrierung);
  FRouter.AddRoute('/registrierung/deleteregistrierung',      CreateDataModulRegistrierung, TDataModulRegistrierung(nil).deleteRegistrierung);

  //DISPO
  FRouter.AddRoute('/dispo/demo', CreateDataModulDispo, TDataModulDispo(nil).Demo);
  FRouter.AddRoute('/dispo/geteinsatz', CreateDataModulDispo, TDataModulDispo(nil).getEinsatz,true,false);
  FRouter.AddRoute('/dispo/geteinsatzfiltered', CreateDataModulDispo, TDataModulDispo(nil).getEinsatzFiltered,true,false);
  FRouter.AddRoute('/dispo/geteinsatzbyid', CreateDataModulDispo, TDataModulDispo(nil).getEinsatzById,true,false);
  FRouter.AddRoute('/dispo/getfahrergruppen', CreateDataModulDispo, TDataModulDispo(nil).getfahrergruppen,true,false);
  FRouter.AddRoute('/dispo/getpersonalstamm', CreateDataModulDispo, TDataModulDispo(nil).getpersonalstamm,true,false);
  FRouter.AddRoute('/dispo/getpersonalstammfiltered', CreateDataModulDispo, TDataModulDispo(nil).getpersonalstammfiltered,true,false);
  FRouter.AddRoute('/dispo/updatepersonalstamm', CreateDataModulDispo, TDataModulDispo(nil).updatepersonalstamm,true,false);
  FRouter.AddRoute('/dispo/deletepersonalstamm', CreateDataModulDispo, TDataModulDispo(nil).deletepersonalstamm,true,false);
  FRouter.AddRoute('/dispo/getFreiesPersonal', CreateDataModulDispo, TDataModulDispo(nil).getFreiesPersonal,true,false);

  FRouter.AddRoute('/dispo/geteinsatzarten', CreateDataModulDispo, TDataModulDispo(nil).geteinsatzarten,true,false);
  FRouter.AddRoute('/dispo/getnextEinsatzkey', CreateDataModulDispo, TDataModulDispo(nil).getnextEinsatzkey,true,false);
  FRouter.AddRoute('/dispo/inserteinsatz', CreateDataModulDispo, TDataModulDispo(nil).insertEinsatz,true,false);
  FRouter.AddRoute('/dispo/updateeinsatz', CreateDataModulDispo, TDataModulDispo(nil).updateEinsatz,true,false);
  FRouter.AddRoute('/dispo/deleteeinsatz', CreateDataModulDispo, TDataModulDispo(nil).deleteEinsatz,true,false);
  FRouter.AddRoute('/dispo/getfis_log',         CreateDataModulDispo, TDataModulDispo(nil).getFis_Log,true,false);
  FRouter.AddRoute('/dispo/getfis_logfiltered', CreateDataModulDispo, TDataModulDispo(nil).getFis_LogFiltered,true,false);
  FRouter.AddRoute('/dispo/getfis_logbyid',     CreateDataModulDispo, TDataModulDispo(nil).getFis_LogById,true,false);
  FRouter.AddRoute('/dispo/getfis_logkey',      CreateDataModulDispo, TDataModulDispo(nil).getFis_LogKey,true,false);
  FRouter.AddRoute('/dispo/insertfis_log',      CreateDataModulDispo, TDataModulDispo(nil).insertFis_Log,true,false);
  FRouter.AddRoute('/dispo/updatefis_log',      CreateDataModulDispo, TDataModulDispo(nil).updateFis_Log,true,false);
  FRouter.AddRoute('/dispo/deletefis_log',      CreateDataModulDispo, TDataModulDispo(nil).deleteFis_Log,true,false);
  FRouter.AddRoute('/dispo/getzeitraum',           CreateDataModulDispo, TDataModulDispo(nil).getZeitraum);
  FRouter.AddRoute('/dispo/getzeitraumfiltered',   CreateDataModulDispo, TDataModulDispo(nil).getZeitraumFiltered);
  FRouter.AddRoute('/dispo/getzeitraumbyid',       CreateDataModulDispo, TDataModulDispo(nil).getZeitraumById);

  FRouter.AddRoute('/dispo/geturlaubsantrag',         CreateDataModulDispo, TDataModulDispo(nil).getUrlaubsantrag,true,false);
  FRouter.AddRoute('/dispo/geturlaubsantragfiltered', CreateDataModulDispo, TDataModulDispo(nil).getUrlaubsantragFiltered,true,false);
  FRouter.AddRoute('/dispo/geturlaubsantragbyid',     CreateDataModulDispo, TDataModulDispo(nil).getUrlaubsantragById,true,false);
  FRouter.AddRoute('/dispo/geturlaubsantragkey',      CreateDataModulDispo, TDataModulDispo(nil).getUrlaubsantragKey,true,false);
  FRouter.AddRoute('/dispo/inserturlaubsantrag',      CreateDataModulDispo, TDataModulDispo(nil).insertUrlaubsantrag,true,false);
  FRouter.AddRoute('/dispo/updateurlaubsantrag',      CreateDataModulDispo, TDataModulDispo(nil).updateUrlaubsantrag,true,false);
  FRouter.AddRoute('/dispo/deleteurlaubsantrag',      CreateDataModulDispo, TDataModulDispo(nil).deleteUrlaubsantrag,true,false);

  FRouter.AddRoute('/dispo/getfahrtablauf',         CreateDataModulDispo, TDataModulDispo(nil).getFahrtablauf,true,false);
  FRouter.AddRoute('/dispo/getfahrtablauffiltered', CreateDataModulDispo, TDataModulDispo(nil).getFahrtablaufFiltered,true,false);
  FRouter.AddRoute('/dispo/getfahrtablaufbyid',     CreateDataModulDispo, TDataModulDispo(nil).getFahrtablaufById,true,false);
  FRouter.AddRoute('/dispo/getfahrtablaufkey',      CreateDataModulDispo, TDataModulDispo(nil).getFahrtablaufKey,true,false);
  FRouter.AddRoute('/dispo/insertfahrtablauf',      CreateDataModulDispo, TDataModulDispo(nil).insertFahrtablauf,true,false);
  FRouter.AddRoute('/dispo/updatefahrtablauf',      CreateDataModulDispo, TDataModulDispo(nil).updateFahrtablauf,true,false);
  FRouter.AddRoute('/dispo/deletefahrtablauf',      CreateDataModulDispo, TDataModulDispo(nil).deleteFahrtablauf,true,false);

  FRouter.AddRoute('/dispo/getliniewegeobjekte',         CreateDataModulDispo, TDataModulDispo(nil).getLiniewegeobjekte,true,false);
  FRouter.AddRoute('/dispo/getliniewegeobjektefiltered', CreateDataModulDispo, TDataModulDispo(nil).getLiniewegeobjekteFiltered,true,false);
  FRouter.AddRoute('/dispo/getliniewegeobjektebyid',     CreateDataModulDispo, TDataModulDispo(nil).getLiniewegeobjekteById,true,false);

  //TOUPAC
  FRouter.AddRoute('/toupac/demo',                CreateDataModulToupac, TDataModulToupac(nil).Demo);
  FRouter.AddRoute('/toupac/gett_vorgang',          CreateDataModulToupac, TDataModulToupac(nil).getT_Vorgang);
  FRouter.AddRoute('/toupac/gett_vorgangfiltered',  CreateDataModulToupac, TDataModulToupac(nil).getT_VorgangFiltered);
  FRouter.AddRoute('/toupac/gett_vorgangbyid',      CreateDataModulToupac, TDataModulToupac(nil).getT_VorgangById);
  FRouter.AddRoute('/toupac/gett_vorgangkey',       CreateDataModulToupac, TDataModulToupac(nil).getT_VorgangKey);
  FRouter.AddRoute('/toupac/insertt_vorgang',       CreateDataModulToupac, TDataModulToupac(nil).insertT_Vorgang);
  FRouter.AddRoute('/toupac/updatet_vorgang',       CreateDataModulToupac, TDataModulToupac(nil).updateT_Vorgang);
  FRouter.AddRoute('/toupac/deletet_vorgang',       CreateDataModulToupac, TDataModulToupac(nil).deleteT_Vorgang);
  FRouter.AddRoute('/toupac/getf_fahrtauftrag',         CreateDataModulToupac, TDataModulToupac(nil).getF_Fahrtauftrag);
  FRouter.AddRoute('/toupac/getf_fahrtauftragfiltered', CreateDataModulToupac, TDataModulToupac(nil).getF_FahrtauftragFiltered);
  FRouter.AddRoute('/toupac/getf_fahrtauftragbyid',     CreateDataModulToupac, TDataModulToupac(nil).getF_FahrtauftragById);
  FRouter.AddRoute('/toupac/getf_fahrtauftragkey',      CreateDataModulToupac, TDataModulToupac(nil).getF_FahrtauftragKey);
  FRouter.AddRoute('/toupac/insertf_fahrtauftrag',      CreateDataModulToupac, TDataModulToupac(nil).insertF_Fahrtauftrag);
  FRouter.AddRoute('/toupac/updatef_fahrtauftrag',      CreateDataModulToupac, TDataModulToupac(nil).updateF_Fahrtauftrag);
  FRouter.AddRoute('/toupac/deletef_fahrtauftrag',      CreateDataModulToupac, TDataModulToupac(nil).deleteF_Fahrtauftrag);
  FRouter.AddRoute('/toupac/gett_kalender',         CreateDataModulToupac, TDataModulToupac(nil).getT_Kalender,true,false);
  FRouter.AddRoute('/toupac/gett_kalenderfiltered', CreateDataModulToupac, TDataModulToupac(nil).getT_KalenderFiltered,true,false);
  FRouter.AddRoute('/toupac/gett_kalenderbyid',     CreateDataModulToupac, TDataModulToupac(nil).getT_KalenderById,true,false);
  FRouter.AddRoute('/toupac/gett_kalenderkey',      CreateDataModulToupac, TDataModulToupac(nil).getT_KalenderKey,true,false);
  FRouter.AddRoute('/toupac/insertt_kalender',      CreateDataModulToupac, TDataModulToupac(nil).insertT_Kalender,true,false);
  FRouter.AddRoute('/toupac/updatet_kalender',      CreateDataModulToupac, TDataModulToupac(nil).updateT_Kalender,true,false);
  FRouter.AddRoute('/toupac/deletet_kalender',      CreateDataModulToupac, TDataModulToupac(nil).deleteT_Kalender,true,false);



  //DOKUMENTE
  FRouter.AddRoute('/dokumente/demo',                CreateDataModulDokumente, TDataModulDokumente(nil).Demo);
  FRouter.AddRoute('/dokumente/getvorlagen',         CreateDataModulDokumente, TDataModulDokumente(nil).getVorlagen);
  FRouter.AddRoute('/dokumente/getvorlagenfiltered', CreateDataModulDokumente, TDataModulDokumente(nil).getVorlagenFiltered);
  FRouter.AddRoute('/dokumente/getvorlagenbyid',     CreateDataModulDokumente, TDataModulDokumente(nil).getVorlagenById);
  FRouter.AddRoute('/dokumente/getvorlagenkey',      CreateDataModulDokumente, TDataModulDokumente(nil).getVorlagenKey);
  FRouter.AddRoute('/dokumente/insertvorlagen',      CreateDataModulDokumente, TDataModulDokumente(nil).insertVorlagen);
  FRouter.AddRoute('/dokumente/updatevorlagen',      CreateDataModulDokumente, TDataModulDokumente(nil).updateVorlagen);
  FRouter.AddRoute('/dokumente/deletevorlagen',      CreateDataModulDokumente, TDataModulDokumente(nil).deleteVorlagen);
  FRouter.AddRoute('/dokumente/uploaddokument',         CreateDataModulDokumente, TDataModulDokumente(nil).uploadDokument);
  FRouter.AddRoute('/dokumente/gett_bildtext',          CreateDataModulDokumente, TDataModulDokumente(nil).getT_Bildtext);
  FRouter.AddRoute('/dokumente/gett_bildtextfiltered',  CreateDataModulDokumente, TDataModulDokumente(nil).getT_BildtextFiltered);
  FRouter.AddRoute('/dokumente/gett_bildtextbyid',      CreateDataModulDokumente, TDataModulDokumente(nil).getT_BildtextById);
  FRouter.AddRoute('/dokumente/insertt_bildtext',       CreateDataModulDokumente, TDataModulDokumente(nil).insertT_Bildtext);
  FRouter.AddRoute('/dokumente/updatet_bildtext',       CreateDataModulDokumente, TDataModulDokumente(nil).updateT_Bildtext);
  FRouter.AddRoute('/dokumente/deletet_bildtext',       CreateDataModulDokumente, TDataModulDokumente(nil).deleteT_Bildtext);

  //INCOMING
  FRouter.AddRoute('/incoming/demo',           CreateDataModulIncoming, TDataModulIncoming(nil).Demo);
  FRouter.AddRoute('/incoming/gett_teilnehmer',         CreateDataModulIncoming, TDataModulIncoming(nil).getTeilnehmer);
  FRouter.AddRoute('/incoming/gett_teilnehmerfiltered', CreateDataModulIncoming, TDataModulIncoming(nil).getTeilnehmerFiltered);
  FRouter.AddRoute('/incoming/gett_teilnehmerbyid',     CreateDataModulIncoming, TDataModulIncoming(nil).getTeilnehmerById);
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

