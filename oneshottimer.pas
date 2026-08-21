unit OneShotTimer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ExtCtrls, Forms;

type
  TOneShotCallback = procedure of object;

// Schedules a one-time callback after the specified delay.
// Call with two arguments to run without cancellation.
// Call with three arguments to get a timer reference for cancellation.
procedure SetTimeout(Delay: cardinal; Callback: TOneShotCallback); overload;
procedure SetTimeout(out Timer: TTimer; Delay: cardinal; Callback: TOneShotCallback); overload;

// Cancels a pending timer obtained from SetTimeout.
// Safe to call even if the timer has already fired or is nil.
procedure ClearTimeout(var Timer: TTimer);

implementation

type
  TOneShotTimer = class(TTimer)
  private
    FCallback: TOneShotCallback;
    FUserVar: ^TTimer;
    procedure AsyncFree(Data: PtrInt);
  public
    constructor CreateWith(ADelay: cardinal; ACallback: TOneShotCallback; var ExtRef: TTimer);
    procedure TimerFire(Sender: TObject);
  end;

constructor TOneShotTimer.CreateWith(ADelay: cardinal; ACallback: TOneShotCallback; var ExtRef: TTimer);
begin
  inherited Create(nil);
  FCallback := ACallback;
  FUserVar := @ExtRef;
  Interval := ADelay;
  OnTimer := @TimerFire;
  Enabled := True;
  ExtRef := Self;
end;

procedure TOneShotTimer.TimerFire(Sender: TObject);
begin
  Enabled := False;
  if FUserVar <> nil then
    FUserVar^ := nil;
  if Assigned(FCallback) then
    FCallback();
  Application.QueueAsyncCall(@AsyncFree, PtrInt(Self));
end;

procedure TOneShotTimer.AsyncFree(Data: PtrInt);
begin
  TOneShotTimer(Data).Free;
end;

procedure SetTimeout(Delay: cardinal; Callback: TOneShotCallback);
var
  dummy: TTimer;
begin
  dummy := nil;
  TOneShotTimer.CreateWith(Delay, Callback, dummy);
end;

procedure SetTimeout(out Timer: TTimer; Delay: cardinal; Callback: TOneShotCallback);
begin
  Timer := nil;
  TOneShotTimer.CreateWith(Delay, Callback, Timer);
end;

procedure ClearTimeout(var Timer: TTimer);
begin
  if Timer = nil then Exit;
  if Timer is TOneShotTimer then
  begin
    Timer.Enabled := False;
    TOneShotTimer(Timer).FUserVar := nil;
    FreeAndNil(Timer);
  end
  else
    FreeAndNil(Timer);
end;

end.
