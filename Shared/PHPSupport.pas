(*
  PHPSupport — Universal-Adapter zum Aufruf von PHP-Endpunkten der IBAPI-Schnittstelle

  Diese Unit dient als Abstraktionsschicht für Delphi-Entwickler, die PHP-Skripte
  des IBAPI-Servers aufrufen möchten, ohne sich um HTTP-Details kümmern zu müssen.

  Konzept:
    PHP_Call() ist der einzige Einstiegspunkt. Die Funktion sendet immer POST
    mit einem JSON-Body und gibt die rohe Antwort als String zurück —
    egal ob der PHP-Endpunkt Text, JSON oder HTML liefert.
    Der Aufrufer entscheidet selbst wie er das Ergebnis weiterverarbeitet.

  Voraussetzung:
    Der Apache-Server mit den PHP-Skripten muss lokal laufen.
    Der Port wird automatisch aus der Windows-Registry gelesen:
      HKEY_LOCAL_MACHINE\SOFTWARE\APACHESERVER\APACHEPORT

  Token-Parameter (optional, aber empfohlen):
    Der JWT-Bearer-Token wird vom IBAPI-Server beim Login ausgestellt und muss
    bei geschützten Endpunkten mitgegeben werden.
    Den Token erhält man aus dem Authorization-Header des eingehenden Requests:

      var
        AuthHeader, Token: string;
      begin
        AuthHeader := Request.GetFieldByName('Authorization');
        if AuthHeader.StartsWith('Bearer ', true) then
          Token := AuthHeader.Substring(7);
      end;

    Wird kein Token übergeben, wird die Anfrage ohne Authentifizierung gesendet
    (nur für öffentliche Endpunkte geeignet).

  Beispiele:

    // Endpunkt ohne Parameter
    Result := PHP_Call('hello', nil, Token);

    // Endpunkt mit Parametern
    var Params := TJSONObject.Create;
    try
      Params.AddPair('start', 'Ulm');
      Params.AddPair('ziel', 'Stuttgart');
      Result := PHP_Call('calculatedistance', Params, Token);
    finally
      Params.Free;
    end;

    // Ergebnis als JSON weiterverarbeiten
    var JSON := TJSONObject.ParseJSONValue(PHP_Call('getdata', nil, Token));

    // Ergebnis als HTML direkt ausgeben
    Response.Content := PHP_Call('routeplaner', Params, Token);
*)

unit PHPSupport;

interface

uses

  Web.HTTPApp,
  System.Classes, System.Win.Registry, Winapi.Windows,
  System.SysUtils, System.Net.HttpClient, System.Net.URLClient, System.JSON,
  System.NetConsts;

// Ruft einen PHP-Endpunkt via POST auf. Parameter werden als JSON-Body übergeben.
// Gibt die rohe Antwort zurück (Text, JSON oder HTML — je nach Endpunkt).
// Params: TJSONObject mit den Parametern, oder nil für leeren Body.
// Token:  JWT-Bearer-Token zur Authentifizierung (optional).
function PHP_Call(const Endpoint: string; const Params: TJSONObject = nil; const Token: string = ''): string;



implementation
uses webUtils;

function GetApachePort: string;
begin
  // Der Port für den Apache-Server wurde bei der Installation in die Registry und in die config.ini eingetragen
  Result:=TConfigFile.GetConfigValue('APACHE', 'port', intTostr(80));
  exit;
end;



function GetPHPServerUrl: string;
begin
  Result :='http://localhost:' + GetApachePort() + '/php/';
end;

function PHP_Call(const Endpoint: string; const Params: TJSONObject = nil; const Token: string = ''): string;
var
  HttpClient: THttpClient;
  Response: IHTTPResponse;
  ContentStream: TStringStream;
  JsonBody: string;
begin
  if Assigned(Params) then
    JsonBody := Params.ToString
  else
    JsonBody := '{}';

  HttpClient := THttpClient.Create;
  try
    HttpClient.ContentType := 'application/json';
    if Token <> '' then
      HttpClient.CustomHeaders['Authorization'] := 'Bearer ' + Token;

    ContentStream := TStringStream.Create(JsonBody, TEncoding.UTF8);
    try
      ContentStream.Position := 0;
      Response := HttpClient.Post(GetPHPServerUrl + Endpoint, ContentStream);
      Result := Response.ContentAsString(TEncoding.UTF8);
    finally
      ContentStream.Free;
    end;
  finally
    HttpClient.Free;
  end;
end;

end.
