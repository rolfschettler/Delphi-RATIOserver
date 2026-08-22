unit DataModulRegistrierungClass;

interface

uses
  Web.HTTPApp,   System.JSON,
  DataModulTableBaseClass,
  System.SysUtils, System.Classes, DataModulBaseClass, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt, FireDAC.UI.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Phys, FireDAC.Phys.IB, FireDAC.Phys.IBDef, FireDAC.VCLUI.Wait, Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet;

type
  TDataModulRegistrierung = class(TDataModulTableBase)
  private

    { Private-Deklarationen }
  public
    { Public-Deklarationen }
    procedure getRegistrierung;
    procedure getRegistrierungFiltered;
    procedure getRegistrierungById;
    procedure getRegistrierungKey;
    procedure insertRegistrierung;
    procedure insertRegistrierungLocal;
    procedure checkUsernameLocal;
    procedure getUserLocal;
    procedure updateRegistrierung;
    procedure deleteRegistrierung;
  end;


function CreateDataModulRegistrierung(Request: TWebRequest; Response: TWebResponse): TObject;

implementation
uses webutils;

function CreateDataModulRegistrierung(Request: TWebRequest; Response: TWebResponse): TObject;
begin
  Result := TDataModulRegistrierung.Create(Request, Response);
end;

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}

{ TDataModulRegistrierung }

// Route: /registrierung/getregistrierung  |  Auth: true  |  LocalOnly: false
procedure TDataModulRegistrierung.getRegistrierung;
// Body: { "fields": ["nr","kennziffer",...] | "*", "orderby": "nr" }
const
  ALLOWED: array[0..12] of string = (
    'nr','kennziffer','username','userkonfig',
    'erstellt','geaendert','gesperrt','versuche',
    'zeitsperre','pushid','letzter_login','hauptregistrierung','typ'
  );
begin
  DoSelect('REGISTRIERUNG', ALLOWED);
end;

// Route: /registrierung/getregistrierungfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulRegistrierung.getRegistrierungFiltered;
// Body: { "fields": [...] | "*", "nr": 1, "kennziffer": 42, "username": "...", ..., "orderby": "nr" }
// Alle Filter-Parameter sind optional - nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..12] of string = (
    'nr','kennziffer','username','userkonfig',
    'erstellt','geaendert','gesperrt','versuche',
    'zeitsperre','pushid','letzter_login','hauptregistrierung','typ'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS uebereinstimmen).
  // userkonfig (Blob) ist bewusst nicht filterbar.
  CONDITIONS: array[0..11] of string = (
    'nr = :nr',
    'kennziffer = :kennziffer',
    'username = :username',
    'erstellt = :erstellt',
    'geaendert = :geaendert',
    'gesperrt = :gesperrt',
    'versuche = :versuche',
    'zeitsperre = :zeitsperre',
    'pushid = :pushid',
    'letzter_login = :letzter_login',
    'hauptregistrierung = :hauptregistrierung',
    'typ = :typ'
  );
  FILTER_PARAMS: array[0..11] of string = (
    'nr','kennziffer','username',
    'erstellt','geaendert','gesperrt','versuche',
    'zeitsperre','pushid','letzter_login','hauptregistrierung','typ'
  );
begin
  DoSelectFilteredDynamic('REGISTRIERUNG', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /registrierung/getregistrierungbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulRegistrierung.getRegistrierungById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..12] of string = (
    'nr','kennziffer','username','userkonfig',
    'erstellt','geaendert','gesperrt','versuche',
    'zeitsperre','pushid','letzter_login','hauptregistrierung','typ'
  );
begin
  DoSelectOne('REGISTRIERUNG', ALLOWED, 'nr');
end;

// Route: /registrierung/getregistrierungkey  |  Auth: true  |  LocalOnly: false
procedure TDataModulRegistrierung.getRegistrierungKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(REGISTRIERUNG_NR_GEN, 1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /registrierung/insertregistrierung  |  Auth: true  |  LocalOnly: false
procedure TDataModulRegistrierung.insertRegistrierung;
// Body: { "kennziffer": 42, "username": "...", ... }
const
  ALLOWED: array[0..13] of string = (
    'kennziffer','pwd','username','userkonfig',
    'erstellt','geaendert','gesperrt','pwd2','versuche',
    'zeitsperre','pushid','letzter_login','hauptregistrierung','typ'
  );
begin
  DoInsert('REGISTRIERUNG', ALLOWED);
end;

// Route: /registrierung/insertregistrierunglocal  |  Auth: false  |  LocalOnly: true
procedure TDataModulRegistrierung.insertRegistrierungLocal;
// Body: { "username": "...", "pwd2": "...", "typ": "kunde",
//         "anrede": "Herr", "name1": "Mustermann", "name2": "Max",
//         "strasse": "...", "plz": "...", "ort": "...", "telefon1": "...",
//         "email": "...", "kennziffer": 12345 }
//
// Adressbehandlung ausschliesslich bei typ=kunde (Vergleich case-insensitiv):
//   Schreibt REGISTRIERUNG und ADRESSEN in EINER Transaktion.
//   anrede, name1 und name2 sind dann Pflichtfelder; ADRESSEN.gruppe ist immer 1.
//   Ist eine kennziffer angegeben, wird die Adresse ueber kennziffer + name1 +
//   name2 gesucht (nativ, lowercase und uppercase). Bei einem Treffer wird diese
//   Kennziffer als Fremdschluessel in REGISTRIERUNG eingetragen und die Adresse
//   bleibt unveraendert; ohne Treffer wird eine neue Adresse angelegt.
//
// Bei jedem anderen typ (z.B. mitarbeiter) und bei fehlendem typ wird KEINE
// Adresse angelegt oder verknuepft: anrede, name1 und name2 sind nicht
// erforderlich und werden ignoriert, REGISTRIERUNG.kennziffer bleibt NULL.
// Die Antwort liefert dann "kennziffer": null und "adresse": "keine".
const
  ALLOWED: array[0..2] of string = (
    'username','pwd2','typ');
  ADR_ALLOWED: array[0..7] of string = (
    'anrede','name1','name2','strasse','plz','ort','telefon1','email');
var
  Q:            TFDQuery;
  Cols, Vals:   string;
  Typ:          string;
  IstKunde:     Boolean;
  Anrede:       string;
  Name1, Name2: string;
  Username:     string;
  SuchKennziffer: Integer;
  Kennziffer:   Integer;
  RegNr:        Integer;
  AdresseNeu:   Boolean;
  Res:          TJSONObject;
  i:            Integer;
begin
  Typ      := Trim(getParamFromBody('typ'));
  IstKunde := SameText(Typ, 'kunde');

  Anrede := Trim(getParamFromBody('anrede'));
  Name1  := Trim(getParamFromBody('name1'));
  Name2  := Trim(getParamFromBody('name2'));

  // anrede, name1 und name2 braucht nur typ=kunde -- nur dort wird ueberhaupt
  // eine Adresse angelegt bzw. verknuepft.
  if IstKunde and ((Anrede = '') or (Name1 = '') or (Name2 = '')) then
    raise Exception.Create('Die Felder anrede, name1 und name2 sind bei typ=kunde Pflichtfelder.');

  Username := Trim(getParamFromBody('username'));

  // Dublettensperre: gleicher Login darf nicht zweimal registriert werden.
  // Vergleich case-insensitiv per UPPER -- genau wie der Trigger
  // TIA_ADRESSEN_REGISTRIERUNG prueft (LOWER() kennt InterBase hier nicht).
  // ACHTUNG: Diese Pruefung allein ist nicht race-sicher; wasserdicht wird die
  // Sperre erst mit einem UNIQUE-Index auf REGISTRIERUNG.USERNAME.
  if Username <> '' then
  begin
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := Connection;
      Q.SQL.Text := 'SELECT nr FROM REGISTRIERUNG WHERE UPPER(username) = :username_up';
      Q.ParamByName('username_up').AsString := UpperCase(Username);
      Q.Open;
      if not Q.IsEmpty then
      begin
        Res := TJSONObject.Create;
        Res.AddPair('status', 'error');
        Res.AddPair('message', 'Der Benutzername ist bereits registriert.');
        Res.AddPair('username', Username);
        Res.AddPair('nr', TJSONNumber.Create(Q.FieldByName('nr').AsInteger));
        SendJson(Res, 409);
        Exit;
      end;
    finally
      Q.Free;
    end;
  end;

  SuchKennziffer := StrToIntDef(getParamFromBody('kennziffer', '0'), 0);
  Kennziffer     := 0;
  // Nur typ=kunde bekommt ueberhaupt eine Adresse; bei allen anderen Typen
  // bleiben Adresssuche und Adress-Insert aus und kennziffer bleibt NULL.
  AdresseNeu     := IstKunde;

  Connection.StartTransaction;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := Connection;

      // 1. Adresse suchen, wenn eine Kennziffer uebergeben wurde.
      //    Namensvergleich in drei Varianten: nativ (Original gegen Original),
      //    lowercase (komplett kleingeschriebener Feldinhalt) und uppercase
      //    (beide Seiten per UPPER normalisiert -- der eigentliche
      //    case-insensitive Vergleich). LOWER() kennt InterBase hier nicht.
      if IstKunde and (SuchKennziffer > 0) then
      begin
        Q.SQL.Text := 'SELECT kennziffer FROM ADRESSEN' +
                      ' WHERE kennziffer = :kennziffer' +
                      '   AND (name1 = :name1 OR name1 = :name1_lo OR UPPER(name1) = :name1_up)' +
                      '   AND (name2 = :name2 OR name2 = :name2_lo OR UPPER(name2) = :name2_up)';
        Q.ParamByName('kennziffer').AsInteger := SuchKennziffer;
        Q.ParamByName('name1').AsString       := Name1;
        Q.ParamByName('name1_lo').AsString    := LowerCase(Name1);
        Q.ParamByName('name1_up').AsString    := UpperCase(Name1);
        Q.ParamByName('name2').AsString       := Name2;
        Q.ParamByName('name2_lo').AsString    := LowerCase(Name2);
        Q.ParamByName('name2_up').AsString    := UpperCase(Name2);
        Q.Open;
        if not Q.IsEmpty then
        begin
          Kennziffer := Q.FieldByName('kennziffer').AsInteger;
          AdresseNeu := False;
        end
        else
          raise Exception.Create('Diese Kennziffer existiert nicht für diesen Namen.');

        Q.Close;
      end;

      // 2. Kein Treffer -> neue Kennziffer ziehen (gleicher Generator wie der
      //    Insert-Trigger TI_ADRESSEN verwendet). AdresseNeu ist nur bei
      //    typ=kunde gesetzt.
      if AdresseNeu then
      begin
        Q.SQL.Text := 'SELECT kennziffer FROM ADRESSEN_NEXTKENNZIFFER';
        Q.Open;
        Kennziffer := Q.FieldByName('kennziffer').AsInteger;
        Q.Close;
      end;

      // 3. Registrierungs-Nr ziehen (Trigger TI_REGISTRIERUNG setzt nur, wenn NULL)
      Q.SQL.Text := 'SELECT GEN_ID(REGISTRIERUNG_NR_GEN, 1) AS nr FROM RDB$DATABASE';
      Q.Open;
      RegNr := Q.FieldByName('nr').AsInteger;
      Q.Close;

      // 4. Registrierung schreiben -- bewusst VOR der Adresse, damit der
      //    Trigger TIA_ADRESSEN_REGISTRIERUNG keine zweite Registrierung anlegt.
      //    kennziffer nur schreiben, wenn eine Adresse verknuepft wird.
      Cols := 'nr';
      Vals := ':nr';
      if Kennziffer > 0 then
      begin
        Cols := Cols + ',kennziffer';
        Vals := Vals + ',:kennziffer';
      end;
      for i := Low(ALLOWED) to High(ALLOWED) do
        if isParamFromBody(ALLOWED[i]) then
        begin
          Cols := Cols + ',' + ALLOWED[i];
          Vals := Vals + ',:' + ALLOWED[i];
        end;

      Q.SQL.Text := 'INSERT INTO REGISTRIERUNG (' + Cols + ') VALUES (' + Vals + ')';
      Q.ParamByName('nr').AsInteger := RegNr;
      if Kennziffer > 0 then
        Q.ParamByName('kennziffer').AsInteger := Kennziffer;
      for i := Low(ALLOWED) to High(ALLOWED) do
        if isParamFromBody(ALLOWED[i]) then
          Q.ParamByName(ALLOWED[i]).Value := getParamFromBody(ALLOWED[i]);
      Q.ExecSQL;

      // 5. Adresse nur anlegen, wenn keine gefunden wurde; gruppe ist immer 1
      if AdresseNeu then
      begin
        Cols := 'kennziffer,gruppe';
        Vals := ':kennziffer,:gruppe';
        for i := Low(ADR_ALLOWED) to High(ADR_ALLOWED) do
          if isParamFromBody(ADR_ALLOWED[i]) then
          begin
            Cols := Cols + ',' + ADR_ALLOWED[i];
            Vals := Vals + ',:' + ADR_ALLOWED[i];
          end;

        Q.SQL.Text := 'INSERT INTO ADRESSEN (' + Cols + ') VALUES (' + Vals + ')';
        Q.ParamByName('kennziffer').AsInteger := Kennziffer;
        Q.ParamByName('gruppe').AsInteger     := 1;
        for i := Low(ADR_ALLOWED) to High(ADR_ALLOWED) do
          if isParamFromBody(ADR_ALLOWED[i]) then
            Q.ParamByName(ADR_ALLOWED[i]).Value := getParamFromBody(ADR_ALLOWED[i]);
        Q.ExecSQL;
      end;
    finally
      Q.Free;
    end;
    Connection.Commit;
  except
    on E: Exception do
    begin
      if Connection.InTransaction then
        Connection.Rollback;
      raise;
    end;
  end;

  Res := TJSONObject.Create;
  Res.AddPair('status', 'OK');
  Res.AddPair('nr', TJSONNumber.Create(RegNr));
  Res.AddPair('kennziffer', JsonOrNull(Kennziffer > 0, Kennziffer));
  if not IstKunde then
    Res.AddPair('adresse', 'keine')
  else if AdresseNeu then
    Res.AddPair('adresse', 'neu')
  else
    Res.AddPair('adresse', 'gefunden');
  SendJson(Res);
end;

// Route: /registrierung/checkusernamelocal  |  Auth: false  |  LocalOnly: true
procedure TDataModulRegistrierung.checkUsernameLocal;
// Body: { "username": "..." }
// Prueft, ob ein Benutzername noch frei ist -- fuer die Formularpruefung der
// aufrufenden Seite, bevor insertRegistrierungLocal aufgerufen wird.
// Antwort frei:   { "status": "OK",    "username": "...", "frei": true,
//                   "nr": null }
// Antwort belegt:  { "status": "error", "username": "...", "frei": false,
//                   "message": "...", "nr": <vorhandene nr> }
// Vergleich auf USERS.loginname case-insensitiv per UPPER (LOWER() kennt InterBase hier nicht).
var
  Q:        TFDQuery;
  Username: string;
  Frei:     Boolean;
  Res:      TJSONObject;
begin
  Username := Trim(getParamFromBody('username'));
  if Username = '' then
    raise Exception.Create('Das Feld username ist ein Pflichtfeld.');

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := Connection;
    Q.SQL.Text := 'SELECT nr FROM REGISTRIERUNG WHERE UPPER(username) = :username_up';
    Q.ParamByName('username_up').AsString := UpperCase(Username);
    Q.Open;

    Frei := Q.IsEmpty;

    Res := TJSONObject.Create;
    if Frei then
      Res.AddPair('status', 'OK')
    else
      Res.AddPair('status', 'error');
    Res.AddPair('username', Username);
    Res.AddPair('frei', TJSONBool.Create(Frei));
    if Frei then
      Res.AddPair('nr', TJSONNull.Create)
    else
    begin
      Res.AddPair('message', 'Der Benutzername ist bereits registriert.');
      Res.AddPair('nr', TJSONNumber.Create(Q.FieldByName('nr').AsInteger));
    end;
    SendJson(Res);
  finally
    Q.Free;
  end;
end;

// Route: /users/getuserlocal  |  Auth: false  |  LocalOnly: true
procedure TDataModulRegistrierung.getUserLocal;
// Body: { "loginname": "ABL" }
// Liefert das codierte Passwort (USERS.passwort, XOR-Codierung aus rechtelib.pas)
// und den Sperrstatus zu einem Loginnamen. Nur fuer lokale Aufrufer (LocalOnly),
// damit die Passwortpruefung dort per DeCodieren erfolgen kann.
// Antwort Treffer:   { "status": "OK", "passwort": "<codiert>", "gesperrt": "NEIN" }
// Antwort unbekannt: { "status": "error", "gefunden": false }
// Vergleich auf USERS.loginname case-insensitiv per UPPER (LOWER() kennt InterBase hier nicht).
// Ist gesperrt leer bzw. NULL, wird 'NEIN' geliefert.
var
  Q:         TFDQuery;
  Loginname: string;
  Gesperrt:  string;
  Res:       TJSONObject;
begin
  Loginname := Trim(getParamFromBody('loginname'));
  if Loginname = '' then
    raise Exception.Create('Das Feld loginname ist ein Pflichtfeld.');

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := Connection;
    Q.SQL.Text := 'SELECT passwort, gesperrt FROM USERS' +
                  ' WHERE UPPER(loginname) = :loginname_up';
    Q.ParamByName('loginname_up').AsString := UpperCase(Loginname);
    Q.Open;

    Res := TJSONObject.Create;
    if Q.IsEmpty then
    begin
      Res.AddPair('status', 'error');
      Res.AddPair('gefunden', TJSONBool.Create(False));
    end
    else
    begin
      Gesperrt := Trim(Q.FieldByName('gesperrt').AsString);
      if Gesperrt = '' then
        Gesperrt := 'NEIN';
      Res.AddPair('status', 'OK');
      Res.AddPair('passwort', Trim(Q.FieldByName('passwort').AsString));
      Res.AddPair('gesperrt', Gesperrt);
    end;
    SendJson(Res);
  finally
    Q.Free;
  end;
end;

// Route: /registrierung/updateregistrierung  |  Auth: true  |  LocalOnly: false
procedure TDataModulRegistrierung.updateRegistrierung;
// Body: { "nr": 42, "username": "...", ... }
const
  ALLOWED: array[0..13] of string = (
    'kennziffer','pwd','username','userkonfig',
    'erstellt','geaendert','gesperrt','pwd2','versuche',
    'zeitsperre','pushid','letzter_login','hauptregistrierung','typ'
  );
begin
  DoUpdate('REGISTRIERUNG', ALLOWED, 'nr');
end;

// Route: /registrierung/deleteregistrierung  |  Auth: true  |  LocalOnly: false
procedure TDataModulRegistrierung.deleteRegistrierung;
// Body: { "nr": 42 }
begin
  DoDelete('REGISTRIERUNG', 'nr');
end;

end.
