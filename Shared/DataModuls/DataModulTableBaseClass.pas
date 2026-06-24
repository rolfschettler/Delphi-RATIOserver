unit DataModulTableBaseClass;

interface

uses
  Web.HTTPApp, System.JSON, System.Generics.Collections,
  System.SysUtils, System.Classes, DataModulBaseClass,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param,
  FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf,
  FireDAC.Stan.Async, FireDAC.DApt, FireDAC.UI.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Phys, FireDAC.Phys.IB,
  FireDAC.Phys.IBDef, FireDAC.VCLUI.Wait, Data.DB,
  FireDAC.Comp.Client, FireDAC.Comp.DataSet;

type
  TDataModulTableBase = class(TDataModulBaseClass)
  private
    procedure ExecWrite(Q: TFDQuery);
    function ParseFieldList(Body: TJSONObject;
      const AAllowed: array of string): string;
    procedure ReadPagination(Body: TJSONObject; out ALimit, AOffset: Integer);
    function BuildPagedResponse(Q: TFDQuery; const ACountSQL: string;
      ACountParams: TDictionary<string, string>;
      ALimit, AOffset: Integer): string;

  protected
    function IsAllowed(const Field: string;
      const Whitelist: array of string): Boolean;

    // SELECT, joinedSql: ein parameterisierter Join
    // Body: { "<param1>": "wert1", ..., }
    procedure DoJoinedSelect(const joinedSql: string;
      const AFilterParams: array of string);

    // SELECT mit optionaler WHERE-Klausel und Server-seitigen Parametern.
    // Body: { "fields": ["f1","f2"] | "*", "orderby": "f1",
    //         "limit": 10, "offset": 0 }
    // Pagination: InterBase ROWS x TO y Syntax.
    // limit=0 -> alle Datensaetze, kein ROWS-Zusatz.
    procedure DoSelect(const ATable: string;
      const AAllowed: array of string;
      const AWhere: string = '';
      AParams: TDictionary<string, string> = nil);

    // SELECT WHERE AKeyField = :key -- Key-Wert kommt aus dem Body.
    // Body: { "<keyfield>": <value>, "fields": [...] }
    procedure DoSelectOne(const ATable: string;
      const AAllowed: array of string;
      const AKeyField: string);

    // INSERT -- alle Body-Felder die in AAllowed stehen werden eingefuegt.
    // Body: { "feld1": "wert1", "feld2": "wert2", ... }
    procedure DoInsert(const ATable: string;
      const AAllowed: array of string);

    // UPDATE WHERE AKeyField = :key -- Body-Felder aus AAllowed werden aktualisiert.
    // Body: { "<keyfield>": <value>, "feld1": "wert1", ... }
    procedure DoUpdate(const ATable: string;
      const AAllowed: array of string;
      const AKeyField: string);

    // DELETE WHERE AKeyField = :key -- Key-Wert kommt aus dem Body.
    // Body: { "<keyfield>": <value> }
    procedure DoDelete(const ATable: string; const AKeyField: string);

    // SELECT mit festem WHERE-SQL im Controller, Parameterwerte kommen aus dem Body.
    // Body: { "fields": [...] | "*", "<param1>": "wert1", ..., "orderby": "f1",
    //         "limit": 10, "offset": 0 }
    // Pagination: InterBase ROWS x TO y Syntax.
    // limit=0 -> alle Datensaetze, kein ROWS-Zusatz.
    procedure DoSelectFiltered(const ATable: string;
      const AAllowed: array of string;
      const AFilter: string;
      const AFilterParams: array of string);
  end;

function CreateDataModulTableBase(Request: TWebRequest;
  Response: TWebResponse): TObject;

implementation

uses webutils;

function CreateDataModulTableBase(Request: TWebRequest;
  Response: TWebResponse): TObject;
begin
  Result := TDataModulTableBase.Create(Request, Response);
end;

{%CLASSGROUP 'Vcl.Controls.TControl'}
{$R *.dfm}

{ TDataModulTableBase }

procedure TDataModulTableBase.ReadPagination(Body: TJSONObject;
  out ALimit, AOffset: Integer);
var
  V: TJSONValue;
begin
  ALimit  := 0;
  AOffset := 0;
  if not Assigned(Body) then Exit;
  V := Body.GetValue('limit');
  if Assigned(V) and not V.Null then ALimit  := StrToIntDef(V.Value, 0);
  V := Body.GetValue('offset');
  if Assigned(V) and not V.Null then AOffset := StrToIntDef(V.Value, 0);
end;

function TDataModulTableBase.BuildPagedResponse(Q: TFDQuery;
  const ACountSQL: string; ACountParams: TDictionary<string, string>;
  ALimit, AOffset: Integer): string;
var
  QCount:   TFDQuery;
  Total:    Integer;
  ParamKey: string;
begin
  QCount := TFDQuery.Create(nil);
  try
    QCount.Connection := Connection;
    QCount.SQL.Text   := ACountSQL;
    if Assigned(ACountParams) then
      for ParamKey in ACountParams.Keys do
        QCount.ParamByName(ParamKey).AsString := ACountParams[ParamKey];
    QCount.Open;
    Total := QCount.Fields[0].AsInteger;
  finally
    QCount.Free;
  end;

  Result := Format('{"total":%d,"limit":%d,"offset":%d,"data":%s}',
    [Total, ALimit, AOffset, SerializeQuery(Q)]);
end;

function TDataModulTableBase.IsAllowed(const Field: string;
  const Whitelist: array of string): Boolean;
var
  W: string;
begin
  Result := False;
  for W in Whitelist do
    if SameText(W, Field) then
      Exit(True);
end;

procedure TDataModulTableBase.ExecWrite(Q: TFDQuery);
begin
  Connection.StartTransaction;
  try
    Q.ExecSQL;
    Connection.Commit;
  except
    on E: Exception do
    begin
      if Connection.InTransaction then Connection.Rollback;
      raise;
    end;
  end;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := '{"status":"OK"}';
end;

function TDataModulTableBase.ParseFieldList(Body: TJSONObject;
  const AAllowed: array of string): string;
var
  FieldsVal: TJSONValue;
  FieldsArr: TJSONArray;
  FieldList: string;
  FieldName: string;
  i:         Integer;
begin
  FieldsVal := Body.GetValue('fields');

  if (FieldsVal = nil) or
     ((FieldsVal is TJSONString) and SameText(FieldsVal.Value, '*')) then
  begin
    // Kein fields-Parameter oder '*' -- alle erlaubten Felder zurueckgeben
    FieldList := '';
    for i := 0 to High(AAllowed) do
    begin
      if FieldList <> '' then FieldList := FieldList + ', ';
      FieldList := FieldList + AAllowed[i];
    end;
  end
  else if FieldsVal is TJSONArray then
  begin
    FieldsArr := TJSONArray(FieldsVal);
    FieldList := '';
    for i := 0 to FieldsArr.Count - 1 do
    begin
      FieldName := LowerCase(FieldsArr.Items[i].Value);
      if not IsAllowed(FieldName, AAllowed) then
        raise Exception.CreateFmt('Feld "%s" ist nicht erlaubt.', [FieldName]);
      if FieldList <> '' then FieldList := FieldList + ', ';
      FieldList := FieldList + FieldName;
    end;
    if FieldList = '' then
      raise Exception.Create('Keine Felder angegeben.');
  end
  else
    raise Exception.Create('"fields" muss "*" oder ein JSON-Array sein.');

  Result := FieldList;
end;

procedure TDataModulTableBase.DoSelect(const ATable: string;
  const AAllowed: array of string; const AWhere: string;
  AParams: TDictionary<string, string>);
// Pagination: InterBase ROWS x TO y
// x = Offset + 1  (1-basiert)
// y = Offset + Limit
// Limit = 0 -> kein ROWS-Zusatz, alle Datensaetze
var
  Body:        TJSONObject;
  OrderVal:    TJSONValue;
  OrderBy:     string;
  Limit:       Integer;
  Offset:      Integer;
  RowsClause:  string;
  WhereClause: string;
  Q:           TFDQuery;
  ParamKey:    string;
begin
  Body := ParseJSONObject(Request.Content);
  if not Assigned(Body) then
    Body := TJSONObject.Create;
  try
    // Sortierung lesen und pruefen
    OrderBy  := '';
    OrderVal := Body.GetValue('orderby');
    if Assigned(OrderVal) and not OrderVal.Null then
    begin
      OrderBy := LowerCase(OrderVal.Value);
      if not IsAllowed(OrderBy, AAllowed) then
        raise Exception.CreateFmt('Sortierfeld "%s" ist nicht erlaubt.', [OrderBy]);
    end;

    // Pagination lesen
    // Limit = 0 bedeutet: alle Datensaetze, kein ROWS-Zusatz
    ReadPagination(Body, Limit, Offset);
    RowsClause := '';
    if Limit > 0 then
      RowsClause := Format(' ROWS %d TO %d', [Offset + 1, Offset + Limit]);

    // WHERE-Klausel
    WhereClause := '';
    if AWhere <> '' then
      WhereClause := ' WHERE ' + AWhere;

    // SQL aufbauen:
    // SELECT <felder> FROM <tabelle> [WHERE ...] [ORDER BY ...] [ROWS x TO y]
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := Connection;
      Q.SQL.Text   := 'SELECT ' + ParseFieldList(Body, AAllowed) +
                      ' FROM ' + ATable + WhereClause;
      if OrderBy <> '' then
        Q.SQL.Text := Q.SQL.Text + ' ORDER BY ' + OrderBy;
      if RowsClause <> '' then
        Q.SQL.Text := Q.SQL.Text + RowsClause;

      if Assigned(AParams) then
        for ParamKey in AParams.Keys do
          Q.ParamByName(ParamKey).AsString := AParams[ParamKey];

      Q.Open;
      Response.ContentType := 'application/json';
      Response.StatusCode  := 200;
      if Limit > 0 then
        Response.Content := BuildPagedResponse(Q,
          'SELECT COUNT(*) FROM ' + ATable + WhereClause,
          AParams, Limit, Offset)
      else
        Response.Content := SerializeQuery(Q);
    finally
      Q.Free;
    end;
  finally
    Body.Free;
  end;
end;

procedure TDataModulTableBase.DoJoinedSelect(const joinedSql: string;
  const AFilterParams: array of string);
var
  Q:           TFDQuery;
  CountParams: TDictionary<string, string>;
  ParamVal:    TJSONValue;
  Body:        TJSONObject;
  ParamName:   string;
  i:           Integer;
begin
  Body := ParseJSONObject(Request.Content);
  try
    if not Assigned(Body) then
      raise Exception.Create('Kein gueltiges JSON im Request-Body.');

    Q := TFDQuery.Create(nil);
    try
      Q.Connection := Connection;
      Q.SQL.Text   := joinedSql;

      CountParams := TDictionary<string, string>.Create;
      try
        for i := 0 to High(AFilterParams) do
        begin
          ParamName := AFilterParams[i];
          ParamVal  := Body.GetValue(ParamName);
          if not Assigned(ParamVal) or ParamVal.Null then
            Q.ParamByName(ParamName).Clear
          else
          begin
            Q.ParamByName(ParamName).AsString := ParamVal.Value;
            CountParams.Add(ParamName, ParamVal.Value);
          end;
        end;

        Q.Open;
        Response.ContentType := 'application/json';
        Response.StatusCode  := 200;
        Response.Content     := SerializeQuery(Q);
      finally
        CountParams.Free;
      end;
    finally
      Q.Free;
    end;
  finally
    Body.Free;
  end;
end;

procedure TDataModulTableBase.DoSelectFiltered(const ATable: string;
  const AAllowed: array of string;
  const AFilter: string;
  const AFilterParams: array of string);
// Pagination: InterBase ROWS x TO y
// x = Offset + 1  (1-basiert)
// y = Offset + Limit
// Limit = 0 -> kein ROWS-Zusatz, alle Datensaetze
var
  Body:        TJSONObject;
  OrderVal:    TJSONValue;
  OrderBy:     string;
  ParamVal:    TJSONValue;
  ParamName:   string;
  Limit:       Integer;
  Offset:      Integer;
  RowsClause:  string;
  Q:           TFDQuery;
  i:           Integer;
  CountParams: TDictionary<string, string>;
begin
  Body := ParseJSONObject(Request.Content);
  if not Assigned(Body) then
    raise Exception.Create('Kein gueltiges JSON im Request-Body.');
  try
    // Sortierung lesen und pruefen
    OrderBy  := '';
    OrderVal := Body.GetValue('orderby');
    if Assigned(OrderVal) and not OrderVal.Null then
    begin
      OrderBy := LowerCase(OrderVal.Value);
      if not IsAllowed(OrderBy, AAllowed) then
        raise Exception.CreateFmt('Sortierfeld "%s" ist nicht erlaubt.', [OrderBy]);
    end;

    // Pagination lesen
    // Limit = 0 bedeutet: alle Datensaetze, kein ROWS-Zusatz
    ReadPagination(Body, Limit, Offset);
    RowsClause := '';
    if Limit > 0 then
      RowsClause := Format(' ROWS %d TO %d', [Offset + 1, Offset + Limit]);

    // SQL aufbauen:
    // SELECT <felder> FROM <tabelle> WHERE <filter> [ORDER BY ...] [ROWS x TO y]
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := Connection;
      Q.SQL.Text   := 'SELECT ' + ParseFieldList(Body, AAllowed) +
                      ' FROM ' + ATable +
                      ' WHERE ' + AFilter;
      if OrderBy <> '' then
        Q.SQL.Text := Q.SQL.Text + ' ORDER BY ' + OrderBy;
      if RowsClause <> '' then
        Q.SQL.Text := Q.SQL.Text + RowsClause;

      // Filterwerte aus dem Body lesen
      CountParams := TDictionary<string, string>.Create;
      try
        for i := 0 to High(AFilterParams) do
        begin
          ParamName := AFilterParams[i];
          ParamVal  := Body.GetValue(ParamName);
          if not Assigned(ParamVal) or ParamVal.Null then
            Q.ParamByName(ParamName).Clear
          else
          begin
            Q.ParamByName(ParamName).AsString := ParamVal.Value;
            CountParams.Add(ParamName, ParamVal.Value);
          end;
        end;

        Q.Open;
        Response.ContentType := 'application/json';
        Response.StatusCode  := 200;
        if Limit > 0 then
          Response.Content := BuildPagedResponse(Q,
            'SELECT COUNT(*) FROM ' + ATable + ' WHERE ' + AFilter,
            CountParams, Limit, Offset)
        else
          Response.Content := SerializeQuery(Q);
      finally
        CountParams.Free;
      end;
    finally
      Q.Free;
    end;
  finally
    Body.Free;
  end;
end;

procedure TDataModulTableBase.DoSelectOne(const ATable: string;
  const AAllowed: array of string; const AKeyField: string);
var
  Body:     TJSONObject;
  KeyValue: string;
  Q:        TFDQuery;
begin
  Body := ParseJSONObject(Request.Content);
  if not Assigned(Body) then
    raise Exception.Create('Kein gueltiges JSON im Request-Body.');
  try
    KeyValue := Body.GetValue<string>(LowerCase(AKeyField));
    if KeyValue = '' then
      raise Exception.CreateFmt('"%s" fehlt im Request-Body.', [AKeyField]);

    Q := TFDQuery.Create(nil);
    try
      Q.Connection := Connection;
      Q.SQL.Text   := 'SELECT ' + ParseFieldList(Body, AAllowed) +
                      ' FROM ' + ATable +
                      ' WHERE ' + LowerCase(AKeyField) + ' = :' + LowerCase(AKeyField);
      Q.ParamByName(LowerCase(AKeyField)).AsString := KeyValue;
      Q.Open;
      Response.ContentType := 'application/json';
      Response.StatusCode  := 200;
      Response.Content     := SerializeQuery(Q);
    finally
      Q.Free;
    end;
  finally
    Body.Free;
  end;
end;

procedure TDataModulTableBase.DoInsert(const ATable: string;
  const AAllowed: array of string);
var
  Body:  TJSONObject;
  Pair:  TJSONPair;
  Field: string;
  Cols:  string;
  Vals:  string;
  Count: Integer;
  Q:     TFDQuery;
begin
  Body := ParseJSONObject(Request.Content);
  if not Assigned(Body) then
    raise Exception.Create('Kein gueltiges JSON.');
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := Connection;
      Cols := ''; Vals := ''; Count := 0;

      for Pair in Body do
      begin
        Field := LowerCase(Pair.JSONString.Value);
        if not IsAllowed(Field, AAllowed) then Continue;
        if Count > 0 then begin Cols := Cols + ','; Vals := Vals + ','; end;
        Cols := Cols + Field;
        Vals := Vals + ':' + Field;
        Inc(Count);
      end;

      if Count = 0 then
        raise Exception.Create('Keine gueltigen Felder uebergeben.');

      Q.SQL.Text := 'INSERT INTO ' + ATable +
                    ' (' + Cols + ') VALUES (' + Vals + ')';

      for Pair in Body do
      begin
        Field := LowerCase(Pair.JSONString.Value);
        if not IsAllowed(Field, AAllowed) then Continue;
        if Pair.JsonValue.Null then
          Q.ParamByName(Field).Clear
        else
          Q.ParamByName(Field).Value := Pair.JsonValue.Value;
      end;

      ExecWrite(Q);
    finally
      Q.Free;
    end;
  finally
    Body.Free;
  end;
end;

procedure TDataModulTableBase.DoUpdate(const ATable: string;
  const AAllowed: array of string; const AKeyField: string);
var
  Body:      TJSONObject;
  Pair:      TJSONPair;
  Field:     string;
  SetClause: string;
  Count:     Integer;
  Q:         TFDQuery;
begin
  Body := ParseJSONObject(Request.Content);
  if not Assigned(Body) then
    raise Exception.Create('Kein gueltiges JSON.');
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := Connection;
      SetClause := ''; Count := 0;

      for Pair in Body do
      begin
        Field := LowerCase(Pair.JSONString.Value);
        if SameText(Field, AKeyField) then Continue;
        if not IsAllowed(Field, AAllowed) then Continue;
        if Count > 0 then SetClause := SetClause + ',';
        SetClause := SetClause + Field + '=:' + Field;
        Inc(Count);
      end;

      if Count = 0 then
        raise Exception.Create('Keine gueltigen Felder uebergeben.');

      Q.SQL.Text := 'UPDATE ' + ATable + ' SET ' + SetClause +
                    ' WHERE ' + LowerCase(AKeyField) + '=:' + LowerCase(AKeyField);

      for Pair in Body do
      begin
        Field := LowerCase(Pair.JSONString.Value);
        if SameText(Field, AKeyField) or IsAllowed(Field, AAllowed) then
          if Q.Params.FindParam(Field) <> nil then
            if Pair.JsonValue.Null then
              Q.ParamByName(Field).Clear
            else
              Q.ParamByName(Field).Value := Pair.JsonValue.Value;
      end;

      ExecWrite(Q);
    finally
      Q.Free;
    end;
  finally
    Body.Free;
  end;
end;

procedure TDataModulTableBase.DoDelete(const ATable: string;
  const AKeyField: string);
var
  Body:     TJSONObject;
  KeyValue: TJSONValue;
  Q:        TFDQuery;
begin
  Body := ParseJSONObject(Request.Content);
  if not Assigned(Body) then
    raise Exception.Create('Kein gueltiges JSON.');
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := Connection;
      KeyValue := Body.GetValue(LowerCase(AKeyField));
      if not Assigned(KeyValue) or KeyValue.Null then
        raise Exception.CreateFmt('"%s" fehlt.', [AKeyField]);

      Q.SQL.Text := 'DELETE FROM ' + ATable +
                    ' WHERE ' + LowerCase(AKeyField) + '=:' + LowerCase(AKeyField);
      Q.ParamByName(LowerCase(AKeyField)).Value := KeyValue.Value;
      ExecWrite(Q);
    finally
      Q.Free;
    end;
  finally
    Body.Free;
  end;
end;

end.
