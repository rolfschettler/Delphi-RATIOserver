unit webUtils;

interface

uses
  System.NetEncoding, Data.DB, IOUTILS,
  System.JSON,
  System.SyncObjs,
  Web.HTTPApp,
  System.IniFiles,
  System.SysUtils,
  System.Net.HttpClient, System.Net.URLClient,
  System.Classes;

type
  TConfigFile = class
  private
    class var FRequest           : TWebRequest;
    class var FCachedConfigFilename : string;        // einmalig ermittelter Pfad
    class var FConfigLock        : TCriticalSection; // schützt ersten Schreibzugriff

    class function GetDocumentRootFromCgi: string;

  public
    class constructor Create;
    class destructor  Destroy;

    class procedure init(pRequest: TWebRequest);
    class function  GetConfigfilename: string;
    class function  GetConfigValue(section: string; key: string; default: string = ''): string;
  end;

function ExcludeLastSlash(s: string): string;

function CreateJsonResponse(const AStatus, AMessage: string): string;
function BlobToBase64(Field: TField): string;
procedure SetBase64ToBlob(const Base64: string; AField: TField);
function GetValueCaseInsensitive(JsonObj: TJSONObject; const key: string): TJSONValue;

// Leak-sicherer Ersatz für: TJSONObject.ParseJSONValue(X) as TJSONObject
// Liefert das TJSONObject (Aufrufer übernimmt Eigentum) oder nil, wenn der Inhalt
// kein gültiges JSON-Objekt ist. Nicht-Objekt-Werte werden freigegeben (kein Leak).
function ParseJSONObject(const AJson: string): TJSONObject;

// Serialisiert ein geöffnetes Dataset als { "header": {...Feldtypen...}, "data": [...] }
// WithBlob = True: BLOB-Felder als Base64, sonst als Platzhalter 'BLOB'
function SerializeQuery(Dataset: TDataSet; WithBlob: Boolean = False): string;

implementation

// ---------------------------------------------------------------------------
// Hilfsfunktionen
// ---------------------------------------------------------------------------

function ExcludeLastSlash(s: string): string;
begin
  Result := s;
  if (Result <> '') and (Result[Length(Result)] = '/') then
    SetLength(Result, Length(Result) - 1);
end;

function CreateJsonResponse(const AStatus, AMessage: string): string;
var
  JSONObject: TJSONObject;
begin
  JSONObject := TJSONObject.Create;
  try
    JSONObject.AddPair('status',  AStatus);
    JSONObject.AddPair('message', AMessage);
    Result := JSONObject.ToString;
  finally
    JSONObject.Free;
  end;
end;

function BlobToBase64(Field: TField): string;
var
  Stream: TMemoryStream;
begin
  if Field.IsNull then
    Exit('');
  Stream := TMemoryStream.Create;
  try
    TBlobField(Field).SaveToStream(Stream);
    Stream.Position := 0;
    Result := TNetEncoding.Base64.EncodeBytesToString(Stream.Memory, Stream.Size);
  finally
    Stream.Free;
  end;
end;

procedure SetBase64ToBlob(const Base64: string; AField: TField);
var
  Bytes  : TBytes;
  Stream : TMemoryStream;
begin
  Bytes  := TNetEncoding.Base64.DecodeStringToBytes(Base64);
  Stream := TMemoryStream.Create;
  try
    if Length(Bytes) > 0 then
      Stream.WriteBuffer(Bytes[0], Length(Bytes)); // Bytes[0]: Daten schreiben, nicht die Array-Variable
    Stream.Position := 0;
    TBlobField(AField).LoadFromStream(Stream);
  finally
    Stream.Free;
  end;
end;

function GetValueCaseInsensitive(JsonObj: TJSONObject; const key: string): TJSONValue;
var
  Pair: TJSONPair;
begin
  Result := nil;
  for Pair in JsonObj do
    if SameText(Pair.JSONString.Value, key) then
    begin
      Result := Pair.JsonValue;
      Exit;
    end;
end;

function ParseJSONObject(const AJson: string): TJSONObject;
var
  V: TJSONValue;
begin
  Result := nil;
  V := TJSONObject.ParseJSONValue(AJson);
  if V is TJSONObject then
    Result := TJSONObject(V)
  else
    V.Free;   // nil-sicher; gibt geparste Nicht-Objekt-Werte frei
end;

// ---------------------------------------------------------------------------
// TConfigFile
// ---------------------------------------------------------------------------

class constructor TConfigFile.Create;
begin
  FRequest              := nil;
  FCachedConfigFilename := '';
  FConfigLock           := TCriticalSection.Create;
end;

class destructor TConfigFile.Destroy;
begin
  FConfigLock.Free;
end;

class procedure TConfigFile.init(pRequest: TWebRequest);
begin
  // Request wird nur noch benötigt wenn der Pfad noch nicht gecacht ist.
  // Wir speichern ihn kurz, GetConfigfilename holt ihn sich falls nötig.
  FConfigLock.Enter;
  try
    FRequest := pRequest;
  finally
    FConfigLock.Leave;
  end;
end;

class function TConfigFile.GetDocumentRootFromCgi: string;
// ACHTUNG: darf nur aus GetConfigfilename innerhalb des Locks aufgerufen werden!
var
  ExePath      : string;
  RelScriptName: string;
  SlashCount   : Integer;
  i            : Integer;
begin
  ExePath       := ExcludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  RelScriptName := FRequest.ScriptName;

  while Pos('//', RelScriptName) > 0 do
    RelScriptName := StringReplace(RelScriptName, '//', '/', [rfReplaceAll]);
  while (Length(RelScriptName) > 0) and (RelScriptName[Length(RelScriptName)] = '/') do
    SetLength(RelScriptName, Length(RelScriptName) - 1);

  SlashCount := 0;
  for i := 1 to Length(RelScriptName) do
    if RelScriptName[i] = '/' then
      Inc(SlashCount);

  for i := 1 to SlashCount - 1 do
    ExePath := ExtractFilePath(ExcludeTrailingPathDelimiter(ExePath));

  Result := IncludeTrailingPathDelimiter(ExePath);
end;

class function TConfigFile.GetConfigfilename: string;
var
  root    : string;
  DocRoot : string;
  filename: string;
begin
  // Schneller Pfad: Dateiname bereits bekannt → kein Lock nötig
  // (FCachedConfigFilename wird nur einmal von '' auf einen Wert gesetzt,
  //  danach nie mehr geändert → sicheres Lesen ohne Lock)
  if FCachedConfigFilename <> '' then
  begin
    Result := FCachedConfigFilename;
    Exit;
  end;

  // Langsamer Pfad: einmalig ermitteln, mit Lock absichern
  FConfigLock.Enter;
  try
    // Nochmal prüfen – ein anderer Thread könnte inzwischen gesetzt haben
    if FCachedConfigFilename = '' then
    begin
      if FRequest = nil then
        raise Exception.Create('TConfigFile.init() wurde noch nicht aufgerufen.');

      root    := GetDocumentRootFromCgi;
      DocRoot := ExtractFilePath(ExcludeTrailingPathDelimiter(root));
      DocRoot := IncludeTrailingPathDelimiter(DocRoot);
      filename := DocRoot + 'cgi-config\config.ini';

      if not FileExists(filename) then
        raise Exception.Create('Configfile (' + filename + ') ist nicht vorhanden.');

      FCachedConfigFilename := filename;  // atomar schreiben
    end;
    Result := FCachedConfigFilename;
  finally
    FConfigLock.Leave;
  end;
end;

class function TConfigFile.GetConfigValue(section: string; key: string; default: string = ''): string;
var
  Ini        : TIniFile;
  inifilename: string;
begin
  inifilename := GetConfigfilename;
  Ini := TIniFile.Create(inifilename);
  try
    Result := Ini.ReadString(section, key, '');

    if (Result = '') and (default <> '') then
      Result := default;

    if Result = '' then
      raise Exception.Create(section + ' / ' + key + ': ist nicht in Configfile definiert.');
  finally
    Ini.Free;
  end;
end;

// ---------------------------------------------------------------------------
// SerializeQuery
// ---------------------------------------------------------------------------

function SerializeQuery(Dataset: TDataSet; WithBlob: Boolean): string;
var
  JSONArray  : TJSONArray;
  JSONdata   : TJSONObject;
  JSONheader : TJSONObject;
  row        : TJSONObject;
  i          : Integer;
  Field      : TField;
  dt         : TDateTime;
begin
  row        := nil;
  JSONArray  := TJSONArray.Create;
  JSONheader := TJSONObject.Create;
  JSONdata   := TJSONObject.Create;
  try
    // Header: Feldname → Delphi-Typ
    for i := 0 to Dataset.Fields.Count - 1 do
    begin
      Field := Dataset.Fields[i];
      case Field.DataType of
        ftFloat, ftCurrency, ftBCD, ftFMTBcd:
          JSONheader.AddPair(LowerCase(Field.FieldName), 'ftfloat');
        ftDate:
          JSONheader.AddPair(LowerCase(Field.FieldName), 'ftdate');
        ftTime, ftDateTime, ftTimeStamp:
          JSONheader.AddPair(LowerCase(Field.FieldName), 'ftdatetime');
        ftBoolean:
          JSONheader.AddPair(LowerCase(Field.FieldName), 'ftinteger');
        ftInteger, ftSmallint, ftWord, ftLargeint, ftAutoInc:
          JSONheader.AddPair(LowerCase(Field.FieldName), 'ftinteger');
        ftBlob:
          JSONheader.AddPair(LowerCase(Field.FieldName), 'ftblob');
      else
        JSONheader.AddPair(LowerCase(Field.FieldName), 'ftstring ' + IntToStr(Field.Size));
      end;
    end;

    // Daten
    Dataset.First;
    while not Dataset.Eof do
    begin
      row := TJSONObject.Create;
      for i := 0 to Dataset.Fields.Count - 1 do
      begin
        Field := Dataset.Fields[i];
        if Field.IsNull then
          row.AddPair(LowerCase(Field.FieldName), TJSONNull.Create)
        else
          case Field.DataType of
            ftFloat, ftCurrency, ftBCD, ftFMTBcd:
              row.AddPair(LowerCase(Field.FieldName),
                TJSONNumber.Create(StringReplace(Field.AsString, ',', '.', [rfReplaceAll])));
            ftDate:
              row.AddPair(LowerCase(Field.FieldName),
                FormatDateTime('yyyy-mm-dd', Field.AsDateTime));
            ftTime, ftDateTime, ftTimeStamp:
              begin
                dt := Field.AsDateTime;
                if Frac(dt) = 0 then
                  row.AddPair(LowerCase(Field.FieldName), FormatDateTime('yyyy-mm-dd', dt))
                else
                  row.AddPair(LowerCase(Field.FieldName), FormatDateTime('yyyy-mm-dd hh:nn:ss', dt));
              end;
            ftBoolean:
              row.AddPair(LowerCase(Field.FieldName), TJSONBool.Create(Field.AsBoolean));
            ftInteger, ftSmallint, ftWord, ftLargeint, ftAutoInc:
              row.AddPair(LowerCase(Field.FieldName), TJSONNumber.Create(Field.AsInteger));
            ftBlob:
              if WithBlob then
                row.AddPair(LowerCase(Field.FieldName), BlobToBase64(Field))
              else
                row.AddPair(LowerCase(Field.FieldName), 'BLOB');
          else
            row.AddPair(LowerCase(Field.FieldName), Field.AsString);
          end;
      end;
      JSONArray.AddElement(row);
      row := nil;
      Dataset.Next;
    end;

    JSONdata.AddPair('header', JSONheader);
    JSONheader := nil;
    JSONdata.AddPair('data', JSONArray);
    JSONArray  := nil;
    Result := JSONdata.ToJSON;
  finally
    JSONdata.Free;
    if Assigned(JSONArray)  then JSONArray.Free;
    if Assigned(JSONheader) then JSONheader.Free;
    if Assigned(row)        then row.Free;
  end;
end;

end.
