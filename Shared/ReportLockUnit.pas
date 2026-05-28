unit ReportLockUnit;

interface

uses
  System.SyncObjs;

procedure AcquireReportLock;
procedure ReleaseReportLock;

implementation

var
  FReportLock: TCriticalSection;

procedure AcquireReportLock;
begin
  FReportLock.Acquire;
end;

procedure ReleaseReportLock;
begin
  FReportLock.Release;
end;

initialization

FReportLock := TCriticalSection.Create;

finalization

FReportLock.Free;

end.
