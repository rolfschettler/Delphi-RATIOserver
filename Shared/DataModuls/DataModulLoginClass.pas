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

uses rechtelib, webUtils, uBCrypt, System.JSON;

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
    (case-insensitiv und umlautsicher — siehe Kommentar an der Query, der
    Zeichensatz NONE erzwingt hier einen Sondervergleich).
    Die Anfrage muss UTF-8 kodiert sein.
    Das Passwort wird im Klartext erwartet (keine Codierung) und per
    TBCrypt.CompareHash (Unit uBCrypt) direkt in Delphi gegen den
    bcrypt-Hash aus REGISTRIERUNG.PWD2 geprüft — dieselbe Prüfung, die
    PHP mit password_verify() vornimmt, nur ohne externen Aufruf.
    Anschließend wird REGISTRIERUNG.GESPERRT ausgewertet: steht dort "JA",
    wird die Anmeldung abgelehnt, obwohl das Passwort stimmt.

  Hinweis URL-Encoding:
    Bei GET und POST Form-encoded dekodiert Delphi URL-Encoding automatisch.
    Ein "+" im Passwort wird dabei als Leerzeichen interpretiert —
    der Aufrufer muss in diesem Fall "+" als "%2B" kodieren.
    Bei JSON-Body kann "+" direkt verwendet werden.
*)
const
  // Höchster akzeptierter bcrypt-Kostenfaktor aus REGISTRIERUNG.PWD2.
  // Der Faktor steckt im Hash selbst und bestimmt die Rechenzeit (2^Cost
  // Runden); uBCrypt lässt 4..31 zu. Die Hashes dieses Systems haben
  // Cost 12 (PHP password_hash), 14 lässt Luft nach oben.
  MAX_BCRYPT_COST = 14;

var
  username: string;
  password: string;
  hash: string;
  gesperrt: string;
  cost: Integer;
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

  // Liest den Kostenfaktor aus einem bcrypt-Hash "$2y$12$<Salt><Hash>".
  // Zerlegt bewusst genauso wie TryParseBCryptHash in uBCrypt, damit auch
  // der alte Präfix "$2$" (einstellig) richtig gelesen wird.
  function TryHashCost(const AHash: string; out ACost: Integer): boolean;
  var
    Parts: TArray<string>;
  begin
    ACost := 0;
    Result := false;
    if (AHash = '') or (AHash[1] <> '$') then Exit;
    Parts := AHash.Substring(1).Split(['$']);
    Result := (Length(Parts) = 3) and TryStrToInt(Parts[1], ACost);
  end;

begin
  username := '';
  password := '';
  Result := false;

  try
//  raise Exception.Create('Fehlermeldung');

    // Das Einlesen der Parameter steht mit im try-Block: enthaelt die Anfrage
    // Bytes, die kein gueltiges UTF-8 sind (z.B. ein Umlaut als Latin-1 %FC
    // statt %C3%BC), wirft bereits der Zugriff auf QueryFields/Content eine
    // Encoding-Exception. Ohne den try-Block schlug das als HTTP 500 mit
    // kryptischer Meldung durch statt als sauberes 401.
    try
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
    except
      on e: Exception do
        raise Exception.Create('Anmeldedaten sind nicht UTF-8 kodiert. Umlaute müssen als UTF-8 übergeben werden (ü = %C3%BC). [' + e.message + ']');
    end;

    with query do
    begin
      close;
      // Umlautsicherer, case-insensitiver Vergleich -- Erlaeuterung des
      // Musters bei CaseInsCondition in webUtils.
      sql.text := 'select nr,kennziffer,username as loginname,username,gesperrt,typ,hauptregistrierung,pwd2 from registrierung' +
                  ' where ' + CaseInsCondition('username', 'username');
      ParamByName('username_asc').AsString   := UpperCaseAscii(username);
      ParamByName('username_asclo').AsString := UpperCaseAscii(ToLowerUni(username));
      ParamByName('username_ascup').AsString := UpperCaseAscii(ToUpperUni(username));
      open;
      if (eof and bof) then
        raise Exception.Create('Benutzername oder Passwort sind falsch');
      hash := trim(FieldByName('pwd2').AsString);
      gesperrt := trim(FieldByName('gesperrt').AsString);
    end;

    if hash = '' then
      raise Exception.Create('Benutzername oder Passwort sind falsch');

    // Kostenfaktor begrenzen, BEVOR uBCrypt zu rechnen anfaengt: die Pruefung
    // laeuft seit der Umstellung im Apache-Worker-Thread, ein untergeschobener
    // Hash mit Cost 31 wuerde ihn praktisch endlos blockieren (pwd2 ist ueber
    // insertregistrierung/insertregistrierunglocal direkt beschreibbar).
    // Die Meldung nach aussen bleibt absichtlich unspezifisch -- der Endpunkt
    // ist unauthentifiziert. Scheitern hier ploetzlich ALLE Anmeldungen, wurde
    // der Kostenfaktor der Hashes ueber MAX_BCRYPT_COST hinaus erhoeht.
    if (not TryHashCost(hash, cost)) or (cost > MAX_BCRYPT_COST) then
      raise Exception.Create('Benutzername oder Passwort sind falsch');

    // Hashprüfung direkt in Delphi (bcrypt, Unit uBCrypt)
    if not TBCrypt.CompareHash(password, hash) then
      raise Exception.Create('Benutzername oder Passwort sind falsch');

    // Sperre erst NACH der Passwortpruefung melden -- wer das Passwort nicht
    // kennt, soll nicht erfahren, ob es das Konto gibt und wie es dasteht.
    // REGISTRIERUNG.GESPERRT ist CHAR(4): steht dort "JA" (in beliebiger
    // Schreibweise), ist das Konto gesperrt; leer/NULL bedeutet offen.
    if SameText(gesperrt, 'JA') then
      raise Exception.Create('Dieses Benutzerkonto ist gesperrt.');

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


