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
  OneShotTimer,
  GlobalMouseHook;

type
  TOneShotTooltip = class;

  // Internal hint form - a borderless, top-most window with a read-only Memo and resize grip
  TfrmHint = class(TForm)
  private
    FMemo: TMemo;
    FOwnerHint: TOneShotTooltip;
    FOwnerControl: TControl;          // control that owns this hint, to avoid hiding on click over it
    FGrip: TPanel;                    // invisible resize grip in the lower-right corner
    FResizing: boolean;
    FResizeStartPos: TPoint;           // screen coordinates of mouse at start
    FResizeStartSize: TPoint;          // form size at start (Width, Height)
    procedure FormDeactivate(Sender: TObject);
    procedure GripMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: integer);
    procedure FormMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: integer);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: integer);
    procedure FormResize(Sender: TObject);
    procedure GripPaint(Sender: TObject);
    procedure UpdateGripPosition;      // recalculates grip placement
  public
    constructor Create(AOwner: TComponent); override;
    procedure SetBackColor(AColor: TColor);
    property HintMemo: TMemo read FMemo;
    property OwnerControl: TControl read FOwnerControl write FOwnerControl;
  end;

  // Non-visual component that owns and manages a hint form
  TOneShotTooltip = class(TComponent)
  private
    FForm: TfrmHint;
    FTimer: TTimer;
    FIsHiding: boolean;
    FAutoFree: boolean;
    FOnHide: TNotifyEvent;
    procedure TimerHide;
    procedure HideHintInternal;
    procedure AppDeactivate(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ShowHintText(const AText: string; X, Y: integer; AWidth: integer = 0; AHeight: integer = 0;
      Duration: integer = 0; AColor: TColor = clInfoBk; AOwnerControl: TControl = nil);
    procedure Hide;
    class procedure Show(const AText: string; AWidth: integer = 0; AColor: TColor = clInfoBk; Duration: integer = 0;
      X: integer = 0; Y: integer = 0; AHeight: integer = 0); static;
    property AutoFree: boolean read FAutoFree write FAutoFree;
    property OnHide: TNotifyEvent read FOnHide write FOnHide;
  end;

implementation

const
  GRIP_SIZE = 16;
  GRIP_MARGIN_RIGHT = 2;
  GRIP_MARGIN_BOTTOM = 2;

  { TfrmHint }

constructor TfrmHint.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  BorderStyle := bsNone;
  FormStyle := fsStayOnTop;   // use fsStayOnTop like in TagCheckPopup
  Position := poDesigned;
  ShowHint := False;

  FMemo := TMemo.Create(Self);
  FMemo.Parent := Self;
  FMemo.Align := alClient;
  FMemo.BorderStyle := bsNone;
  FMemo.ReadOnly := True;
  FMemo.Color := clInfoBk;
  FMemo.Font.Assign(Screen.HintFont);
  FMemo.Font.Color := clWindowText;
  FMemo.WordWrap := True;
  FMemo.ScrollBars := ssVertical;
  FMemo.TabStop := False;

  FGrip := TPanel.Create(Self);
  FGrip.Parent := Self;
  FGrip.Width := GRIP_SIZE;
  FGrip.Height := GRIP_SIZE;
  FGrip.BevelOuter := bvNone;
  FGrip.Color := clInfoBk;
  FGrip.Cursor := crSizeNWSE;
  FGrip.ShowHint := False;
  FGrip.TabStop := False;
  FGrip.OnMouseDown := @GripMouseDown;
  FGrip.OnMouseMove := @FormMouseMove;
  FGrip.OnMouseUp := @FormMouseUp;
  FGrip.OnPaint := @GripPaint;
  FResizing := False;

  //OnMouseMove := @FormMouseMove;
  //OnMouseUp := @FormMouseUp;
  OnDeactivate := @FormDeactivate;
  OnResize := @FormResize;
end;

procedure TfrmHint.SetBackColor(AColor: TColor);
begin
  FMemo.Color := AColor;
  FGrip.Color := AColor;
  Self.Color := AColor;
end;

procedure TfrmHint.UpdateGripPosition;
begin
  FGrip.Left := ClientWidth - GRIP_SIZE - GRIP_MARGIN_RIGHT - GetSystemMetrics(SM_CXVSCROLL);
  FGrip.Top := ClientHeight - GRIP_SIZE - GRIP_MARGIN_BOTTOM;
end;

procedure TfrmHint.FormResize(Sender: TObject);
begin
  UpdateGripPosition;
end;

procedure TfrmHint.FormDeactivate(Sender: TObject);
var
  MousePos: TPoint;
  OwnerRect: TRect;
  ActiveForm: TCustomForm;
begin
  // If the active form is the hint itself or another hint, do not hide
  ActiveForm := Screen.ActiveCustomForm;
  if (ActiveForm = Self) or (ActiveForm is TfrmHint) then
    Exit;

  // If mouse is over the owner control, do not hide (let the button handle click)
  if Assigned(FOwnerControl) then
  begin
    MousePos := Mouse.CursorPos;
    OwnerRect := FOwnerControl.BoundsRect;
    OwnerRect.TopLeft := FOwnerControl.Parent.ClientToScreen(OwnerRect.TopLeft);
    OwnerRect.BottomRight := FOwnerControl.Parent.ClientToScreen(OwnerRect.BottomRight);
    if OwnerRect.Contains(MousePos) then
      Exit;
  end;

  // In all other cases hide the hint
  if Assigned(FOwnerHint) then
    FOwnerHint.HideHintInternal;
end;

procedure TfrmHint.GripMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
  if Button = mbLeft then
  begin
    FResizing := True;
    FResizeStartPos := Mouse.CursorPos;
    FResizeStartSize := Point(ClientWidth, ClientHeight);
    SetCapture(FGrip.Handle);
  end;
end;

procedure TfrmHint.FormMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
  if FResizing and (Button = mbLeft) then
  begin
    FResizing := False;
    ReleaseCapture;
  end;
end;

procedure TfrmHint.FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: integer);
var
  NewPos, Delta: TPoint;
  NewW, NewH: integer;
begin
  if FResizing then
  begin
    NewPos := Mouse.CursorPos;
    Delta.X := NewPos.X - FResizeStartPos.X;
    Delta.Y := NewPos.Y - FResizeStartPos.Y;
    NewW := FResizeStartSize.X + Delta.X;
    NewH := FResizeStartSize.Y + Delta.Y;
    if NewW < 100 then NewW := 100;
    if NewH < 20 then NewH := 20;
    SetBounds(Left, Top, NewW, NewH);
  end;
end;

procedure TfrmHint.GripPaint(Sender: TObject);
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
  ClearTimeout(FTimer);
  FForm.Free;
  inherited Destroy;
end;

procedure TOneShotTooltip.ShowHintText(const AText: string; X, Y: integer; AWidth: integer; AHeight: integer;
  Duration: integer; AColor: TColor; AOwnerControl: TControl);
var
  HtRect: TRect;
  MaxW, W, H: integer;
  HintHelper: THintWindow;
begin
  ClearTimeout(FTimer);
  FForm.HandleNeeded;

  if FForm.Visible then
  begin
    FForm.OnDeactivate := nil;
    try
      FForm.Hide;
    finally
      FForm.OnDeactivate := @FForm.FormDeactivate;
    end;
  end;

  // Store owner control for click-over-button detection
  FForm.OwnerControl := AOwnerControl;

  if AWidth <= 0 then
    MaxW := Screen.Width
  else
    MaxW := AWidth;

  HintHelper := THintWindow.Create(nil);
  try
    HtRect := HintHelper.CalcHintRect(MaxW, AText, nil);
  finally
    HintHelper.Free;
  end;

  W := HtRect.Right - HtRect.Left;
  H := HtRect.Bottom - HtRect.Top;
  if AWidth > 0 then W := AWidth;
  if AHeight > 0 then H := AHeight;

  if X = 0 then X := Screen.Width - W - 20;
  if Y = 0 then Y := Screen.WorkAreaHeight - H - 5;

  if X < 0 then X := 0
  else if X + W > Screen.WorkAreaWidth then X := Screen.WorkAreaWidth - W;
  if Y < 0 then Y := 0
  else if Y + H > Screen.WorkAreaHeight then Y := Screen.WorkAreaHeight - H;

  FForm.SetBackColor(AColor);
  FForm.SetBounds(X, Y, W, H);
  FForm.HintMemo.Text := AText;

  FForm.UpdateGripPosition;
  FForm.FGrip.BringToFront;

  // No PopupParent / PopupMode, no ScreenActiveFormChange
  // Only Application.OnDeactivate is used (fires when app loses focus,
  // not when clicking inside the app). FormDeactivate handles clicks outside.

  Application.AddOnDeactivateHandler(@AppDeactivate);

  if TGlobalMouseHook.GetActiveInstance <> nil then
    TGlobalMouseHook.GetActiveInstance.AddIgnoredWindow(FForm.Handle);

  FForm.Show;
  FForm.BringToFront;

  if Duration > 0 then
    SetTimeout(FTimer, Duration, @TimerHide);
end;

procedure TOneShotTooltip.Hide;
begin
  HideHintInternal;
end;

procedure TOneShotTooltip.TimerHide;
begin
  HideHintInternal;
end;

procedure TOneShotTooltip.HideHintInternal;
begin
  if FIsHiding then Exit;
  FIsHiding := True;
  try
    ClearTimeout(FTimer);
    if Assigned(FForm) then
    begin
      Application.RemoveOnDeactivateHandler(@AppDeactivate);
      if FForm.HandleAllocated and (TGlobalMouseHook.GetActiveInstance <> nil) then
        TGlobalMouseHook.GetActiveInstance.RemoveIgnoredWindow(FForm.Handle);
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

  if Assigned(FOnHide) then
    FOnHide(Self);

  if FAutoFree then
    Application.ReleaseComponent(Self);
end;

procedure TOneShotTooltip.AppDeactivate(Sender: TObject);
begin
  HideHintInternal;
end;

class procedure TOneShotTooltip.Show(const AText: string; AWidth: integer; AColor: TColor; Duration: integer;
  X: integer; Y: integer; AHeight: integer);
var
  Tooltip: TOneShotTooltip;
  MousePos: TPoint;
begin
  if (X = 0) and (Y = 0) then
  begin
    MousePos := Mouse.CursorPos;
    X := MousePos.X + 15;
    Y := MousePos.Y + 15;
  end;
  Tooltip := TOneShotTooltip.Create(Application);
  Tooltip.AutoFree := True;
  Tooltip.ShowHintText(AText, X, Y, AWidth, AHeight, Duration, AColor);
end;

end.
