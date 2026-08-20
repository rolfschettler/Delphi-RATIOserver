unit DataModulDokumenteClass;

interface

uses
  Web.HTTPApp,   System.JSON,
  DataModulTableBaseClass,
  System.SysUtils, System.Classes, DataModulBaseClass, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt, FireDAC.UI.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Phys, FireDAC.Phys.IB, FireDAC.Phys.IBDef, FireDAC.VCLUI.Wait, Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet;

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

end.
