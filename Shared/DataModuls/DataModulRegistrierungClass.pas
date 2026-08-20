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
  ALLOWED: array[0..14] of string = (
    'nr','kennziffer','pwd','username','userkonfig',
    'erstellt','geaendert','gesperrt','pwd2','versuche',
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
  ALLOWED: array[0..14] of string = (
    'nr','kennziffer','pwd','username','userkonfig',
    'erstellt','geaendert','gesperrt','pwd2','versuche',
    'zeitsperre','pushid','letzter_login','hauptregistrierung','typ'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS uebereinstimmen).
  // userkonfig (Blob) ist bewusst nicht filterbar.
  CONDITIONS: array[0..13] of string = (
    'nr = :nr',
    'kennziffer = :kennziffer',
    'pwd = :pwd',
    'username = :username',
    'erstellt = :erstellt',
    'geaendert = :geaendert',
    'gesperrt = :gesperrt',
    'pwd2 = :pwd2',
    'versuche = :versuche',
    'zeitsperre = :zeitsperre',
    'pushid = :pushid',
    'letzter_login = :letzter_login',
    'hauptregistrierung = :hauptregistrierung',
    'typ = :typ'
  );
  FILTER_PARAMS: array[0..13] of string = (
    'nr','kennziffer','pwd','username',
    'erstellt','geaendert','gesperrt','pwd2','versuche',
    'zeitsperre','pushid','letzter_login','hauptregistrierung','typ'
  );
begin
  DoSelectFilteredDynamic('REGISTRIERUNG', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /registrierung/getregistrierungbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulRegistrierung.getRegistrierungById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..14] of string = (
    'nr','kennziffer','pwd','username','userkonfig',
    'erstellt','geaendert','gesperrt','pwd2','versuche',
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
// Body: { "username": "...", "pwd2": "...",
//         "anrede": "Herr", "name1": "Mustermann", "name2": "Max",
//         "strasse": "...", "plz": "...", "ort": "...", "telefon1": "...",
//         "email": "...", "kennziffer": 12345 }
//
// Schreibt REGISTRIERUNG und ADRESSEN in EINER Transaktion.
// anrede, name1 und name2 sind Pflichtfelder; ADRESSEN.gruppe ist immer 1.
// Ist eine kennziffer angegeben, wird die Adresse ueber kennziffer + name1 +
// name2 gesucht (nativ, lowercase und uppercase). Bei einem Treffer wird diese
// Kennziffer als Fremdschluessel in REGISTRIERUNG eingetragen und die Adresse
// bleibt unveraendert; ohne Treffer wird eine neue Adresse angelegt.
const
  ALLOWED: array[0..1] of string = (
    'username','pwd2');
  ADR_ALLOWED: array[0..7] of string = (
    'anrede','name1','name2','strasse','plz','ort','telefon1','email');
var
  Q:            TFDQuery;
  Cols, Vals:   string;
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
  Anrede := Trim(getParamFromBody('anrede'));
  Name1  := Trim(getParamFromBody('name1'));
  Name2  := Trim(getParamFromBody('name2'));

  if (Anrede = '') or (Name1 = '') or (Name2 = '') then
    raise Exception.Create('Die Felder anrede, name1 und name2 sind Pflichtfelder.');

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
  AdresseNeu     := True;

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
      if SuchKennziffer > 0 then
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
        end;
        Q.Close;
      end;

      // 2. Kein Treffer -> neue Kennziffer ziehen (gleicher Generator wie der
      //    Insert-Trigger TI_ADRESSEN verwendet)
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
      //    Trigger TIA_ADRESSEN_REGISTRIERUNG keine zweite Registrierung anlegt
      Cols := 'nr,kennziffer';
      Vals := ':nr,:kennziffer';
      for i := Low(ALLOWED) to High(ALLOWED) do
        if isParamFromBody(ALLOWED[i]) then
        begin
          Cols := Cols + ',' + ALLOWED[i];
          Vals := Vals + ',:' + ALLOWED[i];
        end;

      Q.SQL.Text := 'INSERT INTO REGISTRIERUNG (' + Cols + ') VALUES (' + Vals + ')';
      Q.ParamByName('nr').AsInteger         := RegNr;
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
  Res.AddPair('kennziffer', TJSONNumber.Create(Kennziffer));
  if AdresseNeu then
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
// Vergleich case-insensitiv per UPPER (LOWER() kennt InterBase hier nicht).
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
