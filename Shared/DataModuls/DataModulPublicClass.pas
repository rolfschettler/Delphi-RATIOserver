unit DataModulPublicClass;

interface

uses
  Web.HTTPApp, System.json, System.Hash, System.Generics.Collections,
  System.SysUtils, System.Classes, DataModulTableBaseClass, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt,
  FireDAC.UI.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Phys, FireDAC.Phys.IB, FireDAC.Phys.IBDef, FireDAC.VCLUI.Wait, Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet;

type
  TDataModulPublic = class(TDataModulTableBase)
  private
    { Private-Deklarationen }

    // ── Generischer Kern fuer token-autorisierte Public-Endpunkte ────────────
    // Diese drei Bausteine kennen keine Fachlichkeit. Ein weiterer oeffentlicher
    // Datensatztyp (GEBUCHT, TEILNEHMER, ...) braucht nur zwei duenne Handler
    // nach dem Muster von getAdresseByToken/updateAdresseByToken - die
    // Token-Pruefung wird NICHT erneut geschrieben.

    // Prueft den Einladungs-Token aus Body ("token") oder QueryString
    // (?token=...) und liefert die im Token hinterlegte Referenz zurueck.
    // Bei Misserfolg wird bereits eine Fehlerantwort gesendet -> Handler
    // muss nur noch mit Exit abbrechen.
    // Setzt USED_AT NICHT (Begruendung an der Implementierung).
    // ATokenId brauchen nur Handler, die den Token abschliessen wollen -
    // siehe CloseToken.
    function ValidatePublicToken(const AExpectedRefType, AExpectedPurpose: string;
      out AReferenceId: Integer; out ARecipient: string;
      out ATokenId: Integer): Boolean;

    // Schliesst den Token ab: REVOKED=1 und USED_AT=jetzt.
    //
    // Das ist der Gegenentwurf zu SINGLE_USE. Verbraucht wird ein Token nicht
    // durch einen technischen Zugriff - Mail-Scanner und Link-Vorschauen
    // rufen Links automatisch auf und wuerden ihn verbrennen, bevor ein
    // Mensch klickt -, sondern durch eine bewusste Handlung: der Gast drueckt
    // "Ich bin fertig", oder ein Handler schliesst selbst ab, wenn der
    // Vorgang eindeutig beendet ist (Passwort gesetzt).
    //
    // REVOKED prueft ValidatePublicToken schon - deshalb ist hier KEINE
    // weitere Pruefung noetig und die Validierung bleibt unberuehrt.
    // USED_AT haelt fest, WANN der Gast fertig war; zusammen bedeuten
    // REVOKED=1 mit gesetztem USED_AT "vom Gast abgeschlossen", REVOKED=1
    // ohne USED_AT "von uns widerrufen" (TokenController::revoke).
    procedure CloseToken(ATokenId: Integer);

    // Widerruft alle ANDEREN offenen Passwort-Links desselben Benutzers.
    // Nach einem gesetzten Passwort soll kein zweiter, aelterer Reset-Link
    // mehr funktionieren - Standardverhalten bei Passwort-Zurücksetzung.
    procedure RevokeOtherPasswordTokens(AReferenceId, AKeepTokenId: Integer);

    // SELECT <AAllowed> FROM <ATable> WHERE <AKeyField> = AKeyValue
    // Antwort ist ein EINZELNES Objekt (es ist immer genau ein Satz).
    // AExtra wird - wenn uebergeben - in "data" gemischt und dabei uebernommen.
    procedure SendRecordByKey(const ATable: string;
      const AAllowed: array of string; const AKeyField: string;
      AKeyValue: Integer; AExtra: TJSONObject = nil);

    // UPDATE <ATable> SET <Body-Felder aus AAllowed> WHERE <AKeyField> = AKeyValue
    // Der Schluessel ist ein Parameter und kommt NIE aus dem Body -> IDOR
    // ist strukturell ausgeschlossen, nicht bloss weggeprueft.
    procedure UpdateRecordByKey(const ATable: string;
      const AAllowed: array of string; const AKeyField: string;
      AKeyValue: Integer);

    // Fehlerantwort im Format, das auch CreateJsonResponse liefert
    // ({"status":"ERROR","message":"..."}) - Angular liest err.error.message.
    procedure SendPublicError(const AMessage: string; AStatusCode: Integer);
  public
    { Public-Deklarationen }
    procedure Demo;

    // Oeffentliche Adress-Bearbeitung per Einladungs-Token (kein Bearer-Token)
    procedure getAdresseByToken;
    procedure updateAdresseByToken;

    // "Ich bin fertig": der Gast schliesst seinen Link selbst ab.
    procedure abschliessenByToken;

    // Neues Passwort per Einladungs-Token setzen (PURPOSE='passwort').
    // Genau EIN Endpunkt: die Seite muss nichts lesen, der Gast gibt sein
    // neues Passwort zweimal ein. REGISTRIERUNG wird nur geschrieben.
    procedure setPasswortByToken;

    // Fragebogen per Einladungs-Token ausfüllen (PURPOSE='formular',
    // REFERENCE_TYPE='FORM_KARTEI_HISTORY', REFERENCE_ID = die Instanz).
    // Die Kartei-Definition pflegt DataModulFragebogenClass.
    procedure getFormularByToken;
    procedure saveFormularByToken;
    procedure formularAbschliessenByToken;
  end;


function CreateDataModulPublic(Request: TWebRequest; Response: TWebResponse): TObject;

implementation
uses webutils;

function CreateDataModulPublic(Request: TWebRequest; Response: TWebResponse): TObject;
begin
  Result := TDataModulPublic.Create(Request, Response);
end;

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}

{ TDataModulPublic }

(*
  ============================  DEMO-Endpunkt  ============================
  Referenz-Vorlage fuer die Entwicklung neuer Endpunkte.
  Demonstriert den SICHEREN Zugriff auf Parameter aus zwei Quellen und den
  Umgang mit fehlenden Werten (ein, mehrere oder gar kein Parameter gesetzt).

  Hinweis: Fuer diesen Controller ist KEINE /demo-Route registriert - die
  Prozedur dient als Code-Vorlage. Zum Live-Test in WebModuleUnit1 eine Route
  ergaenzen, z.B.:
    FRouter.AddRoute('/public/demo', CreateDataModulPublic, TDataModulPublic(nil).Demo, false, true);

  Quellen:
    1) URL / QueryString  -> Request.QueryFields   (Beispiel-Parameter: id, filter)
    2) JSON-Body          -> isParamFromBody / getParamFromBody        (Beispiel-Parameter: name, menge)

  ----------------------------- Aufruf (Postman) -----------------------------
    Methode : POST   (GET reicht, wenn nur URL-Parameter genutzt werden)
    URL     : http://localhost:<port>/ibapi/public/demo?id=42&filter=Mueller
    Header  : Content-Type : application/json
              (Authorization nur noetig, wenn die Route Auth verlangt)
    Body    : (raw / JSON, optional)
              { "name": "Helga", "menge": 5 }

    Test-Kombinationen:
      - nur URL   : POST /public/demo?id=42&filter=Mueller   (Body leer lassen)
      - nur Body  : POST /public/demo   Body { "name":"Helga","menge":5 }
      - gemischt  : beide Quellen gleichzeitig
      - nichts    : POST /public/demo ohne Parameter -> alle Felder als null
    Fehlende Werte erzeugen KEINEN Fehler, sondern erscheinen im Ergebnis als null.
  ----------------------------------------------------------------------------
*)
procedure TDataModulPublic.Demo;
var
  // --- 1) URL-Parameter ---
  idText      : string;
  id          : Integer;
  idGesetzt   : Boolean;
  filter      : string;
  // --- 2) Body-Parameter ---
  name        : string;
  nameGesetzt : Boolean;
  menge       : Integer;
  mengeGesetzt: Boolean;
  // --- Antwort ---
  UrlObj, BodyObj, Ergebnis: TJSONObject;
begin
  // ===== 1) Parameter aus der URL (QueryString) =====
  // QueryFields.Values liefert IMMER einen String ('' wenn nicht vorhanden) -
  // also nie nil und nie eine Exception.

  // a) numerisch "id": sicher ueber StrToIntDef, Praesenz ueber ''-Pruefung
  idText    := Trim(Request.QueryFields.Values['id']);
  idGesetzt := idText <> '';
  id        := StrToIntDef(idText, 0);   // Default 0, falls fehlt oder keine Zahl

  // b) String "filter": '' bedeutet "nicht gesetzt"
  filter := Trim(Request.QueryFields.Values['filter']);

  // ===== 2) Parameter aus dem JSON-Body =====
  // Body-Parameter liest man ueber zwei Methoden der Basisklasse - fuer JEDEN
  // Parameter immer nach demselben Muster:
  //   isParamFromBody('x')  -> ist 'x' im Body vorhanden (und nicht null)?
  //   getParamFromBody('x') -> Wert von 'x' als String ('' wenn nicht vorhanden)
  //
  // Der Body wird dabei intern EINMAL geparst (leak-sicher) und beim Zerstoeren
  // des Moduls automatisch freigegeben. Deshalb hier KEIN ParseJSONObject und
  // KEIN try/finally noetig - und keine Gefahr eines Leaks.
  //
  // Werte kommen IMMER als String (so wie im JSON). Brauchst du eine Zahl,
  // wandelst du an der Aufrufstelle mit StrToIntDef - es gibt bewusst keine
  // typgetrennten Varianten.

  // a) String "name"
  nameGesetzt := isParamFromBody('name');
  name        := getParamFromBody('name');

  // b) Zahl "menge": String-Wert mit StrToIntDef in Integer wandeln
  mengeGesetzt := isParamFromBody('menge');
  menge        := StrToIntDef(getParamFromBody('menge'), 0);

  // ===== 3) Antwort aufbauen und senden =====
  // JsonOrNull(gesetzt, wert) -> Wert oder JSON null (eine Zeile pro Feld).
  // SendJson(obj)             -> setzt Content-Type + Status, sendet obj als
  //                              JSON und gibt es frei (auch verschachtelte
  //                              Objekte). Kein try/finally, kein manuelles Free.
  UrlObj := TJSONObject.Create;
  UrlObj.AddPair('id',     JsonOrNull(idGesetzt,    id));
  UrlObj.AddPair('filter', JsonOrNull(filter <> '', filter));

  BodyObj := TJSONObject.Create;
  BodyObj.AddPair('name',  JsonOrNull(nameGesetzt,  name));
  BodyObj.AddPair('menge', JsonOrNull(mengeGesetzt, menge));

  Ergebnis := TJSONObject.Create;
  Ergebnis.AddPair('url',  UrlObj);    // Ownership geht an Ergebnis ueber
  Ergebnis.AddPair('body', BodyObj);   // Ownership geht an Ergebnis ueber
  SendJson(Ergebnis);
end;

// ═══════════════════════════════════════════════════════════════════════════
//  Token-autorisierte Public-Endpunkte
//
//  Aufrufer ist der BROWSER DES GASTES - ohne Login, ohne Bearer-Token.
//  Autorisiert wird ausschliesslich ueber den Einladungs-Token aus der Mail.
//  Routen dazu in WebModuleUnit1: Auth=false, LocalOnly=false.
// ═══════════════════════════════════════════════════════════════════════════

procedure TDataModulPublic.SendPublicError(const AMessage: string;
  AStatusCode: Integer);
var
  Obj: TJSONObject;
begin
  Obj := TJSONObject.Create;
  Obj.AddPair('status',  'ERROR');
  Obj.AddPair('message', AMessage);
  SendJson(Obj, AStatusCode);
end;

function TDataModulPublic.ValidatePublicToken(const AExpectedRefType,
  AExpectedPurpose: string; out AReferenceId: Integer;
  out ARecipient: string; out ATokenId: Integer): Boolean;
var
  Token, TokenHash: string;
begin
  Result       := False;
  AReferenceId := 0;
  ARecipient   := '';
  ATokenId     := 0;

  // Klartext-Token: Body zuerst, ersatzweise QueryString (?token=...).
  // Die zweite Quelle macht den Lese-Endpunkt auch ohne JavaScript nutzbar.
  // Der HASH darf nie vom Client kommen - sonst waere er selbst das Geheimnis.
  Token := Trim(getParamFromBody('token'));
  if Token = '' then
    Token := Trim(Request.QueryFields.Values['token']);

  if Token = '' then
  begin
    SendPublicError('Kein Token uebergeben.', 401);
    Exit;
  end;

  TokenHash := LowerCase(THashSHA2.GetHashString(Token,
                 THashSHA2.TSHA2Version.SHA256));

  Query.Close;
  Query.SQL.Text :=
    'SELECT id, reference_id, reference_type, purpose, recipient_email, ' +
    'expires_at, used_at, single_use, revoked ' +
    'FROM ACCESS_TOKENS WHERE token_hash = :token_hash';
  Query.ParamByName('token_hash').AsString := TokenHash;
  Query.Open;
  try
    // Die einzige Token-Pruefung im Projekt. Alles, was ein Gast mit einem
    // Mail-Token tut, kommt hier vorbei - es gibt keine zweite Fassung
    // dieser Regeln, weder in Delphi noch in PHP.
    if Query.IsEmpty then
    begin
      SendPublicError('Token unbekannt.', 401);
      Exit;
    end;

    if Query.FieldByName('REVOKED').AsInteger = 1 then
    begin
      // Gesetztes USED_AT heisst: der Gast hat selbst abgeschlossen (CloseToken).
      // Ohne USED_AT haben WIR widerrufen. Fuer den Gast sind das zwei ganz
      // verschiedene Nachrichten - "Sie sind fertig" ist keine Stoerung.
      if Query.FieldByName('USED_AT').IsNull then
        SendPublicError('Token wurde widerrufen.', 401)
      else
        SendPublicError('Sie haben diesen Vorgang bereits abgeschlossen.', 401);
      Exit;
    end;

    if Query.FieldByName('EXPIRES_AT').AsDateTime < Now then
    begin
      SendPublicError('Token ist abgelaufen.', 401);
      Exit;
    end;

    if (Query.FieldByName('SINGLE_USE').AsInteger = 1)
       and not Query.FieldByName('USED_AT').IsNull then
    begin
      SendPublicError('Token wurde bereits verwendet.', 401);
      Exit;
    end;

    // Bindung an genau einen Vorgangstyp - verhindert, dass ein Token fuer
    // z.B. GEBUCHT einen Adress-Endpunkt oeffnet.
    if not SameText(Trim(Query.FieldByName('REFERENCE_TYPE').AsString),
                    AExpectedRefType)
    or not SameText(Trim(Query.FieldByName('PURPOSE').AsString),
                    AExpectedPurpose) then
    begin
      SendPublicError('Token gehoert nicht zu diesem Vorgang.', 403);
      Exit;
    end;

    ATokenId     := Query.FieldByName('ID').AsInteger;
    AReferenceId := Query.FieldByName('REFERENCE_ID').AsInteger;
    ARecipient   := Trim(Query.FieldByName('RECIPIENT_EMAIL').AsString);
    Result       := True;

    // Bewusst KEIN Setzen von USED_AT hier: die Seite braucht den Token zum
    // Laden UND zum Speichern, und ein Mail-Scanner darf ihn nicht durch
    // blosses Aufrufen verbrennen. Zeitlich begrenzt wird er ueber
    // EXPIRES_AT, beendet wird er ueber CloseToken - also erst, wenn ein
    // Mensch "fertig" sagt.
    //
    // Folge: SINGLE_USE wird fuer diese Tokens nie wirksam. Die Pruefung
    // oben bleibt trotzdem stehen, falls doch einmal ein Endpunkt USED_AT
    // ohne REVOKED setzt.
  finally
    Query.Close;
  end;
end;

procedure TDataModulPublic.CloseToken(ATokenId: Integer);
begin
  Query.Close;
  Query.SQL.Text :=
    'UPDATE ACCESS_TOKENS ' +
    'SET REVOKED = 1, USED_AT = CURRENT_TIMESTAMP, USED_FROM_IP = :ip ' +
    'WHERE ID = :id AND REVOKED = 0';

  // Hinter dem PHP-Proxy ist das die Adresse des Servers, nicht die des
  // Gastes - der Zeitstempel ist hier die verlaessliche Angabe, nicht die IP.
  Query.ParamByName('ip').AsString  := Copy(Trim(Request.RemoteAddr), 1, 45);
  Query.ParamByName('id').AsInteger := ATokenId;

  Connection.StartTransaction;
  try
    Query.ExecSQL;
    Connection.Commit;
  except
    if Connection.InTransaction then
      Connection.Rollback;
    raise;
  end;
  Query.Close;
end;

procedure TDataModulPublic.SendRecordByKey(const ATable: string;
  const AAllowed: array of string; const AKeyField: string;
  AKeyValue: Integer; AExtra: TJSONObject);
var
  FieldList: string;
  I:         Integer;
  Fld:       TField;
  Pair:      TJSONPair;
  Data, Ergebnis: TJSONObject;
begin
  try
    FieldList := '';
    for I := Low(AAllowed) to High(AAllowed) do
    begin
      if FieldList <> '' then
        FieldList := FieldList + ',';
      FieldList := FieldList + LowerCase(AAllowed[I]);
    end;

    Query.Close;
    Query.SQL.Text := 'SELECT ' + FieldList + ' FROM ' + ATable +
                      ' WHERE ' + LowerCase(AKeyField) + ' = :keyvalue';
    Query.ParamByName('keyvalue').AsInteger := AKeyValue;
    Query.Open;

    if Query.IsEmpty then
    begin
      SendPublicError('Datensatz nicht gefunden.', 404);
      Exit;
    end;

    Data := TJSONObject.Create;
    for I := 0 to Query.Fields.Count - 1 do
    begin
      Fld := Query.Fields[I];
      if Fld.IsNull then
        Data.AddPair(LowerCase(Fld.FieldName), TJSONNull.Create)
      else
        case Fld.DataType of
          ftInteger, ftSmallint, ftLargeint, ftWord:
            Data.AddPair(LowerCase(Fld.FieldName),
                         TJSONNumber.Create(Fld.AsInteger));
          ftFloat, ftCurrency, ftBCD, ftFMTBcd:
            Data.AddPair(LowerCase(Fld.FieldName),
                         TJSONNumber.Create(Fld.AsFloat));
          ftBoolean:
            Data.AddPair(LowerCase(Fld.FieldName),
                         TJSONBool.Create(Fld.AsBoolean));
          ftFixedChar:
            Data.AddPair(LowerCase(Fld.FieldName), Trim(Fld.AsString));
        else
          Data.AddPair(LowerCase(Fld.FieldName), Fld.AsString);
        end;
    end;

    // Zusatzfelder hineinmischen (Ownership geht dabei an Data ueber)
    if Assigned(AExtra) then
      while AExtra.Count > 0 do
      begin
        Pair := AExtra.RemovePair(AExtra.Pairs[0].JsonString.Value);
        Data.AddPair(Pair);
      end;

    Ergebnis := TJSONObject.Create;
    Ergebnis.AddPair('status', 'OK');
    Ergebnis.AddPair('data',   Data);   // Ownership geht an Ergebnis ueber
    SendJson(Ergebnis);
  finally
    Query.Close;
    if Assigned(AExtra) then
      AExtra.Free;   // leer, falls oben ausgeraeumt - sonst bei fruehem Exit
  end;
end;

procedure TDataModulPublic.UpdateRecordByKey(const ATable: string;
  const AAllowed: array of string; const AKeyField: string;
  AKeyValue: Integer);
var
  SetClause: string;
  Felder:    TArray<string>;
  Feld:      string;
  I:         Integer;
  Obj:       TJSONObject;
begin
  SetClause := '';
  SetLength(Felder, 0);

  for I := Low(AAllowed) to High(AAllowed) do
  begin
    Feld := LowerCase(AAllowed[I]);
    if SameText(Feld, AKeyField) then
      Continue;                     // Schluessel wird nie geschrieben
    if not isKeyInBody(Feld) then
      Continue;                     // nimmt auch explizites null mit
    if SetClause <> '' then
      SetClause := SetClause + ',';
    SetClause := SetClause + Feld + '=:' + Feld;
    Felder    := Felder + [Feld];
  end;

  if SetClause = '' then
  begin
    SendPublicError('Keine gueltigen Felder uebergeben.', 400);
    Exit;
  end;

  Query.Close;
  Query.SQL.Text := 'UPDATE ' + ATable + ' SET ' + SetClause +
                    ' WHERE ' + LowerCase(AKeyField) + ' = :keyvalue';

  for I := Low(Felder) to High(Felder) do
    if isParamFromBody(Felder[I]) then
      Query.ParamByName(Felder[I]).AsString := getParamFromBody(Felder[I])
    else
      Query.ParamByName(Felder[I]).Clear;   // im Body stand explizit null

  // Schluessel kommt ausschliesslich aus dem Token, nie aus dem Body.
  Query.ParamByName('keyvalue').AsInteger := AKeyValue;

  Connection.StartTransaction;
  try
    Query.ExecSQL;
    Connection.Commit;
  except
    if Connection.InTransaction then
      Connection.Rollback;
    raise;
  end;
  Query.Close;

  Obj := TJSONObject.Create;
  Obj.AddPair('status', 'OK');
  SendJson(Obj);
end;

// Route: /public/getadresse  |  Auth: false  |  LocalOnly: false
// Body:  { "token": "..." }   oder   ?token=...
procedure TDataModulPublic.getAdresseByToken;
const
  ALLOWED: array[0..9] of string = (
    'kennziffer','anrede','titel','name1','name2',
    'strasse','plz','ort','telefon1','email'
  );
var
  Kennziffer, TokenId: Integer;
  Mail:                string;
  Extra:               TJSONObject;
begin
  if not ValidatePublicToken('ADRESSEN', 'einladung', Kennziffer, Mail, TokenId) then
    Exit;

  Extra := TJSONObject.Create;
  Extra.AddPair('recipient_email', Mail);
  SendRecordByKey('ADRESSEN', ALLOWED, 'kennziffer', Kennziffer, Extra);
end;

// Route: /public/updateadresse  |  Auth: false  |  LocalOnly: false
// Body:  { "token": "...", "name2": "...", "ort": "...", ... }
procedure TDataModulPublic.updateAdresseByToken;
const
  // Bewusst OHNE 'gruppe': die interne Kategorisierung gehoert nicht in
  // Gasthand. Deshalb NICHT die ALLOWED-Liste aus DataModulAdressenClass
  // wiederverwenden.
  ALLOWED: array[0..8] of string = (
    'anrede','titel','name1','name2',
    'strasse','plz','ort','telefon1','email'
  );
var
  Kennziffer, TokenId: Integer;
  Mail:                string;
begin
  if not ValidatePublicToken('ADRESSEN', 'einladung', Kennziffer, Mail, TokenId) then
    Exit;

  UpdateRecordByKey('ADRESSEN', ALLOWED, 'kennziffer', Kennziffer);
end;

// Route: /public/adresse/abschliessen  |  Auth: false  |  LocalOnly: false
// Body:  { "token": "..." }
//
// "Ich bin fertig": der Gast erklaert seinen Vorgang fuer beendet, der Link
// ist danach unbrauchbar. Bewusst ein eigener Aufruf und kein Nebeneffekt des
// Speicherns - solange der Gast nicht abschliesst, darf er beliebig oft
// speichern. Das ist der Fall, den eine Seite mit "Speichern nach Blur"
// braucht und den SINGLE_USE unmoeglich machen wuerde.
//
// Nur ein POST kommt hier an: ein Mail-Scanner ruft Links auf, aber er
// drueckt keinen Knopf.
procedure TDataModulPublic.abschliessenByToken;
var
  Kennziffer, TokenId: Integer;
  Mail:                string;
  Obj:                 TJSONObject;
begin
  if not ValidatePublicToken('ADRESSEN', 'einladung', Kennziffer, Mail, TokenId) then
    Exit;

  CloseToken(TokenId);

  Obj := TJSONObject.Create;
  Obj.AddPair('status', 'OK');
  SendJson(Obj);
end;


// ═══════════════════════════════════════════════════════════════════════════
//  Neues Passwort setzen
//
//  Dasselbe Muster wie die Adress-Seite, nur mit anderem PURPOSE und anderer
//  Tabelle: zwei duenne Handler, dieselbe Token-Pruefung. Kein Sonderweg.
//
//  Der Token traegt PURPOSE='passwort' und REFERENCE_TYPE='REGISTRIERUNG',
//  REFERENCE_ID ist REGISTRIERUNG.NR. Weil ValidatePublicToken BEIDES
//  vergleicht, kann eine Adress-Einladung diese Endpunkte nicht oeffnen.
//
//  Der bcrypt-Hash entsteht in PHP (password_hash) - Delphi hat kein bcrypt,
//  und der Login prueft ihn schon heute ueber PHP (password_verify). Delphi
//  bekommt also den fertigen Hash und schreibt ihn, ohne ihn zu deuten.
// ═══════════════════════════════════════════════════════════════════════════

// Route: /public/setpasswort  |  Auth: false  |  LocalOnly: false
// Body:  { "token": "...", "pwd2": "<bcrypt-Hash aus PHP>" }
//
// Schreibt PWD2 und schliesst den Token danach ab. Beim Passwort ist "fertig"
// nicht verhandelbar, deshalb wird hier nicht gefragt - CloseToken laeuft
// automatisch. Das passiert auf einem POST, also ausserhalb der Reichweite
// von Mail-Scannern.
procedure TDataModulPublic.setPasswortByToken;
var
  Nr, TokenId: Integer;
  Mail, Pwd2:  string;
  Obj:         TJSONObject;
begin
  if not ValidatePublicToken('REGISTRIERUNG', 'passwort', Nr, Mail, TokenId) then
    Exit;

  Pwd2 := Trim(getParamFromBody('pwd2'));

  // PWD2 wird FEST verdrahtet geschrieben - bewusst NICHT ueber
  // UpdateRecordByKey mit einer Feldliste aus dem Body. Die ALLOWED-Liste
  // aus DataModulRegistrierungClass enthaelt neben PWD2 auch GESPERRT,
  // VERSUCHE, ZEITSPERRE, TYP und HAUPTREGISTRIERUNG: mit ihr koennte sich
  // ein Gast selbst entsperren oder seinen Benutzertyp aendern.
  //
  // Plausibilitaet des Hashes: ein Hash aus password_hash() beginnt immer
  // mit '$' (Algorithmus-Kennung) und ist deutlich laenger als 20 Zeichen.
  // Der Test nagelt kein Verfahren fest - er verhindert nur, dass durch
  // einen Fehler auf der Aufruferseite Klartext in PWD2 landet.
  if (Length(Pwd2) < 20) or (Copy(Pwd2, 1, 1) <> '$') then
  begin
    SendPublicError('pwd2 ist kein gueltiger Passwort-Hash.', 400);
    Exit;
  end;

  Query.Close;
  Query.SQL.Text := 'UPDATE REGISTRIERUNG SET PWD2 = :pwd2 WHERE NR = :nr';
  Query.ParamByName('pwd2').AsString := Pwd2;
  Query.ParamByName('nr').AsInteger  := Nr;

  Connection.StartTransaction;
  try
    Query.ExecSQL;
    Connection.Commit;
  except
    if Connection.InTransaction then
      Connection.Rollback;
    raise;
  end;
  Query.Close;

  // Erst diesen Token abschliessen (setzt USED_AT, damit "vom Gast
  // abgeschlossen" erkennbar bleibt), dann alle anderen offenen
  // Passwort-Links dieses Benutzers widerrufen. Reihenfolge ist wichtig:
  // umgekehrt waere dieser Token schon REVOKED und CloseToken wuerde
  // nichts mehr treffen.
  //
  // Die drei Schritte laufen in getrennten Transaktionen. Bricht einer der
  // spaeteren ab, ist das Passwort trotzdem gesetzt und der Link stirbt
  // spaetestens an EXPIRES_AT - kein Datenverlust, kein offener Zugang.
  CloseToken(TokenId);
  RevokeOtherPasswordTokens(Nr, TokenId);

  Obj := TJSONObject.Create;
  Obj.AddPair('status', 'OK');
  SendJson(Obj);
end;

procedure TDataModulPublic.RevokeOtherPasswordTokens(AReferenceId, AKeepTokenId: Integer);
begin
  Query.Close;
  Query.SQL.Text :=
    'UPDATE ACCESS_TOKENS SET REVOKED = 1 ' +
    'WHERE REFERENCE_TYPE = ''REGISTRIERUNG'' AND PURPOSE = ''passwort'' ' +
    '  AND REFERENCE_ID = :nr AND ID <> :keep AND REVOKED = 0';
  Query.ParamByName('nr').AsInteger   := AReferenceId;
  Query.ParamByName('keep').AsInteger := AKeepTokenId;

  Connection.StartTransaction;
  try
    Query.ExecSQL;
    Connection.Commit;
  except
    if Connection.InTransaction then
      Connection.Rollback;
    raise;
  end;
  Query.Close;
end;


// ═══════════════════════════════════════════════════════════════════════════
//  Fragebogen ausfüllen
//
//  Eine Einladung ist eine Zeile in FORM_KARTEI_HISTORY (die Instanz: welche
//  Kartei, für wen, bis wann). Der Token trägt PURPOSE='formular',
//  REFERENCE_TYPE='FORM_KARTEI_HISTORY' und als REFERENCE_ID die ID dieser
//  Instanz - angelegt von PHP (EinladungController::formular).
//
//  Die Instanz kommt ausschließlich aus dem Token. Welche Felder zu ihr
//  gehören, bestimmt die Kartei der Instanz; ein Feld einer anderen Kartei
//  wird abgewiesen, bevor irgendetwas geschrieben wird.
//
//  Werte stehen in FORM_KARTEI_CONTENT.CONTENT (VARCHAR 255) als Text:
//    TXT  Text                      NUM  Zahl mit Punkt als Dezimaltrenner
//    DAT  YYYY-MM-DD                CHK  '1' / '0'
//    RDO, SEL  genau eine Option    MUL  Optionen kommagetrennt, in der
//                                        Reihenfolge der Optionsliste
//  Optionen sind die kommagetrennten Einträge aus FORM_PAT_PROPERTY.OPTIONS,
//  jeweils getrimmt, leere Einträge zählen nicht. Ein leerer Wert löscht den
//  gespeicherten Wert.
// ═══════════════════════════════════════════════════════════════════════════

type
  TFormularFeld = record
    Proptyp: string;
    Options: string;
  end;

// Optionsliste eines Feldes: getrimmt, ohne leere Einträge.
function FormularOptionen(const AOptions: string): TArray<string>;
var
  Teil: string;
begin
  Result := [];
  for Teil in AOptions.Split([',']) do
    if Trim(Teil) <> '' then
      Result := Result + [Trim(Teil)];
end;

function FormularIstOption(const AWert: string; const AOptionen: TArray<string>): Boolean;
var
  O: string;
begin
  Result := False;
  for O in AOptionen do
    if O = AWert then
      Exit(True);
end;

// Prüft einen Wert gegen den Feldtyp und liefert ihn in der gespeicherten
// Form zurück. AFehler ist ein Satz für den Gast.
function FormularWertPruefen(const AFeld: TFormularFeld; const ARoh: string;
  out ANorm, AFehler: string): Boolean;
var
  Wert, Teil, O:  string;
  Optionen:       TArray<string>;
  Gewaehlt:       TArray<string>;
  Zahl:           Double;
  J, M, T:        Integer;
  Datum:          TDateTime;
begin
  Result  := False;
  ANorm   := '';
  AFehler := '';
  Wert    := Trim(ARoh);

  if Wert = '' then
    Exit(True);                     // leer = Wert entfernen

  if Length(Wert) > 255 then
  begin
    AFehler := 'Die Eingabe ist zu lang (höchstens 255 Zeichen).';
    Exit;
  end;

  if AFeld.Proptyp = 'TXT' then
    ANorm := Wert
  else if AFeld.Proptyp = 'NUM' then
  begin
    Wert := StringReplace(Wert, ',', '.', [rfReplaceAll]);
    if not TryStrToFloat(Wert, Zahl, TFormatSettings.Invariant) then
    begin
      AFehler := 'Bitte eine Zahl eingeben.';
      Exit;
    end;
    ANorm := Wert;
  end
  else if AFeld.Proptyp = 'DAT' then
  begin
    if (Length(Wert) <> 10) or (Wert[5] <> '-') or (Wert[8] <> '-')
       or not TryStrToInt(Copy(Wert, 1, 4), J)
       or not TryStrToInt(Copy(Wert, 6, 2), M)
       or not TryStrToInt(Copy(Wert, 9, 2), T)
       or (J < 1) or (M < 1) or (T < 1)
       or not TryEncodeDate(Word(J), Word(M), Word(T), Datum) then
    begin
      AFehler := 'Bitte ein gültiges Datum eingeben.';
      Exit;
    end;
    ANorm := Wert;
  end
  else if AFeld.Proptyp = 'CHK' then
  begin
    if (Wert <> '1') and (Wert <> '0') then
    begin
      AFehler := 'Ungültiger Wert für ein Ankreuzfeld.';
      Exit;
    end;
    ANorm := Wert;
  end
  else if (AFeld.Proptyp = 'RDO') or (AFeld.Proptyp = 'SEL') then
  begin
    if not FormularIstOption(Wert, FormularOptionen(AFeld.Options)) then
    begin
      AFehler := 'Bitte eine der angebotenen Möglichkeiten wählen.';
      Exit;
    end;
    ANorm := Wert;
  end
  else if AFeld.Proptyp = 'MUL' then
  begin
    Optionen := FormularOptionen(AFeld.Options);
    Gewaehlt := FormularOptionen(Wert);
    for Teil in Gewaehlt do
      if not FormularIstOption(Teil, Optionen) then
      begin
        AFehler := 'Bitte nur die angebotenen Möglichkeiten wählen.';
        Exit;
      end;
    // In der Reihenfolge der Optionsliste und ohne Doppelte speichern
    for O in Optionen do
      if FormularIstOption(O, Gewaehlt) then
      begin
        if ANorm <> '' then
          ANorm := ANorm + ',';
        ANorm := ANorm + O;
      end;
  end
  else
  begin
    AFehler := 'Unbekannte Art des Feldes.';
    Exit;
  end;

  Result := True;
end;

// Route: /public/getformular  |  Auth: false  |  LocalOnly: false
// Body:  { "token": "..." }   oder   ?token=...
// Antwort: { "status": "OK", "data": { "karteiname", "beschreibung",
//            "expires", "recipient_email",
//            "empfaenger": { "anrede", "titel", "name1", "name2",
//                            "strasse", "plz", "ort" } | null,
//            "felder": [ { "property_id", "label", "proptyp", "options",
//                          "bereich", "sortierung", "content" }, ... ] } }
//
// "empfaenger" gibt es nur, wenn die Instanz an eine Adresse ging
// (REFTABLE='ADRESSEN'). Für jeden anderen Empfängertyp ist es null und die
// Seite zeigt keine Empfängerdaten an - bewusst ohne Ermittlung über andere
// Tabellen (Entscheidung vom 08.11.2026). Tabelle und Spalten stehen fest im
// Code: REFTABLE wird nur verglichen, nie als Tabellenname verwendet.
procedure TDataModulPublic.getFormularByToken;
var
  HistoryId, TokenId, KarteiId, PropId: Integer;
  RefNr:                                 Integer;
  Mail, RefTable:                        string;
  Data, Feld, Ergebnis, Empfaenger:      TJSONObject;
  Felder:                                TJSONArray;
  Gesehen:                               TList<Integer>;

  function TextOderNull(AField: TField): TJSONValue;
  begin
    if AField.IsNull then
      Result := TJSONNull.Create
    else
      Result := TJSONString.Create(AField.AsString);
  end;

  // Getrimmt (CHAR-Spalten sind mit Leerzeichen aufgefüllt), leer = null
  function GetrimmtOderNull(AField: TField): TJSONValue;
  begin
    if AField.IsNull or (Trim(AField.AsString) = '') then
      Result := TJSONNull.Create
    else
      Result := TJSONString.Create(Trim(AField.AsString));
  end;

begin
  if not ValidatePublicToken('FORM_KARTEI_HISTORY', 'formular', HistoryId, Mail, TokenId) then
    Exit;

  Data := TJSONObject.Create;
  try
    Query.Close;
    Query.SQL.Text :=
      'SELECT h.KARTEI_ID, h.EXPIRES, h.REFTABLE, h.REFNR, k.KARTEINAME, k.BESCHREIBUNG ' +
      'FROM FORM_KARTEI_HISTORY h JOIN FORM_KARTEI k ON k.ID = h.KARTEI_ID ' +
      'WHERE h.ID = :id';
    Query.ParamByName('id').AsInteger := HistoryId;
    Query.Open;
    try
      if Query.IsEmpty then
      begin
        SendPublicError('Formular nicht gefunden.', 404);
        Exit;
      end;
      KarteiId := Query.FieldByName('KARTEI_ID').AsInteger;
      Data.AddPair('karteiname',   Trim(Query.FieldByName('KARTEINAME').AsString));
      Data.AddPair('beschreibung', TextOderNull(Query.FieldByName('BESCHREIBUNG')));
      if Query.FieldByName('EXPIRES').IsNull then
        Data.AddPair('expires', TJSONNull.Create)
      else
        Data.AddPair('expires', FormatDateTime('yyyy-mm-dd hh:nn:ss',
                                               Query.FieldByName('EXPIRES').AsDateTime));
      Data.AddPair('recipient_email', Mail);
      RefTable := Trim(Query.FieldByName('REFTABLE').AsString);
      RefNr    := Query.FieldByName('REFNR').AsInteger;
    finally
      Query.Close;
    end;

    // Empfängerdaten nur für Adressen - siehe Kommentar über der Prozedur
    Empfaenger := nil;
    if SameText(RefTable, 'ADRESSEN') and (RefNr > 0) then
    begin
      Query.SQL.Text :=
        'SELECT ANREDE, TITEL, NAME1, NAME2, STRASSE, PLZ, ORT ' +
        'FROM ADRESSEN WHERE KENNZIFFER = :kz';
      Query.ParamByName('kz').AsInteger := RefNr;
      Query.Open;
      try
        if not Query.IsEmpty then
        begin
          Empfaenger := TJSONObject.Create;
          Empfaenger.AddPair('anrede',  GetrimmtOderNull(Query.FieldByName('ANREDE')));
          Empfaenger.AddPair('titel',   GetrimmtOderNull(Query.FieldByName('TITEL')));
          Empfaenger.AddPair('name1',   GetrimmtOderNull(Query.FieldByName('NAME1')));
          Empfaenger.AddPair('name2',   GetrimmtOderNull(Query.FieldByName('NAME2')));
          Empfaenger.AddPair('strasse', GetrimmtOderNull(Query.FieldByName('STRASSE')));
          Empfaenger.AddPair('plz',     GetrimmtOderNull(Query.FieldByName('PLZ')));
          Empfaenger.AddPair('ort',     GetrimmtOderNull(Query.FieldByName('ORT')));
        end;
      finally
        Query.Close;
      end;
    end;
    if Assigned(Empfaenger) then
      Data.AddPair('empfaenger', Empfaenger)   // Ownership geht an Data über
    else
      Data.AddPair('empfaenger', TJSONNull.Create);

    Felder  := TJSONArray.Create;
    Data.AddPair('felder', Felder);   // Ownership geht an Data über

    Query.SQL.Text :=
      'SELECT p.ID, p.LABEL, p.PROPTYP, p.OPTIONS, p.BEREICH, p.SORTIERUNG, c.CONTENT ' +
      'FROM FORM_PAT_PROPERTY p ' +
      'LEFT JOIN FORM_KARTEI_CONTENT c ' +
      '  ON c.KARTEI_PROPERTY_ID = p.ID AND c.KARTEI_HISTORY_ID = :hid ' +
      'WHERE p.KARTEI_ID = :kid ' +
      'ORDER BY p.SORTIERUNG, p.ID';
    Query.ParamByName('hid').AsInteger := HistoryId;
    Query.ParamByName('kid').AsInteger := KarteiId;
    Query.Open;
    Gesehen := TList<Integer>.Create;
    try
      while not Query.Eof do
      begin
        PropId := Query.FieldByName('ID').AsInteger;
        // Ohne UNIQUE-Constraint auf (KARTEI_HISTORY_ID, KARTEI_PROPERTY_ID)
        // könnte ein Feld doppelt kommen - dann gilt der erste Wert.
        if not Gesehen.Contains(PropId) then
        begin
          Gesehen.Add(PropId);
          Feld := TJSONObject.Create;
          Feld.AddPair('property_id', TJSONNumber.Create(PropId));
          Feld.AddPair('label',       Query.FieldByName('LABEL').AsString);
          Feld.AddPair('proptyp',     Trim(Query.FieldByName('PROPTYP').AsString));
          Feld.AddPair('options',     TextOderNull(Query.FieldByName('OPTIONS')));
          Feld.AddPair('bereich',     TextOderNull(Query.FieldByName('BEREICH')));
          if Query.FieldByName('SORTIERUNG').IsNull then
            Feld.AddPair('sortierung', TJSONNull.Create)
          else
            Feld.AddPair('sortierung', TJSONNumber.Create(Query.FieldByName('SORTIERUNG').AsInteger));
          Feld.AddPair('content',     TextOderNull(Query.FieldByName('CONTENT')));
          Felder.AddElement(Feld);
        end;
        Query.Next;
      end;
    finally
      Gesehen.Free;
      Query.Close;
    end;

    Ergebnis := TJSONObject.Create;
    Ergebnis.AddPair('status', 'OK');
    Ergebnis.AddPair('data',   Data);   // Ownership geht an Ergebnis über
    Data := nil;
    SendJson(Ergebnis);
  finally
    Data.Free;   // nil nach Übergabe, sonst bei frühem Exit
  end;
end;

// Route: /public/saveformular  |  Auth: false  |  LocalOnly: false
// Body:  { "token": "...", "werte": { "<property_id>": "<wert>", ... } }
//
// Es werden nur die mitgeschickten Felder geschrieben, beliebig oft. Erst
// wird ALLES geprüft, dann alles in einer Transaktion geschrieben - ein
// einzelner ungültiger Wert verhindert das Speichern ganz, damit der Gast
// nicht einen halb gespeicherten Stand bekommt.
procedure TDataModulPublic.saveFormularByToken;
var
  HistoryId, TokenId, PropId: Integer;
  Mail, Norm, Fehler:         string;
  Body:                       TJSONObject;
  WerteVal:                   TJSONValue;
  Pair:                       TJSONPair;
  Roh:                        string;
  Definitionen:               TDictionary<Integer, TFormularFeld>;
  Def:                        TFormularFeld;
  Geprueft:                   TList<TPair<Integer, string>>;
  Eintrag:                    TPair<Integer, string>;
  Obj:                        TJSONObject;
begin
  if not ValidatePublicToken('FORM_KARTEI_HISTORY', 'formular', HistoryId, Mail, TokenId) then
    Exit;

  Body         := ParseJSONObject(Request.Content);
  Definitionen := TDictionary<Integer, TFormularFeld>.Create;
  Geprueft     := TList<TPair<Integer, string>>.Create;
  try
    WerteVal := nil;
    if Assigned(Body) then
      WerteVal := GetValueCaseInsensitive(Body, 'werte');
    if not (WerteVal is TJSONObject) then
    begin
      SendPublicError('Keine Werte übergeben.', 400);
      Exit;
    end;

    // Alle Felder der Kartei DIESER Instanz - die Instanz kommt aus dem Token
    Query.Close;
    Query.SQL.Text :=
      'SELECT p.ID, p.PROPTYP, p.OPTIONS ' +
      'FROM FORM_PAT_PROPERTY p ' +
      'JOIN FORM_KARTEI_HISTORY h ON h.KARTEI_ID = p.KARTEI_ID ' +
      'WHERE h.ID = :hid';
    Query.ParamByName('hid').AsInteger := HistoryId;
    Query.Open;
    try
      while not Query.Eof do
      begin
        Def.Proptyp := UpperCase(Trim(Query.FieldByName('PROPTYP').AsString));
        Def.Options := Query.FieldByName('OPTIONS').AsString;
        Definitionen.AddOrSetValue(Query.FieldByName('ID').AsInteger, Def);
        Query.Next;
      end;
    finally
      Query.Close;
    end;

    // 1) Alles prüfen, nichts schreiben
    for Pair in TJSONObject(WerteVal) do
    begin
      PropId := StrToIntDef(Pair.JsonString.Value, 0);
      if not Definitionen.TryGetValue(PropId, Def) then
      begin
        SendPublicError('Feld gehört nicht zu diesem Formular.', 400);
        Exit;
      end;

      if Pair.JsonValue is TJSONNull then
        Roh := ''
      else if (Pair.JsonValue is TJSONString) or (Pair.JsonValue is TJSONNumber) then
        Roh := Pair.JsonValue.Value
      else
      begin
        SendPublicError('Ungültiger Wert übergeben.', 400);
        Exit;
      end;

      if not FormularWertPruefen(Def, Roh, Norm, Fehler) then
      begin
        SendPublicError(Fehler, 400);
        Exit;
      end;
      Geprueft.Add(TPair<Integer, string>.Create(PropId, Norm));
    end;

    // 2) Alles in einer Transaktion schreiben
    Connection.StartTransaction;
    try
      for Eintrag in Geprueft do
      begin
        Query.Close;
        if Eintrag.Value = '' then
        begin
          Query.SQL.Text :=
            'DELETE FROM FORM_KARTEI_CONTENT ' +
            'WHERE KARTEI_HISTORY_ID = :hid AND KARTEI_PROPERTY_ID = :pid';
          Query.ParamByName('hid').AsInteger := HistoryId;
          Query.ParamByName('pid').AsInteger := Eintrag.Key;
          Query.ExecSQL;
          Continue;
        end;

        Query.SQL.Text :=
          'UPDATE FORM_KARTEI_CONTENT SET CONTENT = :content ' +
          'WHERE KARTEI_HISTORY_ID = :hid AND KARTEI_PROPERTY_ID = :pid';
        Query.ParamByName('content').AsString := Eintrag.Value;
        Query.ParamByName('hid').AsInteger    := HistoryId;
        Query.ParamByName('pid').AsInteger    := Eintrag.Key;
        Query.ExecSQL;

        if Query.RowsAffected = 0 then
        begin
          Query.Close;
          Query.SQL.Text :=
            'INSERT INTO FORM_KARTEI_CONTENT ' +
            '  (KARTEI_HISTORY_ID, KARTEI_PROPERTY_ID, CONTENT) ' +
            'VALUES (:hid, :pid, :content)';
          Query.ParamByName('hid').AsInteger    := HistoryId;
          Query.ParamByName('pid').AsInteger    := Eintrag.Key;
          Query.ParamByName('content').AsString := Eintrag.Value;
          Query.ExecSQL;
        end;
      end;
      Connection.Commit;
    except
      if Connection.InTransaction then
        Connection.Rollback;
      raise;
    end;
    Query.Close;

    Obj := TJSONObject.Create;
    Obj.AddPair('status', 'OK');
    SendJson(Obj);
  finally
    Geprueft.Free;
    Definitionen.Free;
    Body.Free;
  end;
end;

// Route: /public/formular/abschliessen  |  Auth: false  |  LocalOnly: false
// Body:  { "token": "..." }
//
// "Ich bin fertig": hält in FORM_KARTEI_HISTORY.RECEIVED fest, wann der Gast
// das Formular zurückgegeben hat, und schließt den Token. Danach ist der Link
// unbrauchbar. GEPRUEFT setzt später der Innendienst, nicht der Gast.
procedure TDataModulPublic.formularAbschliessenByToken;
var
  HistoryId, TokenId: Integer;
  Mail:               string;
  Obj:                TJSONObject;
begin
  if not ValidatePublicToken('FORM_KARTEI_HISTORY', 'formular', HistoryId, Mail, TokenId) then
    Exit;

  Query.Close;
  Query.SQL.Text :=
    'UPDATE FORM_KARTEI_HISTORY SET RECEIVED = CURRENT_TIMESTAMP WHERE ID = :id';
  Query.ParamByName('id').AsInteger := HistoryId;

  Connection.StartTransaction;
  try
    Query.ExecSQL;
    Connection.Commit;
  except
    if Connection.InTransaction then
      Connection.Rollback;
    raise;
  end;
  Query.Close;

  // Getrennte Transaktion wie bei setPasswortByToken: scheitert sie, ist der
  // Eingang trotzdem vermerkt, und der Link endet spätestens an EXPIRES_AT.
  CloseToken(TokenId);

  Obj := TJSONObject.Create;
  Obj.AddPair('status', 'OK');
  SendJson(Obj);
end;

end.
