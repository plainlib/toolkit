//-----------------------------------------------------------------------------------
//  Toolkit Package © 2026 by Alexander Tverskoy
//  Licensed under the MIT License
//  You may obtain a copy of the License at https://opensource.org/licenses/MIT
//-----------------------------------------------------------------------------------

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
  public
    constructor CreateWith(ADelay: cardinal; ACallback: TOneShotCallback; var ExtRef: TTimer);
    procedure TimerFire(Sender: TObject);
  end;

constructor TOneShotTimer.CreateWith(ADelay: cardinal; ACallback: TOneShotCallback; var ExtRef: TTimer);
begin
  // Owner is Application to guarantee cleanup if the timer never fires before shutdown
  inherited Create(Application);
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
  // Immediately nil the external variable so no one touches a dead object
  if FUserVar <> nil then
    FUserVar^ := nil;
  try
    if Assigned(FCallback) then
      FCallback();
  finally
    // Free immediately; the user variable is already nil, and Owner will not double-free
    Free;
  end;
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
