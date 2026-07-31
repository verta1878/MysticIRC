unit BaseRules;

interface

uses
  SysUtils, Windows, Messages, Classes, ElObjList, ElRules, Math, 
  ElProcessUtils, ElList, mmsystem;

type

  TPerformEvent = procedure (Rule : TElRule; Sender : TObject; CurrentTime : 
      TDateTime; CustomData : string; var Perform : boolean) of object;

  TActionProcessThread = class;
  TGetRulePartStringEvent = procedure (Sender: TObject; var DataString : 
      string) of object;
  {:
  }
  TElTimeCondition = class (TElRuleCondition)
  private
    FLastSignaledTime: TDateTime;
  public
    procedure ActionPerformed(AtTime : TDateTime); override;
    function IsInEffect(CurrentTime : TDateTime): Boolean; override;
  published
    property LastSignaledTime: TDateTime read FLastSignaledTime write 
        FLastSignaledTime;
  end;
  
  {:
  }
  TElCronTimeCondition = class (TElTimeCondition)
  private
    FCronMasks: TStringList;
  public
    constructor Create(List : TElObjectList); override;
    destructor Destroy; override;
    procedure Assign(Source : TPersistent); override;
    function GetDescriptionString: String; override;
    class function GetNameString: String; override;
    function IsInEffect(CurrentTime : TDateTime): Boolean; override;
  published
    property CronMasks: TStringList read FCronMasks write FCronMasks;
  end;
  
  {:
  }
  TElProcessCondition = class (TElRuleCondition)
  private
    FProcessName: String;
  public
    procedure Assign(Source : TPersistent); override;
    procedure CreateDetailsString; override;
    function GetDescriptionString: String; override;
    class function GetNameString: String; override;
    function IsInEffect(CurrentTime : TDateTime): Boolean; override;
    procedure ParseDetailsString; override;
    property ProcessName: String read FProcessName write FProcessName;
  end;
  
  {:
  }
  TElRegTimeCondition = class (TElTimeCondition)
  private
    FDateAndTime: TDateTime;
  public
    procedure Assign(Source : TPersistent); override;
    function GetDescriptionString: String; override;
    class function GetNameString: String; override;
    function IsInEffect(CurrentTime : TDateTime): Boolean; override;
  published
    property DateAndTime: TDateTime read FDateAndTime write FDateAndTime;
  end;
  
  {:
  }
  TElWindowCondition = class (TElRuleCondition)
  private
    FPartialMatch: Boolean;
    FWindowCaption: String;
    FWindowClassName: String;
  public
    procedure Assign(Source : TPersistent); override;
    function GetDescriptionString: String; override;
    class function GetNameString: String; override;
    function IsInEffect(CurrentTime : TDateTime): Boolean; override;
  published
    property PartialMatch: Boolean read FPartialMatch write FPartialMatch;
    property WindowCaption: String read FWindowCaption write FWindowCaption;
    property WindowClassName: String read FWindowClassName write 
        FWindowClassName;
  end;
  
  {:
  }
  TElLaunchAction = class (TElRuleAction)
  private
    FCommand: String;
    FFileName: String;
    FOneInstOnly: Boolean;
    FParameters: String;
    FStartupFolder: String;
  public
    procedure Assign(Source : TPersistent); override;
    function GetDescriptionString: String; override;
    class function GetNameString: String; override;
    function Perform(CurrentTime : TDateTime): Boolean; override;
  published
    property Command: String read FCommand write FCommand;
    property FileName: String read FFileName write FFileName;
    property OneInstOnly: Boolean read FOneInstOnly write FOneInstOnly;
    property Parameters: String read FParameters write FParameters;
    property StartupFolder: String read FStartupFolder write FStartupFolder;
  end;
  
  {:
  }
  TElCallBackAction = class (TElRuleAction)
  private
    FActionData: String;
    FOnGetDescriptionStringEvent: TGetRulePartStringEvent;
    FOnGetNameStringEvent: TGetRulePartStringEvent;
    FOnPerform: TPerformEvent;
  public
    procedure Assign(Source : TPersistent); override;
    function Perform(CurrentTime : TDateTime): Boolean; override;
  published
    property ActionData: String read FActionData write FActionData;
    property OnGetDescriptionStringEvent: TGetRulePartStringEvent read 
        FOnGetDescriptionStringEvent write FOnGetDescriptionStringEvent;
    property OnGetNameStringEvent: TGetRulePartStringEvent read 
        FOnGetNameStringEvent write FOnGetNameStringEvent;
    {:
    CallbackAction doesn't have any default 
    behaviour.
    You can use it to call your own event. 
    }
    property OnPerform: TPerformEvent read FOnPerform write FOnPerform;
  end;
  
  {:
  }
  TElExtTimeCondition = class (TElTimeCondition)
  private
    FConditionEndDate: TDateTime;
    FConditionStartDate: TDateTime;
    FFinishFixedTime: TDateTime;
    FFixedTime: TDateTime;
    FFixedTimeIsInterval: Boolean;
    FInitialized: Boolean;
    FInterval: Cardinal;
    FIntervalElapsed: Integer;
    FMonthes: Word;
    FStartFixedTime: TDateTime;
    FTimeIsFixed: Boolean;
    FUseConditionEndDate: Boolean;
    FUseConditionStartDate: Boolean;
    FWeekDays: Byte;
    procedure SetTimeIsFixed(Value: Boolean);
  public
    procedure Assign(Source : TPersistent); override;
    function GetDescriptionString: String; override;
    class function GetNameString: String; override;
    function IsInEffect(CurrentTime : TDateTime): Boolean; override;
  published
    property ConditionEndDate: TDateTime read FConditionEndDate write 
        FConditionEndDate;
    property ConditionStartDate: TDateTime read FConditionStartDate write 
        FConditionStartDate;
    property FinishFixedTime: TDateTime read FFinishFixedTime write 
        FFinishFixedTime;
    property FixedTime: TDateTime read FFixedTime write FFixedTime;
    property FixedTimeIsInterval: Boolean read FFixedTimeIsInterval write 
        FFixedTimeIsInterval;
    property Initialized: Boolean read FInitialized write FInitialized;
    property Interval: Cardinal read FInterval write FInterval;
    property Monthes: Word read FMonthes write FMonthes;
    property StartFixedTime: TDateTime read FStartFixedTime write 
        FStartFixedTime;
    property TimeIsFixed: Boolean read FTimeIsFixed write SetTimeIsFixed;
    property UseConditionEndDate: Boolean read FUseConditionEndDate write 
        FUseConditionEndDate;
    property UseConditionStartDate: Boolean read FUseConditionStartDate write 
        FUseConditionStartDate;
    property WeekDays: Byte read FWeekDays write FWeekDays;
  end;
  
  {:
  }
  TElCallbackCondition = class (TElRuleCondition)
  private
    FConditionData: String;
    FOnCheck: TPerformEvent;
    FOnGetDescriptionStringEvent: TGetRulePartStringEvent;
    FOnGetNameStringEvent: TGetRulePartStringEvent;
  public
    function IsInEffect(CurrentTime : TDateTime): Boolean; override;
  published
    property ConditionData: String read FConditionData write FConditionData;
    {:
    CallbackAction doesn't have any default 
    behaviour.
    You can use it to call your own event. 
    }
    property OnCheck: TPerformEvent read FOnCheck write FOnCheck;
    property OnGetDescriptionStringEvent: TGetRulePartStringEvent read 
        FOnGetDescriptionStringEvent write FOnGetDescriptionStringEvent;
    property OnGetNameStringEvent: TGetRulePartStringEvent read 
        FOnGetNameStringEvent write FOnGetNameStringEvent;
  end;
  
  {:
  }
  TElSoundAction = class (TElRuleAction)
  private
    FSoundFileName: String;
    FUseDefaultSound: Boolean;
  public
    procedure Assign(Source : TPersistent); override;
    function GetDescriptionString: String; override;
    class function GetNameString: String; override;
    function Perform(CurrentTime : TDateTime): Boolean; override;
  published
    property SoundFileName: String read FSoundFileName write FSoundFileName;
    property UseDefaultSound: Boolean read FUseDefaultSound write 
        FUseDefaultSound;
  end;
  
  {:
  }
  TElShutdownAction = class (TElRuleAction)
  public
    procedure Assign(Source : TPersistent); override;
    function GetDescriptionString: String; override;
    class function GetNameString: String; override;
    function Perform(CurrentTime : TDateTime): Boolean; override;
  end;
  
  {:
  }
  TElPeriodCondition = class (TElTimeCondition)
  public
    function GetDescriptionString: String; override;
    class function GetNameString: String; override;
    {:
    Details string format = 
    <period value> <multiplier>
    where multiplier is 
    0: seconds
    1: minutes
    2: hours
    3: days
    4: weeks (7-day periods)
    }
    function IsInEffect(CurrentTime : TDateTime): Boolean; override;
  end;
  
  {:
  }
  TElFileCondition = class (TElRuleCondition)
  private
    FFileName: String;
  public
    procedure Assign(Source : TPersistent); override;
    procedure CreateDetailsString; override;
    function GetDescriptionString: String; override;
    class function GetNameString: String; override;
    function IsInEffect(CurrentTime : TDateTime): Boolean; override;
    procedure ParseDetailsString; override;
    property FileName: String read FFileName write FFileName;
  end;
  
  {:
  }
  TActionProcessThread = class (TThread)
  private
    FFolder: String;
    FParameters: String;
    FProcessName: String;
    FStop: Boolean;
  public
    procedure Execute; override;
    procedure StartProcess;
    procedure StopProcess;
    property Folder: String read FFolder write FFolder;
    property Parameters: String read FParameters write FParameters;
    property ProcessName: String read FProcessName write FProcessName;
    property Stop: Boolean read FStop write FStop;
  end;
  
  {:
  }
  TActionNetSendThread = class (TThread)
  private
    FMessage: TStringList;
    FRecepients: TStringList;
  public
    procedure Execute; override;
    property Message: TStringList read FMessage write FMessage;
    property Recepients: TStringList read FRecepients write FRecepients;
  end;
  
  {:
  }
  TElNetSendAction = class (TElRuleAction)
  private
    FMessage: TStringList;
    FRecepients: TStringList;
    procedure SetRecepients(Value: TStringList);
  public
    constructor Create(List : TElObjectList); override;
    destructor Destroy; override;
    procedure Assign(Source : TPersistent); override;
    function GetDescriptionString: String; override;
    class function GetNameString: String; override;
    function Perform(CurrentTime : TDateTime): Boolean; override;
  published
    property Message: TStringList read FMessage write FMessage;
    property Recepients: TStringList read FRecepients write SetRecepients;
  end;
  
  {:
  }
  TElCloseAppAction = class (TElRuleAction)
  private
    FFileName: String;
  public
    procedure Assign(Source : TPersistent); override;
    function GetDescriptionString: String; override;
    class function GetNameString: String; override;
    function Perform(CurrentTime : TDateTime): Boolean; override;
  published
    property FileName: String read FFileName write FFileName;
  end;
  
  {:
  }
  TElOpenURLAction = class (TElRuleAction)
  private
    FAnURL: String;
  public
    procedure Assign(Source : TPersistent); override;
    function GetDescriptionString: String; override;
    class function GetNameString: String; override;
    function Perform(CurrentTime : TDateTime): Boolean; override;
  published
    property AnURL: String read FAnURL write FAnURL;
  end;
  

implementation

uses ElTools, ElStrUtils, ShellAPI;

{:
}
{
***************************** TElProcessCondition ******************************
}
procedure TElProcessCondition.Assign(Source : TPersistent);
begin
  inherited Assign(Source);
  if Source is TElProcessCondition then
    ProcessName := TElProcessCondition(Source).ProcessName;
end;

procedure TElProcessCondition.CreateDetailsString;
begin
  Details := EscapeString(ProcessName, '', '%');
end;

function TElProcessCondition.GetDescriptionString: String;
var
  S, S1: String;
begin
  if FProcessName <> '' then
     S := ExtractFileName(FProcessName)
  else
     s := 'some application';
  if Inverted then
     S1 := ' not'
  else
     S1 := '';
  result := Format('<a href="%d">%s</a> is%s running', [Integer(Pointer(Self)), 
      S, S1]);
end;

class function TElProcessCondition.GetNameString: String;
begin
  result := 'When application with specified name is running';
end;

function TElProcessCondition.IsInEffect(CurrentTime : TDateTime): Boolean;
begin
  result := ProcessExists(ProcessName);
end;

procedure TElProcessCondition.ParseDetailsString;
begin
  ProcessName := UnEscapeString(Details, '%');
end;

{:
}
{
***************************** TElCronTimeCondition *****************************
}
constructor TElCronTimeCondition.Create(List : TElObjectList);
begin
  inherited Create(List);
  CronMasks := TStringList.Create;
  CronMasks.Add('* * * * *');
end;

destructor TElCronTimeCondition.Destroy;
begin
  CronMasks.Free;
  inherited Destroy;
end;

procedure TElCronTimeCondition.Assign(Source : TPersistent);
begin
  inherited Assign(Source);
  if Source is TElCronTimeCondition then
    CronMasks.Assign(TElCronTimeCondition(Source).CronMasks);
end;

function TElCronTimeCondition.GetDescriptionString: String;
var
  S, S1: String;
  I: Integer;
begin
  if FCronMasks.Count = 0 then
     S := 'some'
  else
  begin
    S := '';
    for i := 0 to FCronMasks.Count - 1 do
    begin
      if Length(S) > 0 then
         S := S + ',<br>' + FCronMasks[i]
      else
         S := S + FCronMasks[i];
    end;
  end;
  if Inverted then
     S1 := 'does not conform'
  else
     S1 := 'conforms';
  result := Format('current time %s to <a href="%d">%s</a> Cron masks', [S1, 
      Integer(Pointer(Self)), S]);
end;

class function TElCronTimeCondition.GetNameString: String;
begin
  result := 'When time conforms to cron mask(s)';
end;

function TElCronTimeCondition.IsInEffect(CurrentTime : TDateTime): Boolean;
var
  T: TSystemTime;
  T1: TSystemTime;
  I: Integer;
  
  function IntInPart(S : String; Value : integer): Boolean;
  var S1, S2 : string;
  begin
    if s='*' then result:=true else
    begin
      s1:=s;
      while pos(',',s1)>0 do
      begin
        s2:=copy(s1,1,pos(',',s1)-1);
        delete(s1,1,pos(',',s1));
        result:= s2 = IntToStr(value);
        if result then exit;
      end;
      result:= s1 = IntToStr(value);
    end;
  end;
  
  function TimeInMask(CurrentTime : TDateTime; Mask : string): Boolean;
  
  var T : TSystemTime;
  begin
    result := false;
    DateTimeToSystemTime(CurrentTime, T);
    if not IntInPart(ExtractWord(Mask,1),T.wMinute) then exit;
    if not IntInPart(ExtractWord(Mask,2),T.wHour) then exit;
    if not IntInPart(ExtractWord(Mask,3),T.wDay) then exit;
    if not IntInPart(ExtractWord(Mask,4),T.wDayOfWeek) then exit;
    if not IntInPart(ExtractWord(Mask,5),T.wMonth) then exit;
    result:=true;
  end;
  
begin
  Result := inherited IsInEffect(CurrentTime);
  if result then
  begin
    DateTimeToSystemTime(CurrentTime, T);
    T.wDayOfWeek := DayOfWeek(CurrentTime) - 1;
    DateTimeToSystemTime(LastSignaledTime, T1);
    T1.wDayOfWeek := DayOfWeek(LastSignaledTime) -1;
    if CompareMem(@T, @T1, sizeof(T.wYear) * 6) then
    begin
      result := false;
      exit;
    end;
  end;
  result := false;
  for i := 0 to CronMasks.Count - 1 do
  begin
    result := TimeInMask(CurrentTime, CronMasks[i]);
    if result then break;
  end;
end;

{:
}
{
***************************** TElRegTimeCondition ******************************
}
procedure TElRegTimeCondition.Assign(Source : TPersistent);
begin
  inherited Assign(Source);
  if Source is TElRegTimeCondition then
    DateAndTime := TElRegTimeCondition(Source).DateAndTime;
end;

function TElRegTimeCondition.GetDescriptionString: String;
begin
  if FDateAndTime = 0 then
     result := Format('on<a href="%d">specified</a> date and time', [Integer(
         Pointer(Self))])
  else
     result := Format('<a href="%d">%s</a> at <a href="%d">%s</a>',
                      [Integer(Pointer(Self)), DateToStr(FDateAndTime),
                       Integer(Pointer(Self)), TimeToStr(FDateAndTime)]);
end;

class function TElRegTimeCondition.GetNameString: String;
begin
  result := 'On specified date and time';
end;

function TElRegTimeCondition.IsInEffect(CurrentTime : TDateTime): Boolean;
var
  T: TSystemTime;
  T1: TSystemTime;
begin
  DateTimeToSystemTime(CurrentTime, T);
  DateTimeToSystemTime(FDateAndTime, T1);
  T1.wDayOfWeek := T.wDayOfWeek;
  Result := CompareMem(@T, @T1, sizeof(T.wYear) * 7);
  if result then
  begin
    DateTimeToSystemTime(LastSignaledTime, T1);
    T1.wDayOfWeek := T.wDayOfWeek;
    result := (not CompareMem(@T, @T1, sizeof(T.wYear) * 7));
  end;
end;

{:
}
{
******************************* TElTimeCondition *******************************
}
procedure TElTimeCondition.ActionPerformed(AtTime : TDateTime);
begin
  inherited ActionPerformed(AtTime);
  LastSignaledTime := AtTime;
end;

function TElTimeCondition.IsInEffect(CurrentTime : TDateTime): Boolean;
begin
  result := true;
end;

{:
}
{
****************************** TElWindowCondition ******************************
}
procedure TElWindowCondition.Assign(Source : TPersistent);
begin
  inherited Assign(Source);
  if Source is TElWindowCondition then
  with TElWindowCondition(Source) do
  begin
    Self.PartialMatch := PartialMatch;
    Self.WindowCaption := WindowCaption;
    Self.WindowClassName := WindowClassName;
  end;
end;

function TElWindowCondition.GetDescriptionString: String;
var
  S, S1: String;
begin
  if FPartialMatch then
     S := ' that starts with'
  else
     s := '';
  if Inverted then
     S1 := ' not'
  else
     S1 := '';
  if FWindowCaption = '' then
     result := Format(
         'window with <a href="%d">undefined</a> caption is%s open', [Integer(
         Pointer(Self)), S1])
  else
     result := Format('window with caption%s <a href="%d">%s</a> is%s open', [S,
         Integer(Pointer(Self)), FWindowCaption, S1]);
end;

class function TElWindowCondition.GetNameString: String;
begin
  result := 'When a window with specified caption is present';
end;

function TElWindowCondition.IsInEffect(CurrentTime : TDateTime): Boolean;
begin
  result := TopWindowExists(PChar(WindowClassName), Pchar(WindowCaption), not
      PartialMatch) <> 0;
end;

{:
}
{
******************************* TElLaunchAction ********************************
}
procedure TElLaunchAction.Assign(Source : TPersistent);
begin
  inherited Assign(Source);
  if Source is TElLaunchAction then
  begin
    command := TElLaunchAction(Source).command;
    FileName := TElLaunchAction(Source).FileName;
    Parameters := TElLaunchAction(Source).Parameters;
    StartupFolder := TElLaunchAction(Source).StartupFolder;
  end;
end;

function TElLaunchAction.GetDescriptionString: String;
begin
  if FileName = '' then
    result := Format('start <a href="%d">some application</a>', [Integer(
        Pointer(Self))])
  else
  begin
    result := Format('start <a href="%d">%s</a>', [Integer(Pointer(Self)), 
        ExtractFileName(FileName)]);
  end;
end;

class function TElLaunchAction.GetNameString: String;
begin
  result := 'Start application';
end;

function TElLaunchAction.Perform(CurrentTime : TDateTime): Boolean;
begin
  if not ProcessExists(ExtractFileName(FileName)) then
    with TActionProcessThread.Create(true) do
    begin
      FreeOnTerminate := true;
      Folder := StartupFolder;
      ProcessName := FileName;
      Parameters := Self.Parameters;
      Stop := false;
      Resume;
    end;
  result := true;
end;

{:
}
{
******************************** TElSoundAction ********************************
}
procedure TElSoundAction.Assign(Source : TPersistent);
begin
  inherited Assign(Source);
  if Source is TElSoundAction then
  begin
    SoundFileName := TElSoundAction(Source).SoundFileName;
    UseDefaultSound := TElSoundAction(Source).UseDefaultSound;
  end;
end;

function TElSoundAction.GetDescriptionString: String;
begin
  if UseDefaultSound then
    result := Format('Play <a href="%d">system default</a> sound', [Integer(
        Pointer(Self))])
  else
  begin
    if SoundFileName = '' then
       result := Format('Play <a href="%d">some</a> sound', [Integer(Pointer(
           Self))])
    else
       result := Format('Play <a href="%d">%s</a>', [Integer(Pointer(Self)), 
           ExtractFileName(SoundFileName)]);
  end;
end;

class function TElSoundAction.GetNameString: String;
begin
  result := 'Play sound';
end;

function TElSoundAction.Perform(CurrentTime : TDateTime): Boolean;
begin
  if FUseDefaultSound then
  begin
    PlaySound('.Default', 0, SND_ALIAS or SND_ASYNC);
    result := true;
  end else
  begin
    PlaySound(PChar(SoundFileName), 0,
              SND_FILENAME or SND_ASYNC or SND_NODEFAULT or SND_NOWAIT);
    result := FileExists(SoundFileName);
  end;
end;

{:
}
{
****************************** TElShutdownAction *******************************
}
procedure TElShutdownAction.Assign(Source : TPersistent);
begin
  inherited Assign(Source);
end;

function TElShutdownAction.GetDescriptionString: String;
var
  S: String;
begin
  case StrToIntDef(Details, EWX_SHUTDOWN) of
    EWX_LOGOFF: S := 'End session';
    EWX_SHUTDOWN: S := 'Shutdown Windows';
    EWX_REBOOT: S := 'Restart Windows';
    EWX_POWEROFF: S := 'Turn off computer';
  end;
  result := Format('<a href="%d">%s</a>', [Integer(Pointer(Self)), S]);
end;

class function TElShutdownAction.GetNameString: String;
begin
  result := 'Shutdown or restart system';
end;

function TElShutdownAction.Perform(CurrentTime : TDateTime): Boolean;
  
  function SetPrivilege(sPrivilegeName : string; bEnabled : boolean): Boolean;
  var
    TPPrev,
    TP         : TTokenPrivileges;
    Token      : THandle;
    dwRetLen   : DWord;
  begin
    Result := False;
    OpenProcessToken(GetCurrentProcess, TOKEN_ADJUST_PRIVILEGES or TOKEN_QUERY, 
        Token);
    TP.PrivilegeCount := 1;
    if( LookupPrivilegeValue( Nil, PChar( sPrivilegeName ), TP.Privileges[ 0 
        ].LUID ) ) then
    begin
      if( bEnabled )then
      begin
        TP.Privileges[ 0 ].Attributes  := SE_PRIVILEGE_ENABLED;
      end else
      begin
        TP.Privileges[ 0 ].Attributes  := 0;
      end;
      dwRetLen := 0;
      Result := AdjustTokenPrivileges(
                  Token,
                  False,
                  TP,
                  SizeOf( TPPrev ),
                  TPPrev,
                  dwRetLen );
    end;
    CloseHandle( Token );
  end;
  
begin
  if IsWinNT then
     SetPrivilege('SeShutdownPrivilege', true);
  result := ExitWindowsEx(StrToIntDef(Details, EWX_SHUTDOWN), 0);
end;

{:
}
{
****************************** TElPeriodCondition ******************************
}
function TElPeriodCondition.GetDescriptionString: String;
var
  S: String;
  Period, Multiplier: Integer;
begin
  if Details = '' then
    result := Format('at a <a href="%d">certain</a> interval', [Integer(Pointer(
        Self))])
  else
  begin
    Period := StrToIntDef(ExtractWord(Details, 1), -1);
    Multiplier := StrToIntDef(ExtractWord(Details, 2), 0);
    S := '';
    case Multiplier of
      0: S := 'second(s)';
      1: S := 'minute(s)';
      2: S := 'hour(s)';
      3: S := 'day(s)';
      4: S := 'week(s)';
    end;
    if (Multiplier < 0) or (Multiplier > 4) or (Period < 0) then
      result := Format('at a <a href="%d">certain</a> interval', [Integer(
          Pointer(Self))])
    else
      result := Format('every <a href="%d">%d %s</a>', [Integer(Pointer(Self)), 
          Period, S]);
  end;
end;

class function TElPeriodCondition.GetNameString: String;
begin
  result := 'At a certain time interval';
end;

{:
TElPeriodCondition.IsInEffect
(CurrentTime)
Details string format = 
<period value> <multiplier>
where multiplier is 
0: seconds
1: minutes
2: hours
3: days
4: weeks (7-day periods)
}
function TElPeriodCondition.IsInEffect(CurrentTime : TDateTime): Boolean;
var
  Multiplier: Integer;
  Period: Integer;
begin
  Result := inherited IsInEffect(CurrentTime);
  if not Result then exit;
  if LastSignaledTime = 0 then
  begin
    result := true;
    exit;
  end;
  
  Period := StrToIntDef(ExtractWord(Details, 1), 1);
  Multiplier := StrToIntDef(ExtractWord(Details, 2), 0);
  case Multiplier of
    0: result := IncTime(CurrentTime, 0, 0, -Period, 0) > LastSignaledTime;
    1: result := IncTime(CurrentTime, 0, -Period, 0, 0) > LastSignaledTime;
    2: result := IncTime(CurrentTime, -Period, 0, 0, 0) > LastSignaledTime;
    3: result := IncTime(CurrentTime, -Period * 24, 0, 0, 0) > LastSignaledTime;
    4: result := IncTime(CurrentTime, -Period * 24 * 7, 0, 0, 0) > 
        LastSignaledTime;
    else
       result := false;
  end;
end;

{:
}
{
******************************* TElFileCondition *******************************
}
procedure TElFileCondition.Assign(Source : TPersistent);
begin
  inherited Assign(Source);
  if Source is TElFileCondition then
    FileName := TElFileCondition(Source).FileName;
end;

procedure TElFileCondition.CreateDetailsString;
begin
  Details := EscapeString(FileName, '', '%');
end;

function TElFileCondition.GetDescriptionString: String;
var
  S, S1: String;
begin
  if FFileName <> '' then
     S := ExtractFileName(FFileName)
  else
     s := 'some file';
  if Inverted then
     S1 := ' not'
  else
     S1 := '';
  result := Format('<a href="%d">%s</a> is%s present on disk', [Integer(Pointer(
      Self)), S, S1]);
end;

class function TElFileCondition.GetNameString: String;
begin
  result := 'When specified file exists';
end;

function TElFileCondition.IsInEffect(CurrentTime : TDateTime): Boolean;
begin
  result := FileExists(FileName);
end;

procedure TElFileCondition.ParseDetailsString;
begin
  FileName := UnEscapeString(Details, '%');
end;

{:
}
{
***************************** TActionProcessThread *****************************
}
procedure TActionProcessThread.Execute;
begin
  if Stop then
     StopProcess
  else
     StartProcess;
end;

procedure TActionProcessThread.StartProcess;
var
  StartInfo: TStartupInfo;
  ProcInfo: TProcessInformation;
begin
  FillMemory(@StartInfo,SizeOf(TStartupInfo), 0);
  with StartInfo do
  begin
    cb:=SizeOf(TStartupInfo);
    lpDesktop:= nil;
    lpTitle  := nil;
    dwFlags := 0;
  end; // with
  CreateProcess(nil, PChar(FProcessName + #32 + Parameters), nil, nil, false, 
      CREATE_DEFAULT_ERROR_MODE, pchar(Folder),
                     nil, StartInfo, ProcInfo);
  CloseHandle(ProcInfo.hProcess);
  CloseHandle(ProcInfo.hThread);
end;

procedure TActionProcessThread.StopProcess;
begin
  CloseProcess(ExtractFileName(ProcessName));
end;

{:
}
{
***************************** TActionNetSendThread *****************************
}
procedure TActionNetSendThread.Execute;
var
  i: Integer;
  MSHandle: THandle;
  S, S1: String;
  cbWritten: DWORD;
begin
  for i := 0 to Recepients.Count - 1 do
  begin
    S := Format('\\%s\mailslot\messngr', [Recepients[i]]);
    S1 := FMessage.Text;
    MSHandle := Windows.CreateFile(PChar(i), GENERIC_WRITE, FILE_SHARE_READ,
                           nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
    if MSHandle <> INVALID_HANDLE_VALUE then
    begin
      Windows.WriteFile(MSHandle, S1, Length(S1) + 1,
                        cbWritten, nil);
      CloseHandle(MSHandle);
    end;
  end;
end;

{:
}
{
******************************* TElNetSendAction *******************************
}
constructor TElNetSendAction.Create(List : TElObjectList);
begin
  inherited Create(List);
  FRecepients := TStringList.Create;
  FMessage := TStringList.Create;
end;

destructor TElNetSendAction.Destroy;
begin
  FRecepients.Free;
  FMessage.Free;
  inherited Destroy;
end;

procedure TElNetSendAction.Assign(Source : TPersistent);
begin
  inherited Assign(Source);
  if Source is TElNetSendAction then
  begin
    Message.Assign(TElNetSendAction(Source).Message);
    Recepients.Assign(TElNetSendAction(Source).Recepients);
  end;
end;

function TElNetSendAction.GetDescriptionString: String;
begin
  result := Format('send <a href="%d">network message</a>', [Integer(Pointer(
      Self))]);
end;

class function TElNetSendAction.GetNameString: String;
begin
  result := 'Send network message';
end;

function TElNetSendAction.Perform(CurrentTime : TDateTime): Boolean;
begin
  with TActionNetSendThread.Create(true) do
  begin
    FreeOnTerminate := true;
    Message := Self.Message;
    Recepients := Self.Recepients;
    Resume;
  end;
  result := true;
end;

procedure TElNetSendAction.SetRecepients(Value: TStringList);
begin
  FRecepients.Assign(Value);
end;

{:
}
{
****************************** TElCloseAppAction *******************************
}
procedure TElCloseAppAction.Assign(Source : TPersistent);
begin
  inherited Assign(Source);
  if Source is TElCloseAppAction then
    FileName := TElCloseAppAction(Source).FileName;
end;

function TElCloseAppAction.GetDescriptionString: String;
begin
  if FileName = '' then
    result := Format('close <a href="%d">some application</a>', [Integer(
        Pointer(Self))])
  else
  begin
    result := Format('close <a href="%d">%s</a>', [Integer(Pointer(Self)), 
        ExtractFileName(FileName)]);
  end;
end;

class function TElCloseAppAction.GetNameString: String;
begin
  result := 'Close application';
end;

function TElCloseAppAction.Perform(CurrentTime : TDateTime): Boolean;
begin
  if ProcessExists(ExtractFileName(FileName)) then
    with TActionProcessThread.Create(true) do
    begin
      FreeOnTerminate := true;
      ProcessName := FileName;
      Stop := true;
      Resume;
    end;
  result := true;
end;

{:
}
{
******************************* TElOpenURLAction *******************************
}
procedure TElOpenURLAction.Assign(Source : TPersistent);
begin
  inherited Assign(Source);
  if Source is TElOpenURLAction then
  AnURL := TElOpenURLAction(Source).AnURL;
end;

function TElOpenURLAction.GetDescriptionString: String;
var
  S: String;
begin
  case StrToIntDef(Details, EWX_SHUTDOWN) of
    EWX_LOGOFF: S := 'End session';
    EWX_SHUTDOWN: S := 'Shutdown Windows';
    EWX_REBOOT: S := 'Restart Windows';
    EWX_POWEROFF: S := 'Turn off computer';
  end;
  result := Format('<a href="%d">%s</a>', [Integer(Pointer(Self)), S]);
end;

class function TElOpenURLAction.GetNameString: String;
begin
  result := 'Shutdown or restart system';
end;

function TElOpenURLAction.Perform(CurrentTime : TDateTime): Boolean;
  
  function SetPrivilege(sPrivilegeName : string; bEnabled : boolean): Boolean;
  var
    TPPrev,
    TP         : TTokenPrivileges;
    Token      : THandle;
    dwRetLen   : DWord;
  begin
    Result := False;
    OpenProcessToken(GetCurrentProcess, TOKEN_ADJUST_PRIVILEGES or TOKEN_QUERY, 
        Token);
    TP.PrivilegeCount := 1;
    if( LookupPrivilegeValue( Nil, PChar( sPrivilegeName ), TP.Privileges[ 0 
        ].LUID ) ) then
    begin
      if( bEnabled )then
      begin
        TP.Privileges[ 0 ].Attributes  := SE_PRIVILEGE_ENABLED;
      end else
      begin
        TP.Privileges[ 0 ].Attributes  := 0;
      end;
      dwRetLen := 0;
      Result := AdjustTokenPrivileges(
                  Token,
                  False,
                  TP,
                  SizeOf( TPPrev ),
                  TPPrev,
                  dwRetLen );
    end;
    CloseHandle( Token );
  end;
  
begin
  if IsWinNT then
     SetPrivilege('SeShutdownPrivilege', true);
  result := ExitWindowsEx(StrToIntDef(Details, EWX_SHUTDOWN), 0);
end;

{:
}
{
***************************** TElCallbackCondition *****************************
}
function TElCallbackCondition.IsInEffect(CurrentTime : TDateTime): Boolean;
begin
  Result := true;
  if Assigned(FOnCheck) then
     FOnCheck(TElRuleParts(List).GetOwner as TElRule, Self, CurrentTime, 
         ConditionData, Result)
  else
     result := false;
end;

{:
}
{
***************************** TElExtTimeCondition ******************************
}
procedure TElExtTimeCondition.Assign(Source : TPersistent);
begin
  inherited Assign(Source);
  if Source is TElExtTimeCondition then
  with TElExtTimeCondition(Source) do
  begin
    Self.ConditionEndDate := ConditionEndDate;
    Self.ConditionStartDate := ConditionStartDate;
    Self.FinishFixedTime := FinishFixedTime;
    Self.FixedTime := FixedTime;
    Self.FixedTimeIsInterval := FixedTimeIsInterval;
    Self.Initialized := Initialized;
    Self.Interval := Interval;
    Self.Monthes := Monthes;
    Self.StartFixedTime := StartFixedTime;
    Self.TimeIsFixed := TimeIsFixed;
    Self.UseConditionEndDate := UseConditionEndDate;
    Self.UseConditionStartDate := UseConditionStartDate;
    Self.WeekDays := WeekDays;
  end;
end;

function TElExtTimeCondition.GetDescriptionString: String;
var
  S: String;
  I: Integer;
  b: Boolean;
  
  const USShortDayNames : array[1..7] of string
                        = ('Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa');
  const USShortMonthNames : array[1..12] of string
                          = ('Jan', 'Feb', 'Mar', 'Apr',
                             'May', 'Jun', 'Jul', 'Aug',
                             'Sep', 'Oct', 'Nov', 'Dec');
  
begin
  if not Initialized then
    result := Format('at <a href="%d">certain</a> time', [Integer(Pointer(
        Self))])
  else
  begin
    b := false;
    // put monthes string
    if FMonthes = 4095 then
      S := Format('<a href="%d">every month,</a> ', [Integer(Pointer(Self))])
    else
    begin
      S := Format('In <a href="%d">', [Integer(Pointer(Self))]);
      for i := 0 to 11 do
      begin
        if ((1 shl i) and FMonthes) <> 0  then
        begin
          if (b) then
            S := S + ', ' + USShortMonthNames[i+1]
          else
          begin
            S := S + USShortMonthNames[i+1];
            b := true;
          end;
        end;
      end;
      S := S + '</a>';
    end;
    b := false;
    // put weekdays string
    if WeekDays = 127 then
      S := S + Format(' <a href="%d">every day</a> ', [Integer(Pointer(Self))])
    else
    begin
      S := S + Format(' on <a href="%d">', [Integer(Pointer(Self))]);
      for i := 0 to 6 do
      begin
        if ((1 shl i) and FWeekDays) <> 0  then
        begin
          if b then
            S := S + ', ' + USShortDayNames[i+1]
          else
          begin
            S := S + USShortDayNames[i+1];
            b := true;
          end;
        end;
      end;
      S := S + '</a>';
    end;
    if TimeIsFixed then
    begin
      if FixedTimeIsInterval then
         S := S + Format(' between <a href="%d">%s and %s</a>', [Integer(
             Pointer(Self)), TimeToStr(StartFixedTime), TimeToStr(
             FinishFixedTime)])
      else
         S := S + Format(' at <a href="%d">%s</a>', [Integer(Pointer(Self)), 
             TimeToStr(FixedTime)]);
    end else
    begin
      S := S + Format(' every <a href="%d">', [Integer(Pointer(Self))]);
      if Interval < 60 then
        S := S + Format('%d second(s)</a>', [Interval])
      else
      if Interval < 3600 then
        S := S + Format('%d minute(s)</a>', [Interval div 60])
      else
      if (Interval < 86400) then
        S := S + Format('%d hour(s)</a>', [Interval div 3600])
      else
        S := S + Format('%d day(s)</a>', [Interval div 86400]);
    end;
    result := S;
  end;
end;

class function TElExtTimeCondition.GetNameString: String;
begin
  result := 'At certain time';
end;

function TElExtTimeCondition.IsInEffect(CurrentTime : TDateTime): Boolean;
var
  ADay: Word;
  AMonth: Word;
  AYear: Word;
  I: Integer;
begin
  if not TimeIsFixed then
    inc(FIntervalElapsed);
  try
    Result := inherited IsInEffect(CurrentTime);
    if not Result then exit;
    DecodeDate(CurrentTime, AYear, AMonth, ADay);
    Result := (FWeekDays and (1 shl (DayOfWeek(CurrentTime) - 1))) <> 0;
    if not Result then exit;
    Result := (FMonthes and (1 shl (AMonth - 1))) <> 1;
    if not Result then exit;
    if (UseConditionStartDate and (CurrentTime < ConditionStartDate)) or
       (UseConditionEndDate and (CurrentTime > ConditionEndDate)) then
      exit;
    if Result then
    begin
      if FTimeIsFixed then
      begin
        if FixedTimeIsInterval then
        begin
          i := Trunc(CurrentTime * 86400);
          result := (i >= Trunc(FStartFixedTime * 86400)) and
                    (i <= Trunc(FFinishFixedTime * 86400)) and
                    (i - Trunc(LastSignaledTime * 86400) >
                      Trunc(FFinishFixedTime * 86400) - Trunc(FStartFixedTime * 
                          86400));
        end else
          result := Trunc(CurrentTime * 86400) = Trunc(FFixedTime * 86400)
      end
      else
        result := FIntervalElapsed = FInterval;
    end;
  finally
    if not FTimeIsFixed then
       if FIntervalElapsed >= FInterval then
          FIntervalElapsed := FIntervalElapsed - FInterval;
  end;
end;

procedure TElExtTimeCondition.SetTimeIsFixed(Value: Boolean);
begin
  if Value <> FTimeIsFixed then
  begin
    FTimeIsFixed := Value;
    if not Value then FIntervalElapsed := 0;
  end;
end;

{:
}
{
****************************** TElCallBackAction *******************************
}
procedure TElCallBackAction.Assign(Source : TPersistent);
begin
  inherited Assign(Source);
  if Source is TElCallbackAction then
  begin
    ActionData := TElCallbackAction(Source).ActionData;
  end;
end;

function TElCallBackAction.Perform(CurrentTime : TDateTime): Boolean;
begin
  result := false;
  if assigned(FOnPerform) then
     FOnPerform(TElRuleParts(List).GetOwner as TElRule, Self, CurrentTime, 
         ActionData, result);
end;


initialization

RegisterClasses([TElTimeCondition, TElExtTimeCondition, TElCronTimeCondition, 
                 TElProcessCondition, TElFileCondition, TElWindowCondition, 
                 TElRegTimeCondition, TElLaunchAction, TElCallbackCondition, 
                 TElCallbackAction, TElSoundAction, TElShutdownAction, 
                 TElPeriodCondition, TElFileCondition]);

end.
