//-----------------------------------------------------------------------------------
//  Toolkit Package © 2026 by Alexander Tverskoy
//  Licensed under the MIT License
//  You may obtain a copy of the License at https://opensource.org/licenses/MIT
//-----------------------------------------------------------------------------------

unit OneShotTooltip;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  Forms,
  Controls,
  StdCtrls,
  ExtCtrls,
  Graphics,
  Types,
  OneShotTimer;

type
  TOneShotTooltip = class;

  // Internal hint form – a borderless, top‑most window with a read‑only Memo
  TfrmHint = class(TForm)
  private
    Memo1: TMemo;
    FOwnerHint: TOneShotTooltip;
    procedure FormDeactivate(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    property HintMemo: TMemo read Memo1;
  end;

  // Non‑visual component that owns and manages a hint form
  TOneShotTooltip = class(TComponent)
  private
    FForm: TfrmHint;
    FTimer: TTimer;        // one‑shot timer for auto‑hide
    FIsHiding: boolean;    // prevents re‑entrant hide calls
    procedure TimerHide;   // timer callback
    procedure HideHintInternal;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // Show hint text at specified position.
    // Duration = 0  : hint stays until the user clicks outside it
    // Duration > 0  : hint hides after Duration ms (or on outside click)
    // AWidth, AHeight : custom size; 0 means auto‑calculate
    procedure ShowHintText(const AText: string; X, Y: integer;
      AWidth: integer = 0; AHeight: integer = 0; Duration: integer = 0);
  end;

implementation

{ TfrmHint }

constructor TfrmHint.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  // Form properties: no border, always on top, manually positioned
  BorderStyle := bsNone;
  FormStyle := fsSystemStayOnTop;
  Position := poDesigned;
  ShowHint := False;

  // Memo for displaying the hint text
  Memo1 := TMemo.Create(Self);
  Memo1.Parent := Self;
  Memo1.Align := alClient;
  Memo1.BorderStyle := bsNone;
  Memo1.ReadOnly := True;
  Memo1.Color := clInfoBk;               // standard hint background colour
  Memo1.Font.Assign(Screen.HintFont);    // standard hint font
  Memo1.WordWrap := True;
  Memo1.ScrollBars := ssNone;            // no scrollbars for a clean look
  Memo1.TabStop := False;

  OnDeactivate := @FormDeactivate;
end;

procedure TfrmHint.FormDeactivate(Sender: TObject);
begin
  // When the form loses focus (user clicks outside), close the hint
  if Assigned(FOwnerHint) then
    FOwnerHint.HideHintInternal;
end;

{ TOneShotTooltip }

constructor TOneShotTooltip.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FForm := TfrmHint.Create(nil); // we manage the form's lifetime manually
  FForm.FOwnerHint := Self;
  FTimer := nil;
  FIsHiding := False;
end;

destructor TOneShotTooltip.Destroy;
begin
  ClearTimeout(FTimer);   // cancel any pending timer (safe, nils FTimer)
  FForm.Free;             // destroy the owned form
  inherited Destroy;
end;

procedure TOneShotTooltip.ShowHintText(const AText: string; X, Y: integer;
  AWidth: integer; AHeight: integer; Duration: integer);
var
  HtRect: TRect;
  MaxW, W, H: integer;
  HintHelper: THintWindow;
begin
  // Cancel any pending timer
  ClearTimeout(FTimer);

  // Ensure the form's window handle exists before any interaction with controls
  FForm.HandleNeeded;

  // If the hint form is currently visible, hide it without triggering deactivation
  if FForm.Visible then
  begin
    FForm.OnDeactivate := nil;
    try
      FForm.Hide;
    finally
      FForm.OnDeactivate := @FForm.FormDeactivate;
    end;
  end;

  // Determine maximum width for text measurement
  if AWidth <= 0 then
    MaxW := Screen.Width
  else
    MaxW := AWidth;

  // Calculate the required size using a helper THintWindow
  HintHelper := THintWindow.Create(nil);
  try
    HtRect := HintHelper.CalcHintRect(MaxW, AText, nil);
  finally
    HintHelper.Free;
  end;

  W := HtRect.Right - HtRect.Left;
  H := HtRect.Bottom - HtRect.Top;

  if AWidth > 0 then
    W := AWidth;
  if AHeight > 0 then
    H := AHeight;

  // Default positioning (bottom‑right corner with a small margin)
  if X = 0 then
    X := Screen.Width - W - 20;
  if Y = 0 then
    Y := Screen.WorkAreaHeight - H - 5;

  // Set size, text, then show
  FForm.SetBounds(X, Y, W, H);
  FForm.HintMemo.Text := AText;   // safe: Handle exists after HandleNeeded

  FForm.Show;
  FForm.BringToFront;

  if Duration > 0 then
    SetTimeoutSafe(FTimer, Duration, @TimerHide);
end;

procedure TOneShotTooltip.TimerHide;
begin
  // Called when the one‑shot timer fires – simply hide the hint
  HideHintInternal;
end;

procedure TOneShotTooltip.HideHintInternal;
begin
  if FIsHiding then Exit;   // prevent recursion (e.g. OnDeactivate ⇄ timer)
  FIsHiding := True;
  try
    ClearTimeout(FTimer);                     // cancel any pending timer
    if Assigned(FForm) then
    begin
      // Detach deactivate handler so hiding won't re‑trigger it
      FForm.OnDeactivate := nil;
      try
        if FForm.Visible then
          FForm.Hide;
      finally
        FForm.OnDeactivate := @FForm.FormDeactivate;
      end;
    end;
  finally
    FIsHiding := False;
  end;
end;

end.
