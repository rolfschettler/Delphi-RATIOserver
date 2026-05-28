unit DataModulAddOnClass;

interface

uses
  Web.HTTPApp, System.DateUtils, System.Generics.Collections, System.JSON,
  System.SysUtils, System.Classes, DataModulBaseClass, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt, FireDAC.UI.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Phys, FireDAC.Phys.IB, FireDAC.Phys.IBDef, Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet, FireDAC.Comp.UI, FireDAC.VCLUI.Wait;

type
  TDataModulAddOn = class(TDataModulBaseClass)
  private

    { Private-Deklarationen }
  public
    { Public-Deklarationen }
    procedure adddemo();
    procedure readjson();
    procedure showhtml();
    procedure calculatedistance();
    procedure travelroute();
    procedure calculateroute();
    procedure KI_GetTeilnehmer();
    procedure ReadTeilnehmer();
    procedure teilnehmerformcsv();

  end;

function CreateDataModulAddOn(Request: TWebRequest; Response: TWebResponse): TObject;

implementation

uses plugin, webUtils, PHPSupport, KI_Support, System.StrUtils;

function CreateDataModulAddOn(Request: TWebRequest; Response: TWebResponse): TObject;
begin
  Result := TDataModulAddOn.Create(Request, Response);
end;

{%CLASSGROUP 'Vcl.Controls.TControl'}
{$R *.dfm}
{ TDataModulAddOn }

// Route: /adddemo  |  Auth: true  |  LocalOnly: TODO
procedure TDataModulAddOn.adddemo;
var
  Adresse: TAdresse;
  IQ: TFDQuery;
  Count: Integer;
begin
  Count := 1;
  if not TrystrToInt(Request.QueryFields.Values['count'], Count) then
    Count := 1;

  IQ := TFDQuery.Create(self);

  try
    for var I := 0 to Count do
    begin
      Adresse := GeneriereZufaelligeAdresse;
      IQ.Connection := Connection;
      IQ.SQL.Text := 'Insert into adressen (gruppe,code,anrede,name1,name2,strasse,plz,ort,email,erfasst_am,briefanrede,telefon1) values(''1'',''demo'',:anrede,:name1,:name2,:strasse,:plz,:ort,:email,:erfasst_am,:briefanrede,:telefon1)';
      with IQ do
      begin
        ParamByName('anrede').AsString := Adresse.Anrede;
        ParamByName('name1').AsString := Adresse.Vorname;
        ParamByName('name2').AsString := Adresse.Nachname;
        ParamByName('strasse').AsString := Adresse.Strasse;
        ParamByName('plz').AsString := Adresse.PLZ;
        ParamByName('ort').AsString := Adresse.Ort;
        ParamByName('email').AsString := Adresse.email;
        ParamByName('briefanrede').AsString := Adresse.briefanrede;
        ParamByName('erfasst_am').asDateTime := RecodeMillisecond(Now, 0); // Datum + Zeit Ohne Millisekunden
        ParamByName('telefon1').AsString := Adresse.Telefon;
        try
          Connection.StartTransaction;
          ExecSQL;
          Connection.Commit;
        except
          on E: Exception do
          begin
            if Connection.InTransaction then
              Connection.Rollback;
            raise;
          end;
        end;

      end;
    end;

    Response.ContentType := 'application/json';
    Response.StatusCode := 200;
    Response.Content := CreateJsonResponse('OK', 'es wurden ' + Inttostr(Count) + ' Adresse(n) zugefügt');

  finally
    IQ.Free;

  end;

end;



// Route: /ki_getteilnehmer  |  Auth: true  |  LocalOnly: TODO
procedure TDataModulAddOn.KI_GetTeilnehmer;
var
  JSONArray: TJSONArray;
  JSONObj: TJSONObject;
  KI_Token: string;
  VorgangNr, NewNr: Integer;
  QGen, QInsert, QCheck: TFDQuery;
  ImportCount, SkipCount: Integer;
  Vorname, Nachname, GeburtstagStr, Email: string;
  Geburtstag: TDateTime;
  FS: TFormatSettings;
begin
  TConfigFile.init(Request);
  KI_Token := TConfigFile.GetConfigValue('KI', 'token');

  VorgangNr := StrToIntDef(Request.QueryFields.Values['vorgangnr'], 0);
  if VorgangNr = 0 then
    raise Exception.Create('Parameter "vorgangnr" fehlt oder ist ungültig');

  JSONArray := nil;
  if Request.Files.Count = 0 then
    raise Exception.Create('Es wurde keine Datei hochgeladen');

  FS := TFormatSettings.Create;
  FS.ShortDateFormat := 'dd.mm.yyyy';
  FS.DateSeparator   := '.';

  QGen    := TFDQuery.Create(nil);
  QInsert := TFDQuery.Create(nil);
  QCheck  := TFDQuery.Create(nil);
  try
    QGen.Connection    := Connection;
    QInsert.Connection := Connection;
    QCheck.Connection  := Connection;

    QGen.SQL.Text :=
      'SELECT GEN_ID(T_TEILNEHMER_NR_GEN,1) FROM RDB$DATABASE';

    QInsert.SQL.Text :=
      'INSERT INTO T_TEILNEHMER (NR, NAME, NAME1, NAME2, GEBURTSTAG, EMAIL, VORGANGNR) ' +
      'VALUES (:NR, :NAME, :NAME1, :NAME2, :GEBURTSTAG, :EMAIL, :VORGANGNR)';

    QCheck.SQL.Text :=
      'SELECT COUNT(*) FROM T_TEILNEHMER ' +
      'WHERE VORGANGNR = :VORGANGNR AND NAME1 = :NAME1 AND NAME2 = :NAME2';

    CheckSupportedFileType(Request.Files[0].FileName);
    Request.Files[0].Stream.Position := 0;
    JSONArray := getTeilnehmer(Request.Files[0].FileName, Request.Files[0].Stream, KI_Token);

    ImportCount := 0;
    SkipCount   := 0;

    Connection.StartTransaction;
    try
      for var i := 0 to JSONArray.Count - 1 do
      begin
        JSONObj   := JSONArray.Items[i] as TJSONObject;
        Vorname   := Trim(JSONObj.GetValue<string>('vorname',   ''));
        Nachname  := Trim(JSONObj.GetValue<string>('nachname',  ''));
        GeburtstagStr := Trim(JSONObj.GetValue<string>('geburtstag', ''));
        Email     := Trim(JSONObj.GetValue<string>('email',     ''));

        // Duplikat-Prüfung: VORGANGNR + NAME1 + NAME2
        QCheck.ParamByName('VORGANGNR').AsInteger := VorgangNr;
        QCheck.ParamByName('NAME1').AsString      := Vorname;
        QCheck.ParamByName('NAME2').AsString      := Nachname;
        QCheck.Open;
        if QCheck.Fields[0].AsInteger > 0 then
        begin
          QCheck.Close;
          Inc(SkipCount);
          Continue;
        end;
        QCheck.Close;

        QGen.Open;
        NewNr := QGen.Fields[0].AsInteger;
        QGen.Close;

        QInsert.ParamByName('NR').AsInteger        := NewNr;
        QInsert.ParamByName('VORGANGNR').AsInteger := VorgangNr;
        QInsert.ParamByName('NAME').AsString       := Trim(Nachname + ' ' + Vorname);
        QInsert.ParamByName('NAME1').AsString      := Vorname;
        QInsert.ParamByName('NAME2').AsString      := Nachname;

        if (GeburtstagStr <> '??????') and TryStrToDate(GeburtstagStr, Geburtstag, FS) then
          QInsert.ParamByName('GEBURTSTAG').AsDateTime := Geburtstag
        else
          QInsert.ParamByName('GEBURTSTAG').Clear;

        if Email = '??????' then
          QInsert.ParamByName('EMAIL').Clear
        else
          QInsert.ParamByName('EMAIL').AsString := Email;

        QInsert.ExecSQL;
        Inc(ImportCount);
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

    Response.ContentType := 'application/json';
    Response.StatusCode  := 200;
    Response.Content     := Format('{"status":"OK","imported":%d,"skipped":%d}',
      [ImportCount, SkipCount]);
  finally
    JSONArray.Free;
    QGen.Free;
    QInsert.Free;
    QCheck.Free;
  end;
end;

// Route: /getjson  |  Auth: true  |  LocalOnly: TODO
procedure TDataModulAddOn.readjson;
begin
  Response.ContentType := 'application/json';
  Response.StatusCode := 200;
  Response.Content := PHP_Call('json', nil, GetAuthToken);
end;



// Route: /readteilnehmer  |  Auth: true  |  LocalOnly: TODO
procedure TDataModulAddOn.ReadTeilnehmer;
var
  Reader: TStreamReader;
  Line: string;
  Headers: TArray<string>;
  Fields: TArray<string>;
  i: Integer;
  HeaderFound: Boolean;
  IdxVorname, IdxNachname, IdxGeburtstag, IdxEmail: Integer;
  QGen, QInsert: TFDQuery;
  NewNr, VorgangNr: Integer;
  Geburtstag: TDateTime;
  ImportCount: Integer;
begin
  try
    if Request.Files.Count = 0 then
      raise Exception.Create('Es wurde keine Datei hochgeladen');

    QGen    := TFDQuery.Create(nil);
    QInsert := TFDQuery.Create(nil);
    try
      QGen.Connection    := Connection;
      QInsert.Connection := Connection;

      QInsert.SQL.Text :=
        'INSERT INTO T_TEILNEHMER (NR, NAME1, NAME2, GEBURTSTAG, EMAIL, VORGANGNR) ' +
        'VALUES (:NR, :NAME1, :NAME2, :GEBURTSTAG, :EMAIL, :VORGANGNR)';

      VorgangNr := StrToIntDef(Request.QueryFields.Values['vorgangnr'], 0);
      if VorgangNr = 0 then
        raise Exception.Create('Parameter "vorgangnr" fehlt oder ist ungültig');

      HeaderFound  := False;
      ImportCount  := 0;
      IdxVorname   := -1;
      IdxNachname  := -1;
      IdxGeburtstag := -1;
      IdxEmail     := -1;

      Request.Files[0].Stream.Position := 0;
      Reader := TStreamReader.Create(Request.Files[0].Stream, TEncoding.Default, True);
      try
        Connection.StartTransaction;
        try
          while not Reader.EndOfStream do
          begin
            Line := Trim(Reader.ReadLine);

            // Leerzeilen und Kommentarzeilen überspringen
            if (Line = '') or (Line.StartsWith('#')) then
              Continue;

            if not HeaderFound then
            begin
              // Erste gültige Zeile = Header → Spaltenindizes ermitteln
              Headers := Line.Split([';']);
              for i := 0 to High(Headers) do
              begin
                if Trim(Headers[i]) = 'Vorname'    then IdxVorname    := i;
                if Trim(Headers[i]) = 'Nachname'   then IdxNachname   := i;
                if Trim(Headers[i]) = 'Geburtstag' then IdxGeburtstag := i;
                if Trim(Headers[i]) = 'E-Mail'     then IdxEmail      := i;
              end;
              HeaderFound := True;
            end
            else
            begin
              Fields := Line.Split([';']);

              // Neuen Primärschlüssel vom Generator holen
              QGen.SQL.Text := 'SELECT GEN_ID(T_TEILNEHMER_NR_GEN,1) FROM RDB$DATABASE';
              QGen.Open;
              NewNr := QGen.Fields[0].AsInteger;
              QGen.Close;

              QInsert.ParamByName('NR').AsInteger := NewNr;

              if IdxVorname >= 0 then
                QInsert.ParamByName('NAME1').AsString := Trim(Fields[IdxVorname])
              else
                QInsert.ParamByName('NAME1').Clear;

              if IdxNachname >= 0 then
                QInsert.ParamByName('NAME2').AsString := Trim(Fields[IdxNachname])
              else
                QInsert.ParamByName('NAME2').Clear;

              if (IdxGeburtstag >= 0) and TryISO8601ToDate(Trim(Fields[IdxGeburtstag]), Geburtstag) then
                QInsert.ParamByName('GEBURTSTAG').AsDateTime := Geburtstag
              else
                QInsert.ParamByName('GEBURTSTAG').Clear;

              if IdxEmail >= 0 then
                QInsert.ParamByName('EMAIL').AsString := Trim(Fields[IdxEmail])
              else
                QInsert.ParamByName('EMAIL').Clear;

              QInsert.ParamByName('VORGANGNR').AsInteger := VorgangNr;

              QInsert.ExecSQL;
              Inc(ImportCount);
            end;
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
      finally
        Reader.Free;
      end;

      Response.ContentType := 'application/json';
      Response.StatusCode := 200;
      Response.Content := Format('{"status":"OK","imported":%d}', [ImportCount]);
    finally
      QGen.Free;
      QInsert.Free;
    end;
  finally
  end;
end;

// Route: /calculatedistance  |  Auth: true  |  LocalOnly: TODO
procedure TDataModulAddOn.calculatedistance;
var
  Params: TJSONObject;
begin
  // Beispiel JSON-Body: {"start": "88487 Mietingen","zwischenstopps": ["Baltringen", "Ochsenhausen"],"ziel": "Biberach"}
  Params := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
  if not Assigned(Params) then
    raise Exception.Create('calculatedistance: Es wurde kein gültiges JSON übergeben');
  try
    Response.ContentType := 'application/json';
    Response.StatusCode := 200;
    Response.Content := PHP_Call('calculatedistance', Params, GetAuthToken);
  finally
    Params.Free;
  end;
end;

// Route: /teilnehmerfromcsv  |  Auth: true  |  LocalOnly: TODO
procedure TDataModulAddOn.teilnehmerformcsv;
var
  Reader: TStreamReader;
  Lines: TStringList;
  Errors: TStringList;
  Line: string;
  Headers: TArray<string>;
  Fields: TArray<string>;
  NameParts: TArray<string>;
  i, RowNum, DummyInt: Integer;
  HeaderFound: Boolean;
  IdxReservierungsnr, IdxGruppe, IdxName: Integer;
  QGen, QInsert, QCheck: TFDQuery;
  NewNr, VorgangNr: Integer;
  ImportCount, SkipCount: Integer;
  ErrArray: TJSONArray;
begin
  try
    if Request.Files.Count = 0 then
      raise Exception.Create('Es wurde keine Datei hochgeladen');

    VorgangNr := StrToIntDef(Request.QueryFields.Values['vorgangnr'], 0);
    if VorgangNr = 0 then
      raise Exception.Create('Parameter "vorgangnr" fehlt oder ist ungültig');

    Lines  := TStringList.Create;
    Errors := TStringList.Create;
    try
      // Datei einlesen
      Request.Files[0].Stream.Position := 0;
      Reader := TStreamReader.Create(Request.Files[0].Stream, TEncoding.UTF8, True);
      try
        while not Reader.EndOfStream do
          Lines.Add(Reader.ReadLine);
      finally
        Reader.Free;
      end;

      // Phase 1: Format validieren
      HeaderFound        := False;
      RowNum             := 0;
      IdxReservierungsnr := -1;
      IdxGruppe          := -1;
      IdxName            := -1;

      for i := 0 to Lines.Count - 1 do
      begin
        Line := Trim(Lines[i]);
        if Line = '' then
          Continue;
        Inc(RowNum);

        if not HeaderFound then
        begin
          Headers := Line.Split([';']);
          for var j := 0 to High(Headers) do
          begin
            if Trim(Headers[j]) = 'Reservierungsnr' then IdxReservierungsnr := j;
            if Trim(Headers[j]) = 'Gruppe'          then IdxGruppe          := j;
            if Trim(Headers[j]) = 'Name'            then IdxName            := j;
          end;
          if IdxReservierungsnr = -1 then Errors.Add('Header: Spalte "Reservierungsnr" fehlt');
          if IdxGruppe          = -1 then Errors.Add('Header: Spalte "Gruppe" fehlt');
          if IdxName            = -1 then Errors.Add('Header: Spalte "Name" fehlt');
          if Errors.Count > 0 then
            Break; // ohne gültigen Header keine weiteren Prüfungen
          HeaderFound := True;
        end
        else
        begin
          Fields := Line.Split([';']);

          if Length(Fields) <> Length(Headers) then
            Errors.Add(Format('Zeile %d: %d Felder erwartet, %d gefunden',
              [RowNum, Length(Headers), Length(Fields)]))
          else
          begin
            if not TryStrToInt(Trim(Fields[IdxReservierungsnr]), DummyInt) then
              Errors.Add(Format('Zeile %d: "Reservierungsnr" ist keine gültige Zahl ("%s")',
                [RowNum, Fields[IdxReservierungsnr]]));

            if not TryStrToInt(Trim(Fields[IdxGruppe]), DummyInt) then
              Errors.Add(Format('Zeile %d: "Gruppe" ist keine gültige Zahl ("%s")',
                [RowNum, Fields[IdxGruppe]]));

            if Pos(',', Fields[IdxName]) = 0 then
              Errors.Add(Format('Zeile %d: "Name" enthält kein Komma ("%s")',
                [RowNum, Fields[IdxName]]));
          end;
        end;
      end;

      // Validierung fehlgeschlagen → Fehler zurückgeben
      if Errors.Count > 0 then
      begin
        ErrArray := TJSONArray.Create;
        try
          for var ErrMsg in Errors do
            ErrArray.Add(ErrMsg);
          Response.ContentType := 'application/json';
          Response.StatusCode  := 400;
          Response.Content     := Format('{"status":"ERROR","errors":%s}', [ErrArray.ToString]);
        finally
          ErrArray.Free;
        end;
        Exit;
      end;

      // Phase 2: DB-Import
      QGen    := TFDQuery.Create(nil);
      QInsert := TFDQuery.Create(nil);
      QCheck  := TFDQuery.Create(nil);
      try
        QGen.Connection    := Connection;
        QInsert.Connection := Connection;
        QCheck.Connection  := Connection;

        QGen.SQL.Text :=
          'SELECT GEN_ID(T_TEILNEHMER_NR_GEN,1) FROM RDB$DATABASE';

        QInsert.SQL.Text :=
          'INSERT INTO T_TEILNEHMER (NR, NAME, NAME1, NAME2, RESERVIERUNGSNR, GRUPPE, VORGANGNR) ' +
          'VALUES (:NR, :NAME, :NAME1, :NAME2, :RESERVIERUNGSNR, :GRUPPE, :VORGANGNR)';

        QCheck.SQL.Text :=
          'SELECT COUNT(*) FROM T_TEILNEHMER ' +
          'WHERE VORGANGNR = :VORGANGNR AND RESERVIERUNGSNR = :RESERVIERUNGSNR';

        ImportCount  := 0;
        SkipCount    := 0;
        HeaderFound  := False; // für Import-Phase neu verwenden

        Connection.StartTransaction;
        try
          for i := 0 to Lines.Count - 1 do
          begin
            Line := Trim(Lines[i]);
            if Line = '' then
              Continue;
            if not HeaderFound then
            begin
              HeaderFound := True; // erste nicht-leere Zeile = Header, überspringen
              Continue;
            end;

            Fields := Line.Split([';']);

            // Duplikat-Prüfung
            QCheck.ParamByName('VORGANGNR').AsInteger      := VorgangNr;
            QCheck.ParamByName('RESERVIERUNGSNR').AsString := Trim(Fields[IdxReservierungsnr]);
            QCheck.Open;
            if QCheck.Fields[0].AsInteger > 0 then
            begin
              QCheck.Close;
              Inc(SkipCount);
              Continue;
            end;
            QCheck.Close;

            QGen.Open;
            NewNr := QGen.Fields[0].AsInteger;
            QGen.Close;

            QInsert.ParamByName('NR').AsInteger            := NewNr;
            QInsert.ParamByName('VORGANGNR').AsInteger     := VorgangNr;
            QInsert.ParamByName('RESERVIERUNGSNR').AsString := Trim(Fields[IdxReservierungsnr]);
            QInsert.ParamByName('GRUPPE').AsInteger        := StrToInt(Trim(Fields[IdxGruppe]));

            NameParts := Trim(Fields[IdxName]).Split([',']);
            QInsert.ParamByName('NAME2').AsString := Trim(NameParts[0]);
            if Length(NameParts) > 1 then
            begin
              QInsert.ParamByName('NAME1').AsString := Trim(NameParts[1]);
              QInsert.ParamByName('NAME').AsString  := Trim(NameParts[0]) + ' ' + Trim(NameParts[1]);
            end
            else
            begin
              QInsert.ParamByName('NAME1').Clear;
              QInsert.ParamByName('NAME').AsString := Trim(NameParts[0]);
            end;

            QInsert.ExecSQL;
            Inc(ImportCount);
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

        Response.ContentType := 'application/json';
        Response.StatusCode  := 200;
        Response.Content     := Format('{"status":"OK","imported":%d,"skipped":%d}',
          [ImportCount, SkipCount]);
      finally
        QGen.Free;
        QInsert.Free;
        QCheck.Free;
      end;
    finally
      Lines.Free;
      Errors.Free;
    end;
  finally
  end;
end;

// Route: /travelroute  |  Auth: false  |  LocalOnly: TODO
procedure TDataModulAddOn.travelroute;
var
  Params: TJSONObject;
  beispiel:string;
begin
  // Ruft den PHP-Endpunkt /travelroute auf und liefert eine HTML-Seite mit optimierter Route (TSP).
  //
  // JSON-Parameter:
  // ---------------
  // PFLICHT:
  //   "start"          : string  – Startadresse (z.B. "88487 Mietingen")
  //   "ziel"           : string  – Zieladresse  (z.B. "Biberach")
  //
  // OPTIONAL:
  //   "zwischenstopps" : array   – Zwischenstopps, darf leer sein (z.B. ["Ochsenhausen", "Baltringen"])
  //                                Reihenfolge wird automatisch optimiert (TSP).
  //   "startzeit"      : string  – Abfahrtszeit im Format "HH:MM" (z.B. "16:00")
  //                                Default: "00:00"
  //   "haltezeit"      : integer – Haltezeit in Minuten an jedem Zwischenstopp (z.B. 3)
  //                                Default: 0
  //
  // Minimales Beispiel:
  //   {"start": "88487 Mietingen", "ziel": "Biberach"}
  //
  // Maximales Beispiel:
  //   {"startzeit": "16:00", "haltezeit": 3, "start": "88487 Mietingen",
  //    "zwischenstopps": ["Bad Saulgau", "Baltringen", "Ochsenhausen", "Bad Buchau"],
  //    "ziel": "Biberach"}

   beispiel:='{"startzeit":"10:00","haltezeit":5, "start": "Friedrichshafen","zwischenstopps": ["Bad Saulgau","Ravensburg", "Ochsenhausen","Bad Buchau"],"ziel": "Biberach"}';
   Params := TJSONObject.ParseJSONValue(beispiel) as TJSONObject;

//Opional, parameter aus Request lesen
//  Params := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;



  if not Assigned(Params) then
    raise Exception.Create('travelroute: Es wurde kein gültiges JSON übergeben');
  try
    Response.ContentType := 'text/html';
    Response.StatusCode := 200;
    Response.Content := PHP_Call('travelroute', Params, GetAuthToken);
  finally
    Params.Free;
  end;
end;


// Route: /calculateroute  |  Auth: true  |  LocalOnly: TODO
procedure TDataModulAddOn.calculateroute;
var
  Params: TJSONObject;
begin
  // Ruft den PHP-Endpunkt /calculateroute auf.
  // Gleiche Parameter wie travelroute, Antwort ist JSON (kein HTML).
  //
  // PFLICHT:
  //   "start"          : string  – Startadresse
  //   "ziel"           : string  – Zieladresse
  //
  // OPTIONAL:
  //   "zwischenstopps" : array   – Zwischenstopps (max. 8), Reihenfolge wird optimiert
  //   "startzeit"      : string  – Abfahrtszeit "HH:MM", Default: "00:00"
  //   "haltezeit"      : integer – Haltezeit in Minuten pro Stopp, Default: 0
  Params := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
  if not Assigned(Params) then
    raise Exception.Create('calculateroute: Es wurde kein gültiges JSON übergeben');
  try
    Response.ContentType := 'application/json';
    Response.StatusCode := 200;
    Response.Content := PHP_Call('calculateroute', Params, GetAuthToken);
  finally
    Params.Free;
  end;
end;


// Route: /showroute  |  Auth: false  |  LocalOnly: TODO
procedure TDataModulAddOn.showhtml;
var
  Params: TJSONObject;
begin
  Params := TJSONObject.Create;
  try
    Params.AddPair('start', Request.QueryFields.Values['start']);
    Params.AddPair('ziel', Request.QueryFields.Values['ziel']);
    Response.ContentType := 'text/html';
    Response.StatusCode := 200;
    Response.Content := PHP_Call('showroute', Params, GetAuthToken);
  finally
    Params.Free;
  end;
end;

end.
