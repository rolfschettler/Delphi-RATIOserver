unit DataModulPrintClass;

interface

uses
  Web.HTTPApp, System.AnsiStrings, Fastrep,
  ReportLockUnit,
  System.SysUtils, System.Classes, DataModulBaseClass, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt, FireDAC.UI.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Phys, FireDAC.Phys.IB, FireDAC.Phys.IBDef, FireDAC.VCLUI.Wait, Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet;

type
  TDataModulPrint = class(TDataModulBaseClass)
  private
    { Private-Deklarationen }
    ReportForm: TReportForm;
  public
    { Public-Deklarationen }
    procedure Print();

  end;

function CreateDataModulPrint(Request: TWebRequest; Response: TWebResponse): TObject;

implementation

uses webUtils;

function CreateDataModulPrint(Request: TWebRequest; Response: TWebResponse): TObject;
begin
  Result := TDataModulPrint.Create(Request, Response);
end;

{%CLASSGROUP 'Vcl.Controls.TControl'}
{$R *.dfm}
{ TDataModulPrint }

// Route: /print  |  Auth: true  |  LocalOnly: TODO
procedure TDataModulPrint.Print;

var
  stream: TMemoryStream;
  formularname: string;
  art: string;
  bereich: string;

  i: integer;

  list: TParams;

begin

  list := nil;
  stream := TMemoryStream.Create;
  try
    AcquireReportLock; // ------------------------Muss sein, da Fastreport nicht 100% Threadfest------------------------------------
    ReportForm := TReportForm.Create(NIL);

    list := TParams.Create;
    // Parameter von der URL in Parameterliste ï¿½bertragen
    for i := 0 to Request.QueryFields.Count - 1 do
    begin
      list.CreateParam(ftWideString, Request.QueryFields.names[i], ptInput).asString := Request.QueryFields.values[Request.QueryFields.names[i]]
    end;

    formularname := Request.QueryFields.values['formularname'];
    bereich := Request.QueryFields.values['bereich'];
    art := Request.QueryFields.values['art'];
    try

      ReportForm.ExternalParamas := list;

      ReportForm.Connect(Connection); //Verbindung auf IBX umsetzten

      ReportForm.DoExportieren(bereich, art, formularname, 'PDF', '', stream);


      Response.ContentType := 'application/pdf';
      stream.Position := 0;

      Response.contentstream := stream;



    except
      on E: Exception do
      begin
        stream.free; // Für den Fall das keine Response gesendtet wurde, muss der "stream" manuell freigegeben werden
        // Response.StatusCode := 500; // MUSS 500 sein !!!!!!
        // Response.ContentType := 'text/plain';
        // Response.Content := 'Fehler beim Erstellen des Formulars:' + E.message;
        raise Exception.Create('Fehler beim Erstellen des Formulars:' + E.message);
      end;
    end;
  finally

    list.free;
    ReportForm.free;

    ReleaseReportLock; // ------------------------------------------------------------------------------------------------------------------------------
  end;
end;

end.
