{ ****************************************** }
{ }
{ FastReport VCL }
{ IBX enduser components }
{ }
{ Copyright (c) 1998-2021 }
{ by Fast Reports Inc. }
{ }
{ ****************************************** }

unit frxIBXComponents;

interface

{$I frx.inc}

uses
  Windows, Classes, frCore, frxClass, frxCustomDB, DB,
{$IFDEF DELPHI20}
  IBX.IBDatabase, IBX.IBTable, IBX.IBQuery, IBX.IBCustomDataSet,
{$ELSE}
  IBDatabase, IBTable, IBQuery,
{$ENDIF}
  Variants;

type

  // Hier wird eine Hilfsklasse deklariert.
  TIBRQuery = class(TIBQuery)
  protected
    procedure DoAfterOpen; override;
  end;

  // Die Hilfsklasse wird TIBRQuery zugewiesen
  TIBQuery = Class(TIBRQuery)

  End;

{$IFDEF DELPHI16}
  [ComponentPlatformsAttribute(frDefaultPlatformIDs)]
{$ENDIF}

  /// <summary>
  /// The TfrxIBXComponents component allows the use of IBX data objects in
  /// your report.
  /// </summary>
  TfrxIBXComponents = class(TfrxDBComponents)
  private
    FDefaultDatabase: TIBDatabase;
    FOldComponents: TfrxIBXComponents;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure SetDefaultDatabase(Value: TIBDatabase);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function GetDescription: String; override;
  published
    /// <summary>
    /// Link to the default database connection that will be used in the
    /// report.
    /// </summary>
    property DefaultDatabase: TIBDatabase read FDefaultDatabase write SetDefaultDatabase;
  end;

  /// <summary>
  /// The TfrxIBXDatabase component represents a database connection.
  /// </summary>
  TfrxIBXDatabase = class(TfrxCustomDatabase)
  private
    FDatabase: TIBDatabase;
    FTransaction: TIBTransaction;
    function GetSQLDialect: Integer;
    procedure SetSQLDialect(const Value: Integer);
  protected
    procedure SetConnected(Value: Boolean); override;
    procedure SetDatabaseName(const Value: String); override;
    procedure SetLoginPrompt(Value: Boolean); override;
    procedure SetParams(Value: TStrings); override;
    function GetConnected: Boolean; override;
    function GetDatabaseName: String; override;
    function GetLoginPrompt: Boolean; override;
    function GetParams: TStrings; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    class function GetDescription: String; override;
    procedure SetLogin(const Login, Password: String); override;
    /// <summary>
    /// Reference to internal TIBDatabase object.
    /// </summary>
    property Database: TIBDatabase read FDatabase;
  published
    property DatabaseName;
    property LoginPrompt;
    property Params;
    /// <summary>
    /// SQL dialect used in the database.
    /// </summary>
    property SQLDialect: Integer read GetSQLDialect write SetSQLDialect;
    property Connected;
  end;

  /// <summary>
  /// The TfrxIBXTable represents a table.
  /// </summary>
  TfrxIBXTable = class(TfrxCustomTable)
  private
    FDatabase: TfrxIBXDatabase;
    FTable: TIBTable;
    procedure SetDatabase(const Value: TfrxIBXDatabase);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure SetMaster(const Value: TDataSource); override;
    procedure SetMasterFields(const Value: String); override;
    procedure SetIndexFieldNames(const Value: String); override;
    procedure SetIndexName(const Value: String); override;
    procedure SetTableName(const Value: String); override;
    function GetIndexFieldNames: String; override;
    function GetIndexName: String; override;
    function GetTableName: String; override;
  public
    constructor Create(AOwner: TComponent); override;
    constructor DesignCreate(AOwner: TComponent; Flags: Word); override;
    class function GetDescription: String; override;
    procedure BeforeStartReport; override;
    /// <summary>
    /// Reference to internal TIBTable object.
    /// </summary>
    property Table: TIBTable read FTable;
  published
    /// <summary>
    /// Link to the database connection object. If this property is nil,
    /// TfrxIBXComponents.DefaultDatabase is used.
    /// </summary>
    property Database: TfrxIBXDatabase read FDatabase write SetDatabase;
  end;

  /// <summary>
  /// The TfrxIBXQuery component represents a query.
  /// </summary>
  TfrxIBXQuery = class(TfrxCustomQuery)
  private
    FDatabase: TfrxIBXDatabase;
    FQuery: TIBQuery;
    procedure SetDatabase(const Value: TfrxIBXDatabase);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure SetMaster(const Value: TDataSource); override;

    procedure SetSQL(Value: TStrings); override;
    function GetSQL: TStrings; override;
  public
    constructor Create(AOwner: TComponent); override;
    constructor DesignCreate(AOwner: TComponent; Flags: Word); override;
    class function GetDescription: String; override;
    procedure BeforeStartReport; override;
    procedure UpdateParams; override;
    /// <summary>
    /// Reference to internal TIBQuery object.
    /// </summary>
    property Query: TIBQuery read FQuery;
  published
    /// <summary>
    /// Link to the database connection object. If this property is nil,
    /// TfrxIBXComponents.DefaultDatabase is used.
    /// </summary>
    property Database: TfrxIBXDatabase read FDatabase write SetDatabase;
  end;

var
  IBXComponents: TfrxIBXComponents;

implementation

uses
  frxIBXRTTI,
{$IFNDEF NO_EDITORS}
  frxIBXEditor,
{$ENDIF}
  frxDsgnIntf, frxRes;

{ TfrxDBComponents }

constructor TfrxIBXComponents.Create(AOwner: TComponent);
begin
  inherited;
  FOldComponents := IBXComponents;
  IBXComponents := Self;
end;

destructor TfrxIBXComponents.Destroy;
begin
  if IBXComponents = Self then
    IBXComponents := FOldComponents;
  inherited;
end;

function TfrxIBXComponents.GetDescription: String;
begin
  Result := 'IBX';
end;

procedure TfrxIBXComponents.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (AComponent = FDefaultDatabase) and (Operation = opRemove) then
    FDefaultDatabase := nil;
end;

procedure TfrxIBXComponents.SetDefaultDatabase(Value: TIBDatabase);
begin
  if (Value <> nil) then
    Value.FreeNotification(Self);

  if FDefaultDatabase <> nil then
    FDefaultDatabase.RemoveFreeNotification(Self);

  FDefaultDatabase := Value;
end;

{ TfrxIBXDatabase }

constructor TfrxIBXDatabase.Create(AOwner: TComponent);
begin
  inherited;
  FDatabase := TIBDatabase.Create(nil);
  FTransaction := TIBTransaction.Create(nil);
  FDatabase.DefaultTransaction := FTransaction;
  Component := FDatabase;
end;

destructor TfrxIBXDatabase.Destroy;
begin
  FTransaction.Free;
  inherited;
end;

class function TfrxIBXDatabase.GetDescription: String;
begin
  Result := frxResources.Get('obIBXDB');
end;

function TfrxIBXDatabase.GetConnected: Boolean;
begin
  Result := FDatabase.Connected;
end;

function TfrxIBXDatabase.GetDatabaseName: String;
begin
  Result := FDatabase.DatabaseName;
end;

function TfrxIBXDatabase.GetLoginPrompt: Boolean;
begin
  Result := FDatabase.LoginPrompt;
end;

function TfrxIBXDatabase.GetParams: TStrings;
begin
  Result := FDatabase.Params;
end;

function TfrxIBXDatabase.GetSQLDialect: Integer;
begin
  Result := FDatabase.SQLDialect;
end;

procedure TfrxIBXDatabase.SetConnected(Value: Boolean);
begin
  BeforeConnect(Value);
  FDatabase.Connected := Value;
  FTransaction.Active := Value;
end;

procedure TfrxIBXDatabase.SetDatabaseName(const Value: String);
begin
  FDatabase.DatabaseName := Value;
end;

procedure TfrxIBXDatabase.SetLoginPrompt(Value: Boolean);
begin
  FDatabase.LoginPrompt := Value;
end;

procedure TfrxIBXDatabase.SetParams(Value: TStrings);
begin
  FDatabase.Params := Value;
end;

procedure TfrxIBXDatabase.SetSQLDialect(const Value: Integer);
begin
  FDatabase.SQLDialect := Value;
end;

procedure TfrxIBXDatabase.SetLogin(const Login, Password: String);
begin
  Params.Text := 'user_name=' + Login + #13#10 + 'password=' + Password;
end;

{ TfrxIBXTable }

constructor TfrxIBXTable.Create(AOwner: TComponent);
begin
  FTable := TIBTable.Create(nil);
  DataSet := FTable;
  SetDatabase(nil);
  inherited;
end;

constructor TfrxIBXTable.DesignCreate(AOwner: TComponent; Flags: Word);
var
  i: Integer;
  l: TList;
begin
  inherited;
  l := Report.AllObjects;
  for i := 0 to l.Count - 1 do
    if TObject(l[i]) is TfrxIBXDatabase then
    begin
      SetDatabase(TfrxIBXDatabase(l[i]));
      break;
    end;
end;

class function TfrxIBXTable.GetDescription: String;
begin
  Result := frxResources.Get('obIBXTb');
end;

procedure TfrxIBXTable.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FDatabase) then
    SetDatabase(nil);
end;

procedure TfrxIBXTable.SetDatabase(const Value: TfrxIBXDatabase);
begin
  FDatabase := Value;
  if Value <> nil then
    FTable.Database := Value.Database
  else if IBXComponents <> nil then
    FTable.Database := IBXComponents.DefaultDatabase
  else
    FTable.Database := nil;
  DBConnected := FTable.Database <> nil;
end;

function TfrxIBXTable.GetIndexFieldNames: String;
begin
  Result := FTable.IndexFieldNames;
end;

function TfrxIBXTable.GetIndexName: String;
begin
  Result := FTable.IndexName;
end;

function TfrxIBXTable.GetTableName: String;
begin
  Result := FTable.TableName;
end;

procedure TfrxIBXTable.SetIndexFieldNames(const Value: String);
begin
  FTable.IndexFieldNames := Value;
end;

procedure TfrxIBXTable.SetIndexName(const Value: String);
begin
  FTable.IndexName := Value;
end;

procedure TfrxIBXTable.SetTableName(const Value: String);
begin
  FTable.TableName := Value;
end;

procedure TfrxIBXTable.SetMaster(const Value: TDataSource);
begin
  FTable.MasterSource := Value;
end;

procedure TfrxIBXTable.SetMasterFields(const Value: String);
begin
  FTable.MasterFields := Value;
end;

procedure TfrxIBXTable.BeforeStartReport;
begin
  SetDatabase(FDatabase);
end;

{ TfrxIBXQuery }

constructor TfrxIBXQuery.Create(AOwner: TComponent);
begin
  FQuery := TIBQuery.Create(nil);
  DataSet := FQuery;
  SetDatabase(nil);
  inherited;
end;

constructor TfrxIBXQuery.DesignCreate(AOwner: TComponent; Flags: Word);
var
  i: Integer;
  l: TList;
begin
  inherited;
  l := Report.AllObjects;
  for i := 0 to l.Count - 1 do
    if TObject(l[i]) is TfrxIBXDatabase then
    begin
      SetDatabase(TfrxIBXDatabase(l[i]));
      break;
    end;
end;

class function TfrxIBXQuery.GetDescription: String;
begin
  Result := frxResources.Get('obIBXQ');
end;

procedure TfrxIBXQuery.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FDatabase) then
    SetDatabase(nil);
end;

procedure TfrxIBXQuery.SetDatabase(const Value: TfrxIBXDatabase);
begin
  FDatabase := Value;

  if Value <> nil then
  begin
    FQuery.Database := Value.Database;
    FQuery.Transaction := Value.FTransaction;
  end
  else if IBXComponents <> nil then
    FQuery.Database := IBXComponents.DefaultDatabase
  else
    FQuery.Database := nil;
  DBConnected := FQuery.Database <> nil;
end;

procedure TfrxIBXQuery.SetMaster(const Value: TDataSource);
begin
  FQuery.DataSource := Value;
end;

procedure TfrxIBXQuery.SetSQL(Value: TStrings);
begin
  FQuery.SQL := Value;
end;

function TfrxIBXQuery.GetSQL: TStrings;
begin
  Result := FQuery.SQL;
end;

procedure TfrxIBXQuery.UpdateParams;
begin
  if Assigned(FQuery.Database) then
    frxParamsToTParams(Self, FQuery.Params);
end;

procedure TfrxIBXQuery.BeforeStartReport;
begin
  SetDatabase(FDatabase);
end;


{ TIBRQuery }
//Hilfsklasse.Hier kann die Query an die geforderten Ansprüche angepasst werden

procedure TIBRQuery.DoAfterOpen;
var
  i: Integer;
begin
    // Alle Stringfelder trimmen
  for i := 0 to FieldCount - 1 do
  begin
    if Fields[i].DataType = ftWideString then
    begin
      TIBStringfield(Fields[i]).FixedChar := False;
    end;
  end;
  Self.First;

  inherited;
end;

initialization

frxObjects.RegisterObject1(TfrxIBXDatabase, nil, '', {$IFDEF DB_CAT}'DATABASES'{$ELSE}''{$ENDIF}, 0, 60);
frxObjects.RegisterObject1(TfrxIBXTable, nil, '', {$IFDEF DB_CAT}'TABLES'{$ELSE}''{$ENDIF}, 0, 61);
frxObjects.RegisterObject1(TfrxIBXQuery, nil, '', {$IFDEF DB_CAT}'QUERIES'{$ELSE}''{$ENDIF}, 0, 62);

finalization

frxObjects.UnRegister(TfrxIBXDatabase);
frxObjects.UnRegister(TfrxIBXTable);
frxObjects.UnRegister(TfrxIBXQuery);

end.
