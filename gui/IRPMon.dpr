program IRPMon;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

{$R 'uac.res' 'uac.rc'}

uses
{$IFnDEF FPC}
  WinSvc,
{$ELSE}
  jwaWinSvc,
  Interfaces,
{$ENDIF}
  Windows,
  SysUtils,
  Forms,
  MainForm in 'MainForm.pas' {MainFrm},
  IRPMonDll in 'IRPMonDll.pas',
  IRPMonRequest in 'IRPMonRequest.pas',
  Utils in 'Utils.pas',
  ListModel in 'ListModel.pas',
  RequestListModel in 'RequestListModel.pas',
  IRPRequest in 'IRPRequest.pas',
  NameTables in 'NameTables.pas',
  RequestFilter in 'RequestFilter.pas',
  TreeForm in 'TreeForm.pas' {TreeFrm},
  HookObjects in 'HookObjects.pas',
  HookProgressForm in 'HookProgressForm.pas' {HookProgressFrm},
  RequestThread in 'RequestThread.pas',
  RequestDetailsForm in 'RequestDetailsForm.pas' {RequestDetailsFrm},
  AboutForm in 'AboutForm.pas' {AboutBox},
  ClassWatch in 'ClassWatch.pas',
  ClassWatchAdd in 'ClassWatchAdd.pas' {ClassWatchAddFrm},
  DriverNameWatchAddForm in 'DriverNameWatchAddForm.pas' {DriverNameWatchAddFrm},
  WatchedDriverNames in 'WatchedDriverNames.pas',
  XXXDetectedRequests in 'XXXDetectedRequests.pas',
  LibJSON in 'LibJSON.pas';

{$R *.res}

Const
  scmAccess = MAXIMUM_ALLOWED;
  serviceName = 'irpmndrv';
  serviceDescription = 'IRPMon Driver Service';
  driverFileName = 'irpmndrv.sys';


Var
  driverStarted : Boolean;

Function OnServiceTaskComplete(AList:TTaskOperationList; AObject:TTaskObject; AOperation:EHookObjectOperation; AStatus:Cardinal; AContext:Pointer):Cardinal;
begin
Case AOperation Of
  hooHook: ;
  hooUnhook: ;
  hooStart: driverStarted := (AStatus = ERROR_SUCCESS);
  hooStop: ;
  Else Result := ERROR_NOT_SUPPORTED;
  end;

Result := AStatus;
end;


Var
  taskList : TTaskOperationList;
  serviceTask : TDriverTaskObject;
  hScm : THandle;
  err : Cardinal;
Begin
driverStarted := False;
Application.Initialize;
Application.MainFormOnTaskbar := True;
err := TablesInit('ntstatus.txt', 'ioctl.txt');
If err = ERROR_SUCCESS Then
  begin
  hScm := OpenSCManagerW(Nil, Nil, scmAccess);
  If hScm <> 0 Then
    begin
    taskList := TTaskOperationList.Create;
    serviceTask := TDriverTaskObject.Create(hScm, serviceName, serviceDescription, serviceDescription, ExtractFilePath(Application.ExeName) + 'irpmndrv.sys');
    serviceTask.SetCompletionCallback(OnServiceTaskComplete, Nil);
    taskList.Add(hooHook, serviceTask);
    taskList.Add(hooStart, serviceTask);
    With THookProgressFrm.Create(Application, taskList) Do
      begin
      ShowModal;
      Free;
      end;

    err := IRPMonDllInitialize;
    If err = ERROR_SUCCESS Then
      begin
      Application.CreateForm(TMainFrm, MainFrm);
      Application.Run;
      IRPMonDllFinalize;
      end
    Else begin
      WinErrorMessage('Unable to initialize irpmondll.dll', err);
      If driverStarted Then
        taskList.Add(hooStop, serviceTask);
      end;

    taskList.Add(hooUnhook, serviceTask);
    With THookProgressFrm.Create(Application, taskList) Do
      begin
      ShowModal;
      Free;
      end;

    serviceTask.Free;
    taskList.Free;
    CloseServiceHandle(hScm);
    end
  Else WinErrorMessage('Unable to access SCM database', GetLastError);

  TablesFinit;
  end
Else WinErrorMessage('Unable to initialize name tables', err);
End.

