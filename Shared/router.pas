unit router;

interface

uses

  StrUtils, System.SysUtils,System.Classes, Web.HTTPApp;

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

  TRouteEntryArray = array of TRouteEntry;

  TRouter = class
  private
    FRoutes: TRouteEntryArray;

  public
    procedure AddRoute(APath: string; AFactory: TInstanceFactory; AMethod: TRouteHandler; AuthRequired: boolean = true; ALocalOnly: boolean = false);
    function FindRoute(Path: string; out AFactory: TInstanceFactory; out MethodCode: Pointer): boolean;
    function IsAuthRequired(Path: string): boolean;
    function IsLocalOnly(Path: string): boolean;
    procedure Clear;
    function ListRoutes: string;
    function ListRoutes2: string;
  end;

implementation

uses webUtils, System.Generics.Collections, System.Generics.Defaults;

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

function IsFlatPath(const APath: string): boolean;
begin
  // Flach = kein Gruppen-Term, z.B. /adddemo statt /adressen/xyz
  Result := APath.TrimLeft(['/']).IndexOf('/') < 0;
end;

function TRouter.ListRoutes2: string;
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
      Result := Result + '<span style="color:green"> [No Auth]</span>';
    if FRoutes[I].LocalOnly then
      Result := Result + '<span style="color:red"> [Localhost only]</span>';
    Result := Result + sLineBreak;
  end;

end;

function TRouter.ListRoutes: string;
var
  I: Integer;
  SortedRoutes: TRouteEntryArray;
  slist:TStringlist;
    s:string;
  Term, LastTerm: string;
  P: Integer;
begin
  slist:=TStringlist.create;

    slist.add('<b>geschützte Endpunkte (nur für PHP-Entwicklung und Diagnose)</b>');
    slist.add('Diese Endpunkte sind nur lokal erreichbar. Also z.B. von PHP-Scripten auf dem selben Server.');
    slist.add('');

  LastTerm := '';
  try

  SortedRoutes := Copy(FRoutes);

  TArray.Sort<TRouteEntry>(SortedRoutes, TComparer<TRouteEntry>.Construct(
    function(const Left, Right: TRouteEntry): Integer
    begin
      if Left.LocalOnly <> Right.LocalOnly then
      begin
        if Left.LocalOnly then
          Exit(-1)
        else
          Exit(1);
      end;

      if not Left.LocalOnly then
        if IsFlatPath(Left.Path) <> IsFlatPath(Right.Path) then
        begin
          if IsFlatPath(Left.Path) then
            Exit(1)
          else
            Exit(-1);
        end;

      Result := CompareText(Left.Path, Right.Path);
    end));




  for I := Low(SortedRoutes) to High(SortedRoutes) do
  begin
  s:=SortedRoutes[I].Path;



    if not SortedRoutes[I].LocalOnly then
    begin
      if IsFlatPath(SortedRoutes[I].Path) then
        Term := 'Sonstige Endpunkte'
      else
      begin
        Term := SortedRoutes[I].Path.TrimLeft(['/']);
        P := Term.IndexOf('/');
        if P >= 0 then
          Term := Term.Substring(0, P);
      end;

      if not SameText(Term, LastTerm) then
      begin
          slist.add('');
           if IsFlatPath(SortedRoutes[I].Path) then
               slist.add('<b style="display:inline; margin-bottom:2px;margin-left:12px">'+Term+'</b>')
           else
               slist.add('<div style="display:inline; margin-bottom:2px;margin-left:12px;text-decoration:underline"> <b>' + UpperCase(Term) + '</b> <span style="font-size:small;">Daten-Endpunkt</span></div> ');
           LastTerm := Term;
      end;
    end;

    if not SortedRoutes[I].AuthRequired then
        s:=s+('<span style="color:green"> [No Auth]</span>');
    if SortedRoutes[I].LocalOnly then
        s:=s+('<span style="color:red"> [Localhost only]</span>');
    slist.add('<span style="margin-left:32px">'+s+'</span>');

  end;
        slist.add('/login');
        result:=slist.text;
  finally
    slist.free;
  end;
end;

end.

