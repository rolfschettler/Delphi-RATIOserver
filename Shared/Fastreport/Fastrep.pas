unit Fastrep;

interface

uses
  // FastReportAddFunctions,
  Winapi.Windows, Winapi.Messages, Winapi.RichEdit, System.SysUtils, System.Variants, System.IOUtils,
  System.Classes, Strutils, DateUtils, Vcl.Graphics, System.Math, jpeg,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def,
  FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys, FireDAC.Phys.PG,
  FireDAC.Phys.PGDef, FireDAC.VCLUI.Wait, FireDAC.Comp.UI, Data.DB,
  FireDAC.Comp.Client, FireDAC.Stan.Param, FireDAC.DatS, FireDAC.DApt.Intf,
  FireDAC.DApt, FireDAC.Comp.DataSet, frxClass, frxExportBaseDialog,
  frxExportPDF, frxDBSet, System.IniFiles,
  frxFDComponents, frxDesgn, frxChart, frxCross, frxChBox, frxTableObject, frxBarcode, frxDCtrl, frxGradient,
  frxExportHelpers, frxExportHTMLDiv, frxRich, frxExportBaseImageSettingsDialog, frCoreClasses,
  IBX.IBDatabase, frxIBXComponents, frxOLE, frxPDFViewer, IBX.IBCustomDataSet,
   IBX.IBQuery;

type
  TReportForm = class(TDataModule)
    FastReport: TfrxReport;
    frxDBDataset1: TfrxDBDataset;
    frxPDFExport1: TfrxPDFExport;
    frxGradientObject1: TfrxGradientObject;
    frxDialogControls1: TfrxDialogControls;
    frxBarCodeObject1: TfrxBarCodeObject;
    frxReportTableObject1: TfrxReportTableObject;
    frxCheckBoxObject1: TfrxCheckBoxObject;
    frxCrossObject1: TfrxCrossObject;
    frxChartObject1: TfrxChartObject;
    frxHTML5DivExport1: TfrxHTML5DivExport;
    frxRichObject1: TfrxRichObject;
    frxPDFObject1: TfrxPDFObject;
    frxIBXComponents1: TfrxIBXComponents;
    IBDatabase1: TIBDatabase;
    frxOLEObject1: TfrxOLEObject;
    VorlagenQuery: TIBQuery;
    procedure FastReportBeginDoc(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private

    RA_CURRENTUSER: string;
    RA_CURRENTLOGIN: string;
    FExternalParamas: TParams;

    function frxReportOnUserFunction(const MethodName: string; var Params: Variant): Variant;
    procedure AddUserFunctions;

    function AssignParams(Parameters: TParams; FastReport: TfrxReport): Boolean;
    procedure SetExternalParamas(const Value: TParams);
    function ContainsForbiddenComponentsInStream(AStream: TStream): Boolean;
    // UserDefined Functions for Fastreport
    function TextFormat(Rtf: string): string;
    function EU: string;
    function ParamByName(s: string): string;
    function POSTANSCHRIFT(s: string): string;
    function PruefZiffer(s: string): string;
    function ReplaceText(s, VonText, NachText: string): string;
    function SekundenInStunden(Sec: Integer; showSec: Boolean = true): String;
    function ZahlAbrunden(Value: Extended; Digit: Integer): Extended;
    function ZahlAufrunden(Value: Extended; Digit: Integer): Extended;
    function ZahlInWort(n: Integer): string;
    function ZeigeBelegt(Image: string; Definition: string; BelegtPlatzQuery: string; ZeigePlatznr: String = ''): string;
    function ZusatzFeld(Content, Wert: string): string;

    { Private-Deklarationen }
  public

    { Public-Deklarationen }

    procedure Connect(Connection: TFDConnection);
    procedure DoExportieren(Bereich, art, formularname: string; ExportFormat, Dateiname: string; Stream: TMemorystream);
    property ExternalParamas: TParams read FExternalParamas write SetExternalParamas;

  end;

var
  GRichEditModule: HMODULE = 0;

implementation

{$R *.dfm}
{ TForm1 }

procedure TReportForm.Connect(Connection: TFDConnection);
begin

  var
    Server, DB, Port: string;
  begin
    (* Hier werden die Verbindungsparameter der FiredacConnection auf die IBX-Database übertragen *)
    IBDatabase1.Connected := False;
    Server := Connection.Params.Values['Server'];
    DB := Connection.Params.Values['Database'];
    Port := Connection.Params.Values['Port'];
    // DatabaseName zusammensetzen
    if Server <> '' then
    begin
      if Port <> '' then
        IBDatabase1.DatabaseName := Server + '/' + Port + ':' + DB
      else
        IBDatabase1.DatabaseName := Server + ':' + DB;
    end
    else
      IBDatabase1.DatabaseName := DB;
    IBDatabase1.Params.Clear;
    IBDatabase1.Params.Values['user_name'] := Connection.Params.Values['User_Name'];
    IBDatabase1.Params.Values['password'] := Connection.Params.Values['Password'];
    IBDatabase1.Params.Values['lc_ctype'] := Connection.Params.Values['CharacterSet'];
    IBDatabase1.Connected := true;
  end;

end;

function TReportForm.ContainsForbiddenComponentsInStream(AStream: TStream): Boolean;
var
  SR: TStringStream;
  s: String;
begin
  AStream.Position := 0;
  SR := TStringStream.Create('', TEncoding.UTF8);
  try
    SR.CopyFrom(AStream, AStream.Size);
    s := UpperCase(SR.DataString);
    Result := (Pos('TFRXDIALOGPAGE', s) > 0) or (Pos('TFRXDIALOGCOMPONENT', s) > 0) or (Pos('TFRXBUTTONCONTROL', s) > 0) or (Pos('TFRXEDITCONTROL', s) > 0) or (Pos('TFRXCHECKBOXCONTROL', s) > 0);
  finally
    SR.Free;
    AStream.Position := 0; // wichtig!
  end;
end;

function TReportForm.AssignParams(Parameters: TParams; FastReport: TfrxReport): Boolean;

(* Zuweisung von Parametern aus einer übergebenen Parameterliste *)
var
  pc, i, j: Integer;
  DS: Tfrxdatasetitem; // FRX-DatasetItem
  ibxDS: TfrxIBXQuery;
  s: string;

begin

  if Parameters <> nil then
    for i := 0 to FastReport.DataSets.Count - 1 do // Schleife durch alle Datasets
    begin
      DS := FastReport.DataSets[i]; // DS ist ein Tfrxdatasetitem
      ibxDS := TfrxIBXQuery(DS.DataSet); // Casting zu TfrxIBXQuery
      for j := 0 to ibxDS.Params.Count - 1 do // Schleife durch alle Parameter der Query
      begin
        for pc := 0 to Parameters.Count - 1 do // Suchen nach Übereinstimmung in der Übergebenen Parameterliste
        begin
          if AnsiUppercase(ibxDS.Params[j].Name) = 'USERNAME' then
            if RA_CURRENTUSER <> '' then
              ibxDS.Params[j].Value := RA_CURRENTUSER
            else
              ibxDS.Params[j].Value := '?';
          if AnsiUppercase(ibxDS.Params[j].Name) = 'LOGINNAME' then
            if RA_CURRENTLOGIN <> '' then
              ibxDS.Params[j].Value := RA_CURRENTLOGIN
            else
              ibxDS.Params[j].Value := '?';

          if (AnsiUppercase(ibxDS.Params[j].Name) = AnsiUppercase(Parameters[pc].Name)) or (AnsiUppercase(ibxDS.Params[j].Name) = '_' + AnsiUppercase(Parameters[pc].Name)) then // Wenn Name übereinstimmt
            if ibxDS.Params[j].Expression = '' then // Wenn noch kein Ausdruck im Report zugewiesen
              ibxDS.Params[j].Value := Parameters[pc].Value; // Wert aus Parameters übernehmen;
        end;
      end;
    end;

  // Überprüfen, ob alle Parameter gesetzt, ggf. manuell eingeben
  for i := 0 to FastReport.DataSets.Count - 1 do // Schleife durch alle Datasets
  begin
    DS := FastReport.DataSets[i]; // DS ist ein Tfrxdatasetitem
    ibxDS := TfrxIBXQuery(DS.DataSet); // Casting zu TfrxIBXQuery
    for j := 0 to ibxDS.Params.Count - 1 do // Schleife durch alle Parameter der Query
      if (ibxDS.Params[j].Expression = '') and // Wenn noch kein Ausdruck im Report zugewiesen
        (Vartostr(ibxDS.Params[j].Value) = '') then // Und kein Wert von der Parmeterliste übernommen wurde
        raise Exception.Create('Fehlender Parameter, Tabelle: ' + ibxDS.Name + ', Param. ' + ibxDS.Params[j].Name);

  end;

  // Es wird eine VARIABLE namens 'PARAMS' erzeugt, die im Report alle übergebenen Parameter anzeigt.
  s := 'Es wurden keine externen Parameter übergeben';
  if Parameters <> nil then
  begin
    if Parameters.Count > 0 then
      s := '';
    for i := 0 to Parameters.Count - 1 do
      s := s + Parameters[i].Name + '=' + Parameters[i].asString + #13;
  end;
  s := s + 'USERNAME=' + RA_CURRENTUSER + #13;
  s := s + 'LOGINNAME=' + RA_CURRENTLOGIN + #13;
  FastReport.Script.AddVariable('PARAMS', '', s);
  Result := true;
end;

Procedure TReportForm.DoExportieren(Bereich, art, formularname: string; ExportFormat, Dateiname: string; Stream: TMemorystream);
var

  // DokumentPfadName: string;
  i: Integer;
  errormsg: string;

  MS: TMemorystream;

begin
  errormsg := '';

  try

    (* 1.Export vorbereiten *)
    MS := TMemorystream.Create;
    try
      // Report anhand von  Bereich, art und formularname einlesen:
      with VorlagenQuery do
      begin
        Close;
        ParamByName('bereich').asString := Bereich;
        ParamByName('art').asString := art;
        ParamByName('name').asString := formularname;
        Open;
        First;
        if eof and bof then
          raise Exception.Create('Das Formular BEREICH=' + Bereich + ' , ART=' + art + ' ,NAME=' + formularname + ' ist nicht vorhanden');
        TBlobfield(VorlagenQuery.fieldbyname('HauptText')).SaveToStream(MS);
        MS.Position := 0;

        // Prüfen, ob sich Komponenten im Formular befinden, die im WEB nicht dargestellt werden können
        if ContainsForbiddenComponentsInStream(MS) then
          raise Exception.Create('Ungültige Componente TfrxDialogPage im Report');
        MS.Position := 0;

        FastReport.LoadFromStream(MS);
      end;
    finally
      MS.Free;
    end;

    FastReport.EngineOptions.SilentMode := true;
    FastReport.EngineOptions.NewSilentMode := simSilent;
    FastReport.PrintOptions.ShowDialog := False;

    FastReport.PrepareReport;
    if FastReport.Errors.Count <> 0 then
    begin
      // Fehler ausgeben
      for i := 0 to FastReport.Errors.Count - 1 do
        errormsg := errormsg + '-' + FastReport.Errors[0];
      raise Exception.Create(errormsg);
    end;

    (* 2.Export durchführen *)

    { PDF-EXPORT FASTREPORTFILTER }
    if UpperCase(ExportFormat) = 'PDF' then
    begin
      frxPDFExport1.Stream := Stream;
      frxPDFExport1.ShowDialog := False;
      frxPDFExport1.ShowProgress := False;
      FastReport.Export(frxPDFExport1);
    end;

    { PDF-EXPORT FASTREPORTFILTER }
    if UpperCase(ExportFormat) = 'HTML' then
    begin
      frxHTML5DivExport1.Stream := Stream;
      frxHTML5DivExport1.ShowDialog := False;
      frxHTML5DivExport1.ShowProgress := False;
      FastReport.Export(frxHTML5DivExport1);
    end;

  except
    on E: Exception do
    begin
      raise
    end;

  end;

end;

procedure TReportForm.FastReportBeginDoc(Sender: TObject);
begin
  if Assigned(ExternalParamas) then // Wenn eine Externe Parameterliste übergeben wurde
  begin
    if not AssignParams(ExternalParamas, FastReport) then // Parameter zuweisen
      raise Exception.Create('Es wurden nicht alle Parameter zugewiesen')
  end
end;

procedure TReportForm.FormCreate(Sender: TObject);
begin
  ExternalParamas := nil;
  AddUserFunctions;
end;

procedure TReportForm.SetExternalParamas(const Value: TParams);
begin
  FExternalParamas := Value;
end;


// ======================================= Benutzerdefinierte Funktionen für Fastreport--------------------------------
// 1. Funktion erstellen

function TReportForm.TextFormat(Rtf: string): string;
var
  i, Len: Integer;
  sb: TStringBuilder;
  HexValue: Integer;
  UnicodeValue: Integer;
  ControlWord: string;
begin
  // Wenn es gar kein RTF ist → direkt zurückgeben
  if not Rtf.StartsWith('{\rtf') then
    Exit(Rtf);

  sb := TStringBuilder.Create;
  try
    Len := Length(Rtf);
    i := 1;

    while i <= Len do
    begin
      case Rtf[i] of

        '{', '}':
          ; // ignorieren

        '\':
          begin
            Inc(i);

            // Hex-Zeichen \'xx
            if (i <= Len) and (Rtf[i] = '''') then
            begin
              if i + 2 <= Len then
              begin
                HexValue := StrToIntDef('$' + Copy(Rtf, i + 1, 2), 32);
                sb.Append(Char(HexValue));
                Inc(i, 2);
              end;
            end
            else
            begin
              // Steuerwort lesen
              ControlWord := '';
              while (i <= Len) and CharInSet(Rtf[i], ['a' .. 'z', 'A' .. 'Z']) do
              begin
                ControlWord := ControlWord + Rtf[i];
                Inc(i);
              end;

              // Unicode \uXXXX
              if ControlWord = 'u' then
              begin
                UnicodeValue := 0;
                while (i <= Len) and CharInSet(Rtf[i], ['0' .. '9', '-']) do
                begin
                  UnicodeValue := UnicodeValue * 10 + StrToIntDef(Rtf[i], 0);
                  Inc(i);
                end;
                sb.Append(Char(UnicodeValue));
              end
              else if ControlWord = 'par' then
                sb.AppendLine;

              // alle anderen Steuerwörter ignorieren
            end;
          end;

      else
        // normales Zeichen → anhängen
        sb.Append(Rtf[i]);
      end;

      Inc(i);
    end;

    Result := sb.ToString;
  finally
    sb.Free;
  end;
end;

function TReportForm.PruefZiffer(s: string): string;
// Subfunction Begin
  function PZiffer(s: string): string;
  type
    ZArr = array [-1 .. 9, -1 .. 10] of Integer;
  const
    z: ZArr = ((-1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, -1), (0, 0, 9, 4, 6, 8, 2, 7, 1, 3, 5, 0), (1, 9, 4, 6, 8, 2, 7, 1, 3, 5, 0, 9), (2, 4, 6, 8, 2, 7, 1, 3, 5, 0, 9, 8), (3, 6, 8, 2, 7, 1, 3, 5, 0, 9, 4, 7),
      (4, 8, 2, 7, 1, 3, 5, 0, 9, 4, 6, 6), (5, 2, 7, 1, 3, 5, 0, 9, 4, 6, 8, 5), (6, 7, 1, 3, 5, 0, 9, 4, 6, 8, 2, 4), (7, 1, 3, 5, 0, 9, 4, 6, 8, 2, 7, 3), (8, 3, 5, 0, 9, 4, 6, 8, 2, 7, 1, 2), (9, 5, 0, 9, 4, 6, 8, 2, 7, 1, 3, 1));
  var
    i: Integer;
    zahl: Integer;
   p: Integer;
  begin
    try

      zahl := strtoint(s[1]);
      p := z[0, zahl];
      for i := 2 to Length(s) do
      begin
        zahl := strtoint(s[i]);
        p := z[p, zahl];
      end;
      Result := inttostr(z[p, 10]);

    except
      on E: Exception do
        Result := 'ungültige Zahl';
    end;
  end;

// Subfunction End
begin
  Result := PZiffer(ReplaceText(s, ' ', ''));
end;

function TReportForm.ParamByName(s: string): string;
// Gibt den Wert eines übergebenen Parameters mit
var
  i: Integer;
begin
  Result := '';
  if s = '' then // Wenn s='' dann alle Parameterwerte auflisten
  begin
    for i := 0 to ExternalParamas.Count - 1 do
    begin
      Result := Result + ExternalParamas.Items[i].Name + '=' + ExternalParamas.Items[i].asString + #13;
    end;
    Result := Result + 'USERNAME=' + RA_CURRENTUSER + #13;
    Result := Result + 'LOGINNAME=' + RA_CURRENTLOGIN + #13;
    Exit;
  end;
  if UpperCase(s) = 'USERNAME' then
    Result := RA_CURRENTUSER
  else if UpperCase(s) = 'LOGINNAME' then
    Result := RA_CURRENTLOGIN
  else
  begin
    if ExternalParamas.FindParam(s) <> nil then
      Result := ExternalParamas.ParamByName(s).asString;
  end;
end;

function TReportForm.EU: string;
var
  fs: TFormatSettings;
begin
  fs := TFormatSettings.Create;
  try
    Result := fs.CurrencyString;
  finally

  end;
end;

function TReportForm.SekundenInStunden(Sec: Integer; showSec: Boolean = true): String;
const
  SecPerDay = 86400;
  SecPerHour = 3600;
  SecPerMinute = 60;
var
  sekunden, h, m, s: Integer;
begin

  h := Sec div SecPerHour;
  sekunden := Sec - (h * SecPerHour);
  m := sekunden div SecPerMinute;
  sekunden := sekunden - (m * SecPerMinute);
  s := sekunden;
  Result := ':' + FormatFloat('00', s) + ' Sek';
  if not showSec then
    Result := '';
  Result := FormatFloat('00', m) + ' Min ' + Result;
  if h > 0 then
    Result := FormatFloat('00', h) + ' Std :' + Result;
end;

function TReportForm.ZahlInWort(n: Integer): string;
// Wandelt eine Zahl in Worte um
const
  Zahlen1: array [0 .. 9] of string = ('', 'zehn', 'zwan', 'drei', 'vier', 'fünf', 'sech', 'sieb', 'acht', 'neun');
  Zahlen: array [0 .. 9] of string = ('', 'ein', 'zwei', 'drei', 'vier', 'fünf', 'sechs', 'sieben', 'acht', 'neun');
var
  n100, n10, n1: Integer;
  s: string;
  function ZehnerUndEiner(n10, n1: Byte): string;
  var
    n: Integer;
  begin
    n := n10 * 10 + n1;
    Result := '';
    if n10 = 0 then
    begin
      if n1 > 0 then
        Result := Result + Zahlen[n1];
      if n1 = 1 then
        Result := Result + 's';
    end
    else
    begin
      if n10 = 1 then
      begin
        if n = 11 then
          Result := Result + 'elf'
        else if n = 12 then
          Result := Result + 'zwölf'
        else
          Result := Result + Zahlen1[n1] + 'zehn';
      end
      else
      begin
        Result := Result + Zahlen[n1];
        if n1 > 0 then
          Result := Result + 'und';
        Result := Result + Zahlen1[n10];
        if n10 <> 3 then
          Result := Result + 'zig'
        else
          Result := Result + 'ßig';
      end;
    end;
  end; { ZehnerUndEiner }

begin
  Result := '';
  if n = 0 then
  begin
    Result := 'null';
    Exit;
  end;
  if n >= 1000000000 then
  begin
    s := ZahlInWort(n div 1000000000);
    if s = 'eins' then
      Result := Result + 'einemilliarde'
    else
      Result := Result + s + 'milliarden';
    n := n mod 1000000000;
  end;
  if n >= 1000000 then
  begin
    s := ZahlInWort(n div 1000000);
    if s = 'eins' then
      Result := Result + 'einemillion'
    else
      Result := Result + s + 'millionen';
    n := n mod 1000000;
  end;
  if n >= 1000 then
  begin
    s := ZahlInWort(n div 1000);
    if s = 'eins' then
      s := 'ein';
    Result := Result + s + 'tausend';
    n := n mod 1000;
  end;
  n100 := n div 100;
  n := n mod 100;
  n10 := n div 10;
  n1 := n mod 10;
  if n100 <> 0 then
    Result := Result + Zahlen[n100] + 'hundert';
  Result := Result + ZehnerUndEiner(n10, n1);
  // result := Uppercase(Copy(result, 1, 1)) + Copy(result, 2, length(result));
end;

function TReportForm.ZeigeBelegt(Image: string; Definition: string; BelegtPlatzQuery: string; ZeigePlatznr: String = ''): string;
var
  pv: TfrxPictureView;
  FrXDS: TFRXDataset; // FRX-Dataset
  c: TfrxComponent;
  jpg: TJpegImage;
  MS: TMemorystream;
  bmp: TBitmap;
  p: TPoint;
  PNeu: TRect;
  tx: string;
  R: TRect;
  offs: Integer;
  Beschriftung: string;
  TagString: string;
  platzfest: Boolean;
  _info2: String;
  _platznummer: String;

  Function _FontSize: Integer;
  begin
    Result := 11;
  end;

  function PlatzPos(s: string; out PNeu: TRect): TPoint;
  var
    sl: TSTringlist;
    i: Integer;
    ts: string;
    Platzliste: TSTringlist;

  begin
    // "TXT="^"IDX=2"^"X=407"^"Y=280"^"ARC=0"

    // NEU:
    // "TXT=57"^"IDX=0"^"X=30"^"Y=743"^"X1=18"^"Y1=737"^"X2=148"^"Y2=752"^"ARC=0"
    MS:=nil;
    offs := 0;
    Result.x := -1;
    Result.x := -1;
    sl := TSTringlist.Create;
    Platzliste := TSTringlist.Create;
    Platzliste.Delimiter := '^';
    PNeu := TRect.Create(-1, -1, -1, -1);
    try
      sl.Text := Definition;
      for i := 1 to sl.Count - 1 do
      begin
        ts := Copy(sl[i], 1, Pos('^', sl[i]) - 1);
        ts := ReplaceText(ts, '~', ' '); // Leerzeichen in der Sitzplatzbezeichnung sind als ~ gespeichert
        if ts = '"TXT=' + s + '"' then
        begin
          Platzliste.delimitedtext := sl[i];
          try
            Result.x := strtoint(Platzliste.Values['X']);
            Result.Y := strtoint(Platzliste.Values['Y']);

            if Platzliste.IndexOfName('X1') >= 0 then
              PNeu.Left := strtoint(Platzliste.Values['X1']);

            if Platzliste.IndexOfName('Y1') >= 0 then
              PNeu.Top := strtoint(Platzliste.Values['Y1']);

            if Platzliste.IndexOfName('X2') >= 0 then
              PNeu.Right := strtoint(Platzliste.Values['X2']);

            if Platzliste.IndexOfName('Y2') >= 0 then
              PNeu.Bottom := strtoint(Platzliste.Values['Y2']);

            if (PNeu.Left < 0) or (PNeu.Top < 0) or (PNeu.Right < 0) or (PNeu.Bottom < 0) then
              PNeu := TRect.Create(-1, -1, -1, -1);
          except
          end;
        end;
      end;
    finally
      sl.Free;
      Platzliste.Free;
    end;
  end;

begin
  jpg:=nil;
  Result := '';
  if Trim(Definition) = '' then
    Exit;

  c := FastReport.FindObject(BelegtPlatzQuery);
  if (c = nil) then
    Exit;

  if (c is TFRXDataset) then
    FrXDS := TFRXDataset(c)
  else
    Exit;

  c := FastReport.FindObject(Image);
  if (c <> nil) then
  begin
    if c is TfrxPictureView then
    begin
      pv := TfrxPictureView(c);
      TagString := pv.TagStr;
      try
        jpg := TJpegImage.Create;
        MS := TMemorystream.Create;
        bmp := TBitmap.Create;
        bmp.canvas.brush.color := clred;
        bmp.canvas.Font.Name := 'ARIAL';
        bmp.canvas.Font.Size := _FontSize;
        bmp.canvas.Font.color := clwhite;

        if Assigned(pv.DataSet) and (pv.DataField <> '') and (pv.DataSet.IsBlobField(pv.DataField)) then
        begin
          pv.DataSet.AssignBlobTo(pv.DataField, MS);
          MS.Position := 0;
          jpg.LoadFromStream(MS);
          bmp.Assign(jpg);

          with FrXDS do
          begin
            FrXDS.First;
            while not eof do // Alle belegten Plätze markieren
            begin
              Beschriftung := '';
              _info2 := '';
              _platznummer := '';

              if FrXDS.HasField('BESCHRIFTUNG') then
                Beschriftung := Trim(Vartostr(FrXDS.Value['BESCHRIFTUNG']));
              if FrXDS.HasField('INFO2') then
                _info2 := Trim(Vartostr(FrXDS.Value['INFO2']))
              else
                _info2 := 'info2 fehlt';

              if FrXDS.HasField('PLATZNUMMER') then
                _platznummer := Trim(Vartostr(FrXDS.Value['PLATZNUMMER']))
              else
                _platznummer := 'platznummer fehlt';

              if ZeigePlatznr = '2' then // UpdateLog 2988, EW
                Beschriftung := Trim(Vartostr(FrXDS.Value['BESCHRIFTUNG'])) + ' ' + _info2;

              if ZeigePlatznr = '3' then // UpdateLog 2988, EW
                Beschriftung := _platznummer + '. ' + #13 + Trim(Vartostr(FrXDS.Value['BESCHRIFTUNG'])) + ' ' + _info2;

              platzfest := False;
              if FrXDS.HasField(TagString) then // Im Property des Picture TagStr als zusätzliche Beschreibung
              begin
                if (UpperCase(Trim(Vartostr(FrXDS.Value[TagString]))) = 'JA') and (UpperCase(TagString) = 'SITZFEST') then
                begin
                  platzfest := UpperCase(Trim(Vartostr(FrXDS.Value[TagString]))) = 'JA';
                  Beschriftung := '[x] ' + Beschriftung;
                end
                else if Trim(Vartostr(FrXDS.Value[TagString])) <> '' then
                  Beschriftung := Beschriftung + ' (' + Trim(Vartostr(FrXDS.Value[TagString])) + ')';

              end;

              tx := Trim(Vartostr(FrXDS.Value['PLATZNUMMER']));
              if tx <> '' then
              begin
                p := PlatzPos(tx, PNeu);
                if p.x > -1 then
                begin
                  if Trim(Beschriftung) = '' then
                  begin
                    offs := 16;
                    bmp.canvas.brush.color := clred;
                    bmp.canvas.Font.color := clwhite;
                    bmp.canvas.brush.Style := bsSolid;
                    bmp.canvas.Font.Size := _FontSize;
                    bmp.canvas.rectangle(p.x - offs, p.Y - offs, p.x + offs, p.Y + offs);
                    R := Rect(p.x - offs, p.Y - offs, p.x + offs, p.Y + offs);
                    bmp.canvas.TextRect(R, tx, [tfVerticalCenter, tfcenter, tfSingleLine]);
                  end
                  else
                  begin
                    If (UpperCase(ZeigePlatznr) <> '0') and (UpperCase(ZeigePlatznr) <> '3') then
                    begin
                      bmp.canvas.brush.color := clwhite;
                      bmp.canvas.brush.Style := bsClear;
                      bmp.canvas.Font.color := clblack;
                      if platzfest then
                        bmp.canvas.Font.color := clred;
                      bmp.canvas.Font.Size := _FontSize - 2;
                      R := Rect(p.x + 12, p.Y - 7, p.x + 120, p.Y + 30);
                      if PNeu.Width > 25 then
                      begin
                        R := Rect(PNeu.Left, PNeu.Top + 16, PNeu.Right, PNeu.Bottom + 16);
                      end;
                      DrawText(bmp.canvas.Handle, PCHar(Beschriftung), -1, R, DT_LEFT + DT_WORDBREAK);
                    end
                    else if (UpperCase(ZeigePlatznr) = '3') then
                    begin
                      bmp.canvas.brush.color := clwhite;
                      bmp.canvas.brush.Style := bsSolid;
                      bmp.canvas.pen.Style := psclear;
                      bmp.canvas.Font.color := clblack;
                      bmp.canvas.Font.Size := _FontSize - 2;
                      R := Rect(p.x - 12, p.Y - 6, p.x + 115, p.Y + 28);
                      if PNeu.Width > 25 then
                      begin
                        R := Rect(PNeu.Left, PNeu.Top, PNeu.Right, PNeu.Bottom + 32);
                      end;
                      bmp.canvas.rectangle(R);
                      DrawText(bmp.canvas.Handle, PCHar(Beschriftung), -1, R, DT_LEFT + DT_WORDBREAK);
                    end
                    else
                    begin
                      bmp.canvas.brush.color := clwhite;
                      bmp.canvas.brush.Style := bsSolid;
                      bmp.canvas.pen.Style := psclear;
                      bmp.canvas.Font.color := clblack;
                      bmp.canvas.Font.Size := _FontSize - 2;
                      R := Rect(p.x - 12, p.Y - 6, p.x + 115, p.Y + 28);
                      if PNeu.Width > 25 then
                      begin
                        R := Rect(PNeu.Left, PNeu.Top, PNeu.Right, PNeu.Bottom + 16);
                      end;
                      bmp.canvas.rectangle(R);
                      DrawText(bmp.canvas.Handle, PCHar(Beschriftung), -1, R, DT_LEFT + DT_WORDBREAK);
                    end

                  end;
                end;
              end;
              Next;
            end;
          end;
          pv.Picture.Assign(bmp);
        end;
      finally
        jpg.Free;
        MS.Free;
      end;
    end
    else
      Result := 'Kein gültiges Ziel: ' + Image;
  end;

end;

function TReportForm.ReplaceText(s: string; VonText: string; NachText: string): string;
begin
  Result := Strutils.ReplaceText(s, VonText, NachText);
end;

function TReportForm.POSTANSCHRIFT(s: string): string;
// Erzeugt eine Anschrift nach DIN 5008 aus einer übergebenen Abrage
var
  DS: TFRXDataset;
  function GetDatasetByName(Datasetname: string): TFRXDataset;
  var
    i : Integer;
    DS: Tfrxdatasetitem; // FRX-DatasetItem
    FrXDS: TFRXDataset; // FRX-Dataset
    ibxDS: TfrxIBXQuery;
  begin
    Result := nil;
    for i := 0 to FastReport.DataSets.Count - 1 do // Schleife durch alle Datasets
    begin
      DS := FastReport.DataSets[i]; // DS ist ein Tfrxdatasetitem
      FrXDS := DS.DataSet;
      ibxDS := TfrxIBXQuery(DS.DataSet); // Casting zu TfrxIBXQuery
      if AnsiUppercase(ibxDS.Name) = AnsiUppercase(Datasetname) then
      begin
        Result := FrXDS;
        break;
      end;
    end;
  end;
  function Feld(FieldName: string): string;
  begin
    Result := '';
    if DS.HasField(FieldName) then
      Result := Trim(Vartostr(DS.Value[FieldName]));
  end;

begin
  Result := '';
  DS := GetDatasetByName(s);
  if DS <> nil then
    with DS do
    begin
      Result := Result + Feld('Anrede') + #13;
      Result := Result + Trim(Feld('Titel') + ' ' + Trim(Feld('NAME1') + ' ' + Feld('NAME2')) + ' ' + Feld('Namenszusatz')) + #13;
      if Trim(Feld('AName1') + Feld('AName2')) <> '' then
        Result := Result + Trim(Trim(Trim(Trim(Feld('AAnrede') + ' ' + Feld('ATitel')) + ' ' + Feld('AName1')) + ' ' + Feld('AName2')) + ' ' + Feld('ANamenszusatz')) + #13
      else if Feld('Name3') <> '' then
        Result := Result + Feld('Name3') + #13;
      Result := Result + Feld('Strasse') + Feld('Strasse2') + #13;
      Result := Result + Trim(Feld('PLZ') + ' ' + Feld('Ort')) + #13;
      Result := Result + Feld('Land') + #13;
      Result := Trim(Result);
    end;
end;

function TReportForm.ZusatzFeld(Content: string; Wert: string): string;
var
  sl: TSTringlist;
  i: Integer;
begin
  Result := '';
  if Trim(Content) = '' then
    Exit;
  sl := TSTringlist.Create;
  sl.Text := ReplaceText(Trim(Content), '"', '');
  try
    if Trim(Wert) = '' then // Kompletten Content
    begin
      Result := ReplaceText(sl.Text, '"', '');
      Result := ReplaceText(Result, '=', ':   ');
      Result := ReplaceText(Result, '~', #13#10); // ~ ist ein Platzhalter für Zeilenvorschub
    end
    else if UpperCase(Wert) = 'LINES' then // Zeilenzahl aus CONTENT
    begin
      Result := inttostr(sl.Count);
    end
    else if UpperCase(Wert) = 'LABELS' then // NAMES aus CONTENT
    begin
      for i := 0 to sl.Count - 1 do
        Result := Result + sl.Names[i] + #13;
    end
    else if UpperCase(Wert) = 'FIELDS' then // VALUES aus CONTENT
    begin
      for i := 0 to sl.Count - 1 do
        Result := Result + ReplaceText(sl.ValueFromIndex[i], '~', #13#10) + #13; // ~ ist ein Platzhalter für Zeilenvorschub
    end
    else
    begin
      Result := ReplaceText(sl.Values[Wert], '~', #13#10); // ~ ist ein Platzhalter für Zeilenvorschub
    end;
    Result := Trim(Result)
  finally
    sl.Free;
  end;
end;

function TReportForm.ZahlAbrunden(Value: Extended; Digit: Integer): Extended;
// Eine Zahl auf Abfrunden (Hundertstel, Zehntel, einer Zehner usw.
var
  v: Extended;
  Mode: TFPURoundingMode;
begin
  v := Value;
  Mode := GetRoundMode;
  try
    setRoundMode(rmdown);
    Result := RoundTo(v, Digit);
  finally
    setRoundMode(Mode);
  end;
end;

function TReportForm.ZahlAufrunden(Value: Extended; Digit: Integer): Extended;
// Eine Zahl auf Aufrunden (Hundertstel, Zehntel, einer Zehner usw.
var
  v: Extended;
  Mode: TFPURoundingMode;
begin
  v := Value;
  Mode := GetRoundMode;
  try
    setRoundMode(rmup);
    Result := RoundTo(v, Digit);
  finally
    setRoundMode(Mode);
  end;
end;

// 2. Funktion anmelden
function TReportForm.frxReportOnUserFunction(const MethodName: string; var Params: Variant): Variant;
begin
  if MethodName = 'KW' then
    Result := WeekOfTheYear(Params[0]); // Unit "StrUtils"
  if MethodName = 'PRUEFZIFFER' then
    Result := PruefZiffer(Params[0]);
  if MethodName = 'TEXTFORMAT' then
    Result := TextFormat(Params[0]);
  if MethodName = 'PARAMBYNAME' then
    Result := ParamByName(Params[0]);
  if MethodName = 'POSTANSCHRIFT' then
    Result := POSTANSCHRIFT(Params[0]);
  if MethodName = 'ZAHLINWORT' then
    Result := ZahlInWort(Params[0]);
  if MethodName = 'SEKUNDENINSTUNDEN' then
    Result := SekundenInStunden(Params[0], Params[1]);
  if MethodName = 'ZEIGEBELEGT' then
    Result := ZeigeBelegt(Params[0], Params[1], Params[2], Params[3]);
  if MethodName = 'ZUSATZFELD' then
    Result := ZusatzFeld(Params[0], Params[1]);
  if MethodName = 'REPLACETEXT' then
    Result := ReplaceText(Params[0], Params[1], Params[2]);
  if MethodName = 'EU' then
    Result := EU;
  if MethodName = 'ABRUNDEN' then
    Result := ZahlAbrunden(Params[0], Params[1]);
  if MethodName = 'AUFRUNDEN' then
    Result := ZahlAufrunden(Params[0], Params[1]);
  // Procedur Aufruf
  // if MethodName='MYPROC' then
  // MyProc(Params[0]);

end;

// 3. Funktion an Report übergeben
procedure TReportForm.AddUserFunctions;
begin
  FastReport.OnUserFunction := frxReportOnUserFunction;
  FastReport.OnUserFunction := frxReportOnUserFunction;
  FastReport.AddFunction('Function KW(Datum: TDate): String', 'RATIO-Funktionen', 'Ermittelt die Kalenderwoche aus dem gegebenen Datum');
  FastReport.AddFunction('Function Pruefziffer(text: String): String', 'RATIO-Funktionen', 'ermittelt UBS-Prüfziffer');
  FastReport.AddFunction('Function TextFormat(text: String): String', 'RATIO-Funktionen', 'Wandelt Richtext (Text mit Schriftformatierung) in reinen Text um');
  FastReport.AddFunction('Function ParamByName(Parametername: String): String', 'RATIO-Funktionen', 'Wenn Parametername leer '''' dann Auflistung aller Parameter' + #13 + 'Gibt den Wert des Parameters zurück');
  FastReport.AddFunction('Function PostAnschrift(Queryname: String): String', 'RATIO-Funktionen',
    '(Queryname=Tabelle mit Adressfeldern) Um den Namen des Ansprechpartners einzufügen, müssen Felder wie z.B. ANAME1, ANAME2 usw. vorhanden sein' + #13 + 'Erzeugt eine Anschrit nach DIN 5008');
  FastReport.AddFunction('Function ZahlInWort(zahl:Integer): String', 'RATIO-Funktionen', 'ZahlInWort(zahl:Integer): String' + #13 + 'Gibt eine Zahl in Worten aus');
  FastReport.AddFunction('Function SekundenInStunden(Sec:Integer;showSec:boolean=true): String', 'RATIO-Funktionen', 'SekundenInStunden(Sec:Integer;showSec:boolean): String' + #13 +
    'Gibt Sekunden im Format Std., Min., Sek. aus. (01 Std:15 Min:10 Sek)' + #13 + '(showSec gibt an, ob auch Sekunden angezeigt werden sollen)');
  FastReport.AddFunction('Function Zeigebelegt(ZielImage:string;Definition:string;BelegtPlatzQuery:String;ZeigePlatzNr:String='')', 'RATIO-Funktionen',
    'ZielImage=Name Bildcomponente, Definition=Feld aus T_GERAET, BelegtPlatzQuery=Name der Query mit den Feldern PLATZNUMMER. Wenn Feld BESCHRIFTUNG vorhanden ist, wird es angezeigt. ZEIGEPLATZNR=(Siehe UpdateLog 2988)' + #13 +
    'Markiert alle belegten Plätze auf einem Sitzplatzspiegel' + #13 + '(WICHTIG:Funktion muss im selben Band des Bildes sein + [nach vorne setzen] )');
  FastReport.AddFunction('Function ZusatzFeld(Content:String;Wert:String): String', 'RATIO-Funktionen', 'ZusatzFeld(Content:String;Wert:String): String' + #13 + 'Liest einen Wert aus den benutzerdefinierten Feldern (Content)' + #13 +
    '(Wert: LABELS ALLE Labels,FIELDS alle Feldinhalte, LINES Anzahl Felder)');
  FastReport.AddFunction('Function Replacetext(S:String;Von:String;Nach:String): String', 'RATIO-Funktionen', 'Replacetext(S:String;Von:String;Nach:String): String' + #13 +
    'Ersetzt einen Text (Von) innerhalb einer Zeichenkette (S) durch einen anderen Text (Nach)' + #13 + 'Gross / Kleinschreibung bei [Von] ist hierbei gleichgültig)');
  FastReport.AddFunction('Function EU: String', 'RATIO-Funktionen', 'EU:String' + #13 + 'Gibt das Währungssymbol aus');
  FastReport.AddFunction('Function Aufrunden(zahl:Extended;genauigkeit:Integer):Extended', 'RATIO-Funktionen', 'Aufrunden(zahl:Extended;genauigkeit:Integer):Extended' + #13 + 'Aufrunden auf nächste Zahl' + #13 +
    '(Genauigkeit :0=Einer ,1=Zehner, 2=Hunderter... -1=Zehntel, -2=Hundertstel...)');
  FastReport.AddFunction('Function Abrunden(zahl:Extended;genauigkeit:Integer):Extended', 'RATIO-Funktionen', 'Abrunden(zahl:Extended;genauigkeit:Integer):Extended' + #13 + 'Abfrunden zur nächste Zahl' + #13 +
    '(Genauigkeit :0=Einer ,1=Zehner, 2=Hunderter... -1=Zehntel, -2=Hundertstel...)');

end;

end.
