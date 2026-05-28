unit router;

interface

uses

  StrUtils, System.SysUtils, Web.HTTPApp;

type
  // Factory erzeugt die Instanz und erhält Request + Response
  TInstanceFactory = function(Request: TWebRequest; Response: TWebResponse): TObject;

  // Handler-Signatur (parameterlos, DataModule hat Request/Response schon gespeichert)
  TRouteHandler = procedure of object;

  // Ein Eintrag im Router
  TRouteEntry = record
    Path: string;
    Factory: TInstanceFactory;
    MethodCode: Pointer; // Code-Pointer der Methode (Data später gebunden)
    AuthRequired: boolean;
    LocalOnly: boolean;  // Zugriff nur vom localhost erlaubt
  end;

  TRouter = class
  private
    FRoutes: array of TRouteEntry;

  public
    procedure AddRoute(APath: string; AFactory: TInstanceFactory; AMethod: TRouteHandler; AuthRequired: boolean = true; ALocalOnly: boolean = false);
    function FindRoute(Path: string; out AFactory: TInstanceFactory; out MethodCode: Pointer): boolean;
    function IsAuthRequired(Path: string): boolean;
    function IsLocalOnly(Path: string): boolean;
    procedure Clear;
    function ListRoutes: string;
  end;

implementation

uses webUtils;

procedure TRouter.AddRoute(APath: string; AFactory: TInstanceFactory; AMethod: TRouteHandler; AuthRequired: boolean = true; ALocalOnly: boolean = false);
var
  Len: Integer;
  M: TMethod;
begin
  Len := Length(FRoutes);
  SetLength(FRoutes, Len + 1);
  FRoutes[Len].Path := APath;
  FRoutes[Len].AuthRequired := AuthRequired;
  FRoutes[Len].LocalOnly := ALocalOnly;
  FRoutes[Len].Factory := AFactory;

  // Nur den Code-Pointer der Methode speichern (ohne Data)
  M := TMethod(AMethod);
  FRoutes[Len].MethodCode := M.Code;
end;

function TRouter.FindRoute(Path: string; out AFactory: TInstanceFactory; out MethodCode: Pointer): boolean;
var
  I: Integer;
  haswildcard: boolean;
  APath: string;
  _path: string;

begin
  Result := False;
  for I := Low(FRoutes) to High(FRoutes) do
  begin
    APath := ExcludeLastSlash(Path);

    haswildcard := AnsiRightStr(FRoutes[I].Path, 1) = '*';
    _path := FRoutes[I].Path.TrimRight(['*']);

    // Wenn eine Pfad mit einem * am Ende registriert wurde, können beliebige weitere Pfade folgen um von der registrierten Methode aufgefangen zu werden.
    if haswildcard then
      if APath.StartsWith(_path + '/', true) then // CaseInsensitiv!
      begin
        AFactory := FRoutes[I].Factory;
        MethodCode := FRoutes[I].MethodCode;
        exit(true);
      end;

    if SameText(_path, ExcludeLastSlash(Path)) then // CaseInsensitiv!
    begin
      AFactory := FRoutes[I].Factory;
      MethodCode := FRoutes[I].MethodCode;
      exit(true);
    end;

  end;
end;

function TRouter.IsAuthRequired(Path: string): boolean;
var
  I: Integer;
  haswildcard: boolean;
  APath: string;
  _path: string;
begin


  // Diese Routine prüft, ob eine Anmeldung erforderlich ist
  Result := true;
  for I := Low(FRoutes) to High(FRoutes) do
  begin
    APath := ExcludeLastSlash(Path);

    haswildcard := AnsiRightStr(FRoutes[I].Path, 1) = '*';
    _path := FRoutes[I].Path.TrimRight(['*']);

    // Wenn eine Pfad mit einem * am Ende registriert wurde, können beliebige weitere Pfade folgen um von der registrierten Methode aufgefangen zu werden.
    if haswildcard then
      if APath.StartsWith(_path + '/', true) then // CaseInsensitiv!
      begin
        Result := FRoutes[I].AuthRequired;
        exit;
      end;

    if SameText(_path, ExcludeLastSlash(Path)) then // CaseInsensitiv!
    begin
      Result := FRoutes[I].AuthRequired;
      exit;
    end;

  end;

end;

function TRouter.IsLocalOnly(Path: string): boolean;
var
  I: Integer;
  haswildcard: boolean;
  APath: string;
  _path: string;
begin
  // Diese Routine prüft, ob eine Route nur vom localhost erreichbar ist
  Result := false;
  for I := Low(FRoutes) to High(FRoutes) do
  begin
    APath := ExcludeLastSlash(Path);

    haswildcard := AnsiRightStr(FRoutes[I].Path, 1) = '*';
    _path := FRoutes[I].Path.TrimRight(['*']);

    if haswildcard then
      if APath.StartsWith(_path + '/', true) then
      begin
        Result := FRoutes[I].LocalOnly;
        exit;
      end;

    if SameText(_path, ExcludeLastSlash(Path)) then
    begin
      Result := FRoutes[I].LocalOnly;
      exit;
    end;
  end;
end;

procedure TRouter.Clear;
begin
  SetLength(FRoutes, 0);
end;

function TRouter.ListRoutes: string;
var
  I: Integer;
begin
  Result := '/login' + sLineBreak;
  // for I := Low(FRoutes) to High(FRoutes) do
  // Result := Result + FRoutes[I].Path + sLineBreak;

  for I := Low(FRoutes) to High(FRoutes) do
  begin
    Result := Result + FRoutes[I].Path ;
    if not FRoutes[I].AuthRequired then
      Result := Result + ' [No Auth]';
    if FRoutes[I].LocalOnly then
      Result := Result + ' [Localhost only]';
    Result := Result + sLineBreak;
  end;

end;

end.

