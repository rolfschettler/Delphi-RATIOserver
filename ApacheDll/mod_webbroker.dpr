library mod_webbroker;

uses
  {$IFDEF MSWINDOWS}
  Winapi.ActiveX,
  {$ENDIF }
  System.Win.ComObj,
  System.SyncObjs,
  Web.WebBroker,
  Web.ApacheApp,
  Web.HTTPD24Impl,
  WebModuleUnit1 in '..\Shared\WebModuleUnit1.pas' {WebModule1: TWebModule},
  DataModulBaseClass in '..\Shared\DataModuls\DataModulBaseClass.pas' {DataModulBaseClass: TDataModule},
  DataModulSQLClass in '..\Shared\DataModuls\DataModulSQLClass.pas' {DataModulSQL: TDataModule},
  DataModulAddOnClass in '..\Shared\DataModuls\DataModulAddOnClass.pas' {DataModulAddOn: TDataModule},
  DataModulPrintClass in '..\Shared\DataModuls\DataModulPrintClass.pas' {DataModulPrint: TDataModule},
  DataModulTableBaseClass in '..\Shared\DataModuls\DataModulTableBaseClass.pas' {DataModulTableBase: TDataModule},
  DataModulAdressenClass in '..\Shared\DataModuls\DataModulAdressenClass.pas' {DataModulAdressen: TDataModule},
  DataModulTouristikClass in '..\Shared\DataModuls\DataModulTouristikClass.pas' {DataModulTouristik: TDataModule},
  DataModulAnmietClass in '..\Shared\DataModuls\DataModulAnmietClass.pas' {DataModulAnmiet: TDataModule},
  DataModulIncomingClass in '..\Shared\DataModuls\DataModulIncomingClass.pas' {DataModulIncoming: TDataModule},
  DataModulPublicClass in '..\Shared\DataModuls\DataModulPublicClass.pas' {DataModulPublic: TDataModule},
  router in '..\Shared\router.pas',
  webUtils in '..\Shared\webUtils.pas',
  uJWTUtils in '..\Shared\uJWTUtils.pas',
  rechtelib in '..\Shared\rechtelib.pas',
  DataModulLoginClass in '..\Shared\DataModuls\DataModulLoginClass.pas' {DataModulLoginClass: TDataModule},
  plugin in '..\Shared\plugin.pas',
  Fastrep in '..\Shared\Fastreport\Fastrep.pas' {ReportForm},
  PHPSupport in '..\Shared\PHPSupport.pas',
  KI_Support in '..\Shared\KI_Support.pas' ;




{$R *.res}



// httpd.conf-Einträge:
//
(*
  LoadModule webbroker_module modules/mod_webbroker.dll

  <Location /xyz>
  SetHandler mod_webbroker-handler
  </Location>
*)
//
// Diese Einträge setzen voraus, dass das Ausgabeverzeichnis für dieses Projekt das apache/modules-Verzeichnis ist.
//
// httpd.conf-Einträge sollten unterschiedlich sein, wenn das Projekt auf eine der folgenden Weisen geändert wird:
// 1. Der Name der Variable TApacheModuleData wird geändert.
// 2. Das Projekt wird umbenannt.
// 3. Das Ausgabeverzeichnis ist nicht das Verzeichnis apache/modules.
// 4. Die Erweiterung der dynamischen Bibliothek ist von der Plattform abhängig. Verwenden Sie für Windows .dll und für Linux .so.
//

// Exportierte Variable deklarieren, damit Apache auf dieses Modul zugreifen kann.
var
  GModuleData: TApacheModuleData;


exports
  GModuleData name 'webbroker_module';

begin
{$IFDEF MSWINDOWS}
  CoInitFlags := COINIT_MULTITHREADED;
{$ENDIF}
  Web.ApacheApp.InitApplication(@GModuleData);
  Application.Initialize;
  Application.WebModuleClass := WebModuleClass;
  Application.Run;
end.
