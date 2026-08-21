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
  LCLIntf,
  LCLType,
  OneShotTimer;

type
  TOneShotTooltip = class;

  // Internal hint form - a borderless, top-most window with a read-only Memo and resize grip
  TfrmHint = class(TForm)
  private
    FMemo: TMemo;
    FOwnerHint: TOneShotTooltip;
    FGrip: TPanel;          // invisible resize grip in the lower-right corner
    FResizing: boolean;
    FResizeStartPos: TPoint; // screen coordinates of mouse at start
    FResizeStartSize: TPoint; // form size at start (Width, Height)
    procedure FormDeactivate(Sender: TObject);
    procedure GripMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: integer);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: integer);
    procedure FormMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: integer);
    procedure FormResize(Sender: TObject);
    procedure GripPaint(Sender: TObject);
    procedure UpdateGripPosition; // recalculates grip placement
  public
    constructor Create(AOwner: TComponent); override;
    procedure SetBackColor(AColor: TColor); // changes background color of hint content and grip
    property HintMemo: TMemo read FMemo;
  end;

  // Non-visual component that owns and manages a hint form
  TOneShotTooltip = class(TComponent)
  private
    FForm: TfrmHint;
    FTimer: TTimer;        // one-shot timer for auto-hide
    FIsHiding: boolean;    // prevents re-entrant hide calls
    FAutoFree: boolean;    // if true, component frees itself after hiding
    procedure TimerHide;   // timer callback
    procedure HideHintInternal;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // Show hint text at specified position.
    // Duration = 0  : hint stays until the user clicks outside it
    // Duration > 0  : hint hides after Duration ms (or on outside click)
    // AWidth, AHeight : custom size; 0 means auto-calculate
    // AColor : background color of the hint window
    procedure ShowHintText(const AText: string; X, Y: integer; AWidth: integer = 0; AHeight: integer = 0;
      Duration: integer = 0; AColor: TColor = clInfoBk);
    // Static method for quickly showing a hint without manual lifetime management.
    // Parameters: AText (text), AWidth (width, 0 = auto), AColor (background color),
    //   Duration (auto-hide timeout in ms, 0 = no timeout), X,Y (position, 0 = near mouse),
    //   AHeight (height, 0 = auto).
    class procedure Show(const AText: string; AWidth: integer = 0; AColor: TColor = clInfoBk; Duration: integer = 0;
      X: integer = 0; Y: integer = 0; AHeight: integer = 0); static;
    property AutoFree: boolean read FAutoFree write FAutoFree; // enable auto-free after hide
  end;

implementation

const
  GRIP_SIZE = 16;       // side length of the resize grip square
  GRIP_MARGIN_RIGHT = 2;      // distance from form edges
  GRIP_MARGIN_BOTTOM = 2;      // distance from form edges

  { TfrmHint }

constructor TfrmHint.Create(AOwner: TComponent);
begin
  // We inherit from TForm but have no LFM resource.
  // The host temporarily disables RequireDerivedFormResource before creating us.
  inherited Create(AOwner);

  // Form properties: no border, always on top, manually positioned
  BorderStyle := bsNone;
  FormStyle := fsSystemStayOnTop;
  Position := poDesigned;
  ShowHint := False;

  // Memo for displaying the hint text
  FMemo := TMemo.Create(Self);
  FMemo.Parent := Self;
  FMemo.Align := alClient;
  FMemo.BorderStyle := bsNone;
  FMemo.ReadOnly := True;
  FMemo.Color := clInfoBk;               // standard hint background colour
  FMemo.Font.Assign(Screen.HintFont);    // standard hint font
  FMemo.WordWrap := True;
  FMemo.ScrollBars := ssVertical;        // vertical scrollbar appears when content overflows
  FMemo.TabStop := False;

  // Create an invisible resize grip
  FGrip := TPanel.Create(Self);
  FGrip.Parent := Self;
  FGrip.Width := GRIP_SIZE;
  FGrip.Height := GRIP_SIZE;
  FGrip.BevelOuter := bvNone;
  FGrip.Color := clInfoBk;               // blend with background
  FGrip.Cursor := crSizeNWSE;
  FGrip.ShowHint := False;
  FGrip.TabStop := False;
  FGrip.OnMouseDown := @GripMouseDown;
  FGrip.OnPaint := @GripPaint;           // draw diagonal lines for visual cue

  FResizing := False;

  // Form-level mouse handlers for resize tracking
  OnMouseMove := @FormMouseMove;
  OnMouseUp := @FormMouseUp;
  OnDeactivate := @FormDeactivate;
  OnResize := @FormResize;               // keep grip in corner when size changes
end;

procedure TfrmHint.SetBackColor(AColor: TColor);
begin
  // Apply the requested background color to the memo, grip, and the form itself
  FMemo.Color := AColor;
  FGrip.Color := AColor;
  Self.Color := AColor;
end;

procedure TfrmHint.UpdateGripPosition;
begin
  // Place the grip in the bottom-right corner with a small margin
  FGrip.Left := ClientWidth - GRIP_SIZE - GRIP_MARGIN_RIGHT - GetSystemMetrics(SM_CXVSCROLL);
  FGrip.Top := ClientHeight - GRIP_SIZE - GRIP_MARGIN_BOTTOM;
end;

procedure TfrmHint.FormResize(Sender: TObject);
begin
  UpdateGripPosition;
end;

procedure TfrmHint.FormDeactivate(Sender: TObject);
begin
  // When the form loses focus (user clicks outside), close the hint
  if Assigned(FOwnerHint) then
    FOwnerHint.HideHintInternal;
end;

procedure TfrmHint.GripMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
  if Button = mbLeft then
  begin
    FResizing := True;
    // Record starting position (screen coordinates) and current client size
    FResizeStartPos := Mouse.CursorPos;
    FResizeStartSize := Point(ClientWidth, ClientHeight);
    // Capture all mouse events to this form until mouse up
    Self.MouseCapture := True;
  end;
end;

procedure TfrmHint.FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: integer);
var
  NewPos: TPoint;
  Delta: TPoint;
  NewW, NewH: integer;
begin
  if FResizing then
  begin
    NewPos := Mouse.CursorPos;
    Delta.X := NewPos.X - FResizeStartPos.X;
    Delta.Y := NewPos.Y - FResizeStartPos.Y;
    NewW := FResizeStartSize.X + Delta.X;
    NewH := FResizeStartSize.Y + Delta.Y;
    // Enforce reasonable minimum size
    if NewW < 100 then
      NewW := 100;
    if NewH < 20 then
      NewH := 20;
    SetBounds(Left, Top, NewW, NewH);
    // UpdateGripPosition is called automatically via OnResize
  end;
end;

procedure TfrmHint.FormMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
  if FResizing and (Button = mbLeft) then
  begin
    FResizing := False;
    Self.MouseCapture := False; // release capture back to normal
  end;
end;

procedure TfrmHint.GripPaint(Sender: TObject);
// Paints three small diagonal lines in the bottom-right corner
const
  LINE_OFFSET = 4;
var
  i: integer;
begin
  with TPanel(Sender).Canvas do
  begin
    Pen.Color := clBtnShadow;
    Pen.Width := 1;
    for i := 0 to 2 do
    begin
      MoveTo(GRIP_SIZE - LINE_OFFSET, LINE_OFFSET + i * 4);
      LineTo(LINE_OFFSET + i * 4, GRIP_SIZE - LINE_OFFSET);
    end;
  end;
end;

{ TOneShotTooltip }

constructor TOneShotTooltip.Create(AOwner: TComponent);
var
  OldRequire: boolean;
begin
  inherited Create(AOwner);
  // Temporarily allow creating a form without a corresponding resource file
  OldRequire := RequireDerivedFormResource;
  RequireDerivedFormResource := False;
  try
    FForm := TfrmHint.Create(nil);
  finally
    RequireDerivedFormResource := OldRequire;
  end;
  FForm.FOwnerHint := Self;
  FTimer := nil;
  FIsHiding := False;
  FAutoFree := False;
end;

destructor TOneShotTooltip.Destroy;
begin
  ClearTimeout(FTimer);   // cancel any pending timer (safe, nils FTimer)
  FForm.Free;             // destroy the owned form
  inherited Destroy;
end;

procedure TOneShotTooltip.ShowHintText(const AText: string; X, Y: integer; AWidth: integer; AHeight: integer;
  Duration: integer; AColor: TColor);
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

  // Default positioning (bottom-right corner with a small margin)
  if X = 0 then
    X := Screen.Width - W - 20;
  if Y = 0 then
    Y := Screen.WorkAreaHeight - H - 5;

  // Keep the window inside the working area of the screen
  if X < 0 then
    X := 0
  else if X + W > Screen.WorkAreaWidth then
    X := Screen.WorkAreaWidth - W;
  if Y < 0 then
    Y := 0
  else if Y + H > Screen.WorkAreaHeight then
    Y := Screen.WorkAreaHeight - H;

  // Apply the requested background color before showing
  FForm.SetBackColor(AColor);

  // Set size, text, then show
  FForm.SetBounds(X, Y, W, H);
  FForm.HintMemo.Text := AText;   // safe: Handle exists after HandleNeeded

  // Ensure grip is positioned correctly after the first resize
  FForm.UpdateGripPosition;
  FForm.FGrip.BringToFront;       // stay above the memo

  FForm.Show;
  FForm.BringToFront;

  if Duration > 0 then
    SetTimeout(FTimer, Duration, @TimerHide);
end;

procedure TOneShotTooltip.TimerHide;
begin
  // Called when the one-shot timer fires - simply hide the hint
  HideHintInternal;
end;

procedure TOneShotTooltip.HideHintInternal;
begin
  if FIsHiding then Exit;   // prevent recursion (e.g. OnDeactivate and timer)
  FIsHiding := True;
  try
    ClearTimeout(FTimer);                     // cancel any pending timer
    if Assigned(FForm) then
    begin
      // Detach deactivate handler so hiding won't re-trigger it
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
  // If auto-free is enabled, schedule the component to be freed after the current message
  if FAutoFree then
    Application.ReleaseComponent(Self);
end;

class procedure TOneShotTooltip.Show(const AText: string; AWidth: integer; AColor: TColor; Duration: integer;
  X: integer; Y: integer; AHeight: integer);
var
  Tooltip: TOneShotTooltip;
  MousePos: TPoint;
begin
  // If no coordinates were specified, show the hint near the current mouse position
  if (X = 0) and (Y = 0) then
  begin
    MousePos := Mouse.CursorPos;
    X := MousePos.X + 15; // small offset from cursor to avoid covering it
    Y := MousePos.Y + 15;
  end;
  Tooltip := TOneShotTooltip.Create(Application); // Application owns the component for final cleanup
  Tooltip.AutoFree := True;
  Tooltip.ShowHintText(AText, X, Y, AWidth, AHeight, Duration, AColor);
end;

end.
