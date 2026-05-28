unit RechteLib;

interface

uses db, classes, dialogs, sysutils, windows;

Type
{
  RechteRec = Record
    vorgang: String[20];
    bereich: String[20];
    nr: Integer;
    Bezeichnung: String[40];
  end;

  RechteRecord = Class
    vorgang: String[20];
    bereich: String[20];
    nr: Integer;
    Bezeichnung: String[40];
  end;
  }

  RechteRec = Record
    vorgang: String;
    bereich: String;
    nr: Integer;
    Bezeichnung: String;
  end;

  RechteRecord = Class
    vorgang: String;
    bereich: String;
    nr: Integer;
    Bezeichnung: String;
  end;


Procedure SaveRechteToBlob(SList: TStrings; Feld: TField);
Function Codieren(wort: String): String;
Function DeCodieren(wort: String): String;

Procedure ReadRechteFromBlob(RechteSet: TDataset; SList, DList: TStrings; Feld: TField);

implementation

Procedure ReadRechteFromBlob(RechteSet: TDataset; SList, DList: TStrings; Feld: TField);
var
  Stream: TMemoryStream;
  i: Integer;
  readCount: Integer;
  r: RechteRec;
  Rc: RechteRecord;
  gefunden: Boolean;
begin
//  readCount := 0;
  Stream := TMemoryStream.create;
  (Feld as TBlobField).SaveToStream(Stream);
  Stream.seek(0, soFromBeginning);

  // DList mit Werten Füllen
  while True do
  begin
    readCount := Stream.Read(r, SizeOf(r));
    if readCount < SizeOf(r) then
      break;

    Rc := RechteRecord.create;
    Rc.vorgang := r.vorgang;
    Rc.bereich := r.bereich;
    Rc.nr := r.nr;
    Rc.Bezeichnung := r.Bezeichnung;
    DList.addObject(Rc.bereich + ' -' + Rc.Bezeichnung, Rc);
  End;

  // SList mit Werten füllen
  with RechteSet do
  begin
    Close;
    Open;
    First;
    While not eof do

    begin
      gefunden := False;
      For i := 0 to DList.count - 1 do
      begin
        If (Fieldbyname('nr').asInteger = RechteRecord(DList.objects[i]).nr) AND (Fieldbyname('BEREICH').asString = RechteRecord(DList.objects[i]).bereich) AND (Fieldbyname('VORGANG').asString = RechteRecord(DList.objects[i]).vorgang) then
        begin
          gefunden := True;
          break;
        end;
      end;
      If not gefunden then
      begin
        Rc := RechteRecord.create;
        Rc.vorgang := Fieldbyname('vorgang').asString;
        Rc.bereich := Fieldbyname('Bereich').asString;
        Rc.nr := Fieldbyname('nr').asInteger;
        Rc.Bezeichnung := Fieldbyname('Bezeichnung').asString;
        SList.addObject(Fieldbyname('BEREICH').asString + ' -' + Fieldbyname('Bezeichnung').asString, Rc);
      end;
      next;
    end;
  end;

end;

Procedure SaveRechteToBlob(SList: TStrings; Feld: TField);
var
  Stream: TMemoryStream;
  i: Integer;
  r: RechteRec;
begin
  Stream := TMemoryStream.create;
  For i := 0 to SList.count - 1 do
    with RechteRecord(SList.objects[i]) do
    begin
      r.vorgang := vorgang;
      r.nr := nr;
      r.bereich := bereich;
      r.Bezeichnung := Bezeichnung;
      Stream.write(r, SizeOf(r));
    end;
  Feld.dataset.edit;
  (Feld as TBlobField).LoadFromStream(Stream);
  Feld.dataset.Post;
end;

Function Codieren(wort: String): String;
Var
  i: Integer;
  s: PChar;
  key: String;
  l: Integer;
begin
  result := '';
  If wort = '' then
    Exit;
  key := '';
  l := length(wort);
  s := PChar(wort);
  For i := 1 to l do
  begin
    key := key + Chr((Ord(s[i - 1]) XOR (65 + i)));
  end;
  result := key;
end;

Function DeCodieren(wort: String): String;
Var
  i: Integer;
  s: PChar;
  key: String;
  l: Integer;
begin

  result := '';
  If wort = '' then
    Exit;
  key := '';

  l := length(wort);
  s := PChar(wort);
  // Sonderzeichen mit . abgeschlossen
  if copy(wort, length(wort), 1) = '.' then
    l := l - 1;

  For i := 1 to l do
  begin
    key := key + Chr((Ord(s[i - 1]) XOR (65 + i)));
  end;
  result := key;
end;

end.



