unit WinOCRApi;

{$mode objfpc}{$H+}
{$INTERFACES COM}

interface

{$IFDEF WINDOWS}

uses
  Types, SysUtils, Classes, Menus, Windows, IntfGraphics;

type
  // Raised when native OCR cannot be performed
  EWinOcrError = class(Exception);

  IInspectable = interface;
  IAsyncInfo = interface;
  IAsyncOperationBitmapDecoder = interface;
  IAsyncOperationSoftwareBitmap = interface;
  IAsyncOperationOcrResult = interface;
  IBitmapDecoder = interface;
  IBitmapFrameWithSoftwareBitmap = interface;
  IOcrEngine = interface;
  IOcrResult = interface;
  IOcrLine = interface;
  IVectorViewOcrLine = interface;

  IInspectable = interface(IUnknown)
    ['{AF86E2E0-B12D-4C6A-9C5A-D7AA65101E90}']
    function GetIids(out IidCount: longword; out Iids: Pointer): HRESULT; stdcall;
    function GetRuntimeClassName(out ClassName: Pointer): HRESULT; stdcall;
    function GetTrustLevel(out TrustLevel: integer): HRESULT; stdcall;
  end;

  IAsyncInfo = interface(IInspectable)
    ['{00000036-0000-0000-C000-000000000046}']
    function GetId(out Id: longword): HRESULT; stdcall;
    function GetStatus(out Status: longword): HRESULT; stdcall;
    function GetErrorCode(out ErrorCode: HRESULT): HRESULT; stdcall;
    function Cancel: HRESULT; stdcall;
    function Close: HRESULT; stdcall;
  end;

  IAsyncOperationBitmapDecoder = interface(IInspectable)
    ['{AA94D8E9-CAEF-53F6-823D-91B6E8340510}']
    function PutCompleted(Handler: IUnknown): HRESULT; stdcall;
    function GetCompleted(out Handler: IUnknown): HRESULT; stdcall;
    function GetResults(out Results: IBitmapDecoder): HRESULT; stdcall;
  end;

  IAsyncOperationSoftwareBitmap = interface(IInspectable)
    ['{C4A10980-714B-5501-8DA2-DBDACCE70F73}']
    function PutCompleted(Handler: IUnknown): HRESULT; stdcall;
    function GetCompleted(out Handler: IUnknown): HRESULT; stdcall;
    function GetResults(out Results: IUnknown): HRESULT; stdcall;
  end;

  IAsyncOperationOcrResult = interface(IInspectable)
    ['{C7D7118E-AE36-59C0-AC76-7BADEE711C8B}']
    function PutCompleted(Handler: IUnknown): HRESULT; stdcall;
    function GetCompleted(out Handler: IUnknown): HRESULT; stdcall;
    function GetResults(out Results: IOcrResult): HRESULT; stdcall;
  end;

  ILanguageFactory = interface(IInspectable)
    ['{9B0252AC-0C27-44F8-B792-9793FB66C63E}']
    function CreateLanguage(LanguageTag: Pointer; out Value: IUnknown): HRESULT; stdcall;
  end;

  IOcrEngineStatics = interface(IInspectable)
    ['{5BFFA85A-3384-3540-9940-699120D428A8}']
    function GetMaxImageDimension(out Value: longword): HRESULT; stdcall;
    function GetAvailableRecognizerLanguages(out Value: IUnknown): HRESULT; stdcall;
    function IsLanguageSupported(Language: IUnknown; out Value: longbool): HRESULT; stdcall;
    function TryCreateFromLanguage(Language: IUnknown; out Value: IOcrEngine): HRESULT; stdcall;
    function TryCreateFromUserProfileLanguages(out Value: IOcrEngine): HRESULT; stdcall;
  end;

  IOcrEngine = interface(IInspectable)
    ['{5A14BC41-5B76-3140-B680-8825562683AC}']
    function RecognizeAsync(Bitmap: IUnknown; out Value: IAsyncOperationOcrResult): HRESULT; stdcall;
    function GetRecognizerLanguage(out Value: IUnknown): HRESULT; stdcall;
  end;

  IBitmapFrameWithSoftwareBitmap = interface(IInspectable)
    ['{FE287C9A-420C-4963-87AD-691436E08383}']
    function GetSoftwareBitmapAsync(out Value: IAsyncOperationSoftwareBitmap): HRESULT; stdcall;
    function GetSoftwareBitmapConvertedAsync(AlphaMode, ColorMode: integer;
      out Value: IAsyncOperationSoftwareBitmap): HRESULT; stdcall;
    function GetSoftwareBitmapTransformedAsync(PixelFormat, AlphaMode: integer; Transform: IUnknown;
      ExifOrientationMode, ColorManagementMode: integer; out Value: IAsyncOperationSoftwareBitmap): HRESULT; stdcall;
  end;

  IBitmapDecoder = interface(IInspectable)
    ['{ACEF22BA-1D74-4C91-9DFC-9620745233E6}']
  end;

  IBitmapDecoderStatics = interface(IInspectable)
    ['{438CCB26-BCEF-4E95-BAD6-23A822E58D01}']
    function GetBmpDecoderId(out Value: TGUID): HRESULT; stdcall;
    function GetJpegDecoderId(out Value: TGUID): HRESULT; stdcall;
    function GetPngDecoderId(out Value: TGUID): HRESULT; stdcall;
    function GetGifDecoderId(out Value: TGUID): HRESULT; stdcall;
    function GetTiffDecoderId(out Value: TGUID): HRESULT; stdcall;
    function GetJpegXRDecoderId(out Value: TGUID): HRESULT; stdcall;
    function GetIcoDecoderId(out Value: TGUID): HRESULT; stdcall;
    function GetDecoderInformationEnumerator(out Value: IUnknown): HRESULT; stdcall;
    function CreateAsync(Stream: IUnknown; out Value: IAsyncOperationBitmapDecoder): HRESULT; stdcall;
    function CreateWithIdAsync(DecoderId: TGUID; Stream: IUnknown; out Value: IAsyncOperationBitmapDecoder): HRESULT; stdcall;
  end;

  IOcrResult = interface(IInspectable)
    ['{9BD235B2-175B-3D6A-92E2-388C206E2F63}']
    function GetLines(out Value: IUnknown): HRESULT; stdcall;
    function GetTextAngle(out Value: IUnknown): HRESULT; stdcall;
    function GetText(out Value: Pointer): HRESULT; stdcall;
  end;

  IOcrLine = interface(IInspectable)
    ['{0043A16F-E31F-3A24-899C-D444BD088124}']
    function GetWords(out Value: IUnknown): HRESULT; stdcall;
    function GetText(out Value: Pointer): HRESULT; stdcall;
  end;

  IVectorViewOcrLine = interface(IInspectable)
    ['{60C76EAC-8875-5DDB-A19B-65A3936279EA}']
    function GetAt(Index: longword; out Item: IUnknown): HRESULT; stdcall;
    function GetSize(out Size: longword): HRESULT; stdcall;
    function IndexOf(Value: IUnknown; out Index: longword; out Found: longbool): HRESULT; stdcall;
    function GetMany(StartIndex, Capacity: longword; out Items: IUnknown; out Actual: longword): HRESULT; stdcall;
  end;

  // Native OCR through Windows.Media.Ocr
  TWinOcrDirect = class
  private
    FLastError: string;
  public
    constructor Create;
    // Recognizes text from an image file, raises EWinOcrError on failure
    function RecognizeFile(const FilePath, LanguageTag: string): string;
    // Recognizes text from an image file, returns False and fills Text and ErrorMessage
    function TryRecognizeFile(const FilePath, LanguageTag: string; out Text: string; out ErrorMessage: string): boolean;
    // Recognizes text from an image stream, raises EWinOcrError on failure
    function RecognizeStream(Stream: TStream; const LanguageTag: string): string;
    // Recognizes text from an image stream, returns False and fills Text and ErrorMessage
    function TryRecognizeStream(Stream: TStream; const LanguageTag: string; out Text: string; out ErrorMessage: string): boolean;
    // Returns OCR language tags supported on this system
    function GetSupportedLanguages: TStringArray;
    // Returns True if the given language tag has an OCR engine on this system
    function IsLanguageSupported(const LanguageTag: string): boolean;
    // Captures the screen, lets the user select a region, raises EWinOcrError on failure
    function RecognizeScreenRegion(const LanguageTag: string): string;
    // Captures the screen, lets the user select a region, returns False on cancel/error
    function TryRecognizeScreenRegion(const LanguageTag: string; out Text: string; out ErrorMessage: string): boolean;
    // Like TryRecognizeScreenRegion but also returns the chosen popup action
    function TryRecognizeScreenRegionWithAction(const LanguageTag: string; const ActionCaptions: TStringArray;
      out Text: string; out ActionIndex: integer; out ErrorMessage: string): boolean;
    // Last failure reason, empty on success
    property LastError: string read FLastError;
  end;

const
  IID_IRandomAccessStream: TGUID =
    '{905A0FE1-BC53-11DF-8C49-001E4FC686DA}';
  RO_INIT_MULTITHREADED = 1;
  RPC_E_CHANGED_MODE: HRESULT = HRESULT($80010106);

{$ENDIF}

implementation

{$IFDEF WINDOWS}

uses
  Forms, Controls, Graphics, osutils;

type
  // WinRT entry point signatures, resolved dynamically from system DLLs
  TWindowsCreateString = function(SourceString: pwidechar; Length: longword; out Value: Pointer): HRESULT; stdcall;
  TWindowsDeleteString = function(Value: Pointer): HRESULT; stdcall;
  TWindowsGetStringRawBuffer = function(Value: Pointer; out Length: longword): pwidechar; stdcall;
  TRoGetActivationFactory = function(ActivatableClassId: Pointer; const IID: TGUID; out Factory: IUnknown): HRESULT; stdcall;
  TRoInitialize = function(InitType: integer): HRESULT; stdcall;
  TRoUninitialize = procedure; stdcall;
  TCreateRandomAccessStreamOnFile = function(FilePath: pwidechar; AccessMode: DWORD; const IID: TGUID; out Stream: IUnknown): HRESULT; stdcall;

var
  // Monotonic counter keeps temp names unique within a process
  GTempCounter: integer = 0;
  // Cached result of the WinRT availability probe
  GWinRtChecked: boolean = False;
  GWinRtAvailable: boolean = False;
  // Loaded modules and resolved entry points, filled once by IsWinRtAvailable
  GCombaseLib: HMODULE = 0;
  GShCoreLib: HMODULE = 0;
  GWindowsCreateString: TWindowsCreateString = nil;
  GWindowsDeleteString: TWindowsDeleteString = nil;
  GWindowsGetStringRawBuffer: TWindowsGetStringRawBuffer = nil;
  GRoGetActivationFactory: TRoGetActivationFactory = nil;
  GRoInitialize: TRoInitialize = nil;
  GRoUninitialize: TRoUninitialize = nil;
  GCreateRandomAccessStreamOnFile: TCreateRandomAccessStreamOnFile = nil;

// Probes for the WinRT runtime once and caches all entry points
function IsWinRtAvailable: boolean;
begin
  if GWinRtChecked then
  begin
    Result := GWinRtAvailable;
    Exit;
  end;
  GWinRtChecked := True;
  GWinRtAvailable := False;

  GCombaseLib := LoadLibrary('combase.dll');
  if GCombaseLib = 0 then
    Exit;
  GShCoreLib := LoadLibrary('ShCore.dll');
  if GShCoreLib = 0 then
  begin
    FreeLibrary(GCombaseLib);
    GCombaseLib := 0;
    Exit;
  end;

  GWindowsCreateString := TWindowsCreateString(GetProcAddress(GCombaseLib, 'WindowsCreateString'));
  GWindowsDeleteString := TWindowsDeleteString(GetProcAddress(GCombaseLib, 'WindowsDeleteString'));
  GWindowsGetStringRawBuffer := TWindowsGetStringRawBuffer(GetProcAddress(GCombaseLib, 'WindowsGetStringRawBuffer'));
  GRoGetActivationFactory := TRoGetActivationFactory(GetProcAddress(GCombaseLib, 'RoGetActivationFactory'));
  GRoInitialize := TRoInitialize(GetProcAddress(GCombaseLib, 'RoInitialize'));
  GRoUninitialize := TRoUninitialize(GetProcAddress(GCombaseLib, 'RoUninitialize'));
  GCreateRandomAccessStreamOnFile := TCreateRandomAccessStreamOnFile(GetProcAddress(GShCoreLib, 'CreateRandomAccessStreamOnFile'));

  GWinRtAvailable := Assigned(GWindowsCreateString) and
                     Assigned(GWindowsDeleteString) and
                     Assigned(GWindowsGetStringRawBuffer) and
                     Assigned(GRoGetActivationFactory) and
                     Assigned(GRoInitialize) and
                     Assigned(GRoUninitialize) and
                     Assigned(GCreateRandomAccessStreamOnFile);

  if not GWinRtAvailable then
  begin
    FreeLibrary(GShCoreLib);
    FreeLibrary(GCombaseLib);
    GShCoreLib := 0;
    GCombaseLib := 0;
  end;

  Result := GWinRtAvailable;
end;

// Thin wrappers keep the original names used throughout the rest of the code
function WindowsCreateString(SourceString: pwidechar; Length: longword; out Value: Pointer): HRESULT; stdcall;
begin
  Result := GWindowsCreateString(SourceString, Length, Value);
end;

function WindowsDeleteString(Value: Pointer): HRESULT; stdcall;
begin
  Result := GWindowsDeleteString(Value);
end;

function WindowsGetStringRawBuffer(Value: Pointer; out Length: longword): pwidechar; stdcall;
begin
  Result := GWindowsGetStringRawBuffer(Value, Length);
end;

function RoGetActivationFactory(ActivatableClassId: Pointer; const IID: TGUID; out Factory: IUnknown): HRESULT; stdcall;
begin
  Result := GRoGetActivationFactory(ActivatableClassId, IID, Factory);
end;

function RoInitialize(InitType: integer): HRESULT; stdcall;
begin
  Result := GRoInitialize(InitType);
end;

procedure RoUninitialize; stdcall;
begin
  GRoUninitialize;
end;

function CreateRandomAccessStreamOnFile(FilePath: pwidechar; AccessMode: DWORD; const IID: TGUID; out Stream: IUnknown): HRESULT; stdcall;
begin
  Result := GCreateRandomAccessStreamOnFile(FilePath, AccessMode, IID, Stream);
end;

function MakeTempPath(const Prefix, Ext: string): string;
begin
  Inc(GTempCounter);
  Result := IncludeTrailingPathDelimiter(GetTempDir) + Prefix + IntToStr(TOS.GetTickCountXp) + '_' + IntToStr(GTempCounter) + Ext;
end;

// Detects an image format by magic bytes and returns a matching extension
function DetectImageExtension(Stream: TStream): string;
var
  Buf: array[0..11] of byte = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
  SavePos: int64 = 0;
  ReadN: longint = 0;
begin
  Result := '.png';
  SavePos := Stream.Position;
  try
    FillChar(Buf, SizeOf(Buf), 0);
    ReadN := Stream.Read(Buf, SizeOf(Buf));
    Stream.Position := SavePos;
    if ReadN >= 4 then
    begin
      if (Buf[0] = $89) and (Buf[1] = $50) and (Buf[2] = $4E) and (Buf[3] = $47) then
        Result := '.png'
      else if (Buf[0] = $FF) and (Buf[1] = $D8) and (Buf[2] = $FF) then
        Result := '.jpg'
      else if (Buf[0] = $42) and (Buf[1] = $4D) then
        Result := '.bmp'
      else if (Buf[0] = $47) and (Buf[1] = $49) and (Buf[2] = $46) and (Buf[3] = $38) then
        Result := '.gif'
      else if (Buf[0] = $49) and (Buf[1] = $49) and (Buf[2] = $2A) and (Buf[3] = $00) then
        Result := '.tif'
      else if (Buf[0] = $4D) and (Buf[1] = $4D) and (Buf[2] = $00) and (Buf[3] = $2A) then
        Result := '.tif';
    end;
  except
    Stream.Position := SavePos;
  end;
end;

// Copies the rest of the stream to a file without altering its position
procedure SaveStreamToFile(Stream: TStream; const FileName: string);
var
  FS: TFileStream = nil;
begin
  FS := TFileStream.Create(FileName, fmCreate);
  try
    FS.CopyFrom(Stream, 0);
  finally
    FS.Free;
  end;
end;

function HStringFromWide(const S: widestring; out H: Pointer): HRESULT;
begin
  H := nil;
  Result := WindowsCreateString(pwidechar(S), Length(S), H);
end;

function HResultText(HR: HRESULT): string;
begin
  Result := 'HRESULT=0x' + IntToHex(longword(HR), 8);
end;

procedure SetFailure(var Failure: string; const Stage: string; HR: HRESULT);
begin
  Failure := Stage + ': ' + HResultText(HR);
end;

procedure SetSimpleFailure(var Failure: string; const MessageText: string);
begin
  Failure := MessageText;
end;

function WideFromHString(H: Pointer): widestring;
var
  Raw: pwidechar;
  Len: longword;
begin
  Result := '';
  if H = nil then Exit;

  Raw := WindowsGetStringRawBuffer(H, Len);
  if (Raw <> nil) and (Len > 0) then
    SetString(Result, Raw, Len);
end;

function GetFactory(const ClassName: widestring; const IID: TGUID; out Factory: IUnknown; var Failure: string): boolean;
var
  H: Pointer;
  HR: HRESULT;
begin
  Result := False;
  Factory := nil;
  H := nil;

  HR := HStringFromWide(ClassName, H);
  if Failed(HR) then
  begin
    SetFailure(Failure, 'WindowsCreateString(' + UTF8Encode(ClassName) + ')', HR);
    Exit;
  end;
  try
    HR := RoGetActivationFactory(H, IID, Factory);
    if Failed(HR) then
    begin
      SetFailure(Failure, 'RoGetActivationFactory(' + UTF8Encode(ClassName) + ')', HR);
      Exit;
    end;
    if Factory = nil then
    begin
      SetSimpleFailure(Failure, 'RoGetActivationFactory(' + UTF8Encode(ClassName) + '): returned nil factory');
      Exit;
    end;
    Result := True;
  finally
    WindowsDeleteString(H);
  end;
end;

function WaitAsync(const Op: IInspectable; const Stage: string; var Failure: string; TimeoutMs: cardinal = 5000): boolean;
var
  AsyncInfo: IAsyncInfo;
  Status: longword;
  Start: DWORD;
  HR: HRESULT;
  AsyncError: HRESULT;
begin
  Result := False;
  if Op = nil then
  begin
    SetSimpleFailure(Failure, Stage + ': asynchronous operation is nil');
    Exit;
  end;

  HR := Op.QueryInterface(IAsyncInfo, AsyncInfo);
  if Failed(HR) or (AsyncInfo = nil) then
  begin
    SetFailure(Failure, Stage + '.QueryInterface(IAsyncInfo)', HR);
    Exit;
  end;

  Start := TOS.GetTickCountXp;
  repeat
    HR := AsyncInfo.GetStatus(Status);
    if Failed(HR) then
    begin
      SetFailure(Failure, Stage + '.GetStatus', HR);
      Exit;
    end;

    case Status of
      1:
      begin
        Result := True;
        Exit;
      end;
      2:
      begin
        AsyncError := E_FAIL;
        HR := AsyncInfo.GetErrorCode(AsyncError);
        if Succeeded(HR) then
          SetFailure(Failure, Stage + ': asynchronous operation failed', AsyncError)
        else
          SetFailure(Failure, Stage + '.GetErrorCode', HR);
        Exit;
      end;
      3:
      begin
        AsyncError := E_ABORT;
        HR := AsyncInfo.GetErrorCode(AsyncError);
        if Succeeded(HR) then
          SetFailure(Failure, Stage + ': asynchronous operation canceled', AsyncError)
        else
          SetFailure(Failure, Stage + ': asynchronous operation canceled; GetErrorCode failed', HR);
        Exit;
      end;
    end;

    if (TOS.GetTickCountXp - Start) >= TimeoutMs then
    begin
      SetSimpleFailure(Failure, Stage + ': timeout after ' + IntToStr(TimeoutMs) + ' ms');
      Exit;
    end;
    Sleep(10);
  until False;
end;

function CreateEngine(const LanguageTag: widestring; out Engine: IOcrEngine; var Failure: string): boolean;
var
  Factory: IUnknown;
  Statics: IOcrEngineStatics;
  LanguageFactory: IUnknown;
  LangFactory: ILanguageFactory;
  Language: IUnknown;
  TagH: Pointer;
  HR: HRESULT;
begin
  Result := False;
  Engine := nil;
  Language := nil;
  TagH := nil;

  if not GetFactory('Windows.Media.Ocr.OcrEngine', IOcrEngineStatics, Factory, Failure) then Exit;

  HR := Factory.QueryInterface(IOcrEngineStatics, Statics);
  if Failed(HR) then
  begin
    SetFailure(Failure, 'OcrEngine.QueryInterface(IOcrEngineStatics)', HR);
    Exit;
  end;

  if not GetFactory('Windows.Globalization.Language', ILanguageFactory, LanguageFactory, Failure) then Exit;

  HR := LanguageFactory.QueryInterface(ILanguageFactory, LangFactory);
  if Failed(HR) then
  begin
    SetFailure(Failure, 'Language.QueryInterface(ILanguageFactory)', HR);
    Exit;
  end;

  HR := HStringFromWide(LanguageTag, TagH);
  if Failed(HR) then
  begin
    SetFailure(Failure, 'WindowsCreateString(language tag)', HR);
    Exit;
  end;
  try
    HR := LangFactory.CreateLanguage(TagH, Language);
    if Failed(HR) then
    begin
      SetFailure(Failure, 'Language.CreateLanguage(' + UTF8Encode(LanguageTag) + ')', HR);
      Exit;
    end;
  finally
    WindowsDeleteString(TagH);
  end;

  HR := Statics.TryCreateFromLanguage(Language, Engine);
  if Failed(HR) then
  begin
    SetFailure(Failure, 'OcrEngine.TryCreateFromLanguage', HR);
    Exit;
  end;
  if Engine = nil then
  begin
    SetSimpleFailure(Failure, 'OcrEngine.TryCreateFromLanguage: no OCR engine for language ' + UTF8Encode(LanguageTag) +
      '; check installed Windows OCR language packs');
    Exit;
  end;
  Result := True;
end;

// Opens the file directly as a WinRT IRandomAccessStream.
function OpenStorageFileStream(const FilePath: widestring; out Stream: IUnknown; var Failure: string): boolean;
var
  HR: HRESULT;
begin
  Result := False;
  Stream := nil;
  HR := CreateRandomAccessStreamOnFile(pwidechar(FilePath), 0, IID_IRandomAccessStream, Stream);
  if Failed(HR) then
  begin
    SetFailure(Failure, 'Open image file ' + UTF8Encode(FilePath), HR);
    Exit;
  end;
  if Stream = nil then
  begin
    SetSimpleFailure(Failure, 'Open image file ' + UTF8Encode(FilePath) + ': returned nil stream');
    Exit;
  end;
  Result := True;
end;

function CreateSoftwareBitmap(const FilePath: widestring; out Bitmap: IUnknown; var Failure: string): boolean;
var
  Factory: IUnknown;
  Statics: IBitmapDecoderStatics;
  Stream: IUnknown;
  DecoderOp: IAsyncOperationBitmapDecoder;
  Decoder: IBitmapDecoder;
  SoftwareFrame: IBitmapFrameWithSoftwareBitmap;
  BitmapOp: IAsyncOperationSoftwareBitmap;
  HR: HRESULT;
begin
  Result := False;
  Bitmap := nil;
  Decoder := nil;
  SoftwareFrame := nil;
  Stream := nil;
  DecoderOp := nil;
  BitmapOp := nil;

  if not GetFactory('Windows.Graphics.Imaging.BitmapDecoder', IBitmapDecoderStatics, Factory, Failure) then Exit;

  HR := Factory.QueryInterface(IBitmapDecoderStatics, Statics);
  if Failed(HR) then
  begin
    SetFailure(Failure, 'BitmapDecoder.QueryInterface(IBitmapDecoderStatics)', HR);
    Exit;
  end;

  if not OpenStorageFileStream(FilePath, Stream, Failure) then Exit;

  HR := Statics.CreateAsync(Stream, DecoderOp);
  if Failed(HR) then
  begin
    SetFailure(Failure, 'BitmapDecoder.CreateAsync', HR);
    Exit;
  end;
  if not WaitAsync(DecoderOp, 'BitmapDecoder.CreateAsync', Failure) then Exit;

  HR := DecoderOp.GetResults(Decoder);
  if Failed(HR) then
  begin
    SetFailure(Failure, 'BitmapDecoder.CreateAsync.GetResults', HR);
    Exit;
  end;
  if Decoder = nil then
  begin
    SetSimpleFailure(Failure, 'BitmapDecoder.CreateAsync.GetResults: returned nil decoder');
    Exit;
  end;

  HR := Decoder.QueryInterface(IBitmapFrameWithSoftwareBitmap, SoftwareFrame);
  if Failed(HR) then
  begin
    SetFailure(Failure, 'BitmapDecoder.QueryInterface(IBitmapFrameWithSoftwareBitmap)', HR);
    Exit;
  end;

  HR := SoftwareFrame.GetSoftwareBitmapAsync(BitmapOp);
  if Failed(HR) then
  begin
    SetFailure(Failure, 'BitmapDecoder.GetSoftwareBitmapAsync', HR);
    Exit;
  end;
  if not WaitAsync(BitmapOp, 'BitmapDecoder.GetSoftwareBitmapAsync', Failure) then Exit;

  HR := BitmapOp.GetResults(Bitmap);
  if Failed(HR) then
  begin
    SetFailure(Failure, 'GetSoftwareBitmapAsync.GetResults', HR);
    Exit;
  end;
  if Bitmap = nil then
  begin
    SetSimpleFailure(Failure, 'GetSoftwareBitmapAsync.GetResults: returned nil bitmap');
    Exit;
  end;
  Result := True;
end;

function OcrRecognizeFileCore(const FilePath, LanguageTag: widestring; out Text: widestring; var Failure: string): boolean;
var
  Engine: IOcrEngine;
  Bitmap: IUnknown;
  Op: IAsyncOperationOcrResult;
  OcrResult: IOcrResult;
  LinesUnknown: IUnknown;
  Lines: IVectorViewOcrLine;
  LineUnknown: IUnknown;
  Line: IOcrLine;
  TextH: Pointer;
  HR: HRESULT;
  LineCount: longword;
  I: longword;
  LineText: widestring;
begin
  Result := False;
  Text := '';
  TextH := nil;
  Engine := nil;
  Bitmap := nil;
  Op := nil;
  OcrResult := nil;
  LinesUnknown := nil;
  Lines := nil;
  LineUnknown := nil;
  Line := nil;
  LineCount := 0;

  if not CreateEngine(LanguageTag, Engine, Failure) then Exit;
  if not CreateSoftwareBitmap(FilePath, Bitmap, Failure) then Exit;

  HR := Engine.RecognizeAsync(Bitmap, Op);
  if Failed(HR) then
  begin
    SetFailure(Failure, 'OcrEngine.RecognizeAsync', HR);
    Exit;
  end;
  if not WaitAsync(Op, 'OcrEngine.RecognizeAsync', Failure) then Exit;

  HR := Op.GetResults(OcrResult);
  if Failed(HR) then
  begin
    SetFailure(Failure, 'OcrEngine.RecognizeAsync.GetResults', HR);
    Exit;
  end;
  if OcrResult = nil then
  begin
    SetSimpleFailure(Failure, 'OcrEngine.RecognizeAsync.GetResults: returned nil OCR result');
    Exit;
  end;

  HR := OcrResult.GetLines(LinesUnknown);
  if Failed(HR) then
  begin
    SetFailure(Failure, 'OcrResult.GetLines', HR);
    Exit;
  end;
  if LinesUnknown = nil then
  begin
    SetSimpleFailure(Failure, 'OcrResult.GetLines: returned nil collection');
    Exit;
  end;

  HR := LinesUnknown.QueryInterface(IVectorViewOcrLine, Lines);
  if Failed(HR) then
  begin
    SetFailure(Failure, 'OcrResult.Lines.QueryInterface(IVectorViewOcrLine)', HR);
    Exit;
  end;

  HR := Lines.GetSize(LineCount);
  if Failed(HR) then
  begin
    SetFailure(Failure, 'OcrResult.Lines.GetSize', HR);
    Exit;
  end;

  // Empty result is valid, return success with empty text
  if LineCount = 0 then
  begin
    Result := True;
    Exit;
  end;

  for I := 0 to LineCount - 1 do
  begin
    LineUnknown := nil;
    Line := nil;
    TextH := nil;

    HR := Lines.GetAt(I, LineUnknown);
    if Failed(HR) then
    begin
      SetFailure(Failure, 'OcrResult.Lines.GetAt', HR);
      Text := '';
      Exit;
    end;

    if LineUnknown = nil then
    begin
      SetSimpleFailure(Failure, 'OcrResult.Lines.GetAt: returned nil line');
      Text := '';
      Exit;
    end;

    HR := LineUnknown.QueryInterface(IOcrLine, Line);
    if Failed(HR) then
    begin
      SetFailure(Failure, 'OcrLine.QueryInterface(IOcrLine)', HR);
      Text := '';
      Exit;
    end;

    HR := Line.GetText(TextH);
    if Failed(HR) then
    begin
      SetFailure(Failure, 'OcrLine.GetText', HR);
      Text := '';
      Exit;
    end;

    if TextH = nil then
    begin
      SetSimpleFailure(Failure, 'OcrLine.GetText: returned nil HSTRING');
      Text := '';
      Exit;
    end;

    try
      LineText := WideFromHString(TextH);
    finally
      WindowsDeleteString(TextH);
      TextH := nil;
    end;

    if I > 0 then
      Text := Text + LineEnding;

    Text := Text + LineText;
  end;

  Result := True;
end;

type
  // Runs OCR on a dedicated MTA thread.
  TOcrWorker = class(TThread)
  private
    FFilePath: widestring;
    FLanguageTag: widestring;
    FText: widestring;
    FSuccess: boolean;
    FFailure: string;
  protected
    procedure Execute; override;
  public
    constructor Create(const AFilePath, ALanguageTag: widestring);
    property Text: widestring read FText;
    property Success: boolean read FSuccess;
    property Failure: string read FFailure;
  end;

constructor TOcrWorker.Create(const AFilePath, ALanguageTag: widestring);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FFilePath := AFilePath;
  FLanguageTag := ALanguageTag;
  FSuccess := False;
  FText := '';
  FFailure := '';
end;

procedure TOcrWorker.Execute;
var
  HR: HRESULT;
begin
  HR := RoInitialize(RO_INIT_MULTITHREADED);
  if Failed(HR) and (HR <> RPC_E_CHANGED_MODE) then
  begin
    SetFailure(FFailure, 'RoInitialize', HR);
    Exit;
  end;

  try
    try
      FSuccess := OcrRecognizeFileCore(FFilePath, FLanguageTag, FText, FFailure);
    except
      on E: Exception do
      begin
        FSuccess := False;
        FText := '';
        FFailure := 'Unexpected exception: ' + E.ClassName + ': ' + E.Message;
      end;
    end;
  finally
    if Succeeded(HR) then
      RoUninitialize;
  end;
end;

const
  WM_CLEAR_SELECTION_IF_IDLE = WM_APP + 1;

type
  // Full-screen form that shows the captured screen and lets the user drag a rectangle
  TScreenSelectForm = class(TForm)
  private
    FBitmap: TBitmap;
    FDimmedBitmap: TBitmap;
    FStartPoint: TPoint;
    FEndPoint: TPoint;
    FSelecting: boolean;
    FDone: boolean;
    FSelectionRect: TRect;
    // Optional action popup shown after the user finishes dragging
    FActionMenu: TPopupMenu;
    FSelectedAction: integer;
    procedure UpdateSelection;
    procedure BuildDimmedBitmap;
    procedure DrawDashedRect(const R: TRect);
    procedure ShowActionMenu;
    procedure PopupItemClick(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: integer);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: integer);
    procedure FormMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: integer);
    procedure FormKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure WMClearSelectionIfIdle(var Msg: TMessage); message WM_CLEAR_SELECTION_IF_IDLE;
  public
    // ActionCaptions defines the popup items; pass nil for no menu
    constructor CreateFullScreen(const ActionCaptions: TStringArray);
    destructor Destroy; override;
    property Bitmap: TBitmap read FBitmap;
    property SelectionRect: TRect read FSelectionRect;
    property Done: boolean read FDone;
    // Index of the chosen popup item; -1 when nothing was chosen
    property SelectedAction: integer read FSelectedAction;
  end;

constructor TScreenSelectForm.CreateFullScreen(const ActionCaptions: TStringArray);
var
  VX: integer = 0;
  VY: integer = 0;
  VW: integer = 0;
  VH: integer = 0;
  ScreenDC: HDC = 0;
  I: integer = 0;
  Item: TMenuItem = nil;
begin
  inherited CreateNew(Application);
  FBitmap := TBitmap.Create;
  FBitmap.PixelFormat := pf32bit;

  VX := GetSystemMetrics(SM_XVIRTUALSCREEN);
  VY := GetSystemMetrics(SM_YVIRTUALSCREEN);
  VW := GetSystemMetrics(SM_CXVIRTUALSCREEN);
  VH := GetSystemMetrics(SM_CYVIRTUALSCREEN);
  if (VW <= 0) or (VH <= 0) then
  begin
    VX := 0;
    VY := 0;
    VW := Screen.Width;
    VH := Screen.Height;
  end;

  FBitmap.Width := VW;
  FBitmap.Height := VH;

  ScreenDC := GetDC(0);
  try
    BitBlt(FBitmap.Canvas.Handle, 0, 0, VW, VH, ScreenDC, VX, VY, SRCCOPY);
  finally
    ReleaseDC(0, ScreenDC);
  end;

  // Dimmed grayscale copy used as the backdrop
  FDimmedBitmap := TBitmap.Create;
  FDimmedBitmap.PixelFormat := pf32bit;
  BuildDimmedBitmap;

  BorderStyle := bsNone;
  FormStyle := fsStayOnTop;
  Position := poDesigned;
  Scaled := False;
  Left := VX;
  Top := VY;
  Width := VW;
  Height := VH;
  Caption := '';
  KeyPreview := True;
  ShowInTaskBar := stNever;
  Cursor := crCross;

  FSelecting := False;
  FDone := False;
  FSelectionRect := Types.Rect(0, 0, 0, 0);

  // Build action popup only when the caller supplied captions
  FSelectedAction := -1;
  FActionMenu := nil;
  if Length(ActionCaptions) > 0 then
  begin
    FActionMenu := TPopupMenu.Create(Self);
    for I := 0 to High(ActionCaptions) do
    begin
      Item := TMenuItem.Create(FActionMenu);
      Item.Caption := ActionCaptions[I];
      Item.Tag := I;
      Item.OnClick := @PopupItemClick;
      FActionMenu.Items.Add(Item);
    end;
  end;

  OnPaint := @FormPaint;
  OnMouseDown := @FormMouseDown;
  OnMouseMove := @FormMouseMove;
  OnMouseUp := @FormMouseUp;
  OnKeyDown := @FormKeyDown;
end;

destructor TScreenSelectForm.Destroy;
begin
  FDimmedBitmap.Free;
  FBitmap.Free;
  inherited Destroy;
end;

// Builds a desaturated, darkened copy of the screenshot for the dimmed backdrop
procedure TScreenSelectForm.BuildDimmedBitmap;
var
  IntfImg: TLazIntfImage = nil;
  X: integer = 0;
  Y: integer = 0;
  Row: pbyte = nil;
  Pix: PRGBQuad = nil;
  R: integer = 0;
  G: integer = 0;
  B: integer = 0;
  Luma: integer = 0;
  Rsat: integer = 0;
  Gsat: integer = 0;
  Bsat: integer = 0;
const
  // Backdrop dimming, 0 is full black, 255 keeps original brightness
  BackdropDimLevel: integer = 220;

  // Backdrop saturation, 0 is grayscale, 256 keeps the original colors
  BackdropSatLevel: integer = 120;

  // BT.601 luma weights, sum to 256 so a shift by 8 gives 0..255
  LumaWeightR: integer = 77;
  LumaWeightG: integer = 151;
  LumaWeightB: integer = 28;
begin
  // CreateIntfImage returns a pixel buffer matching the bitmap format
  IntfImg := FBitmap.CreateIntfImage;
  try
    for Y := 0 to IntfImg.Height - 1 do
    begin
      Row := IntfImg.GetDataLineStart(Y);
      Pix := PRGBQuad(Row);
      for X := 0 to IntfImg.Width - 1 do
      begin
        B := Pix^.rgbBlue;
        G := Pix^.rgbGreen;
        R := Pix^.rgbRed;
        // Luma weights sum to 256 so shifting by 8 gives 0..255 brightness
        Luma := (R * LumaWeightR + G * LumaWeightG + B * LumaWeightB) shr 8;
        // Blend each channel toward its gray value, SatLevel 0 is grayscale
        Rsat := Luma + ((R - Luma) * BackdropSatLevel) div 256;
        Gsat := Luma + ((G - Luma) * BackdropSatLevel) div 256;
        Bsat := Luma + ((B - Luma) * BackdropSatLevel) div 256;
        // Apply dimming to the already desaturated result
        Pix^.rgbBlue := byte((Bsat * BackdropDimLevel) shr 8);
        Pix^.rgbGreen := byte((Gsat * BackdropDimLevel) shr 8);
        Pix^.rgbRed := byte((Rsat * BackdropDimLevel) shr 8);
        // Force fully opaque so the result is never treated as transparent
        Pix^.rgbReserved := 255;
        Inc(Pix);
      end;
    end;
    // LoadFromIntfImage rebuilds the bitmap handle from the modified pixels
    FDimmedBitmap.LoadFromIntfImage(IntfImg);
  finally
    IntfImg.Free;
  end;
end;

// Draws a 2 pixel wide dashed gray border along the given rectangle
procedure TScreenSelectForm.DrawDashedRect(const R: TRect);
const
  DashLen = 6;
  GapLen = 4;
var
  X: integer = 0;
  Y: integer = 0;
  SegEnd: integer = 0;
  Step: integer = 0;
begin
  Step := DashLen + GapLen;
  Canvas.Brush.Style := bsClear;
  // Inverted border stays visible on any background color
  Canvas.Pen.Color := clWhite;
  Canvas.Pen.Mode := pmXor;
  Canvas.Pen.Width := 2;
  Canvas.Pen.Style := psSolid;

  // Top and bottom edges drawn from short solid segments
  X := R.Left;
  while X < R.Right do
  begin
    SegEnd := X + DashLen;
    if SegEnd > R.Right then SegEnd := R.Right;
    Canvas.MoveTo(X, R.Top);
    Canvas.LineTo(SegEnd, R.Top);
    Canvas.MoveTo(X, R.Bottom - 2);
    Canvas.LineTo(SegEnd, R.Bottom - 2);
    Inc(X, Step);
  end;

  // Left and right edges drawn the same way
  Y := R.Top;
  while Y < R.Bottom do
  begin
    SegEnd := Y + DashLen;
    if SegEnd > R.Bottom then SegEnd := R.Bottom;
    Canvas.MoveTo(R.Left, Y);
    Canvas.LineTo(R.Left, SegEnd);
    Canvas.MoveTo(R.Right - 2, Y);
    Canvas.LineTo(R.Right - 2, SegEnd);
    Inc(Y, Step);
  end;
end;

procedure TScreenSelectForm.UpdateSelection;
var
  L: integer = 0;
  T: integer = 0;
  R: integer = 0;
  B: integer = 0;
begin
  L := FStartPoint.X;
  T := FStartPoint.Y;
  R := FEndPoint.X;
  B := FEndPoint.Y;
  if L > R then
  begin
    L := FEndPoint.X;
    R := FStartPoint.X;
  end;
  if T > B then
  begin
    T := FEndPoint.Y;
    B := FStartPoint.Y;
  end;
  if L < 0 then L := 0;
  if T < 0 then T := 0;
  if R > FBitmap.Width then R := FBitmap.Width;
  if B > FBitmap.Height then B := FBitmap.Height;
  FSelectionRect := Types.Rect(L, T, R, B);
end;

procedure TScreenSelectForm.FormPaint(Sender: TObject);
begin
  // Dimmed screenshot as the backdrop
  Canvas.Draw(0, 0, FDimmedBitmap);

  // Keep the selection visible until a new one starts or the form closes
  if (FSelectionRect.Right > FSelectionRect.Left) and (FSelectionRect.Bottom > FSelectionRect.Top) then
  begin
    // Restore the original colors inside the selection area
    Canvas.CopyMode := cmSrcCopy;
    Canvas.CopyRect(FSelectionRect, FBitmap.Canvas, FSelectionRect);
    // Dashed gray border around the selection
    DrawDashedRect(FSelectionRect);
  end;
end;

procedure TScreenSelectForm.FormMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
  if Button <> mbLeft then Exit;
  FStartPoint := Types.Point(X, Y);
  FEndPoint := FStartPoint;
  FSelecting := True;
  UpdateSelection;
  Invalidate;
end;

procedure TScreenSelectForm.FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: integer);
begin
  if not FSelecting then Exit;
  FEndPoint := Types.Point(X, Y);
  UpdateSelection;
  Invalidate;
end;

procedure TScreenSelectForm.FormMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
  if (Button <> mbLeft) or not FSelecting then Exit;
  FEndPoint := Types.Point(X, Y);
  UpdateSelection;
  FSelecting := False;

  if (FSelectionRect.Right > FSelectionRect.Left) and (FSelectionRect.Bottom > FSelectionRect.Top) then
  begin
    if FActionMenu <> nil then
      ShowActionMenu
    else
    begin
      // No menu configured, accept immediately with the default action
      FSelectedAction := 0;
      FDone := True;
      ModalResult := mrOk;
    end;
  end
  else
  begin
    // Selection too small, reset and let the user try again
    FSelectionRect := Types.Rect(0, 0, 0, 0);
    Invalidate;
  end;
end;

procedure TScreenSelectForm.FormKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
  begin
    FDone := False;
    ModalResult := mrCancel;
  end;
end;

// Runs after any pending menu command; clears the region only if nothing was picked
procedure TScreenSelectForm.WMClearSelectionIfIdle(var Msg: TMessage);
begin
  Msg.Result := 0;
  // Valid item was picked or form is closing, keep the region intact
  if FDone or (ModalResult <> mrNone) then Exit;
  // Nothing to clear
  if FSelectionRect.Right <= FSelectionRect.Left then Exit;
  if FSelectionRect.Bottom <= FSelectionRect.Top then Exit;
  // Menu dismissed (Esc or outside click), drop the region
  FSelectionRect := Types.Rect(0, 0, 0, 0);
  Invalidate;
end;

// Pops up the action menu at the mouse release point without closing the form
procedure TScreenSelectForm.ShowActionMenu;
var
  ScreenPt: TPoint = (X: 0; Y: 0);
begin
  FSelectedAction := -1;
  ScreenPt := ClientToScreen(Types.Point(FEndPoint.X, FEndPoint.Y));
  // Popup runs its own loop and fires PopupItemClick on selection
  FActionMenu.Popup(ScreenPt.X, ScreenPt.Y);
  // Defer clearing so any pending item click is processed first
  PostMessage(Handle, WM_CLEAR_SELECTION_IF_IDLE, 0, 0);
end;

// Records the chosen popup item and closes the form right away
procedure TScreenSelectForm.PopupItemClick(Sender: TObject);
begin
  if Sender is TMenuItem then
  begin
    FSelectedAction := TMenuItem(Sender).Tag;
    FDone := True;
    ModalResult := mrOk;
  end;
end;

{ TWinOcrDirect }

constructor TWinOcrDirect.Create;
begin
  inherited Create;
  FLastError := '';
end;

function TWinOcrDirect.RecognizeFile(const FilePath, LanguageTag: string): string;
var
  ErrorMessage: string = '';
begin
  if not TryRecognizeFile(FilePath, LanguageTag, Result, ErrorMessage) then
    raise EWinOcrError.Create(ErrorMessage);
end;

function TWinOcrDirect.TryRecognizeFile(const FilePath, LanguageTag: string; out Text: string; out ErrorMessage: string): boolean;
var
  Worker: TOcrWorker = nil;
  WFilePath: widestring = '';
  WLanguageTag: widestring = '';
begin
  Result := False;
  Text := '';
  ErrorMessage := '';
  FLastError := '';

  if FilePath = '' then
  begin
    ErrorMessage := 'File path is empty';
    FLastError := ErrorMessage;
    Exit;
  end;
  if LanguageTag = '' then
  begin
    ErrorMessage := 'Language tag is empty';
    FLastError := ErrorMessage;
    Exit;
  end;
  if not IsWinRtAvailable then
  begin
    ErrorMessage := 'Windows OCR is not available on this system (Windows 8 or newer required)';
    FLastError := ErrorMessage;
    Exit;
  end;

  WFilePath := UTF8Decode(FilePath);
  WLanguageTag := UTF8Decode(LanguageTag);

  Worker := TOcrWorker.Create(WFilePath, WLanguageTag);
  try
    Worker.Start;
    Worker.WaitFor;
    Text := UTF8Encode(Worker.Text);
    Result := Worker.Success;
    if Result then
      FLastError := ''
    else
    begin
      FLastError := Worker.Failure;
      if FLastError = '' then
        FLastError := 'OCR failed without a reported error';
    end;
    ErrorMessage := FLastError;
  finally
    Worker.Free;
  end;
end;

function TWinOcrDirect.RecognizeStream(Stream: TStream; const LanguageTag: string): string;
var
  ErrorMessage: string = '';
begin
  if not TryRecognizeStream(Stream, LanguageTag, Result, ErrorMessage) then
    raise EWinOcrError.Create(ErrorMessage);
end;

function TWinOcrDirect.TryRecognizeStream(Stream: TStream; const LanguageTag: string; out Text: string;
  out ErrorMessage: string): boolean;
var
  TempImage: string = '';
  Ext: string = '';
begin
  Result := False;
  Text := '';
  ErrorMessage := '';
  FLastError := '';

  if Stream = nil then
  begin
    ErrorMessage := 'Stream is nil';
    FLastError := ErrorMessage;
    Exit;
  end;
  if not IsWinRtAvailable then
  begin
    ErrorMessage := 'Windows OCR is not available on this system (Windows 8 or newer required)';
    FLastError := ErrorMessage;
    Exit;
  end;

  Ext := DetectImageExtension(Stream);
  TempImage := MakeTempPath('qt_ocr_direct_image_', Ext);
  try
    try
      SaveStreamToFile(Stream, TempImage);
    except
      on E: Exception do
      begin
        ErrorMessage := 'Failed to save stream to temp file: ' + E.Message;
        FLastError := ErrorMessage;
        Exit;
      end;
    end;

    Result := TryRecognizeFile(TempImage, LanguageTag, Text, ErrorMessage);
  finally
    if FileExists(TempImage) then
      SysUtils.DeleteFile(TempImage);
  end;
end;

function TWinOcrDirect.GetSupportedLanguages: TStringArray;
const
  // Known Windows OCR language tags, filtered by IsLanguageSupported
  KnownTags: array[0..44] of string = (
    // Base two-letter tags work when a single regional engine is installed
    'ar', 'bg', 'cs', 'da', 'de', 'el', 'en', 'es', 'fi', 'fr',
    'hr', 'hu', 'it', 'ja', 'ko', 'nb', 'nl', 'pl', 'pt', 'ro',
    'ru', 'sk', 'sl', 'sv', 'tr',
    // Regional tags are needed when multiple engines exist for one language
    'en-GB', 'en-US',
    'es-MX',
    'fr-CA',
    'pt-BR', 'pt-PT',
    // Script subtags are mandatory for Serbian and Chinese
    'sr-Cyrl', 'sr-Latn',
    'zh-Hans', 'zh-Hant',
    // Additional base tags for less common OCR packs
    'af', 'ca', 'cy', 'ga', 'gl', 'is', 'mi', 'sq', 'uk', 'vi'
    );
var
  Factory: IUnknown = nil;
  Statics: IOcrEngineStatics = nil;
  LanguageFactory: IUnknown = nil;
  LangFactory: ILanguageFactory = nil;
  Language: IUnknown = nil;
  TagH: Pointer = nil;
  Failure: string = '';
  Supported: longbool = False;
  HR: HRESULT;
  I: integer = 0;
  Count: integer = 0;
  Tag: widestring = '';
begin
  Result := nil;
  FLastError := '';

  if not IsWinRtAvailable then
  begin
    FLastError := 'Windows OCR is not available on this system (Windows 8 or newer required)';
    Exit;
  end;

  if not GetFactory('Windows.Media.Ocr.OcrEngine', IOcrEngineStatics, Factory, Failure) then
  begin
    FLastError := Failure;
    Exit;
  end;

  HR := Factory.QueryInterface(IOcrEngineStatics, Statics);
  if Failed(HR) or (Statics = nil) then
  begin
    SetFailure(Failure, 'OcrEngine.QueryInterface(IOcrEngineStatics)', HR);
    FLastError := Failure;
    Exit;
  end;

  if not GetFactory('Windows.Globalization.Language', ILanguageFactory, LanguageFactory, Failure) then
  begin
    FLastError := Failure;
    Exit;
  end;

  HR := LanguageFactory.QueryInterface(ILanguageFactory, LangFactory);
  if Failed(HR) or (LangFactory = nil) then
  begin
    SetFailure(Failure, 'Language.QueryInterface(ILanguageFactory)', HR);
    FLastError := Failure;
    Exit;
  end;

  // Reserve max size, shrink at the end to the actually supported count
  SetLength(Result, Length(KnownTags));
  for I := 0 to High(KnownTags) do
  begin
    Language := nil;
    TagH := nil;
    Tag := UTF8Decode(KnownTags[I]);

    HR := HStringFromWide(Tag, TagH);
    if Failed(HR) then Continue;
    try
      HR := LangFactory.CreateLanguage(TagH, Language);
      if Failed(HR) or (Language = nil) then Continue;
    finally
      WindowsDeleteString(TagH);
    end;

    Supported := False;
    HR := Statics.IsLanguageSupported(Language, Supported);
    if Succeeded(HR) and Supported then
    begin
      Result[Count] := KnownTags[I];
      Inc(Count);
    end;
  end;
  SetLength(Result, Count);
end;

function TWinOcrDirect.IsLanguageSupported(const LanguageTag: string): boolean;
var
  Factory: IUnknown = nil;
  Statics: IOcrEngineStatics = nil;
  LanguageFactory: IUnknown = nil;
  LangFactory: ILanguageFactory = nil;
  Language: IUnknown = nil;
  TagH: Pointer = nil;
  Failure: string = '';
  Supported: longbool = False;
  HR: HRESULT;
begin
  Result := False;
  FLastError := '';

  if LanguageTag = '' then
  begin
    FLastError := 'Language tag is empty';
    Exit;
  end;

  if not IsWinRtAvailable then
  begin
    FLastError := 'Windows OCR is not available on this system (Windows 8 or newer required)';
    Exit;
  end;

  if not GetFactory('Windows.Media.Ocr.OcrEngine', IOcrEngineStatics, Factory, Failure) then
  begin
    FLastError := Failure;
    Exit;
  end;

  HR := Factory.QueryInterface(IOcrEngineStatics, Statics);
  if Failed(HR) or (Statics = nil) then
  begin
    SetFailure(Failure, 'OcrEngine.QueryInterface(IOcrEngineStatics)', HR);
    FLastError := Failure;
    Exit;
  end;

  if not GetFactory('Windows.Globalization.Language', ILanguageFactory, LanguageFactory, Failure) then
  begin
    FLastError := Failure;
    Exit;
  end;

  HR := LanguageFactory.QueryInterface(ILanguageFactory, LangFactory);
  if Failed(HR) or (LangFactory = nil) then
  begin
    SetFailure(Failure, 'Language.QueryInterface(ILanguageFactory)', HR);
    FLastError := Failure;
    Exit;
  end;

  HR := HStringFromWide(UTF8Decode(LanguageTag), TagH);
  if Failed(HR) then
  begin
    SetFailure(Failure, 'WindowsCreateString(language tag)', HR);
    FLastError := Failure;
    Exit;
  end;
  try
    HR := LangFactory.CreateLanguage(TagH, Language);
    if Failed(HR) or (Language = nil) then
    begin
      SetFailure(Failure, 'Language.CreateLanguage', HR);
      FLastError := Failure;
      Exit;
    end;
  finally
    WindowsDeleteString(TagH);
  end;

  Supported := False;
  HR := Statics.IsLanguageSupported(Language, Supported);
  if Failed(HR) then
  begin
    SetFailure(Failure, 'OcrEngine.IsLanguageSupported', HR);
    FLastError := Failure;
    Exit;
  end;
  Result := Supported;
end;

function TWinOcrDirect.RecognizeScreenRegion(const LanguageTag: string): string;
var
  ErrorMessage: string = '';
begin
  if not TryRecognizeScreenRegion(LanguageTag, Result, ErrorMessage) then
    raise EWinOcrError.Create(ErrorMessage);
end;

function TWinOcrDirect.TryRecognizeScreenRegion(const LanguageTag: string; out Text: string; out ErrorMessage: string): boolean;
var
  ActionIndex: integer = -1;
begin
  Result := TryRecognizeScreenRegionWithAction(LanguageTag, nil, Text, ActionIndex, ErrorMessage);
end;

function TWinOcrDirect.TryRecognizeScreenRegionWithAction(const LanguageTag: string; const ActionCaptions: TStringArray;
  out Text: string; out ActionIndex: integer; out ErrorMessage: string): boolean;
const
  // Pixels added around the selection so OCR sees complete glyph shapes
  ContextPad = 8;

  // Crops shorter than this are upscaled to help the OCR engine
  UpscaleThreshold = 80;

  // Integer zoom factors applied to small and medium crops
  UpscaleSmallFactor = 3;
  UpscaleMediumFactor = 2;
var
  SelForm: TScreenSelectForm = nil;
  Crop: TBitmap = nil;
  ScaledCrop: TBitmap = nil;
  TempImage: string = '';
  PadRect: TRect;
  ScaleFactor: integer = 1;
begin
  Result := False;
  Text := '';
  ActionIndex := -1;
  ErrorMessage := '';
  FLastError := '';

  SelForm := nil;
  Crop := nil;
  ScaledCrop := nil;
  TempImage := '';

  if not IsWinRtAvailable then
  begin
    ErrorMessage := 'Windows OCR is not available on this system (Windows 8 or newer required)';
    FLastError := ErrorMessage;
    Exit;
  end;

  try
    SelForm := TScreenSelectForm.CreateFullScreen(ActionCaptions);
    SelForm.ShowModal;

    if not SelForm.Done then
    begin
      ErrorMessage := 'Screen region selection canceled';
      FLastError := ErrorMessage;
      Exit;
    end;

    ActionIndex := SelForm.SelectedAction;
    if ActionIndex < 0 then
    begin
      ErrorMessage := 'No action selected';
      FLastError := ErrorMessage;
      Exit;
    end;

    // Expand the selection to include full glyphs and give OCR some margin
    PadRect := SelForm.SelectionRect;
    if PadRect.Left < ContextPad then
      PadRect.Left := 0
    else
      PadRect.Left := PadRect.Left - ContextPad;
    if PadRect.Top < ContextPad then
      PadRect.Top := 0
    else
      PadRect.Top := PadRect.Top - ContextPad;
    if PadRect.Right + ContextPad > SelForm.Bitmap.Width then
      PadRect.Right := SelForm.Bitmap.Width
    else
      PadRect.Right := PadRect.Right + ContextPad;
    if PadRect.Bottom + ContextPad > SelForm.Bitmap.Height then
      PadRect.Bottom := SelForm.Bitmap.Height
    else
      PadRect.Bottom := PadRect.Bottom + ContextPad;

    Crop := TBitmap.Create;
    Crop.PixelFormat := pf32bit;
    Crop.Width := PadRect.Right - PadRect.Left;
    Crop.Height := PadRect.Bottom - PadRect.Top;
    Crop.Canvas.CopyRect(
      Types.Rect(0, 0, Crop.Width, Crop.Height),
      SelForm.Bitmap.Canvas,
      PadRect);

    // Upscale short crops so a single line of text has enough pixels for OCR
    if Crop.Height < UpscaleThreshold then
    begin
      if Crop.Height < UpscaleThreshold div 2 then
        ScaleFactor := UpscaleSmallFactor
      else
        ScaleFactor := UpscaleMediumFactor;
    end;

    if ScaleFactor > 1 then
    begin
      ScaledCrop := TBitmap.Create;
      ScaledCrop.PixelFormat := pf32bit;
      ScaledCrop.Width := Crop.Width * ScaleFactor;
      ScaledCrop.Height := Crop.Height * ScaleFactor;
      ScaledCrop.Canvas.StretchDraw(
        Types.Rect(0, 0, ScaledCrop.Width, ScaledCrop.Height), Crop);
      Crop.Free;
      Crop := ScaledCrop;
      ScaledCrop := nil;
    end;

    TempImage := MakeTempPath('qt_ocr_screen_', '.bmp');
    Crop.SaveToFile(TempImage);

    Result := TryRecognizeFile(TempImage, LanguageTag, Text, ErrorMessage);
  finally
    if (TempImage <> '') and FileExists(TempImage) then
      SysUtils.DeleteFile(TempImage);
    ScaledCrop.Free;
    Crop.Free;
    SelForm.Free;
  end;
end;

{$ENDIF}

end.
