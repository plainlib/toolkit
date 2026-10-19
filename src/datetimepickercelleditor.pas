unit DateTimePickerCellEditor;

{$mode ObjFPC}{$H+}

interface

uses
  Classes,
  SysUtils,
  Grids,
  DateTimePicker;

type
  TDateTimePickerCellEditor = class(TDateTimePicker)
  private
    FGrid: TCustomGrid;
    FCol: Integer;
    FRow: Integer;
  protected
    procedure MsgSetGrid(var Msg: TGridMessage); message GM_SETGRID;
    procedure MsgSetPos(var Msg: TGridMessage); message GM_SETPOS;
    procedure MsgSetBounds(var Msg: TGridMessage); message GM_SETBOUNDS;
    procedure MsgSetValue(var Msg: TGridMessage); message GM_SETVALUE;
    procedure MsgGetValue(var Msg: TGridMessage); message GM_GETVALUE;
  end;

implementation

procedure TDateTimePickerCellEditor.MsgSetGrid(var Msg: TGridMessage);
begin
  FGrid := Msg.Grid;
   AutoSize := False;
end;

procedure TDateTimePickerCellEditor.MsgSetPos(var Msg: TGridMessage);
begin
  FCol := Msg.Col;
  FRow := Msg.Row;
end;

procedure TDateTimePickerCellEditor.MsgSetBounds(var Msg: TGridMessage);
begin
  with Msg.CellRect do
    SetBounds(Left, Top, Right - Left-1, Bottom - Top-1);
end;

procedure TDateTimePickerCellEditor.MsgSetValue(var Msg: TGridMessage);
var
  D: TDateTime;
begin
  if TryStrToDateTime(Msg.Value, D) then
    DateTime := D;
end;

procedure TDateTimePickerCellEditor.MsgGetValue(var Msg: TGridMessage);
begin
  Msg.Value := DateTimeToStr(DateTime);
end;

end.
