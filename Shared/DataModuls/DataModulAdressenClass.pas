unit DataModulAdressenClass;

interface

uses
  Web.HTTPApp, System.SysUtils, System.Classes,
  DataModulTableBaseClass, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt, FireDAC.UI.Intf, FireDAC.Stan.Def,
  FireDAC.Stan.Pool, FireDAC.Phys, FireDAC.Phys.IB, FireDAC.Phys.IBDef, FireDAC.VCLUI.Wait, Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet;

type
  TDataModulAdressen = class(TDataModulTableBase)
  private

  public
    procedure getAdressen;
    procedure getAdressenFiltered;
   procedure getAdressenJoinedQuery;
    procedure getAdresseById;
    procedure getNextKennziffer;
    procedure getKategorien;
    procedure getKategorieById;
    procedure insertKategorie;
    procedure updateKategorie;
    procedure deleteKategorie;
    procedure insertAdresse;
    procedure updateAdresse;
    procedure deleteAdresse;
  end;

function CreateDataModulAdressen(Request: TWebRequest; Response: TWebResponse): TObject;

implementation

uses webutils;

function CreateDataModulAdressen(Request: TWebRequest; Response: TWebResponse): TObject;
begin
  Result := TDataModulAdressen.Create(Request, Response);
end;

{%CLASSGROUP 'Vcl.Controls.TControl'}
{$R *.dfm}

{ TDataModulAdressen }

// Route: /getadressen  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getAdressen;
// Body: { "fields": ["kennziffer","name1",...] | "*", "orderby": "name1" }
const
  ALLOWED: array[0..12] of string = (
    'kennziffer','gruppe','anrede','titel','name1','name2',
    'strasse','plz','ort','telefon1','email','matchcode','lvorgang'
  );
begin
  DoSelect('ADRESSEN', ALLOWED);
end;

// Route: /getadressenfiltered  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getAdressenFiltered;
// Body: { "fields": [...] | "*", "gruppe": "K", "orderby": "name1" }
const
  ALLOWED: array[0..12] of string = (
    'kennziffer','gruppe','anrede','titel','name1','name2',
    'strasse','plz','ort','telefon1','email','matchcode','lvorgang'
  );
  FILTER        = 'gruppe = :gruppe';
  FILTER_PARAMS: array[0..0] of string = ('gruppe');
begin
  DoSelectFiltered('ADRESSEN', ALLOWED, FILTER, FILTER_PARAMS);
end;


// Route: /getjoin  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getAdressenJoinedQuery;
// Body: {  "gruppe": 1,"name1":"Helga" }
const
  FILTER_PARAMS: array[0..1] of string = ('gruppe','name1');
begin
  var joinedSql:='Select a.name1,a.name2,a.ort,a.gruppe,k.bezeichnung from adressen a join adrkats k on a.gruppe=k.gruppe where a.name1=:name1 and a.gruppe= :gruppe';
  DoJoinedSelect(joinedSql, FILTER_PARAMS);
end;




// Route: /getadressebyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getAdresseById;
// Body: { "kennziffer": 42, "fields": [...] | "*" }
const
  ALLOWED: array[0..10] of string = (
    'kennziffer','gruppe','anrede','titel','name1','name2',
    'strasse','plz','ort','telefon1','email'
  );
begin
  DoSelectOne('ADRESSEN', ALLOWED, 'kennziffer');
end;

// Route: /getnextkennziffer  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getNextKennziffer;
begin
  Query.SQL.Text := 'SELECT * FROM ADRESSEN_NEXTKENNZIFFER';
  Query.Open;
  Response.ContentType := 'application/json';
  Response.StatusCode  := 200;
  Response.Content     := SerializeQuery(Query);
end;

// Route: /adressen/getkategorien  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getKategorien;
// Body: { "fields": ["gruppe","bezeichnung",...] | "*", "orderby": "bezeichnung" }
const
  ALLOWED: array[0..27] of string = (
    'gruppe','kat1','kat2','kat3','kat4','kat5','kat6','kat7',
    'kat8','kat9','kat10','kat11','kat12','bezeichnung','debitkredit',
    'symbol','kat13','kat14','kat15','kat16','kat17','kat18','kat19',
    'kat20','kat21','kat22','kat23','kat24'
  );
begin
  DoSelect('ADRKATS', ALLOWED);
end;

// Route: /adressen/getkategoriebyid  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.getKategorieById;
// Body: { "gruppe": 1, "fields": [...] | "*" }
const
  ALLOWED: array[0..27] of string = (
    'gruppe','kat1','kat2','kat3','kat4','kat5','kat6','kat7',
    'kat8','kat9','kat10','kat11','kat12','bezeichnung','debitkredit',
    'symbol','kat13','kat14','kat15','kat16','kat17','kat18','kat19',
    'kat20','kat21','kat22','kat23','kat24'
  );
begin
  DoSelectOne('ADRKATS', ALLOWED, 'gruppe');
end;

// Route: /adressen/insertkategorie  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.insertKategorie;
// Body: { "gruppe": 1, "bezeichnung": "...", "kat1": "...", ... }
const
  ALLOWED: array[0..27] of string = (
    'gruppe','kat1','kat2','kat3','kat4','kat5','kat6','kat7',
    'kat8','kat9','kat10','kat11','kat12','bezeichnung','debitkredit',
    'symbol','kat13','kat14','kat15','kat16','kat17','kat18','kat19',
    'kat20','kat21','kat22','kat23','kat24'
  );
begin
  DoInsert('ADRKATS', ALLOWED);
end;

// Route: /adressen/updatekategorie  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.updateKategorie;
// Body: { "gruppe": 1, "bezeichnung": "...", "kat1": "...", ... }
const
  ALLOWED: array[0..26] of string = (
    'kat1','kat2','kat3','kat4','kat5','kat6','kat7',
    'kat8','kat9','kat10','kat11','kat12','bezeichnung','debitkredit',
    'symbol','kat13','kat14','kat15','kat16','kat17','kat18','kat19',
    'kat20','kat21','kat22','kat23','kat24'
  );
begin
  DoUpdate('ADRKATS', ALLOWED, 'gruppe');
end;

// Route: /adressen/deletekategorie  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.deleteKategorie;
// Body: { "gruppe": 1 }
begin
  DoDelete('ADRKATS', 'gruppe');
end;

// Route: /insertadresse  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.insertAdresse;
// Body: { "name1": "...", "ort": "...", ... }
const
  ALLOWED: array[0..10] of string = (
    'gruppe','anrede','titel','name1','name2','strasse','plz','ort','telefon1','email','code'
  );
begin
  DoInsert('ADRESSEN', ALLOWED);
end;

// Route: /updateadresse  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.updateAdresse;
// Body: { "kennziffer": 42, "name1": "...", ... }
const
  ALLOWED: array[0..9] of string = (
    'gruppe','anrede','titel','name1','name2','strasse','plz','ort','telefon1','email'
  );
begin
  DoUpdate('ADRESSEN', ALLOWED, 'kennziffer');
end;

// Route: /deleteadresse  |  Auth: true  |  LocalOnly: false
procedure TDataModulAdressen.deleteAdresse;
// Body: { "kennziffer": 42 }
begin
  DoDelete('ADRESSEN', 'kennziffer');
end;

end.
