program IBApiTest;
{$APPTYPE GUI}

uses
  Vcl.Forms,
  Web.WebReq,
  IdHTTPWebBrokerBridge,
  FormUnit1 in 'FormUnit1.pas' {Form1},
  WebModuleUnit1 in '..\Shared\WebModuleUnit1.pas' {WebModule1: TWebModule},
  DataModulBaseClass in '..\Shared\DataModuls\DataModulBaseClass.pas' {DataModulBaseClass: TDataModule},
  DataModulSQLClass in '..\Shared\DataModuls\DataModulSQLClass.pas' {DataModulSQL: TDataModule},
  DataModulAddOnClass in '..\Shared\DataModuls\DataModulAddOnClass.pas' {DataModulAddOn: TDataModule},
  DataModulPrintClass in '..\Shared\DataModuls\DataModulPrintClass.pas' {DataModulPrint: TDataModule},
  DataModulLoginClass in '..\Shared\DataModuls\DataModulLoginClass.pas' {DataModulLoginClass: TDataModule},
  DataModulTableBaseClass in '..\Shared\DataModuls\DataModulTableBaseClass.pas' {DataModulTableBase: TDataModule},
  DataModulAdressenClass in '..\Shared\DataModuls\DataModulAdressenClass.pas' {DataModulAdressen: TDataModule},
  DataModulTouristikClass in '..\Shared\DataModuls\DataModulTouristikClass.pas' {DataModulTouristik: TDataModule},
  DataModulAnmietClass in '..\Shared\DataModuls\DataModulAnmietClass.pas' {DataModulAnmiet: TDataModule},
  DataModulIncomingClass in '..\Shared\DataModuls\DataModulIncomingClass.pas' {DataModulIncoming: TDataModule},
  router in '..\Shared\router.pas',
  uJWTUtils in '..\Shared\uJWTUtils.pas',
  rechtelib in '..\Shared\rechtelib.pas',
  plugin in '..\Shared\plugin.pas',
  Fastrep in '..\Shared\Fastreport\Fastrep.pas' {ReportForm},
  PHPSupport in '..\Shared\PHPSupport.pas',
  KI_Support in '..\Shared\KI_Support.pas',
  webUtils in '..\Shared\webUtils.pas',
  DataModulPublicClass in '..\Shared\DataModuls\DataModulPublicClass.pas' {DataModulPublic: TDataModule};

{$R *.res}

begin
  if WebRequestHandler <> nil then
    WebRequestHandler.WebModuleClass := WebModuleClass;
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;

end.
