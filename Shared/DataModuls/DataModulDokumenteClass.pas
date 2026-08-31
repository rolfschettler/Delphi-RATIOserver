unit DataModulDokumenteClass;

interface

uses
  Web.HTTPApp,   System.JSON,
  DataModulTableBaseClass,
  System.SysUtils, System.Classes, DataModulBaseClass, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt, FireDAC.UI.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Phys, FireDAC.Phys.IB, FireDAC.Phys.IBDef, FireDAC.VCLUI.Wait, Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet,
  System.NetEncoding, System.RegularExpressions;

type
  TDataModulDokumente = class(TDataModulTableBase)
  private
    { Private-Deklarationen }
  public
    { Public-Deklarationen }
    procedure Demo;
    procedure getVorlagen;
    procedure getVorlagenFiltered;
    procedure getVorlagenById;
    procedure getVorlagenKey;
    procedure insertVorlagen;
    procedure updateVorlagen;
    procedure deleteVorlagen;
    procedure uploadDokument;
    procedure getT_Bildtext;
    procedure getT_BildtextFiltered;
    procedure getT_BildtextById;
    procedure insertT_Bildtext;
    procedure updateT_Bildtext;
    procedure deleteT_Bildtext;
  end;


function CreateDataModulDokumente(Request: TWebRequest; Response: TWebResponse): TObject;

implementation
uses webutils;

function CreateDataModulDokumente(Request: TWebRequest; Response: TWebResponse): TObject;
begin
  Result := TDataModulDokumente.Create(Request, Response);
end;

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}

procedure TDataModulDokumente.Demo;
var
  idText      : string;
  id          : Integer;
  idGesetzt   : Boolean;
  filter      : string;
  name        : string;
  nameGesetzt : Boolean;
  menge       : Integer;
  mengeGesetzt: Boolean;
  UrlObj, BodyObj, Ergebnis: TJSONObject;
begin
  idText    := Trim(Request.QueryFields.Values['id']);
  idGesetzt := idText <> '';
  id        := StrToIntDef(idText, 0);

  filter := Trim(Request.QueryFields.Values['filter']);

  nameGesetzt := isParamFromBody('name');
  name        := getParamFromBody('name');

  mengeGesetzt := isParamFromBody('menge');
  menge        := StrToIntDef(getParamFromBody('menge'), 0);

  UrlObj := TJSONObject.Create;
  UrlObj.AddPair('id',     JsonOrNull(idGesetzt,    id));
  UrlObj.AddPair('filter', JsonOrNull(filter <> '', filter));

  BodyObj := TJSONObject.Create;
  BodyObj.AddPair('name',  JsonOrNull(nameGesetzt,  name));
  BodyObj.AddPair('menge', JsonOrNull(mengeGesetzt, menge));

  Ergebnis := TJSONObject.Create;
  Ergebnis.AddPair('url',  UrlObj);
  Ergebnis.AddPair('body', BodyObj);
  SendJson(Ergebnis);
end;


// Route: /dokumente/getvorlagen  |  Auth: true  |  LocalOnly: false
procedure TDataModulDokumente.getVorlagen;
// Body: { "fields": ["nr","name",...] | "*", "orderby": "name" }
const
  ALLOWED: array[0..33] of string = (
    'nr','haupttext','art','standard','name','text1','text2','drucker',
    'druckerwahl','folgeformular','datum','angepasst','bereich','doktyp',
    'versteckt','dokkategorie','geaendertam','bearbeiter','pwd','archiv',
    'dms_key','wiedervorlage','gueltigbis','reftable','refnr',
    'datumfeld1','datumfeld2','zusatzfeld1','zusatzfeld2','anmietnr',
    'senderemail','empfaengeremail','dateiname','mandant'
  );
begin
  DoSelect('VORLAGEN', ALLOWED);
end;

// Route: /dokumente/getvorlagenfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulDokumente.getVorlagenFiltered;
// Body: { "fields": [...] | "*", "art": "...", "name": "...", "bereich": "...", "orderby": "name" }
const
  ALLOWED: array[0..33] of string = (
    'nr','haupttext','art','standard','name','text1','text2','drucker',
    'druckerwahl','folgeformular','datum','angepasst','bereich','doktyp',
    'versteckt','dokkategorie','geaendertam','bearbeiter','pwd','archiv',
    'dms_key','wiedervorlage','gueltigbis','reftable','refnr',
    'datumfeld1','datumfeld2','zusatzfeld1','zusatzfeld2','anmietnr',
    'senderemail','empfaengeremail','dateiname','mandant'
  );
  CONDITIONS: array[0..10] of string = (
    'art = :art',
    'name = :name',
    'bereich = :bereich',
    'doktyp = :doktyp',
    'dokkategorie = :dokkategorie',
    'archiv = :archiv',
    'versteckt = :versteckt',
    'reftable = :reftable',
    'refnr = :refnr',
    'mandant = :mandant',
    'text2 = :text2'
  );
  FILTER_PARAMS: array[0..10] of string = (
    'art','name','bereich','doktyp','dokkategorie','archiv','versteckt','reftable','refnr','mandant','text2'
  );
begin
  DoSelectFilteredDynamic('VORLAGEN', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /dokumente/getvorlagenbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulDokumente.getVorlagenById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..33] of string = (
    'nr','haupttext','art','standard','name','text1','text2','drucker',
    'druckerwahl','folgeformular','datum','angepasst','bereich','doktyp',
    'versteckt','dokkategorie','geaendertam','bearbeiter','pwd','archiv',
    'dms_key','wiedervorlage','gueltigbis','reftable','refnr',
    'datumfeld1','datumfeld2','zusatzfeld1','zusatzfeld2','anmietnr',
    'senderemail','empfaengeremail','dateiname','mandant'
  );
begin
  DoSelectOne('VORLAGEN', ALLOWED, 'nr');
end;

// Route: /dokumente/getvorlagenkey  |  Auth: true  |  LocalOnly: false
procedure TDataModulDokumente.getVorlagenKey;
begin
  Query.SQL.Text := 'SELECT GEN_ID(VORLAGENNR,1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /dokumente/insertvorlagen  |  Auth: true  |  LocalOnly: false
procedure TDataModulDokumente.insertVorlagen;
// Body: { "nr": 1, "name": "...", "art": "...", ... }
const
  ALLOWED: array[0..33] of string = (
    'nr','haupttext','art','standard','name','text1','text2','drucker',
    'druckerwahl','folgeformular','datum','angepasst','bereich','doktyp',
    'versteckt','dokkategorie','geaendertam','bearbeiter','pwd','archiv',
    'dms_key','wiedervorlage','gueltigbis','reftable','refnr',
    'datumfeld1','datumfeld2','zusatzfeld1','zusatzfeld2','anmietnr',
    'senderemail','empfaengeremail','dateiname','mandant'
  );
begin
  DoInsert('VORLAGEN', ALLOWED);
end;

procedure TDataModulDokumente.uploadDokument;
var

  i: Integer;
  text1,text2,bereich,bearbeiter: string;

  name,art:string;
  datum:Tdate;
  Q: TFDQuery;


begin



  Q := TFDQuery.Create(nil);
  Q.Connection:=Connection;

  try
      text1 := Request.ContentFields.Values['text1'];
      text2 := Request.ContentFields.Values['text2'];
      bereich := Request.ContentFields.Values['bereich'];
      datum:=date();
      Connection.StartTransaction;
      try
          for i := 0 to Request.Files.Count - 1 do
          begin
            Request.Files[i].Stream.Position:=0;

            art:=lowercase(ExtractFileExt(Request.Files[i].FileName));
            name:=copy(Request.Files[i].FileName,1,30);

            Q.SQL.Text :='INSERT INTO VORLAGEN (ART,NAME, DATUM,GEAENDERTAM,DOKTYP,TEXT1,TEXT2,BEREICH,BEARBEITER, HAUPTTEXT) VALUES (:ART,:NAME, :DATUM,:GEAENDERTAM, :DOKTYP, :TEXT1,:TEXT2,:BEREICH,:BEARBEITER,:HAUPTTEXT)';
            Q.ParamByName('ART').AsString := art;
            Q.ParamByName('NAME').AsString := Name;
            Q.ParamByName('TEXT1').AsString := copy(text1,1,200);
            Q.ParamByName('TEXT2').AsString := copy(text2,1,200);
            Q.ParamByName('BEREICH').AsString := copy(bereich,1,20);
            Q.ParamByName('DOKTYP').AsString := 'D';
            Q.ParamByName('BEARBEITER').AsString := copy(bearbeiter,1,30);
            Q.ParamByName('GEAENDERTAM').Asdate := datum;
            Q.ParamByName('DATUM').Asdate := datum;
            Q.ParamByName('HAUPTTEXT').LoadFromStream(Request.Files[i].Stream, ftBlob);
            Q.ExecSQL;
          end;

      Response.ContentType := 'application/json';
      Response.StatusCode := 200;
      Response.Content := '{"status":"OK"}';
      Connection.Commit;
    except
      on E: exception do
      begin
        if Connection.InTransaction then
          Connection.Rollback;
        raise;
      end;
    end;

  finally
    Q.Free;


  end;
end;






// Route: /dokumente/updatevorlagen  |  Auth: true  |  LocalOnly: false
procedure TDataModulDokumente.updateVorlagen;
// Body: { "nr": 42, "name": "...", "art": "...", ... }
const
  ALLOWED: array[0..32] of string = (
    'haupttext','art','standard','name','text1','text2','drucker',
    'druckerwahl','folgeformular','datum','angepasst','bereich','doktyp',
    'versteckt','dokkategorie','geaendertam','bearbeiter','pwd','archiv',
    'dms_key','wiedervorlage','gueltigbis','reftable','refnr',
    'datumfeld1','datumfeld2','zusatzfeld1','zusatzfeld2','anmietnr',
    'senderemail','empfaengeremail','dateiname','mandant'
  );
begin
  DoUpdate('VORLAGEN', ALLOWED, 'nr');
end;

// Route: /dokumente/deletevorlagen  |  Auth: true  |  LocalOnly: false
procedure TDataModulDokumente.deleteVorlagen;
// Body: { "nr": 42 }
begin
  DoDelete('VORLAGEN', 'nr');
end;

// Route: /dokumente/gett_bildtext  |  Auth: true  |  LocalOnly: false
procedure TDataModulDokumente.getT_Bildtext;
// Body: { "fields": ["nr","kategorie",...] | "*", "orderby": "nr" }
// BILD und TEXT werden als Base64-String zurueckgegeben (SerializeQuery
// codiert BLOB-Felder standardmaessig nach Base64).
const
  ALLOWED: array[0..21] of string = (
    'nr','reftable','refnr','bildindex','bildmodifed','textmodified','kategorie',
    'bild','text','lastlock','copr','sprache','internet','app','externe_id',
    'nutzungsrecht_bis','urheber','erfasst_am','versteckt','bildformat',
    'textformat','bereich'
  );
begin
  DoSelect('T_BILDTEXT', ALLOWED);
end;

// Route: /dokumente/gett_bildtextfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulDokumente.getT_BildtextFiltered;
// Body: { "fields": [...] | "*", "reftable": "...", "refnr": 42, "kategorie": "...", "orderby": "nr" }
// BILD und TEXT sind BLOB-Felder und deshalb nur in ALLOWED, nie als Filter.
const
  ALLOWED: array[0..21] of string = (
    'nr','reftable','refnr','bildindex','bildmodifed','textmodified','kategorie',
    'bild','text','lastlock','copr','sprache','internet','app','externe_id',
    'nutzungsrecht_bis','urheber','erfasst_am','versteckt','bildformat',
    'textformat','bereich'
  );
  CONDITIONS: array[0..7] of string = (
    'reftable = :reftable',
    'refnr = :refnr',
    'kategorie = :kategorie',
    'sprache = :sprache',
    'internet = :internet',
    'app = :app',
    'versteckt = :versteckt',
    'bereich = :bereich'
  );
  FILTER_PARAMS: array[0..7] of string = (
    'reftable','refnr','kategorie','sprache','internet','app','versteckt','bereich'
  );
begin
  DoSelectFilteredDynamic('T_BILDTEXT', ALLOWED, CONDITIONS, FILTER_PARAMS);
end;

// Route: /dokumente/gett_bildtextbyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulDokumente.getT_BildtextById;
// Body: { "nr": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..21] of string = (
    'nr','reftable','refnr','bildindex','bildmodifed','textmodified','kategorie',
    'bild','text','lastlock','copr','sprache','internet','app','externe_id',
    'nutzungsrecht_bis','urheber','erfasst_am','versteckt','bildformat',
    'textformat','bereich'
  );
begin
  DoSelectOne('T_BILDTEXT', ALLOWED, 'nr');
end;

// Prueft, ob AValue syntaktisch gueltiges Base64 ist (Zeichensatz + Laenge/Padding).
// Leerstring gilt als gueltig (entspricht einem leeren Blob).
function IsValidBase64Value(const AValue: string): Boolean;
begin
  Result := (AValue = '') or
    (((Length(AValue) mod 4) = 0) and
     TRegEx.IsMatch(AValue, '^[A-Za-z0-9+/]*={0,2}$'));
end;

// Prueft die JPEG-Signatur (Magic Bytes): SOI FF D8 FF am Anfang, EOI FF D9
// am Ende. Kein vollstaendiges Dekodieren, nur Format-Erkennung.
function IsValidJpegSignature(const ABytes: TBytes): Boolean;
var
  Len: Integer;
begin
  Len := Length(ABytes);
  Result := (Len >= 4) and
    (ABytes[0] = $FF) and (ABytes[1] = $D8) and (ABytes[2] = $FF) and
    (ABytes[Len - 2] = $FF) and (ABytes[Len - 1] = $D9);
end;

// Route: /dokumente/insertt_bildtext  |  Auth: true  |  LocalOnly: false
procedure TDataModulDokumente.insertT_Bildtext;
// Body: { "reftable": "...", "refnr": 42, "kategorie": "...", ...,
//         "bild": "<Base64>", "text": "<Base64>" }
// NR wird serverseitig per GEN_ID(T_BILDTEXT_NR_GEN,1) erzeugt, nicht aus dem Body.
// BILD und TEXT sind Base64-codierte Blob-Felder, optional; JSON-null ist
// erlaubt (Blob bleibt dann NULL). Sind sie gesetzt, wird der Base64-Wert vor
// dem Schreiben auf syntaktische Gueltigkeit geprueft.
const
  ALLOWED: array[0..18] of string = (
    'reftable','refnr','bildindex','bildmodifed','textmodified','kategorie',
    'lastlock','copr','sprache','internet','app','externe_id',
    'nutzungsrecht_bis','urheber','erfasst_am','versteckt','bildformat',
    'textformat','bereich'
  );
  BLOB_ALLOWED: array[0..1] of string = ('bild','text');
var
  Q: TFDQuery;
  Cols, Vals, Field, Base64Value: string;
  i: Integer;
  Nr: Integer;
  Bytes: TBytes;
  Stream: TMemoryStream;
begin
  Query.SQL.Text := 'SELECT GEN_ID(T_BILDTEXT_NR_GEN,1) AS nr FROM RDB$DATABASE';
  Query.Open;
  Nr := Query.FieldByName('nr').AsInteger;
  Query.Close;

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := Connection;
    Cols := 'nr'; Vals := ':nr';

    for i := Low(ALLOWED) to High(ALLOWED) do
      if isParamFromBody(ALLOWED[i]) then
      begin
        Cols := Cols + ',' + ALLOWED[i];
        Vals := Vals + ',:' + ALLOWED[i];
      end;

    for i := Low(BLOB_ALLOWED) to High(BLOB_ALLOWED) do
      if isKeyInBody(BLOB_ALLOWED[i]) then
      begin
        Cols := Cols + ',' + BLOB_ALLOWED[i];
        Vals := Vals + ',:' + BLOB_ALLOWED[i];
      end;

    Q.SQL.Text := 'INSERT INTO T_BILDTEXT (' + Cols + ') VALUES (' + Vals + ')';
    Q.ParamByName('nr').AsInteger := Nr;

    for i := Low(ALLOWED) to High(ALLOWED) do
      if isParamFromBody(ALLOWED[i]) then
        Q.ParamByName(ALLOWED[i]).Value := getParamFromBody(ALLOWED[i]);

    for i := Low(BLOB_ALLOWED) to High(BLOB_ALLOWED) do
    begin
      Field := BLOB_ALLOWED[i];
      if not isKeyInBody(Field) then Continue;

      if not isParamFromBody(Field) then
      begin
        // Feld war im Body vorhanden, aber JSON-null -> Blob bleibt NULL.
        Q.ParamByName(Field).Clear;
        Continue;
      end;

      Base64Value := getParamFromBody(Field);
      if not IsValidBase64Value(Base64Value) then
        raise Exception.Create('Feld "' + Field + '": kein gueltiger Base64-Wert.');

      try
        Bytes := TNetEncoding.Base64.DecodeStringToBytes(Base64Value);
      except
        on E: Exception do
          raise Exception.Create('Feld "' + Field + '": Base64-Dekodierung fehlgeschlagen (' + E.Message + ').');
      end;

      if SameText(Field, 'bild') and (Length(Bytes) > 0) and
         not IsValidJpegSignature(Bytes) then
        raise Exception.Create('Feld "bild": keine gueltige JPEG-Bilddatei (Signatur ungueltig).');

      Stream := TMemoryStream.Create;
      try
        if Length(Bytes) > 0 then
          Stream.WriteBuffer(Bytes[0], Length(Bytes));
        Stream.Position := 0;
        Q.ParamByName(Field).LoadFromStream(Stream, ftBlob);
      finally
        Stream.Free;
      end;
    end;

    Connection.StartTransaction;
    try
      Q.ExecSQL;
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
    Response.Content     := Format('{"status":"OK","nr":%d}', [Nr]);
  finally
    Q.Free;
  end;
end;

// Route: /dokumente/updatet_bildtext  |  Auth: true  |  LocalOnly: false
procedure TDataModulDokumente.updateT_Bildtext;
// Body: { "nr": 42, "reftable": "...", "refnr": 42, "kategorie": "...", ...,
//         "bild": "<Base64>", "text": "<Base64>" }
// NR ist der Schluessel (WHERE nr = :nr) und wird nicht mitgeschrieben.
// BILD und TEXT sind Base64-codierte Blob-Felder, optional; JSON-null ist
// erlaubt (Blob wird dann auf NULL gesetzt). Sind sie gesetzt, wird der
// Base64-Wert vor dem Schreiben auf syntaktische Gueltigkeit geprueft; bei
// "bild" zusaetzlich auf gueltige JPEG-Signatur.
const
  ALLOWED: array[0..18] of string = (
    'reftable','refnr','bildindex','bildmodifed','textmodified','kategorie',
    'lastlock','copr','sprache','internet','app','externe_id',
    'nutzungsrecht_bis','urheber','erfasst_am','versteckt','bildformat',
    'textformat','bereich'
  );
  BLOB_ALLOWED: array[0..1] of string = ('bild','text');
var
  Q: TFDQuery;
  SetClause, Field, Base64Value: string;
  i: Integer;
  Nr: Integer;
  Bytes: TBytes;
  Stream: TMemoryStream;
begin
  if not isParamFromBody('nr') then
    raise Exception.Create('Feld "nr" fehlt.');
  Nr := StrToIntDef(getParamFromBody('nr'), 0);

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := Connection;
    SetClause := '';

    for i := Low(ALLOWED) to High(ALLOWED) do
      if isParamFromBody(ALLOWED[i]) then
      begin
        if SetClause <> '' then SetClause := SetClause + ',';
        SetClause := SetClause + ALLOWED[i] + ' = :' + ALLOWED[i];
      end;

    for i := Low(BLOB_ALLOWED) to High(BLOB_ALLOWED) do
      if isKeyInBody(BLOB_ALLOWED[i]) then
      begin
        if SetClause <> '' then SetClause := SetClause + ',';
        SetClause := SetClause + BLOB_ALLOWED[i] + ' = :' + BLOB_ALLOWED[i];
      end;

    if SetClause = '' then
      raise Exception.Create('Keine gueltigen Felder uebergeben.');

    Q.SQL.Text := 'UPDATE T_BILDTEXT SET ' + SetClause + ' WHERE nr = :nr';
    Q.ParamByName('nr').AsInteger := Nr;

    for i := Low(ALLOWED) to High(ALLOWED) do
      if isParamFromBody(ALLOWED[i]) then
        Q.ParamByName(ALLOWED[i]).Value := getParamFromBody(ALLOWED[i]);

    for i := Low(BLOB_ALLOWED) to High(BLOB_ALLOWED) do
    begin
      Field := BLOB_ALLOWED[i];
      if not isKeyInBody(Field) then Continue;

      if not isParamFromBody(Field) then
      begin
        // Feld war im Body vorhanden, aber JSON-null -> Blob wird NULL.
        Q.ParamByName(Field).Clear;
        Continue;
      end;

      Base64Value := getParamFromBody(Field);
      if not IsValidBase64Value(Base64Value) then
        raise Exception.Create('Feld "' + Field + '": kein gueltiger Base64-Wert.');

      try
        Bytes := TNetEncoding.Base64.DecodeStringToBytes(Base64Value);
      except
        on E: Exception do
          raise Exception.Create('Feld "' + Field + '": Base64-Dekodierung fehlgeschlagen (' + E.Message + ').');
      end;

      if SameText(Field, 'bild') and (Length(Bytes) > 0) and
         not IsValidJpegSignature(Bytes) then
        raise Exception.Create('Feld "bild": keine gueltige JPEG-Bilddatei (Signatur ungueltig).');

      Stream := TMemoryStream.Create;
      try
        if Length(Bytes) > 0 then
          Stream.WriteBuffer(Bytes[0], Length(Bytes));
        Stream.Position := 0;
        Q.ParamByName(Field).LoadFromStream(Stream, ftBlob);
      finally
        Stream.Free;
      end;
    end;

    Connection.StartTransaction;
    try
      Q.ExecSQL;
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
    Response.Content     := '{"status":"OK"}';
  finally
    Q.Free;
  end;
end;

// Route: /dokumente/deletet_bildtext  |  Auth: true  |  LocalOnly: false
procedure TDataModulDokumente.deleteT_Bildtext;
// Body: { "nr": 42 }
begin
  DoDelete('T_BILDTEXT', 'nr');
end;

end.
