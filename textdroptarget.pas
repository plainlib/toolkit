//-----------------------------------------------------------------------------------
//  Toolkit Package © 2026 by Alexander Tverskoy
//  Licensed under the MIT License
//  You may obtain a copy of the License at https://opensource.org/licenses/MIT
//-----------------------------------------------------------------------------------

unit TextDropTarget;

{$NOTES OFF}
{$HINTS OFF}
{$WARNINGS OFF}

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, StdCtrls, Controls
  {$IFDEF WINDOWS}
  , Windows, ActiveX, ComObj
  {$ENDIF};

type
  TTextDropTarget = class;

  TTextDropEvent = procedure(Sender: TObject; const Text: string) of object;

  {$IFDEF WINDOWS}

  TTextDropTargetImpl = class(TInterfacedObject, IDropTarget)
  private
    FOwner: TTextDropTarget;
    FEdit: TCustomEdit;

    function HasTextFormat(const DataObj: IDataObject): Boolean;

    function DragEnter(const DataObj: IDataObject; GrfKeyState: DWORD;
      Pt: TPoint; var dwEffect: DWORD): HRESULT; stdcall;

    function DragOver(GrfKeyState: DWORD; Pt: TPoint;
      var dwEffect: DWORD): HRESULT; stdcall;

    function DragLeave: HRESULT; stdcall;

    function Drop(const DataObj: IDataObject; GrfKeyState: DWORD;
      Pt: TPoint; var dwEffect: DWORD): HRESULT; stdcall;
  public
    constructor Create(AOwner: TTextDropTarget; AEdit: TCustomEdit);
  end;

  TTextDropTargetSubImpl = class(TInterfacedObject, IDropTarget)
  private
    FOwner: TTextDropTarget;
    FSubControl: TWinControl;

    function HasTextFormat(const DataObj: IDataObject): Boolean;

    function DragEnter(const DataObj: IDataObject; GrfKeyState: DWORD;
      Pt: TPoint; var dwEffect: DWORD): HRESULT; stdcall;

    function DragOver(GrfKeyState: DWORD; Pt: TPoint;
      var dwEffect: DWORD): HRESULT; stdcall;

    function DragLeave: HRESULT; stdcall;

    function Drop(const DataObj: IDataObject; GrfKeyState: DWORD;
      Pt: TPoint; var dwEffect: DWORD): HRESULT; stdcall;
  public
    constructor Create(AOwner: TTextDropTarget; AControl: TWinControl);
  end;

  {$ENDIF}

  TTextDropTarget = class(TComponent)
  private
    FTarget: TCustomEdit;
    FInsertText: boolean;
    FOnTextDropped: TTextDropEvent;

    {$IFDEF WINDOWS}
    FImpl: IDropTarget;
    FRegisteredHandle: HWND;

    FSubControls: TFPList;
    FSubHandles: TFPList;
    FSubImpls: TInterfaceList;

    procedure RegisterTarget;
    procedure UnregisterTarget;

    procedure RegisterSubTarget(AControl: TWinControl);
    procedure UnregisterSubTarget(AControl: TWinControl);

    function GetSubTarget(Index: Integer): TWinControl;
    {$ENDIF}

    procedure SetTarget(AValue: TCustomEdit);
    procedure SetInsertText(AValue: boolean);

  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;

    procedure DoTextDropped(ASender: TObject; const Text: string); virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    {$IFDEF WINDOWS}
    property SubTargets[Index: Integer]: TWinControl
      read GetSubTarget;

    procedure ForceRegister;
    procedure Unregister;

    procedure AddSubTarget(AControl: TWinControl);
    procedure RemoveSubTarget(AControl: TWinControl);
    procedure ClearSubTargets;

    function SubTargetCount: Integer;
    {$ENDIF}

  published
    property Target: TCustomEdit read FTarget write SetTarget;
    property InsertText: boolean read FInsertText write SetInsertText default True;
    property OnTextDropped: TTextDropEvent read FOnTextDropped write FOnTextDropped;
  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('Common Controls', [TTextDropTarget]);
end;

{ TTextDropTarget }

constructor TTextDropTarget.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FTarget := nil;
  FInsertText := True;
  FOnTextDropped := nil;

  {$IFDEF WINDOWS}
  FImpl := nil;
  FRegisteredHandle := 0;

  FSubControls := TFPList.Create;
  FSubHandles := TFPList.Create;
  FSubImpls := TInterfaceList.Create;
  {$ENDIF}
end;

destructor TTextDropTarget.Destroy;
begin
  {$IFDEF WINDOWS}
  ClearSubTargets;

  FSubImpls.Free;
  FSubHandles.Free;
  FSubControls.Free;
  {$ENDIF}

  Target := nil;

  inherited Destroy;
end;

procedure TTextDropTarget.SetTarget(AValue: TCustomEdit);
begin
  if FTarget = AValue then
    Exit;

  {$IFDEF WINDOWS}
  UnregisterTarget;
  {$ENDIF}

  FTarget := AValue;

  {$IFDEF WINDOWS}
  if Assigned(FTarget) then
  begin
    FTarget.FreeNotification(Self);

    if FTarget.HandleAllocated then
      RegisterTarget;
  end;
  {$ENDIF}
end;

procedure TTextDropTarget.SetInsertText(AValue: boolean);
begin
  if FInsertText = AValue then
    Exit;

  FInsertText := AValue;
end;

procedure TTextDropTarget.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;

  if Operation <> opRemove then
    Exit;

  if AComponent = FTarget then
  begin
    Target := nil;
    Exit;
  end;

  {$IFDEF WINDOWS}
  if AComponent is TWinControl then
    RemoveSubTarget(TWinControl(AComponent));
  {$ENDIF}
end;

procedure TTextDropTarget.DoTextDropped(ASender: TObject; const Text: string);
begin
  if Assigned(FOnTextDropped) then
    FOnTextDropped(ASender, Text);
end;

{$IFDEF WINDOWS}

var
  CF_HTML_FORMAT: UINT = 0;
  CF_HTML_MIME: UINT = 0;
  CF_TEXT_PLAIN: UINT = 0;

function StripHTMLTags(const HTML: string): string;
var
  I: Integer;
  InTag: Boolean;
begin
  Result := '';
  InTag := False;

  for I := 1 to Length(HTML) do
  begin
    if HTML[I] = '<' then
      InTag := True
    else if HTML[I] = '>' then
      InTag := False
    else if not InTag then
      Result := Result + HTML[I];
  end;
end;

function HasDropTextFormat(const DataObj: IDataObject): Boolean;
var
  Fmt: TFormatEtc;
begin
  Result := False;

  Fmt.ptd := nil;
  Fmt.dwAspect := DVASPECT_CONTENT;
  Fmt.lindex := -1;
  Fmt.tymed := TYMED_HGLOBAL;

  Fmt.cfFormat := CF_UNICODETEXT;
  if Succeeded(DataObj.QueryGetData(Fmt)) then
    Exit(True);

  Fmt.cfFormat := CF_TEXT;
  if Succeeded(DataObj.QueryGetData(Fmt)) then
    Exit(True);

  if CF_HTML_FORMAT <> 0 then
  begin
    Fmt.cfFormat := CF_HTML_FORMAT;
    if Succeeded(DataObj.QueryGetData(Fmt)) then
      Exit(True);
  end;

  if CF_HTML_MIME <> 0 then
  begin
    Fmt.cfFormat := CF_HTML_MIME;
    if Succeeded(DataObj.QueryGetData(Fmt)) then
      Exit(True);
  end;

  if CF_TEXT_PLAIN <> 0 then
  begin
    Fmt.cfFormat := CF_TEXT_PLAIN;
    if Succeeded(DataObj.QueryGetData(Fmt)) then
      Exit(True);
  end;
end;

function GetDropText(const DataObj: IDataObject): string;
var
  Fmt: TFormatEtc;
  Stg: TStgMedium;
  PText: PChar;

  IsUnicode: Boolean;
  IsPlainText: Boolean;
  IsHTML: Boolean;
  IsHTMLMime: Boolean;

  CF: UINT;
begin
  Result := '';

  Fmt.ptd := nil;
  Fmt.dwAspect := DVASPECT_CONTENT;
  Fmt.lindex := -1;
  Fmt.tymed := TYMED_HGLOBAL;

  IsUnicode := False;
  IsPlainText := False;
  IsHTML := False;
  IsHTMLMime := False;
  CF := 0;

  Fmt.cfFormat := CF_UNICODETEXT;

  if Succeeded(DataObj.QueryGetData(Fmt)) then
    IsUnicode := True
  else
  begin
    if CF_HTML_FORMAT <> 0 then
    begin
      Fmt.cfFormat := CF_HTML_FORMAT;

      if Succeeded(DataObj.QueryGetData(Fmt)) then
      begin
        IsHTML := True;
        CF := CF_HTML_FORMAT;
      end;
    end;

    if not IsHTML and (CF_HTML_MIME <> 0) then
    begin
      Fmt.cfFormat := CF_HTML_MIME;

      if Succeeded(DataObj.QueryGetData(Fmt)) then
      begin
        IsHTMLMime := True;
        CF := CF_HTML_MIME;
      end;
    end;

    if not IsHTML and not IsHTMLMime and
       (CF_TEXT_PLAIN <> 0) then
    begin
      Fmt.cfFormat := CF_TEXT_PLAIN;

      if Succeeded(DataObj.QueryGetData(Fmt)) then
      begin
        IsPlainText := True;
        CF := CF_TEXT_PLAIN;
      end;
    end;

    if not IsHTML and not IsHTMLMime and not IsPlainText then
    begin
      Fmt.cfFormat := CF_TEXT;

      if Failed(DataObj.QueryGetData(Fmt)) then
        Exit;
    end;
  end;

  if IsUnicode then
    Fmt.cfFormat := CF_UNICODETEXT
  else if IsHTML or IsHTMLMime then
    Fmt.cfFormat := CF
  else if IsPlainText then
    Fmt.cfFormat := CF_TEXT_PLAIN
  else
    Fmt.cfFormat := CF_TEXT;

  if Failed(DataObj.GetData(Fmt, Stg)) then
    Exit;

  try
    PText := GlobalLock(Stg.hGlobal);

    if not Assigned(PText) then
      Exit;

    try
      if IsUnicode then
        Result := PWideChar(PText)
      else if IsHTML or IsHTMLMime then
        Result := StripHTMLTags(string(PAnsiChar(PText)))
      else
        Result := string(PAnsiChar(PText));
    finally
      GlobalUnlock(Stg.hGlobal);
    end;
  finally
    ReleaseStgMedium(Stg);
  end;
end;

function IsStandardEditWindow(AHandle: HWND): Boolean;
var
  Buffer: array[0..255] of Char;
  Len: Integer;
begin
  Result := False;

  if AHandle = 0 then
    Exit;

  Len := GetClassName(AHandle, Buffer, Length(Buffer));

  if Len > 0 then
    Result := StrComp(Buffer, 'EDIT') = 0;
end;

function IsRichEditWindow(AHandle: HWND): Boolean;
var
  Buffer: array[0..255] of Char;
  Len: Integer;
begin
  Result := False;

  if AHandle = 0 then
    Exit;

  Len := GetClassName(AHandle, Buffer, Length(Buffer));

  if Len > 0 then
    Result :=
      (StrComp(Buffer, 'RICHEDIT') = 0) or
      (StrComp(Buffer, 'RICHEDIT20W') = 0) or
      (StrComp(Buffer, 'RICHEDIT50W') = 0);
end;

function GetCharIndexFromPos(AEdit: TCustomEdit;
  X, Y: Integer): Integer;
var
  ClientPt: TPoint;
  PtL: POINTL;
  CharIdx: LResult;
  IsEdit: Boolean;
  IsRich: Boolean;
begin
  Result := -1;

  if not Assigned(AEdit) or not AEdit.HandleAllocated then
    Exit;

  IsEdit := IsStandardEditWindow(AEdit.Handle);
  IsRich := IsRichEditWindow(AEdit.Handle);

  if not (IsEdit or IsRich) then
    Exit;

  ClientPt := AEdit.ScreenToClient(Classes.Point(X, Y));

  if IsEdit then
  begin
    CharIdx := SendMessage(
      AEdit.Handle,
      EM_CHARFROMPOS,
      0,
      MakeLParam(ClientPt.X, ClientPt.Y)
    );
  end
  else
  begin
    PtL.X := ClientPt.X;
    PtL.Y := ClientPt.Y;

    CharIdx := SendMessage(
      AEdit.Handle,
      EM_CHARFROMPOS,
      0,
      LPARAM(@PtL)
    );
  end;

  if CharIdx >= 0 then
    Result := Integer(CharIdx);
end;

{ Registration }

procedure TTextDropTarget.RegisterTarget;
begin
  if not Assigned(FTarget) or not FTarget.HandleAllocated then
    Exit;

  if FRegisteredHandle = FTarget.Handle then
    Exit;

  UnregisterTarget;

  FImpl := TTextDropTargetImpl.Create(Self, FTarget);

  OleCheck(
    RegisterDragDrop(FTarget.Handle, FImpl)
  );

  FRegisteredHandle := FTarget.Handle;
end;

procedure TTextDropTarget.UnregisterTarget;
begin
  if FRegisteredHandle <> 0 then
  begin
    if IsWindow(FRegisteredHandle) then
      RevokeDragDrop(FRegisteredHandle);

    FRegisteredHandle := 0;
  end;

  FImpl := nil;
end;

procedure TTextDropTarget.ForceRegister;
var
  I: Integer;
  Ctrl: TWinControl;
  H: HWND;
  SubImpl: IDropTarget;
begin
  if Assigned(FTarget) and FTarget.HandleAllocated then
  begin
    if FRegisteredHandle <> FTarget.Handle then
    begin
      UnregisterTarget;
      RegisterTarget;
    end;
  end
  else
    UnregisterTarget;

  for I := 0 to FSubHandles.Count - 1 do
  begin
    H := HWND(FSubHandles[I]);

    if (H <> 0) and IsWindow(H) then
      RevokeDragDrop(H);
  end;

  FSubHandles.Clear;
  FSubImpls.Clear;

  for I := 0 to FSubControls.Count - 1 do
  begin
    Ctrl := TWinControl(FSubControls[I]);

    if not Ctrl.HandleAllocated then
      Ctrl.HandleNeeded;

    H := Ctrl.Handle;

    SubImpl := TTextDropTargetSubImpl.Create(Self, Ctrl);

    OleCheck(
      RegisterDragDrop(H, SubImpl)
    );

    FSubHandles.Add(Pointer(H));
    FSubImpls.Add(SubImpl as IUnknown);
  end;
end;

procedure TTextDropTarget.Unregister;
var
  I: Integer;
  H: HWND;
begin
  UnregisterTarget;

  for I := 0 to FSubHandles.Count - 1 do
  begin
    H := HWND(FSubHandles[I]);

    if (H <> 0) and IsWindow(H) then
      RevokeDragDrop(H);
  end;

  FSubHandles.Clear;
  FSubImpls.Clear;
end;

{ Sub-targets }

procedure TTextDropTarget.RegisterSubTarget(AControl: TWinControl);
var
  SubImpl: IDropTarget;
  H: HWND;
begin
  if not Assigned(AControl) or (AControl = FTarget) then
    Exit;

  if FSubControls.IndexOf(AControl) >= 0 then
    Exit;

  if not AControl.HandleAllocated then
    AControl.HandleNeeded;

  H := AControl.Handle;

  SubImpl := TTextDropTargetSubImpl.Create(Self, AControl);

  OleCheck(
    RegisterDragDrop(H, SubImpl)
  );

  FSubControls.Add(AControl);
  FSubHandles.Add(Pointer(H));
  FSubImpls.Add(SubImpl as IUnknown);

  AControl.FreeNotification(Self);
end;

procedure TTextDropTarget.UnregisterSubTarget(AControl: TWinControl);
var
  Idx: Integer;
  H: HWND;
begin
  Idx := FSubControls.IndexOf(AControl);

  if Idx < 0 then
    Exit;

  if Idx < FSubHandles.Count then
  begin
    H := HWND(FSubHandles[Idx]);

    if (H <> 0) and IsWindow(H) then
      RevokeDragDrop(H);

    FSubHandles.Delete(Idx);
    FSubImpls.Delete(Idx);
  end;

  FSubControls.Delete(Idx);
end;

procedure TTextDropTarget.AddSubTarget(AControl: TWinControl);
begin
  RegisterSubTarget(AControl);
end;

procedure TTextDropTarget.RemoveSubTarget(AControl: TWinControl);
begin
  UnregisterSubTarget(AControl);
end;

procedure TTextDropTarget.ClearSubTargets;
begin
  while FSubControls.Count > 0 do
    RemoveSubTarget(
      TWinControl(FSubControls.Last)
    );
end;

function TTextDropTarget.SubTargetCount: Integer;
begin
  Result := FSubControls.Count;
end;

function TTextDropTarget.GetSubTarget(Index: Integer): TWinControl;
begin
  Result := TWinControl(FSubControls[Index]);
end;

{ TTextDropTargetImpl }

constructor TTextDropTargetImpl.Create(
  AOwner: TTextDropTarget;
  AEdit: TCustomEdit);
begin
  inherited Create;

  FOwner := AOwner;
  FEdit := AEdit;
end;

function TTextDropTargetImpl.HasTextFormat(
  const DataObj: IDataObject): Boolean;
begin
  Result := HasDropTextFormat(DataObj);
end;

function TTextDropTargetImpl.DragEnter(
  const DataObj: IDataObject;
  GrfKeyState: DWORD;
  Pt: TPoint;
  var dwEffect: DWORD): HRESULT; stdcall;
begin
  if HasTextFormat(DataObj) then
    dwEffect := DROPEFFECT_COPY
  else
    dwEffect := DROPEFFECT_NONE;

  Result := S_OK;
end;

function TTextDropTargetImpl.DragOver(
  GrfKeyState: DWORD;
  Pt: TPoint;
  var dwEffect: DWORD): HRESULT; stdcall;
var
  CharIdx: Integer;
begin
  dwEffect := DROPEFFECT_COPY;

  // Insert mode is the only mode where the caret follows the mouse.
  if not FOwner.InsertText then
  begin
    Result := S_OK;
    Exit;
  end;

  if not Assigned(FEdit) or not FEdit.HandleAllocated then
  begin
    Result := S_OK;
    Exit;
  end;

  CharIdx := GetCharIndexFromPos(FEdit, Pt.X, Pt.Y);

  if CharIdx >= 0 then
  begin
    FEdit.SelStart := CharIdx;
    FEdit.SelLength := 0;
  end;

  Result := S_OK;
end;

function TTextDropTargetImpl.DragLeave: HRESULT; stdcall;
begin
  Result := S_OK;
end;

function TTextDropTargetImpl.Drop(
  const DataObj: IDataObject;
  GrfKeyState: DWORD;
  Pt: TPoint;
  var dwEffect: DWORD): HRESULT; stdcall;
var
  S: string;
  CharIdx: Integer;
begin
  if not Assigned(FEdit) or not Assigned(FOwner) then
  begin
    dwEffect := DROPEFFECT_NONE;
    Exit(E_FAIL);
  end;

  S := GetDropText(DataObj);

  if S = '' then
  begin
    dwEffect := DROPEFFECT_NONE;
    Exit(E_FAIL);
  end;

  if not FOwner.InsertText then
  begin
    // Replace the complete contents without touching the caret position.
    FEdit.Text := S;

    dwEffect := DROPEFFECT_COPY;
    Exit(S_OK);
  end;

  CharIdx := GetCharIndexFromPos(FEdit, Pt.X, Pt.Y);

  if CharIdx >= 0 then
  begin
    FEdit.SelStart := CharIdx;
    FEdit.SelLength := 0;
  end;

  FEdit.SelText := S;

  FOwner.DoTextDropped(FEdit, S);

  dwEffect := DROPEFFECT_COPY;
  Result := S_OK;
end;

{ TTextDropTargetSubImpl }

constructor TTextDropTargetSubImpl.Create(
  AOwner: TTextDropTarget;
  AControl: TWinControl);
begin
  inherited Create;

  FOwner := AOwner;
  FSubControl := AControl;
end;

function TTextDropTargetSubImpl.HasTextFormat(
  const DataObj: IDataObject): Boolean;
begin
  Result := HasDropTextFormat(DataObj);
end;

function TTextDropTargetSubImpl.DragEnter(
  const DataObj: IDataObject;
  GrfKeyState: DWORD;
  Pt: TPoint;
  var dwEffect: DWORD): HRESULT; stdcall;
begin
  if HasTextFormat(DataObj) then
    dwEffect := DROPEFFECT_COPY
  else
    dwEffect := DROPEFFECT_NONE;

  Result := S_OK;
end;

function TTextDropTargetSubImpl.DragOver(
  GrfKeyState: DWORD;
  Pt: TPoint;
  var dwEffect: DWORD): HRESULT; stdcall;
var
  CharIdx: Integer;
begin
  dwEffect := DROPEFFECT_COPY;

  // No caret tracking at all in replace mode.
  if not FOwner.InsertText then
  begin
    Result := S_OK;
    Exit;
  end;

  if not Assigned(FOwner.FTarget) or
     not FOwner.FTarget.HandleAllocated then
  begin
    Result := S_OK;
    Exit;
  end;

  CharIdx := GetCharIndexFromPos(
    FOwner.FTarget,
    Pt.X,
    Pt.Y
  );

  if CharIdx >= 0 then
  begin
    FOwner.FTarget.SelStart := CharIdx;
    FOwner.FTarget.SelLength := 0;
  end;

  Result := S_OK;
end;

function TTextDropTargetSubImpl.DragLeave: HRESULT; stdcall;
begin
  Result := S_OK;
end;

function TTextDropTargetSubImpl.Drop(
  const DataObj: IDataObject;
  GrfKeyState: DWORD;
  Pt: TPoint;
  var dwEffect: DWORD): HRESULT; stdcall;
var
  S: string;
  CharIdx: Integer;
begin
  if not Assigned(FOwner) then
  begin
    dwEffect := DROPEFFECT_NONE;
    Exit(E_FAIL);
  end;

  S := GetDropText(DataObj);

  if S = '' then
  begin
    dwEffect := DROPEFFECT_NONE;
    Exit(E_FAIL);
  end;

  if not FOwner.InsertText then
  begin
    // Replace the complete contents without moving the caret.
    if Assigned(FOwner.FTarget) and
       FOwner.FTarget.HandleAllocated then
      FOwner.FTarget.Text := S;

    FOwner.DoTextDropped(FSubControl, S);

    dwEffect := DROPEFFECT_COPY;
    Exit(S_OK);
  end;

  if Assigned(FOwner.FTarget) and
     FOwner.FTarget.HandleAllocated then
  begin
    CharIdx := GetCharIndexFromPos(
      FOwner.FTarget,
      Pt.X,
      Pt.Y
    );

    if CharIdx >= 0 then
    begin
      FOwner.FTarget.SelStart := CharIdx;
      FOwner.FTarget.SelLength := 0;
    end;

    FOwner.FTarget.SelText := S;
  end;

  FOwner.DoTextDropped(FSubControl, S);

  dwEffect := DROPEFFECT_COPY;
  Result := S_OK;
end;

{$ENDIF}

{$IFDEF WINDOWS}

initialization
  CoInitializeEx(nil, COINIT_APARTMENTTHREADED);

  CF_HTML_FORMAT := RegisterClipboardFormat('HTML Format');
  CF_HTML_MIME := RegisterClipboardFormat('text/html');
  CF_TEXT_PLAIN := RegisterClipboardFormat('text/plain');

finalization
  CoUninitialize;

{$ENDIF}

end.
