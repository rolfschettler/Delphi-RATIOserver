unit KI_Support;

interface

uses
  System.Generics.Collections,
  System.Net.HttpClient, System.Net.mime, System.Net.HttpClientComponent, IdGlobal, IdCoderMIME,
  System.Net.URLClient, System.JSON, System.NetEncoding,
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  System.IOUtils, DateUtils;


function Analyze_File_V2(FStream: TStream; const FilePath, UserPrompt, ApiKey: string): String;
function getTeilnehmer(filename: string; FStream: TStream; ki_token: string): TJSONArray;
procedure CheckSupportedFileType(const FilePath: string);

implementation

function EncodeFileToBase64(Memstream: TStream): string;
var
  sstream: TStringStream;
begin
  sstream := nil;
  Memstream.Position := 0;
  try
    sstream := TStringStream.Create;
    TIdEncoderMIME.EncodeStream(Memstream, sstream);
    sstream.Position := 0;
    result := sstream.DataString;
  finally
    sstream.free;
  end;

end;

procedure CheckSupportedFileType(const FilePath: string);
const
  SupportedTypes = '.pdf .txt .csv .jpg .jpeg .png .gif .webp .docx .xlsx';
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(FilePath));
  if Ext = '' then
    raise Exception.Create('Die Datei hat keine Dateiendung. Unterstuetzte Formate: ' + SupportedTypes);
  if Pos(Ext + ' ', SupportedTypes + ' ') = 0 then
    raise Exception.CreateFmt('Dateiformat "%s" wird nicht unterstuetzt. Unterstuetzte Formate: %s', [Ext, SupportedTypes]);
end;

function Analyze_File_V2(FStream: TStream; const FilePath, UserPrompt, ApiKey: string): String;
// Verbesserte Version von Analyze_File:
//   - Unterstützt PDFs nativ via inline Base64 (kein File-Upload nötig)
//   - Verwendet gpt-4o statt gpt-4o-mini (nötig für Dokument- und PDF-Verständnis)
//   - Bilder: weiterhin input_image mit Base64
//   - Alle anderen Dateitypen: input_file mit inline Base64 + media_type
var
  HttpClient:   THttpClient;
  RequestBody:  TStringStream;
  Response:     IHttpResponse;
  JsonBody, MessageObj: TJSONObject;
  InputArray, ContentArray: TJSONArray;
  Base64Data, Ext, MediaType: string;
  OutputArray, ContentOut: TJSONArray;
  JsonResp: TJSONObject;
begin
  Result := '';
  Ext := LowerCase(ExtractFileExt(FilePath));

  HttpClient := THttpClient.Create;
  try
    HttpClient.ConnectionTimeout := 30000;
    HttpClient.ResponseTimeout   := 120000; // PDFs brauchen mehr Zeit

    HttpClient.CustomHeaders['Authorization'] := 'Bearer ' + ApiKey;
    HttpClient.CustomHeaders['Content-Type']  := 'application/json';

    Base64Data := EncodeFileToBase64(FStream);

    JsonBody := TJSONObject.Create;
    try
      JsonBody.AddPair('model', 'gpt-4o'); // gpt-4o-mini unterstützt keine PDFs

      InputArray   := TJSONArray.Create;
      MessageObj   := TJSONObject.Create;
      ContentArray := TJSONArray.Create;
      try
        MessageObj.AddPair('role', 'user');

        // Textprompt
        ContentArray.AddElement(
          TJSONObject.Create.AddPair('type', 'input_text').AddPair('text', UserPrompt)
        );

        // Media-Type bestimmen
        if      Ext = '.jpg'  then MediaType := 'image/jpeg'
        else if Ext = '.jpeg' then MediaType := 'image/jpeg'
        else if Ext = '.png'  then MediaType := 'image/png'
        else if Ext = '.gif'  then MediaType := 'image/gif'
        else if Ext = '.webp' then MediaType := 'image/webp'
        else if Ext = '.pdf'  then MediaType := 'application/pdf'
        else if Ext = '.txt'  then MediaType := 'text/plain'
        else if Ext = '.csv'  then MediaType := 'text/plain'
        else if Ext = '.docx' then MediaType := 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
        else if Ext = '.xlsx' then MediaType := 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        else                       MediaType := 'application/octet-stream';

        // Bilder → input_image, image_url als einfacher Data-URL String
        if (Ext = '.jpg') or (Ext = '.jpeg') or (Ext = '.png') or (Ext = '.gif') or (Ext = '.webp') then
        begin
          ContentArray.AddElement(
            TJSONObject.Create
              .AddPair('type',      'input_image')
              .AddPair('image_url', 'data:' + MediaType + ';base64,' + Base64Data)
          );
        end
        else
        begin
          // PDF und andere Dateien → input_file inline
          ContentArray.AddElement(
            TJSONObject.Create
              .AddPair('type',      'input_file')
              .AddPair('filename',  ExtractFileName(FilePath))
              .AddPair('file_data', 'data:' + MediaType + ';base64,' + Base64Data)
          );
        end;

        // Ownership übergeben
        MessageObj.AddPair('content', ContentArray);
        ContentArray := nil;
        InputArray.AddElement(MessageObj);
        MessageObj := nil;
        JsonBody.AddPair('input', InputArray);
        InputArray := nil;

      except
        ContentArray.Free;
        MessageObj.Free;
        InputArray.Free;
        raise;
      end;

      RequestBody := TStringStream.Create(JsonBody.ToString, TEncoding.UTF8);
      try
        Response := HttpClient.Post('https://api.openai.com/v1/responses', RequestBody);

        if Response.StatusCode <> 200 then
          raise Exception.Create('API Fehler: ' + Response.ContentAsString);

        JsonResp := TJSONObject.ParseJSONValue(Response.ContentAsString) as TJSONObject;
        try
          OutputArray := JsonResp.GetValue<TJSONArray>('output');
          if Assigned(OutputArray) and (OutputArray.Count > 0) then
          begin
            ContentOut := OutputArray.Items[0].GetValue<TJSONArray>('content');
            if Assigned(ContentOut) then
              for var j := 0 to ContentOut.Count - 1 do
                if ContentOut.Items[j].GetValue<string>('type', '') = 'output_text' then
                begin
                  Result := ContentOut.Items[j].GetValue<string>('text', '');
                  Break;
                end;
          end;
        finally
          JsonResp.Free;
        end;
      finally
        RequestBody.Free;
      end;

    finally
      JsonBody.Free;
    end;

  finally
    HttpClient.Free;
  end;
end;

function getTeilnehmer(filename: string; FStream: TStream; ki_token: string): TJSONArray;
var
  prompt: string;
  RawText: string;
  JsonArray: TJSONArray;
begin
  prompt := 'Du bist ein Datenextraktor. Extrahiere aus dem Dokument eine Teilnehmerliste.' +
    'Antworte NUR mit einem gueltigen JSON-Array, keine Markups, kein Text davor oder danach.' +
    'Benoetigt werden folgende Felder: vorname, nachname, geburtstag, email. Die Property-Namen immer in Kleinbuchstaben. Die Werte exakt so uebernehmen wie sie im Dokument stehen (Gross-/Kleinschreibung nicht veraendern).' +
    'Das Feld geburtstag immer im deutschen Format ausgeben (DD.MM.YYYY), egal in welchem Format es im Dokument steht. Falls kein Geburtsdatum vorhanden, setze "??????".' +
    'KRITISCHE REGEL: Erfinde KEINE Daten. Wenn ein Wert nicht eindeutig im Dokument steht, setze ZWINGEND "??????".' +
    'Das gilt auch fuer E-Mail-Adressen und Geburtsdaten - auch wenn du sie erraten koenntest, schreibe "??????".' +
    'Nur Daten die EXPLIZIT im Dokument stehen duerfen uebernommen werden.' +
    'Wenn keine Teilnehmerdaten vorhanden sind, gib ein leeres Array [] zurueck. Keine Erklaerungen, kein Text davor oder danach.';
  RawText := Analyze_File_V2(FStream, filename, prompt, ki_token);

  // GPT-4o umschliesst die Antwort manchmal mit Markdown-Code-Fences (```json ... ```)
  // Diese werden hier entfernt, bevor das JSON geparst wird
  RawText := Trim(RawText);
  if RawText.StartsWith('```') then
  begin
    RawText := RawText.Substring(RawText.IndexOf(#10) + 1);
    if RawText.EndsWith('```') then
      RawText := RawText.Substring(0, RawText.LastIndexOf('```'));
    RawText := Trim(RawText);
  end;

  var jv := TJSONObject.ParseJSONValue(RawText);
  if not (jv is TJSONArray) then
  begin
    jv.Free;
    raise Exception.Create('Es sind keine Teilnehmerdaten in diesem Dokument vorhanden.');
  end;

  JsonArray := jv as TJSONArray;
  if JsonArray.Count = 0 then
  begin
    JsonArray.Free;
    raise Exception.Create('Es sind keine Teilnehmerdaten in diesem Dokument vorhanden.');
  end;

  result := JsonArray;

end;

end.
