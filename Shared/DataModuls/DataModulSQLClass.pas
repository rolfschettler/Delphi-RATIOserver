unit DataModulSQLClass;

interface

uses
  dialogs,

  ReqMulti,
  System.JSON, System.Variants,
  System.DateUtils,
  System.Generics.Collections,
  Web.HTTPApp,
  System.SysUtils, System.Classes, DataModulBaseClass, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys, FireDAC.Phys.IB,
  FireDAC.Phys.IBDef, FireDAC.Stan.Param, FireDAC.DatS, FireDAC.DApt.Intf, FireDAC.DApt, Data.DB, FireDAC.Comp.DataSet, FireDAC.Comp.Client, FireDAC.Comp.UI, FireDAC.VCLUI.Wait;

type
  TParsedSQL = record
    SQL: string;
    Params: TDictionary<string, string>;
  end;

  TDataModulSQL = class(TDataModulBaseClass)
  private
    { Private-Deklarationen }
    function ParseJsonSQL(const JsonStr: string): TParsedSQL;
    procedure ApplyParamsToFDQuery(Query: TFDQuery; const JsonStr: string);
    function GenerateInsertSQLAndAssignParams(const JSONText: string; Query: TFDQuery; table: string; key: string = ''): string;
    function GenerateUpdateSQLAndAssignParams(const JSONText: string; Query: TFDQuery; table: string; key: string = ''): string;
    function GenerateDeleteSQLAndAssignParams(const JSONText: string; Query: TFDQuery; table: string): string;

    function LastAutoKeyValue(bodycontent, table: string): string;
    function DumpWebRequestInfo(DBParamsOnly: boolean = false): string;
    function GetTableStructure(table: string): string;

  public

    Procedure getparams;
    procedure Select();
    Procedure TableStructure();
    procedure Update();
    procedure FileToBlob();
    procedure Insert();
    procedure Delete();
    procedure execute();
    procedure base64ToBlob();

    { Public-Deklarationen }
  end;

function CreateDataModulSQL(Request: TWebRequest; Response: TWebResponse): TObject;

implementation

uses webUtils;

function CreateDataModulSQL(Request: TWebRequest; Response: TWebResponse): TObject;
begin
  Result := TDataModulSQL.Create(Request, Response);
end;

{%CLASSGROUP 'Vcl.Controls.TControl'}
{$R *.dfm}
{ TDataModulSQL }

function TDataModulSQL.GetTableStructure(table: string): string;
const
  C_FireDAC_FieldInfo_SQL = 'SELECT' + sLineBreak + '    rf.RDB$FIELD_NAME AS FIELD_NAME,' + sLineBreak + '    CASE f.RDB$FIELD_TYPE' + sLineBreak + '        WHEN 7  THEN ''ftSmallint''' + sLineBreak + '        WHEN 8  THEN ''ftInteger''' +
    sLineBreak + '        WHEN 9  THEN ''ftQuad''' + sLineBreak + '        WHEN 10 THEN ''ftFloat''' + sLineBreak + '        WHEN 12 THEN ''ftDate''' + sLineBreak + '        WHEN 13 THEN ''ftTime''' + sLineBreak +
    '        WHEN 14 THEN ''ftFixedChar''' + sLineBreak + '        WHEN 16 THEN ' + sLineBreak + '            CASE f.RDB$FIELD_SUB_TYPE' + sLineBreak + '                WHEN 0 THEN ''ftLargeint''' + sLineBreak +
    '                WHEN 1 THEN ''ftBCD''' + sLineBreak + '                WHEN 2 THEN ''ftFMTBCD''' + sLineBreak + '                ELSE ''ftUnknown''' + sLineBreak + '            END' + sLineBreak + '        WHEN 27 THEN ''ftFloat''' +
    sLineBreak + '        WHEN 35 THEN ''ftDateTime''' + sLineBreak + '        WHEN 37 THEN ''ftString''' + sLineBreak + '        WHEN 40 THEN ''ftBlob''' + sLineBreak + '        WHEN 261 THEN ' + sLineBreak +
    '            CASE f.RDB$FIELD_SUB_TYPE' + sLineBreak + '                WHEN 1 THEN ''ftMemo''' + sLineBreak + '                ELSE ''ftBlob''' + sLineBreak + '            END' + sLineBreak + '        ELSE ''ftUnknown''' + sLineBreak +
    '    END AS DELPHI_FIREDAC_TYPE,' + sLineBreak + '    f.RDB$CHARACTER_LENGTH AS MAX_LENGTH,' + sLineBreak + '    rf.RDB$NULL_FLAG AS NOT_NULL,' + sLineBreak + '    rf.RDB$DEFAULT_SOURCE AS DEFAULT_VALUE' + sLineBreak + 'FROM' +
    sLineBreak + '    RDB$RELATION_FIELDS rf' + sLineBreak + 'JOIN' + sLineBreak + '    RDB$FIELDS f ON rf.RDB$FIELD_SOURCE = f.RDB$FIELD_NAME' + sLineBreak + 'WHERE' + sLineBreak + '    rf.RDB$RELATION_NAME = UPPER(:TABLENAME)' +
    sLineBreak + 'ORDER BY' + sLineBreak + '    rf.RDB$FIELD_POSITION;';

var
  Q: TFDQuery;

  // lokale Procedur
  procedure QueryToJSON(FDQuery: TFDQuery);
  var
    s: string;
    JSONArray: TJSONArray;
    JSONObject: TJSONObject;
    JSONStructureObject: TJSONObject;
    JSONFieldObject: TJSONPair;
    JSONPrimaryKeyObject: TJSONPair;
    PList: TStringList;

  begin
    JSONArray := TJSONArray.Create;
    JSONObject := nil;
    JSONFieldObject := nil;
    JSONPrimaryKeyObject := nil;
    JSONStructureObject := nil;
    PList := TStringList.Create;

    try
      FDQuery.First;
      while not FDQuery.Eof do
      begin
        JSONObject := TJSONObject.Create;
        JSONObject.AddPair(lowercase('FIELD_NAME'), lowercase(FDQuery.Fieldbyname('FIELD_NAME').AsString));
        JSONObject.AddPair(lowercase('FIELD_TYPE'), lowercase(FDQuery.Fieldbyname('DELPHI_FIREDAC_TYPE').AsString));

        // MAX_LENGTH kann NULL sein
        if not FDQuery.Fieldbyname('MAX_LENGTH').IsNull then
          JSONObject.AddPair(lowercase('MAX_LENGTH'), TJSONNumber.Create(FDQuery.Fieldbyname('MAX_LENGTH').AsInteger))
        else
          JSONObject.AddPair(lowercase('MAX_LENGTH'), TJSONNull.Create);

        // NOT_NULL kann NULL sein
        if not FDQuery.Fieldbyname('NOT_NULL').IsNull then
          JSONObject.AddPair(lowercase('NOT_NULL'), TJSONBool.Create(FDQuery.Fieldbyname('NOT_NULL').AsInteger = 1))
        else
          JSONObject.AddPair(lowercase('NOT_NULL'), TJSONNull.Create);

        // DEFAULT_VALUE kann NULL sein
        if not FDQuery.Fieldbyname('DEFAULT_VALUE').IsNull then
          JSONObject.AddPair(lowercase('DEFAULT_VALUE'), FDQuery.Fieldbyname('DEFAULT_VALUE').AsString)
        else
          JSONObject.AddPair(lowercase('DEFAULT_VALUE'), TJSONNull.Create);

        JSONArray.AddElement(JSONObject);
        JSONObject := nil; // Wichtig damit im Finally kein Pointer-Error entsteht
        FDQuery.Next;
      end;

      JSONStructureObject := TJSONObject.Create;

      JSONFieldObject := TJSONPair.Create('fields', JSONArray);
      JSONArray := nil; // JSONArray ist nun Eigentum von  JSONFieldObject;

      Connection.GetKeyFieldNames('', '', table, '', PList);

      for var i := 0 to PList.count - 1 do
        s := s + lowercase(PList[i]) + ' ';

      JSONPrimaryKeyObject := TJSONPair.Create('primarykey', Trim(s));

      JSONStructureObject.AddPair(JSONPrimaryKeyObject);
      JSONPrimaryKeyObject := nil;

      JSONStructureObject.AddPair(JSONFieldObject);
      JSONFieldObject := nil; // JSONFieldObject ist nun Eigentum vonJSONStructureObject

      Result := JSONStructureObject.ToString;

    finally

      PList.Free;

      JSONStructureObject.Free;
      JSONPrimaryKeyObject.Free;

      if assigned(JSONFieldObject) then
        JSONFieldObject.Free;

      if assigned(JSONArray) then
        JSONArray.Free;
      if assigned(JSONObject) then
        JSONObject.Free;
    end;
  end;

begin
  Result := '';
  Q := TFDQuery.Create(nil);

  try
    Q.SQL.Text := C_FireDAC_FieldInfo_SQL;
    Q.ParamByName('tablename').AsString := table;
    Q.Connection := Connection;
    Q.Open;
    if Q.Eof and Q.Bof then
      Raise exception.Create('Tabelle ' + table + ' existiert nicht');
    QueryToJSON(Q);
  finally
    Q.Free;

  end;
end;

function TDataModulSQL.DumpWebRequestInfo(DBParamsOnly: boolean = false): string;
var
  i: Integer;
  ParamName: string;
  ARequest: TWebRequest;

begin

  ARequest := Request;
  var
  linebreak := '<br>';
  Response.ContentType := 'text/html';
  Result := '<div style="font-family:Arial"> --- WebRequest Dump ---' + linebreak;


  // Grundlegende Infos
  // Hier werden all Parameter geparst
  if not DBParamsOnly then
  begin
    Result := Result + Format('Request.Method: %s%s', [ARequest.Method, linebreak]);
    Result := Result + Format('Request.ProtocolVersion: %s%s', [ARequest.ProtocolVersion, linebreak]);
    Result := Result + Format('<b>Request.URL: %s%s</b>', [ARequest.URL, linebreak]);
    Result := Result + Format('Request.PathInfo: %s%s', [ARequest.PathInfo, linebreak]);
    Result := Result + Format('first_pathinfo:%s%s', [first_pathInfo, linebreak]);
    Result := Result + Format('last_pathinfo:%s%s', [last_pathInfo, linebreak]);

    for var a := 1 to High(Paths) do
    begin
      Result := Result + 'path[' + intToStr(a) + ']=' + Paths[a] + linebreak;

    end;

    Result := Result + Format('<b>Request.Query: %s%s</b>', [ARequest.Query, linebreak]);
    Result := Result + Format('Request.ContentLength: %d%s', [ARequest.ContentLength, linebreak]);
    Result := Result + Format('Request.ContentType: %s%s', [ARequest.ContentType, linebreak]);
    if ARequest.ContentType = 'text/plain' then
      Result := Result + 'Request.Content: ' + Request.Content + linebreak;

    Result := Result + Format('Request.RemoteAddr: %s%s', [ARequest.RemoteAddr, linebreak]);
    Result := Result + Format('Request.RemoteHost: %s%s', [ARequest.RemoteHost, linebreak]);
    Result := Result + Format('Request.Host: %s%s', [ARequest.Host, linebreak]);
    Result := Result + linebreak;

    // GET-/POST-Parameter
    Result := Result + '<div style="color:blue;">--- Parameters ---</div>' + linebreak;
    Result := Result + '<div style="color:green">';
    Result := Result + '--- QueryFields ---' + linebreak;
    for i := 0 to ARequest.QueryFields.count - 1 do
    begin
      ParamName := ARequest.QueryFields.Names[i];
      Result := Result + intToStr(i) + '. ' + Format('Request.QueryFields.Values[''%s''] = %s%s', [ParamName, ARequest.QueryFields.Values[ParamName], linebreak]);
    end;
    Result := Result + '</div>';

    Result := Result + '<div style="color:#e7a032">' + linebreak;

    Result := Result + '--- ContentFields ---' + linebreak;
    for i := 0 to ARequest.ContentFields.count - 1 do
    begin
      ParamName := ARequest.ContentFields.Names[i];
      Result := Result + intToStr(i) + '. ' + Format('Request.ContentFields.Values[''%s''] = %s%s', [ParamName, ARequest.ContentFields.Values[ParamName], linebreak]);
    end;

    Result := Result + '</div>';

    if Request.Files.count > 0 then
    begin
      Result := Result + '<b>--- Upload ---</b>' + linebreak;
      Result := Result + 'Files Uploaded: ' + intToStr(Request.Files.count) + linebreak;
      for var f := 0 to Request.Files.count - 1 do
        Result := Result + 'Filename ' + intToStr(f) + ' :' + Request.Files[f].FileName + linebreak;

    end;

  end;

  // Database-Parameter
  Result := Result + '<b>--- Database-Parameters ---</b>' + linebreak;
  Result := Result + Format('Connection.Drivername= %s%s', [Connection.drivername, linebreak]);
  Result := Result + Format('Connection.Params.UserName= %s%s', ['*********', linebreak]); // Connection.Params.UserName
  Result := Result + Format('Connection.Params.Password= %s%s', ['*********', linebreak]); // Connection.Params.Password
  Result := Result + Format('Connection.Params.database= %s%s', [Connection.Params.database, linebreak]);
  Result := Result + Format('Connection.Params.server= %s%s', [Connection.Params.Values['server'], linebreak]);
  Result := Result + Format('Connection.Params.port= %s%s', [Connection.Params.Values['port'], linebreak]);

  try
    Connection.Connected := true;
  except
    on E: exception do
      Result := Result + Format('ConnectionError= %s%s', [E.message, linebreak])
  end;

  Result := Result + '<b>';
  if Connection.Connected then
    Result := Result + Format('Connection.Connected= %s%s', ['true', linebreak])
  else
    Result := Result + Format('Connection.Connected= %s%s', ['false', linebreak]);
  Result := Result + '</b>' + linebreak;

  Result := Result + '--- Anmeldedaten ---' + linebreak;
  Result := Result + 'GetUserInfo.LoginName= ' + GetUserInfo.LoginName + linebreak;
  Result := Result + 'GetUserInfo.UserName= ' + GetUserInfo.UserName + linebreak;
  Result := Result + 'GetUserInfo.Kennziffer= ' + GetUserInfo.Kennziffer + linebreak;

  Result := Result + '</div>'

end;

// Route: /getparams*, /getparams/dbonly  |  Auth: false  |  LocalOnly: true
procedure TDataModulSQL.getparams;
begin

  if Uppercase(last_pathInfo) = 'DBONLY' then
    Response.Content := DumpWebRequestInfo(true)
  else
    Response.Content := DumpWebRequestInfo(false)

end;

(* ******************************************** UNTERSTÜTZENDE FUNCTIONS FÜR DB-OPERATIONEN *********************************************************** *)

function SQLWithParams(Q: TFDQuery): string;
var
  s: string;
  i: Integer;
  P: TFDParam;
  V: string;

  function QuoteIfNeeded(const AValue: string; ADataType: TFieldType): string;
  begin
    case ADataType of
      ftString, ftWideString, ftMemo, ftWideMemo, ftFixedChar, ftFmtMemo:
        Result := QuotedStr(AValue);
      ftDate, ftTime, ftDateTime, ftTimeStamp:
        // ISO-like formatting; passe bei Bedarf an DB an
        Result := QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:ss', StrToDateTime(AValue)));
      ftBoolean:
        // viele DBs erwarten 1/0 oder TRUE/FALSE; hier TRUE/FALSE
        if SameText(AValue, '1') or SameText(AValue, 'True') then
          Result := 'TRUE'
        else
          Result := 'FALSE';
    else
      Result := AValue; // Zahlen, etc. ohne quotes
    end;
  end;

begin
  // Stelle sicher, dass Query.SQL.Text ein String ist
  s := Q.SQL.Text;

  // Optional: Q.Prepare; // falls Params noch nicht angelegt sind
  for i := 0 to Q.Params.count - 1 do
  begin
    P := TFDParam(Q.Params[i]);

    if P.IsNull then
      V := 'NULL'
    else
    begin
      case P.DataType of
        ftString, ftWideString, ftMemo, ftWideMemo, ftFixedChar, ftFmtMemo:
          V := QuotedStr(P.AsString);

        ftDate, ftTime, ftDateTime, ftTimeStamp:
          V := QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:ss', P.AsDateTime));

        ftBoolean:
          if P.AsBoolean then
            V := 'TRUE'
          else
            V := 'FALSE';

        ftBlob, ftGraphic, ftOraClob:
          V := '<BLOB>'; // BLOBs nicht inline darstellen

      else
        // Default: AsString (Zahlen, Dezimal etc.)
        V := P.AsString;
      end;
    end;

    // Ersetze :ParamName (case-insensitive). Wir ersetzen alle Vorkommen.
    s := StringReplace(s, ':' + P.Name, V, [rfReplaceAll, rfIgnoreCase]);
    // Falls du Paramennamen auch mit f�hrendem ? (oder ohne :) brauchst, erweitern.
  end;

  Result := s;
end;

function StringHasTime(const Str: string): boolean;
var
  dt: TDateTime;
  s: string;
begin
  (*
    *
    *Dies Funktion prüft ob ein String eine Datum plus einen zusätzlichen Zeitanteil enth�lt
  *)
  Result := false;
  s := StringReplace(Str, 'T', ' ', [rfReplaceAll]); // ffg. Das "T" zwischen datum und Zeit durch Leerzeichen tauschen
  IF TryISO8601ToDate(s, dt) then // Wenn ISO-Datumsfeld dann konvertieren zu TDateTime!
  begin
    Result := Frac(dt) <> 0;
  end
  else
  begin
    // Falls überhaupt kein gültiges Datum= false
    if not TryStrToDateTime(s, dt) then
      exit;
    // Wenn nach dem Konvertieren ein Zeitanteil vorhanden ist
    Result := Frac(dt) <> 0;
  end;
end;

function TDataModulSQL.ParseJsonSQL(const JsonStr: string): TParsedSQL;
var
  JSONObject: TJSONObject;
  ParamsObj: TJSONObject;
  Pair: TJSONPair;
begin
  (*
    *   Diese Funktion Zerlegt den Body eines Request in seine Bestandteile SQL und PARAMS
    *       Beispiel-sql:
    *      {"sql":"Select * from fahrzeug where kennzeichen=:kennzeichen","params":{"kennzeichen":"UL-RS 100"}}
  *)

  Result.Params := TDictionary<string, string>.Create;
  try
    JSONObject := TJSONObject.ParseJSONValue(JsonStr) as TJSONObject;
    if JSONObject = nil then
      raise exception.Create('Die übergebenen JSON-Daten sind ungültig.');
    try
      Result.SQL := JSONObject.GetValue<string>('sql');
      ParamsObj := JSONObject.GetValue<TJSONObject>('params');
      for Pair in ParamsObj do
      begin
        Result.Params.Add(Pair.JSONString.Value, Pair.JsonValue.Value);
      end;
    finally

      JSONObject.Free;
    end;
  except
    on E: exception do
    begin
      Result.Params.Free;
      raise exception.Create('Fehler beim Parsen des JSON: ' + E.message);
    end;
  end;
end;

procedure TDataModulSQL.ApplyParamsToFDQuery(Query: TFDQuery; const JsonStr: string);
var
  Parsed: TParsedSQL;
  ParamName: string;
  Param: TFDParam;
  JSONObject: TJSONObject;
  ParamsObj: TJSONObject;
  JsonValue: TJSONValue;
begin
  (*
    *   Diese Funktion ersetzt alle Parameter einer SQL-Abfrage mit den zugehörigen Werten (Select und EXECSQL)
  *)

  Parsed := ParseJsonSQL(JsonStr);
  try
    // SQL setzen
    Query.SQL.Text := Parsed.SQL;

    // JSON nochmals parsen um NULL-Werte zu erkennen , also der value des Params wäre NULL
    JSONObject := TJSONObject.ParseJSONValue(JsonStr) as TJSONObject;
    try
      ParamsObj := JSONObject.GetValue<TJSONObject>('params');
      // Parameter zuweisen
      for ParamName in Parsed.Params.Keys do
      begin
        Param := Query.Params.FindParam(ParamName);
        if Assigned(Param) then
        begin
          JsonValue := ParamsObj.GetValue(ParamName);
          if (JsonValue = nil) or (JsonValue is TJSONNull) then
            Param.Clear //NULL-value muss gesondert behandelt werden
          else
            Param.AsString := Parsed.Params[ParamName];
        end
        else
          raise exception.CreateFmt('Parameter "%s" nicht im SQL gefunden.', [ParamName]);
      end;
    finally
      JSONObject.Free;
    end;
  finally
    Parsed.Params.Free;
  end;
end;

function TDataModulSQL.GenerateInsertSQLAndAssignParams(const JSONText: string; Query: TFDQuery; table, key: string): string;
var
  JSONObject: TJSONObject;
  Pair: TJSONPair;
  i: Integer;
  dt: TDateTime;
  FieldName, FieldValue: string;
  s, SQL: string;

begin

  Result := '';
  if Trim(table) = '' then
    Raise exception.Create('INSERT: Der Parameter table fehlt');

  SQL := 'insert into ' + table + '(';
  JSONObject := TJSONObject.ParseJSONValue(JSONText) as TJSONObject;
  if JSONObject = nil then
    raise exception.Create('Die übergebenen JSON-Daten sind ungültig.');

  try
    // SQL zusammensetzen
    for i := 0 to JSONObject.count - 1 do
    begin
      Pair := JSONObject.Pairs[i];
      FieldName := Pair.JSONString.Value;
      FieldValue := Pair.JsonValue.Value;
      SQL := SQL + FieldName;

      if i < JSONObject.count - 1 then
        SQL := SQL + ', '
      else
        SQL := SQL + ') '

    end;

    SQL := SQL + ' VALUES (';
    for i := 0 to JSONObject.count - 1 do
    begin
      Pair := JSONObject.Pairs[i];
      FieldName := Pair.JSONString.Value;
      FieldValue := Pair.JsonValue.Value;
      SQL := SQL + ':' + FieldName;

      if i < JSONObject.count - 1 then
        SQL := SQL + ', '
      else
        SQL := SQL + ') '

    end;

    Query.SQL.Text := SQL;

    // Query.Prepare;

    // Parameter zuweisen
    s := '';
    for i := 0 to JSONObject.count - 1 do
    begin
      Pair := JSONObject.Pairs[i];
      FieldName := Pair.JSONString.Value;
      FieldValue := Pair.JsonValue.Value;

      if Pair.JsonValue.NULL then
        Query.ParamByName(FieldName).clear
      else IF TryISO8601ToDate(FieldValue, dt) then // Wenn ISO-Datumsfeld!
      begin
        Query.ParamByName(FieldName).Value := dt
      end
      else
        Query.ParamByName(FieldName).Value := FieldValue;
    end;

    (*
      // DEBUGCODE:
      S := '';
      for var x := 0 to Query.paramcount - 1 do
      S := S + Query.Params[x].Name + '=' + Query.Params[x].AsString + ' ';
      raise exception.Create(S);
    *)

    Result := 'OK';

  finally

    JSONObject.Free;
  end;
end;

function TDataModulSQL.GenerateDeleteSQLAndAssignParams(const JSONText: string; Query: TFDQuery; table: string): string;
var
  JSONObject: TJSONObject;
  Pair: TJSONPair;
  i: Integer;
  FieldName, FieldValue: string;
  SQL: string;
begin

  Result := '';

  if Trim(table) = '' then
    Raise exception.Create('DELETE: Der Parameter table fehlt');

  SQL := 'delete from ' + table + ' where ';
  JSONObject := TJSONObject.ParseJSONValue(JSONText) as TJSONObject;
  if JSONObject = nil then
    raise exception.Create('Die übergebenen JSON-Daten sind ungültig.');

  try
    // SQL zusammensetzen
    for i := 0 to JSONObject.count - 1 do
    begin
      Pair := JSONObject.Pairs[i];
      FieldName := Pair.JSONString.Value;
      FieldValue := Pair.JsonValue.Value;

      if Uppercase(Pair.JsonValue.Value) = 'NULL' then
        SQL := SQL + FieldName + ' is NULL '
      else
        SQL := SQL + FieldName + '=' + ':' + FieldName + ' ';

      if i < JSONObject.count - 1 then
        SQL := SQL + ' and '

    end;

    Query.SQL.Text := SQL;

    // Parameter zuweisen
    for i := 0 to JSONObject.count - 1 do
    begin
      Pair := JSONObject.Pairs[i];
      FieldName := Pair.JSONString.Value;
      FieldValue := Pair.JsonValue.Value;

      if not Pair.JsonValue.NULL then
        Query.ParamByName(FieldName).Value := FieldValue;
    end;

    (*
      //DEBUGCODE:
      s := '';
      for var x := 0 to Query.paramcount - 1 do
      s := s + Query.Params[x].Name + '=' + Query.Params[x].asstring + ' ';
    *)

    Result := 'OK';
  finally
    JSONObject.Free;
  end;
end;

function TDataModulSQL.GenerateUpdateSQLAndAssignParams(const JSONText: string; Query: TFDQuery; table, key: string): string;
var
  JSONObject: TJSONObject;
  Pair: TJSONPair;
  i: Integer;
  FieldName, FieldValue: string;
  SQL: string;
begin
  Result := '';
  SQL := 'update ' + table + ' set ';
  JSONObject := TJSONObject.ParseJSONValue(JSONText) as TJSONObject;
  if JSONObject = nil then
    raise exception.Create('Die übergebenen JSON-Daten sind ungültig.');

  try

    if Trim(table) = '' then
      Raise exception.Create('UPDATE: Der Parameter table fehlt');

    // SQL zusammensetzen
    for i := 0 to JSONObject.count - 1 do
    begin
      Pair := JSONObject.Pairs[i];
      FieldName := Pair.JSONString.Value;
      FieldValue := Pair.JsonValue.Value;
      SQL := SQL + ' ' + FieldName + ' = :' + FieldName;
      if i < JSONObject.count - 1 then
        SQL := SQL + ', ';
    end;

    if key = '' then
      raise exception.Create('UPDATE: KEY IST ERFORDERLICH (WERT "NULL" FÜR UPDATE ALLE RECORDS)');
    if Uppercase(key) <> 'NULL' then
      SQL := SQL + ' where ' + key + '= :' + key;
    Query.SQL.Text := SQL;
    // Parameter zuweisen
    for i := 0 to JSONObject.count - 1 do
    begin
      Pair := JSONObject.Pairs[i];
      FieldName := Pair.JSONString.Value;
      FieldValue := Pair.JsonValue.Value;

      // if Uppercase(FieldValue) = 'NULL' then
      if Pair.JsonValue.NULL then
      begin
        Query.ParamByName(FieldName).Value := NULL
      end
      else
        Query.ParamByName(FieldName).Value := FieldValue;
    end;

    Result := 'OK';

  finally
    JSONObject.Free;
  end;
end;

(* ******************************************** SQL-INSERT *********************************************************** *)

function TDataModulSQL.LastAutoKeyValue(bodycontent, table: string): string;
var
  DFQ: TFDQuery;
  keyfield: string;
  JSONObject: TJSONObject;
  _lastkey: string;
  Value: TJSONValue;
  PList: TStringList;

begin
  (*
    *  Ermittelt den letzten, vom Generator vergebenen Key (Primary-Key)
    *  D.h. es wird der MAX. Wert des Feldes ermittelt, der sich unmittelbar nach dem Einfügen ergeben hat
  *)
  DFQ := nil;
  JSONObject := nil;
  _lastkey := '';
  PList := TStringList.Create;
  try
    DFQ := TFDQuery.Create(self);
    DFQ.Connection := Connection;

    Connection.GetKeyFieldNames('', '', table, '', PList); // Ermitteln des Feldnamens, der dem Primary Key entspricht:
    if PList.count > 0 then
      keyfield := lowercase(PList[0]);

    JSONObject := TJSONObject.ParseJSONValue(bodycontent) as TJSONObject;
    if JSONObject = nil then
      raise exception.Create('Die übergebenen JSON-Daten sind ungültig.');

    // Wenn key mitgegeben wurde
    Value := GetValueCaseInsensitive(JSONObject, keyfield);
    if assigned(Value) then
      _lastkey := Value.Value;

    if _lastkey = '' then
    begin
      DFQ.SQL.Text := 'Select MAX(' + keyfield + ') as wert from ' + table;
      DFQ.Open;
      Result := '"keyname": "' + keyfield + '","keyvalue":"' + DFQ.Fieldbyname('wert').AsString + '"';
    end
    else
      Result := '"keyname": "' + keyfield + '","keyvalue":"' + _lastkey + '"';

  finally
    DFQ.Free;
    PList.Free;
    if assigned(JSONObject) then
      JSONObject.Free;
  end;
end;

// Route: /insert  |  Auth: true  |  LocalOnly: true
procedure TDataModulSQL.Insert;
var
  table: string;
  key: string;
  requestbody: string;
  Q: TFDQuery;
  lastkeyvalue: string;
begin

  table := Request.QueryFields.Values['table'];
  key := Request.QueryFields.Values['key'];
  requestbody := Request.Content;
  Q := TFDQuery.Create(nil);
  try

    Q.Connection := Connection;

    Response.Content := GenerateInsertSQLAndAssignParams(requestbody, Q, table, key);

    try
      Connection.StartTransaction;
      Q.ExecSQL; // Datensatz Schreiben
      lastkeyvalue := LastAutoKeyValue(requestbody, table); // Letzten PrimaryKey ermitteln
      Response.ContentType := 'application/json';
      Response.StatusCode := 200;

      Response.Content := Format('{"status":"OK", %s}', [lastkeyvalue]);

      Connection.Commit;
      (*
        *     Das Ergebnis beinhaltet des Status (OK) und den beim Einfügen vergebenen Primärschlüssel (name+value)
        *
        *    {"status": "OK", "keyname": "NR", "keyvalue": "26"}
      *)

    except
      on E: exception do
      begin
        if Connection.InTransaction then
          Connection.Rollback;
        raise;
      end;
    end;

  finally
    Q.Free;

  end;
end;

(* ******************************************** SQL-Select *********************************************************** *)
// Route: /select, /select/withblob, /execsql  |  Auth: true  |  LocalOnly: true
procedure TDataModulSQL.Select;
var
  Q:        TFDQuery;
  withblob: Boolean;
begin
  withblob := UpperCase(last_pathInfo) = 'WITHBLOB';
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := Connection;
    ApplyParamsToFDQuery(Q, Request.Content);
    if first_pathInfo = 'exexslq' then
      Q.ExecSQL
    else
      Q.Open;
    Response.ContentType := 'application/json';
    Response.Content     := SerializeQuery(Q, withblob);
  finally
    Q.Free;
  end;
end;

// Route: /tablestructure  |  Auth: true  |  LocalOnly: true
procedure TDataModulSQL.TableStructure;
begin

  var
  table := Request.QueryFields.Values['table'];
  try
    if table <> '' then
    begin
      Response.ContentType := 'application/json';
      Response.StatusCode := 200;
      Response.Content := GetTableStructure(table);
      Connection.Commit;

    end
    else
      raise exception.Create('Parameter "table" fehlt');

  except
    on E: exception do
      raise;
  end;
end;

(* ******************************************** Upload To Blobfield *********************************************************** *)
// Route: /filetoblob  |  Auth: true  |  LocalOnly: true
procedure TDataModulSQL.FileToBlob;
var
  _table: string;
  _blobfield, _keyfield, _keyvalue: string;
  Q: TFDQuery;
  Fields: TStringList;

begin

  _table := Request.QueryFields.Values['table'];
  _keyfield := Request.QueryFields.Values['keyfield'];
  _keyvalue := Request.QueryFields.Values['keyvalue'];
  _blobfield := Request.QueryFields.Values['blobfield'];

  Q := TFDQuery.Create(nil);

  Fields := TStringList.Create;
  try
    // WhiteList f�r Feldnamen erzeugen:   (Alle Felder der angeforderten tabelle)
    Connection.GetFieldNames('', '', _table, '', Fields);

    // Feldname auf g�ltigkeit pr�fen:
    if Fields.count = 0 then
      raise exception.Create('Feldname für table ungültig');
    if Fields.IndexOf(_keyfield) < 0 then
      raise exception.Create('Feldname für keyfield ungültig');
    if Fields.IndexOf(_blobfield) < 0 then
      raise exception.Create('Feldname für blobfield ungültig');

    Q.Connection := Connection;
    Q.SQL.Text := 'select ' + _keyfield + ', ' + _blobfield + ' from ' + _table + ' where ' + _keyfield + '= :KEYVALUE';
    // Parameter setzen:
    Q.ParamByName('keyvalue').AsString := _keyvalue;

    try
      Connection.StartTransaction;
      Q.Open;
      Q.UpdateOptions.ReadOnly := false;
      Q.UpdateOptions.EnableUpdate := true;

      If Q.Eof and Q.Bof then
        raise exception.Create('Kein Datensatz für Blobfield ' + _table + 'vorhanden');

      if Request.Files.count = 0 then
        raise exception.Create('Es wurde keine Datei hochgeladen');

      if Request.Files[0].FileName <> '' then
      begin
        Q.Edit;
        TBlobfield(Q.Fieldbyname(_blobfield)).clear;
        Request.Files[0].Stream.Position := 0;
        TBlobfield(Q.Fieldbyname(_blobfield)).LoadFromStream(Request.Files[0].Stream);
        Q.Post;
      end;

      Response.ContentType := 'application/json';
      Response.StatusCode := 200;
      Response.Content := '{"status":"OK"}';
      Connection.Commit;
    except
      on E: exception do
      begin
        if Connection.InTransaction then
          Connection.Rollback;
        raise;
      end;
    end;

  finally
    Q.Free;
    Fields.Free;

  end;
end;

(* ******************************************** Upload To Blobfield *********************************************************** *)

(* ******************************************** SQL-Update *********************************************************** *)
// Route: /update  |  Auth: true  |  LocalOnly: true
procedure TDataModulSQL.Update;
var
  table: string;
  key: string;
  requestbody: string;
  Q: TFDQuery;

begin
  table := Request.QueryFields.Values['table'];
  key := Request.QueryFields.Values['key'];
  requestbody := Request.Content;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := Connection;
    GenerateUpdateSQLAndAssignParams(requestbody, Q, table, key);
    try
      Connection.StartTransaction;
      Q.ExecSQL;
      Response.ContentType := 'application/json';
      Response.StatusCode := 200;
      Response.Content := '{"status":"OK"}';
      Connection.Commit;
    except
      on E: exception do
      begin
        if Connection.InTransaction then
          Connection.Rollback;
        raise;
      end;
    end;

  finally
    Q.Free;
  end;
end;

(* ******************************************** Base64ToBlob *********************************************************** *)
// Route: /base64toblob  |  Auth: true  |  LocalOnly: true
procedure TDataModulSQL.base64ToBlob;
var
  _table: string;
  _blobfield, _keyfield, _keyvalue: string;
  Q: TFDQuery;
  Fields: TStringList;

begin

  _table := Request.QueryFields.Values['table'];
  _keyfield := Request.QueryFields.Values['keyfield'];
  _keyvalue := Request.QueryFields.Values['keyvalue'];
  _blobfield := Request.QueryFields.Values['blobfield'];

  Q := TFDQuery.Create(nil);

  Fields := TStringList.Create;
  try
    // WhiteList f�r Feldnamen erzeugen:   (Alle Felder der angeforderten tabelle)
    Connection.GetFieldNames('', '', _table, '', Fields);

    // Feldname auf g�ltigkeit pr�fen:
    if Fields.count = 0 then
      raise exception.Create('Feldname f�r table ungültig');
    if Fields.IndexOf(_keyfield) < 0 then
      raise exception.Create('Feldname f�r keyfield ungültig');
    if Fields.IndexOf(_blobfield) < 0 then
      raise exception.Create('Feldname f�r blobfield ungültig');

    Q.Connection := Connection;
    Q.SQL.Text := 'select ' + _keyfield + ', ' + _blobfield + ' from ' + _table + ' where ' + _keyfield + '= :KEYVALUE';
    // Parameter setzen:
    Q.ParamByName('keyvalue').AsString := _keyvalue;

    try
      Connection.StartTransaction;
      Q.Open;
      Q.UpdateOptions.ReadOnly := false;
      Q.UpdateOptions.EnableUpdate := true;

      If Q.Eof and Q.Bof then
        raise exception.Create('Kein Datensatz für Blobfiled ' + _table + 'vorhanden');

      Q.Edit;
      if Trim(Request.Content) <> '' then
        SetBase64ToBlob(Request.Content, TBlobfield(Q.Fieldbyname(_blobfield)))
      else
        TBlobfield(Q.Fieldbyname(_blobfield)).clear;
      Q.Post;

      Response.ContentType := 'application/json';
      Response.StatusCode := 200;
      Response.Content := '{"status":"OK"}';
      Connection.Commit;
    except
      on E: exception do
      begin
        if Connection.InTransaction then
          Connection.Rollback;
        raise;
      end;
    end;

  finally
    Q.Free;
    Fields.Free;

  end;
end;


(* ******************************************** Base64ToBlob *********************************************************** *)
// Route: /delete  |  Auth: true  |  LocalOnly: true
procedure TDataModulSQL.Delete;
var
  table: string;
  key: string;
  requestbody: string;
  Q: TFDQuery;

begin
  table := Request.QueryFields.Values['table'];
  key := Request.QueryFields.Values['key'];
  requestbody := Request.Content;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := Connection;
    GenerateDeleteSQLAndAssignParams(requestbody, Q, table);
    try
      Connection.StartTransaction;
      Q.ExecSQL;
      Response.ContentType := 'application/json';
      Response.StatusCode := 200;
      Response.Content := '{"status":"OK"}';

      Connection.Commit;
    except
      on E: exception do
      begin
        if Connection.InTransaction then
          Connection.Rollback;
        raise;
      end;
    end;

  finally
    Q.Free;
  end;
end;

(* ******************************************** SQL-execute *********************************************************** *)
// Route: /execute  |  Auth: true  |  LocalOnly: true
procedure TDataModulSQL.execute;
var
  requestbody: string;
  Q: TFDQuery;

begin
  requestbody := Request.Content;
  Q := TFDQuery.Create(nil);

  try
    Q.Connection := Connection;
    ApplyParamsToFDQuery(Q, requestbody);

    try
      Connection.StartTransaction;
      Q.ExecSQL;
      Connection.Commit;
    except
      on E: exception do
      begin
        if Connection.InTransaction then
          Connection.Rollback;
        raise;
      end;
    end;
    Response.ContentType := 'application/json';

    Response.Content := '{"status":"OK"}';
  finally
    Q.Free;
  end;
end;

end.
