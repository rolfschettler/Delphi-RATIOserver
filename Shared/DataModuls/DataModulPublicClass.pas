unit DataModulPublicClass;

interface

uses
  Web.HTTPApp, System.json,
  System.SysUtils, System.Classes, DataModulTableBaseClass, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt,
  FireDAC.UI.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Phys, FireDAC.Phys.IB, FireDAC.Phys.IBDef, FireDAC.VCLUI.Wait, Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet;

type
  TDataModulPublic = class(TDataModulTableBase)
  private
    { Private-Deklarationen }
  public
    { Public-Deklarationen }
    procedure checkmailtoken();
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
procedure TDataModulPublic.checkmailtoken;
var
  Body: TJSONObject;
  ResponseObj, DataObj: TJSONObject;
  token_hash, client_ip: string;
  TokenId: Integer;
  IsSingleUse: Boolean;
  Sql: string;
  TransactionStarted: Boolean;
begin
  Body := nil;
  ResponseObj := nil;
  DataObj := nil;
  TransactionStarted := False;

  try
    // === Body parsen ===
    Body := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;
    if not Assigned(Body) then
      raise Exception.Create('Kein gueltiges JSON im Request-Body.');

    token_hash := Body.GetValue<string>('token_hash');
    client_ip  := Body.GetValue<string>('client_ip', '');

    // === Format-Prüfung ===
    if Length(token_hash) <> 64 then
    begin
      Response.ContentType := 'application/json';
      Response.StatusCode := 200;
      Response.Content := '{"status":"ERROR","message":"Token-Format ungueltig"}';
      Exit;
    end;

    // === Transaktion starten ===
    Connection.StartTransaction;
    TransactionStarted := True;

    // === SELECT ===
    Sql := 'SELECT ID, PURPOSE, REFERENCE_TYPE, REFERENCE_ID, ' +
           'RECIPIENT_EMAIL, EXPIRES_AT, USED_AT, SINGLE_USE, REVOKED ' +
           'FROM ACCESS_TOKENS WHERE TOKEN_HASH = :token_hash';

    Query.Close;
    Query.SQL.Clear;
    Query.SQL.Text := Sql;
    Query.ParamByName('token_hash').AsString := token_hash;
    Query.Open;

    // === Validierung 1: Token gefunden? ===
    if Query.IsEmpty then
    begin
      Response.ContentType := 'application/json';
      Response.StatusCode := 200;
      Response.Content := '{"status":"ERROR","message":"Token unbekannt"}';
      Connection.Rollback;
      TransactionStarted := False;
      Exit;
    end;

    // === Validierung 2: Widerrufen? ===
    if Query.FieldByName('REVOKED').AsInteger = 1 then
    begin
      Response.ContentType := 'application/json';
      Response.StatusCode := 200;
      Response.Content := '{"status":"ERROR","message":"Token wurde widerrufen"}';
      Connection.Rollback;
      TransactionStarted := False;
      Exit;
    end;

    // === Validierung 3: Abgelaufen? ===
    if Query.FieldByName('EXPIRES_AT').AsDateTime < Now then
    begin
      Response.ContentType := 'application/json';
      Response.StatusCode := 200;
      Response.Content := '{"status":"ERROR","message":"Token ist abgelaufen"}';
      Connection.Rollback;
      TransactionStarted := False;
      Exit;
    end;

    // === Validierung 4: Bereits verwendet? ===
    if (Query.FieldByName('SINGLE_USE').AsInteger = 1)
       and not Query.FieldByName('USED_AT').IsNull then
    begin
      Response.ContentType := 'application/json';
      Response.StatusCode := 200;
      Response.Content := '{"status":"ERROR","message":"Token wurde bereits verwendet"}';
      Connection.Rollback;
      TransactionStarted := False;
      Exit;
    end;

    // === Werte für später merken ===
    TokenId := Query.FieldByName('ID').AsInteger;
    IsSingleUse := Query.FieldByName('SINGLE_USE').AsInteger = 1;

    // === Erfolgs-Antwort bauen ===
    DataObj := TJSONObject.Create;
    DataObj.AddPair('id', TJSONNumber.Create(Query.FieldByName('ID').AsInteger));
    DataObj.AddPair('purpose', Query.FieldByName('PURPOSE').AsString);
    DataObj.AddPair('reference_type', Query.FieldByName('REFERENCE_TYPE').AsString);
    DataObj.AddPair('reference_id', TJSONNumber.Create(Query.FieldByName('REFERENCE_ID').AsInteger));
    DataObj.AddPair('recipient_email', Query.FieldByName('RECIPIENT_EMAIL').AsString);
    DataObj.AddPair('expires_at', FormatDateTime('yyyy-mm-dd hh:nn:ss', Query.FieldByName('EXPIRES_AT').AsDateTime));
    DataObj.AddPair('single_use', TJSONBool.Create(IsSingleUse));

    ResponseObj := TJSONObject.Create;
    ResponseObj.AddPair('status', 'OK');
    ResponseObj.AddPair('data', DataObj);
    DataObj := nil;  // ← KRITISCH: ResponseObj besitzt nun DataObj

    Query.Close;

    // === UPDATE bei single_use=1 ===
    if IsSingleUse then
    begin
      Query.SQL.Text :=
        'UPDATE ACCESS_TOKENS ' +
        'SET USED_AT = CURRENT_TIMESTAMP, USED_FROM_IP = :client_ip ' +
        'WHERE ID = :id AND USED_AT IS NULL';
      Query.ParamByName('client_ip').AsString := client_ip;
      Query.ParamByName('id').AsInteger := TokenId;
      Query.ExecSQL;

      if Query.RowsAffected = 0 then
      begin
        Response.ContentType := 'application/json';
        Response.StatusCode := 200;
        Response.Content := '{"status":"ERROR","message":"Token wurde bereits verwendet"}';
        Connection.Rollback;
        TransactionStarted := False;
        Exit;
      end;
    end;

    // === Antwort senden ===
    Response.ContentType := 'application/json';
    Response.StatusCode := 200;
    Response.Content := ResponseObj.ToString;

    Connection.Commit;
    TransactionStarted := False;

  finally
    // Reihenfolge der Aufräumarbeiten:
    // 1. Wenn Transaktion noch offen → Rollback
    // 2. Query schließen
    // 3. Lokale JSON-Objekte freigeben

    if TransactionStarted then
    begin
      try
        Connection.Rollback;
      except
        // Rollback sollte nicht scheitern, aber falls doch:
        // ignorieren, damit das Aufräumen weitergehen kann
      end;
    end;

    if Assigned(Query) then
      Query.Close;

    // ResponseObj enthält DataObj - eines reicht zum Freigeben
    if Assigned(ResponseObj) then
      ResponseObj.Free
    else if Assigned(DataObj) then
      DataObj.Free;  // Falls ResponseObj noch nicht erzeugt wurde

    if Assigned(Body) then
      Body.Free;
  end;
end;
end.
