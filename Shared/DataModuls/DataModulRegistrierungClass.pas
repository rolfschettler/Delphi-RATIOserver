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
    procedure getUsers;
    procedure getUsersFiltered;
    procedure getUsersById;
  end;


function CreateDataModulRegistrierung(Request: TWebRequest; Response: TWebResponse): TObject;

implementation
uses webutils;

// Setzt die drei Parameter zu webUtils.CaseInsCondition mit demselben Praefix.
// Die Funktion steht hier und nicht in webUtils, weil sie TFDQuery braucht --
// webUtils wird auch von Units ohne FireDAC verwendet (router, uJWTUtils,
// PHPSupport, KI_Support). Erlaeuterung des Vergleichsmusters: siehe webUtils.
procedure SetCaseInsParams(AQuery: TFDQuery; const APrefix, AValue: string);
begin
  AQuery.ParamByName(APrefix + '_asc').AsString   := UpperCaseAscii(AValue);
  AQuery.ParamByName(APrefix + '_asclo').AsString := UpperCaseAscii(ToLowerUni(AValue));
  AQuery.ParamByName(APrefix + '_ascup').AsString := UpperCaseAscii(ToUpperUni(AValue));
end;

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
  ALLOWED: array[0..16] of string = (
    'nr','kennziffer','username','userkonfig',
    'erstellt','geaendert','gesperrt','versuche',
    'zeitsperre','pushid','letzter_login','hauptregistrierung','typ','rollen','email',
    'personalzeichen','usersloginname'
  );
begin
  DoSelect('REGISTRIERUNG', ALLOWED);
end;

// Route: /registrierung/getregistrierungfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulRegistrierung.getRegistrierungFiltered;
// Body: { "fields": [...] | "*", "nr": 1, "kennziffer": 42, "username": "...", ..., "orderby": "nr" }
// Alle Filter-Parameter sind optional - nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
const
  ALLOWED: array[0..16] of string = (
    'nr','kennziffer','username','userkonfig',
    'erstellt','geaendert','gesperrt','versuche',
    'zeitsperre','pushid','letzter_login','hauptregistrierung','typ','rollen','email',
    'personalzeichen','usersloginname'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS uebereinstimmen).
  // userkonfig (Blob) ist bewusst nicht filterbar.
  CONDITIONS: array[0..14] of string = (
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
    'typ = :typ',
    'email = :email',
    'personalzeichen = :personalzeichen',
    'usersloginname = :usersloginname'
  );
  FILTER_PARAMS: array[0..14] of string = (
    'nr','kennziffer','username',
    'erstellt','geaendert','gesperrt','versuche',
    'zeitsperre','pushid','letzter_login','hauptregistrierung','typ','email',
    'personalzeichen','usersloginname'
  );
begin
  DoSelectFilteredDynamic('REGISTRIERUNG', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /registrierung/getregistrierungbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulRegistrierung.getRegistrierungById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..16] of string = (
    'nr','kennziffer','username','userkonfig',
    'erstellt','geaendert','gesperrt','versuche',
    'zeitsperre','pushid','letzter_login','hauptregistrierung','typ','rollen','email',
    'personalzeichen','usersloginname'
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
  ALLOWED: array[0..16] of string = (
    'kennziffer','pwd','username','userkonfig',
    'erstellt','geaendert','gesperrt','pwd2','versuche',
    'zeitsperre','pushid','letzter_login','hauptregistrierung','typ','email',
    'personalzeichen','usersloginname'
  );
var
  Username, Typ: string;
  Q: TFDQuery;
begin
  DoInsert('REGISTRIERUNG', ALLOWED);

  // Rollen-Blaupause passend zum typ zuweisen (kunde -> @KUNDE usw.), wie in
  // insertRegistrierungLocal. DoInsert ist generisch, daher als UPDATE danach.
  // Nicht bei Blaupausen selbst (username mit '@') und nicht ohne typ.
  Username := Trim(getParamFromBody('username'));
  Typ      := Trim(getParamFromBody('typ'));
  if (Username = '') or (Typ = '') or Username.StartsWith('@') then
    exit;

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := Connection;
    // username umlautsicher und case-insensitiv vergleichen -- siehe
    // CaseInsCondition in webUtils.
    Q.SQL.Text := 'UPDATE REGISTRIERUNG SET rollen = :rollen' +
                  ' WHERE ' + CaseInsCondition('username', 'username') +
                  '   AND rollen IS NULL';
    Q.ParamByName('rollen').AsString := '@' + UpperCase(Typ);
    SetCaseInsParams(Q, 'username', Username);
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

// Route: /registrierung/insertregistrierunglocal  |  Auth: false  |  LocalOnly: true
procedure TDataModulRegistrierung.insertRegistrierungLocal;
// Body: { "username": "...", "pwd2": "...", "typ": "kunde|mitarbeiter|fahrer",
//         "anrede": "Herr", "name1": "Mustermann", "name2": "Max",
//         "strasse": "...", "plz": "...", "ort": "...", "telefon1": "...",
//         "email": "...", "kennziffer": 12345, "usersloginname": "...",
//         "personalzeichen": "..." }
//
// usersloginname -- Verknuepfung zum USERS-Satz (typ=mitarbeiter). Ein
//   USERS-Loginname darf nur EINEN Portalzugang haben: ist er bereits in
//   REGISTRIERUNG.usersloginname eingetragen, wird mit HTTP 409 abgelehnt
//   (Vergleich case-insensitiv). Gespeichert wird immer in Grossschreibung.
//
// personalzeichen -- Verknuepfung zum PERSONALSTAMM-Satz (typ=fahrer). Wie
//   usersloginname: hoechstens EIN Portalzugang je Kurzzeichen (HTTP 409),
//   Vergleich case-insensitiv, gespeichert in Grossschreibung. Nur bei
//   typ=fahrer zulaessig; Altbestand-Fahrer (personalzeichen NULL,
//   username = Kuerzel) gelten ebenfalls als belegt.
//
// Gueltige Typen sind ausschliesslich kunde, mitarbeiter und fahrer
// (Vergleich case-insensitiv); jeder andere sowie ein fehlender typ wird
// abgewiesen.
//
// typ=kunde -- Adresse anlegen bzw. verknuepfen:
//   Schreibt REGISTRIERUNG und ADRESSEN in EINER Transaktion.
//   anrede, name1 und name2 sind Pflichtfelder; ADRESSEN.gruppe ist immer 1.
//   Ist eine kennziffer angegeben, wird die Adresse ueber kennziffer + name1 +
//   name2 gesucht (nativ, lowercase und uppercase). Bei einem Treffer wird diese
//   Kennziffer als Fremdschluessel in REGISTRIERUNG eingetragen und die Adresse
//   bleibt unveraendert; ohne Treffer wird eine neue Adresse angelegt.
//
// typ=fahrer -- Abgleich mit dem PERSONALSTAMM:
//   personalzeichen, name1 (Vorname), name2 (Nachname) und username sind
//   Pflichtfelder. personalzeichen wird vor der Pruefung auf Grossschreibung
//   gesetzt und muss zusammen mit name1/name2 einem Satz in PERSONALSTAMM
//   entsprechen (personalzeichen = PERSONALSTAMM.zeichen, name1 = name1,
//   name2 = name2). Ohne Treffer: 'Benutzer ist nicht im Personalstamm vorhanden.'
//   username ist frei gewaehlt und wird unveraendert gespeichert (seit
//   2026-10-25; Altbestand hat personalzeichen NULL und username = Kuerzel).
//
// Rollen: REGISTRIERUNG.rollen wird automatisch auf die Blaupause des typs
//   gesetzt (kunde -> @KUNDE, fahrer -> @FAHRER, mitarbeiter -> @MITARBEITER).
//   Benutzernamen mit '@' am Anfang sind fuer Blaupausen reserviert.
//
// typ=mitarbeiter und typ=fahrer legen KEINE Adresse an und verknuepfen keine:
//   REGISTRIERUNG.kennziffer bleibt NULL, die Antwort liefert
//   "kennziffer": null und "adresse": "keine".
//
// Sperre: typ=mitarbeiter und typ=fahrer werden mit gesperrt='JA' angelegt
//   und muessen erst freigeschaltet werden (Login lehnt 'JA' ab). Der Wert
//   wird fest gesetzt und nie aus dem Body uebernommen. typ=kunde bleibt
//   offen (gesperrt NULL).
const
  ALLOWED: array[0..6] of string = (
    'username','pwd2','typ','userkonfig','email','usersloginname',
    'personalzeichen');
  ADR_ALLOWED: array[0..7] of string = (
    'anrede','name1','name2','strasse','plz','ort','telefon1','email');
var
  Q:            TFDQuery;
  Cols, Vals:   string;
  Typ:          string;
  IstKunde:     Boolean;
  IstFahrer:    Boolean;
  Anrede:       string;
  Name1, Name2: string;
  Username:     string;
  UsersLogin:   string;
  PersZeichen:  string;
  SuchKennziffer: Integer;
  Kennziffer:   Integer;
  RegNr:        Integer;
  AdresseNeu:   Boolean;
  Res:          TJSONObject;
  i:            Integer;
  BodyCheck:    TJSONObject;
begin
  // Ein ungueltiger JSON-Body wuerde sonst als fehlender typ gemeldet:
  // ParseJSONObject liefert dann nil und jedes getParamFromBody seinen Default.
  BodyCheck := ParseJSONObject(Request.Content);
  try
    if not Assigned(BodyCheck) then
      raise Exception.Create('Der Request-Body enthaelt kein gueltiges JSON-Objekt.');
  finally
    BodyCheck.Free;
  end;

  Typ       := Trim(getParamFromBody('typ'));
  IstKunde  := SameText(Typ, 'kunde');
  IstFahrer := SameText(Typ, 'fahrer');

  // In diesem Endpunkt sind nur kunde, mitarbeiter und fahrer zugelassen.
  if not (IstKunde or IstFahrer or SameText(Typ, 'mitarbeiter')) then
    raise Exception.Create('Ungueltiger typ. Erlaubt sind kunde, mitarbeiter und fahrer.');

  Anrede := Trim(getParamFromBody('anrede'));
  Name1  := Trim(getParamFromBody('name1'));
  Name2  := Trim(getParamFromBody('name2'));

  // anrede, name1 und name2 braucht nur typ=kunde -- nur dort wird ueberhaupt
  // eine Adresse angelegt bzw. verknuepft.
  if IstKunde and ((Anrede = '') or (Name1 = '') or (Name2 = '')) then
    raise Exception.Create('Die Felder anrede, name1 und name2 sind bei typ=kunde Pflichtfelder.');

  Username := Trim(getParamFromBody('username'));

  // '@' am Anfang ist fuer Rollen-Blaupausen reserviert (z.B. '@FAHRER').
  if Username.StartsWith('@') then
    raise Exception.Create('Der Benutzername darf nicht mit @ beginnen.');

  // Kurzzeichen des Personalstamms immer in Grossschreibung -- so steht es im
  // PERSONALSTAMM und so wird es in REGISTRIERUNG gespeichert.
  // ToUpperUni statt UpperCase: letzteres laesst Umlaute klein.
  PersZeichen := ToUpperUni(Trim(getParamFromBody('personalzeichen')));

  // personalzeichen nur bei typ=fahrer -- nur dort wird es gegen den
  // PERSONALSTAMM geprueft; sonst koennte jeder ein fremdes Kurzzeichen belegen.
  if (PersZeichen <> '') and not IstFahrer then
    raise Exception.Create('Das Feld personalzeichen ist nur bei typ=fahrer zulaessig.');
  // REGISTRIERUNG.personalzeichen ist CHAR(15) -- vorab pruefen statt
  // InterBase-Fehler "string truncation" durchzureichen.
  if Length(PersZeichen) > 15 then
    raise Exception.Create('Das Feld personalzeichen darf hoechstens 15 Zeichen lang sein.');

  // typ=fahrer: Identitaetsnachweis ueber den PERSONALSTAMM. Der Benutzername
  // ist frei gewaehlt und bleibt unveraendert.
  if IstFahrer then
  begin
    if (PersZeichen = '') or (Name1 = '') or (Name2 = '') or (Username = '') then
      raise Exception.Create('Die Felder personalzeichen, name1, name2 und username sind bei typ=fahrer Pflichtfelder.');

    // Abgleich mit dem PERSONALSTAMM: personalzeichen = zeichen,
    // name1 = Vorname, name2 = Nachname. Alle drei umlautsicher vergleichen --
    // siehe CaseInsCondition in webUtils.
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := Connection;
      Q.SQL.Text := 'SELECT nr FROM PERSONALSTAMM' +
                    ' WHERE ' + CaseInsCondition('zeichen', 'zeichen') +
                    '   AND ' + CaseInsCondition('name1', 'name1') +
                    '   AND ' + CaseInsCondition('name2', 'name2');
      SetCaseInsParams(Q, 'zeichen', PersZeichen);
      SetCaseInsParams(Q, 'name1', Name1);
      SetCaseInsParams(Q, 'name2', Name2);
      Q.Open;
      if Q.IsEmpty then
        raise Exception.Create('Benutzer ist nicht im Personalstamm vorhanden.');
    finally
      Q.Free;
    end;
  end;

  // Dublettensperre: gleicher Login darf nicht zweimal registriert werden.
  // Vergleich case-insensitiv und umlautsicher -- siehe CaseInsCondition am
  // in webUtils.
  // ACHTUNG: Diese Pruefung allein ist nicht race-sicher; wasserdicht wird die
  // Sperre erst mit einem UNIQUE-Index auf REGISTRIERUNG.USERNAME.
  if Username <> '' then
  begin
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := Connection;
      Q.SQL.Text := 'SELECT nr FROM REGISTRIERUNG WHERE ' + CaseInsCondition('username', 'username');
      SetCaseInsParams(Q, 'username', Username);
      Q.Open;
      if not Q.IsEmpty then
      begin
        Res := TJSONObject.Create;
        try
          Res.AddPair('status', 'error');
          Res.AddPair('message', 'Der Benutzername ist bereits registriert.');
          Res.AddPair('username', Username);
          Res.AddPair('nr', TJSONNumber.Create(Q.FieldByName('nr').AsInteger));
        except
          Res.Free;
          raise;
        end;
        SendJson(Res, 409);
        Exit;
      end;
    finally
      Q.Free;
    end;
  end;

  // Ein USERS-Loginname bekommt hoechstens einen Portalzugang. Gespeichert
  // wird er immer in Grossschreibung (ToUpperUni -- laesst Umlaute nicht klein).
  UsersLogin := ToUpperUni(Trim(getParamFromBody('usersloginname')));
  // REGISTRIERUNG.usersloginname ist CHAR(20) -- siehe personalzeichen oben.
  if Length(UsersLogin) > 20 then
    raise Exception.Create('Das Feld usersloginname darf hoechstens 20 Zeichen lang sein.');
  if UsersLogin <> '' then
  begin
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := Connection;
      Q.SQL.Text := 'SELECT nr FROM REGISTRIERUNG WHERE ' + CaseInsCondition('usersloginname', 'usersloginname');
      SetCaseInsParams(Q, 'usersloginname', UsersLogin);
      Q.Open;
      if not Q.IsEmpty then
      begin
        Res := TJSONObject.Create;
        try
          Res.AddPair('status', 'error');
          Res.AddPair('message', 'Für diesen Ratio-Loginnamen ist bereits ein Portalzugang angelegt.');
          Res.AddPair('nr', TJSONNumber.Create(Q.FieldByName('nr').AsInteger));
        except
          Res.Free;
          raise;
        end;
        SendJson(Res, 409);
        Exit;
      end;
    finally
      Q.Free;
    end;
  end;

  // Ein Kurzzeichen des Personalstamms bekommt hoechstens einen Portalzugang.
  // Altbestand-Fahrer haben personalzeichen NULL und das Kuerzel als username
  // -- die zaehlen ebenfalls als belegt.
  if PersZeichen <> '' then
  begin
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := Connection;
      Q.SQL.Text := 'SELECT nr FROM REGISTRIERUNG WHERE ' + CaseInsCondition('personalzeichen', 'personalzeichen') +
                    ' OR (personalzeichen IS NULL AND UPPER(typ) = ''FAHRER'' AND ' +
                    CaseInsCondition('username', 'altzeichen') + ')';
      SetCaseInsParams(Q, 'personalzeichen', PersZeichen);
      SetCaseInsParams(Q, 'altzeichen', PersZeichen);
      Q.Open;
      if not Q.IsEmpty then
      begin
        Res := TJSONObject.Create;
        try
          Res.AddPair('status', 'error');
          Res.AddPair('message', 'Für dieses Kurzzeichen des Personalstamms ist bereits ein Portalzugang angelegt.');
          Res.AddPair('nr', TJSONNumber.Create(Q.FieldByName('nr').AsInteger));
        except
          Res.Free;
          raise;
        end;
        SendJson(Res, 409);
        Exit;
      end;
    finally
      Q.Free;
    end;
  end;

  SuchKennziffer := StrToIntDef(getParamFromBody('kennziffer', '0'), 0);
  Kennziffer     := 0;
  // Nur typ=kunde bekommt ueberhaupt eine Adresse; bei mitarbeiter und fahrer
  // bleiben Adresssuche und Adress-Insert aus und kennziffer bleibt NULL.
  AdresseNeu     := IstKunde;

  Connection.StartTransaction;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := Connection;

      // 1. Adresse suchen, wenn eine Kennziffer uebergeben wurde.
      //    Namensvergleich case-insensitiv und umlautsicher -- siehe
      //    CaseInsCondition in webUtils.
      if IstKunde and (SuchKennziffer > 0) then
      begin
        Q.SQL.Text := 'SELECT kennziffer FROM ADRESSEN' +
                      ' WHERE kennziffer = :kennziffer' +
                      '   AND ' + CaseInsCondition('name1', 'name1') +
                      '   AND ' + CaseInsCondition('name2', 'name2');
        Q.ParamByName('kennziffer').AsInteger := SuchKennziffer;
        SetCaseInsParams(Q, 'name1', Name1);
        SetCaseInsParams(Q, 'name2', Name2);
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
      // Rollen-Blaupause passend zum typ zuweisen: kunde -> @KUNDE usw.
      Cols := Cols + ',rollen';
      Vals := Vals + ',:rollen';
      // mitarbeiter und fahrer starten gesperrt -- freigeschaltet wird in der
      // Registrierungsverwaltung. gesperrt steht bewusst NICHT in ALLOWED:
      // der Wert kommt nie aus dem Request.
      if not IstKunde then
      begin
        Cols := Cols + ',gesperrt';
        Vals := Vals + ',:gesperrt';
      end;

      Q.SQL.Text := 'INSERT INTO REGISTRIERUNG (' + Cols + ') VALUES (' + Vals + ')';
      Q.ParamByName('nr').AsInteger := RegNr;
      Q.ParamByName('rollen').AsString := '@' + UpperCase(Typ);
      if not IstKunde then
        Q.ParamByName('gesperrt').AsString := 'JA';
      if Kennziffer > 0 then
        Q.ParamByName('kennziffer').AsInteger := Kennziffer;
      for i := Low(ALLOWED) to High(ALLOWED) do
        if isParamFromBody(ALLOWED[i]) then
          Q.ParamByName(ALLOWED[i]).Value := getParamFromBody(ALLOWED[i]);
      // usersloginname und personalzeichen immer in Grossschreibung
      // speichern (siehe oben)
      // leere Werte als NULL speichern -- NULL heisst "nicht verknuepft",
      // beim personalzeichen kennzeichnet NULL zudem den Altbestand
      if isParamFromBody('usersloginname') then
        if UsersLogin <> '' then
          Q.ParamByName('usersloginname').AsString := UsersLogin
        else
          Q.ParamByName('usersloginname').Clear;
      if isParamFromBody('personalzeichen') then
        if PersZeichen <> '' then
          Q.ParamByName('personalzeichen').AsString := PersZeichen
        else
          Q.ParamByName('personalzeichen').Clear;
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
// Vergleich auf REGISTRIERUNG.username case-insensitiv und umlautsicher --
// siehe CaseInsCondition in webUtils.
var
  Q:        TFDQuery;
  Username: string;
  Frei:     Boolean;
  Res:      TJSONObject;
  BodyCheck: TJSONObject;
begin
  // Ungueltiges JSON nicht als fehlenden username melden (siehe insertRegistrierungLocal)
  BodyCheck := ParseJSONObject(Request.Content);
  try
    if not Assigned(BodyCheck) then
      raise Exception.Create('Der Request-Body enthaelt kein gueltiges JSON-Objekt.');
  finally
    BodyCheck.Free;
  end;

  Username := Trim(getParamFromBody('username'));
  if Username = '' then
    raise Exception.Create('Das Feld username ist ein Pflichtfeld.');

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := Connection;
    Q.SQL.Text := 'SELECT nr FROM REGISTRIERUNG WHERE ' + CaseInsCondition('username', 'username');
    SetCaseInsParams(Q, 'username', Username);
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
// Vergleich auf USERS.loginname case-insensitiv und umlautsicher -- siehe
// CaseInsCondition in webUtils.
// Ist gesperrt leer bzw. NULL, wird 'NEIN' geliefert.
var
  Q:         TFDQuery;
  Loginname: string;
  Gesperrt:  string;
  Res:       TJSONObject;
  BodyCheck: TJSONObject;
begin
  // Ungueltiges JSON nicht als fehlenden loginname melden (siehe oben)
  BodyCheck := ParseJSONObject(Request.Content);
  try
    if not Assigned(BodyCheck) then
      raise Exception.Create('Der Request-Body enthaelt kein gueltiges JSON-Objekt.');
  finally
    BodyCheck.Free;
  end;

  Loginname := Trim(getParamFromBody('loginname'));
  if Loginname = '' then
    raise Exception.Create('Das Feld loginname ist ein Pflichtfeld.');

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := Connection;
    Q.SQL.Text := 'SELECT passwort, gesperrt FROM USERS' +
                  ' WHERE ' + CaseInsCondition('loginname', 'loginname');
    SetCaseInsParams(Q, 'loginname', Loginname);
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
  ALLOWED: array[0..17] of string = (
    'kennziffer','pwd','username','userkonfig',
    'erstellt','geaendert','gesperrt','pwd2','versuche',
    'zeitsperre','pushid','letzter_login','hauptregistrierung','typ','email','rollen',
    'personalzeichen','usersloginname'
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

// Route: /registrierung/getusers  |  Auth: true  |  LocalOnly: false
procedure TDataModulRegistrierung.getUsers;
// Body: { "fields": ["loginname","username",...] | "*", "orderby": "loginname" }
// passwort bewusst nicht in ALLOWED (nicht lesbar).
const
  ALLOWED: array[0..11] of string = (
    'loginname','username','rechte','gruppe','zugruppe','agenturcode',
    'kennziffer','filiale','abteilung','gesperrt','pushid','mandant'
  );
begin
  DoSelect('USERS', ALLOWED);
end;

// Route: /registrierung/getusersfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulRegistrierung.getUsersFiltered;
// Body: { "fields": [...] | "*", "loginname": "...", "username": "...", "gruppe": "...",
//         "zugruppe": "...", "agenturcode": "...", "kennziffer": 1, "filiale": "...",
//         "abteilung": "...", "gesperrt": "...", "pushid": "...", "mandant": "...",
//         "orderby": "loginname" }
// Alle Filter-Parameter sind optional – nur im Body vorhandene Parameter werden als WHERE-Bedingung eingesetzt.
// passwort bewusst weder lesbar noch filterbar; rechte (Blob) nur lesbar, nicht filterbar.
const
  ALLOWED: array[0..11] of string = (
    'loginname','username','rechte','gruppe','zugruppe','agenturcode',
    'kennziffer','filiale','abteilung','gesperrt','pushid','mandant'
  );
  // Eine Bedingung pro Parameter (Index muss mit FILTER_PARAMS übereinstimmen).
  CONDITIONS: array[0..10] of string = (
    'loginname = :loginname',
    'username = :username',
    'gruppe = :gruppe',
    'zugruppe = :zugruppe',
    'agenturcode = :agenturcode',
    'kennziffer = :kennziffer',
    'filiale = :filiale',
    'abteilung = :abteilung',
    'gesperrt = :gesperrt',
    'pushid = :pushid',
    'mandant = :mandant'
  );
  FILTER_PARAMS: array[0..10] of string = (
    'loginname','username','gruppe','zugruppe','agenturcode',
    'kennziffer','filiale','abteilung','gesperrt','pushid','mandant'
  );
begin
  DoSelectFilteredDynamic('USERS', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /registrierung/getusersbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulRegistrierung.getUsersById;
// Body: { "loginname": "...", "fields": [...] | "*" }
// passwort bewusst nicht in ALLOWED (nicht lesbar).
const
  ALLOWED: array[0..11] of string = (
    'loginname','username','rechte','gruppe','zugruppe','agenturcode',
    'kennziffer','filiale','abteilung','gesperrt','pushid','mandant'
  );
begin
  DoSelectOne('USERS', ALLOWED, 'loginname');
end;

end.
