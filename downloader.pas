//-----------------------------------------------------------------------------------
//  Downloader Module © 2026 by Alexander Tverskoy
//  Licensed under the MIT License
//  You may obtain a copy of the License at https://opensource.org/licenses/MIT
//-----------------------------------------------------------------------------------
// Simple usage example:
//   DownloadFiles(['https://example.com/file1.txt', 'https://example.com/file2.txt'], @OnDownloadComplete);
//   ...
//   procedure TForm1.OnDownloadComplete(Sender: TObject; AStreams: array of TMemoryStream; AErrors: array of string);
//   var i: integer;
//   begin
//     for i := 0 to High(AStreams) do
//       if AErrors[i] = '' then AStreams[i].SaveToFile('file' + IntToStr(i+1) + '.dat')
//       else ShowMessage(AErrors[i]);
//     for i := 0 to High(AStreams) do AStreams[i].Free;
//   end;
//-----------------------------------------------------------------------------------

unit Downloader;

{$mode ObjFPC}{$H+}

interface

uses
  Classes,
  SysUtils,
  Process,
  fphttpclient,
  openssl,
  opensslsockets,
  {$IFDEF WINDOWS}
  wininet,
  {$ENDIF}
  {$IFDEF Linux}
  Unix,
  {$ENDIF}
  {$IFDEF MacOS}
  MacOSAll,
  {$ENDIF}
  LResources;

type
  TDownloadCompleteEvent = procedure(Sender: TObject; AStreams: array of TMemoryStream; AErrors: array of string) of object;

  TDownloadThread = class(TThread)
  private
    FURLs: array of string;
    FStreams: array of TMemoryStream;
    FErrors: array of string;
    FOnComplete: TDownloadCompleteEvent;
    procedure DoComplete; // called in main thread via Synchronize
  protected
    procedure Execute; override;
  public
    constructor Create(const AURLs: array of string);
    destructor Destroy; override;
    property OnDownloadComplete: TDownloadCompleteEvent read FOnComplete write FOnComplete;
  end;

// Convenience procedure to start download without manual thread creation
procedure DownloadFiles(const AURLs: array of string; AOnComplete: TDownloadCompleteEvent);

function IsSSLAvailable: boolean;

var
  _SSLChecked: boolean = False;
  _SSLAvailable: boolean = False;

resourcestring
  downloaderror = 'Download failed';

implementation

{%Region -fold SSL check}

function IsSSLAvailable: boolean;
begin
  if not _SSLChecked then
  begin
    try
      _SSLAvailable := InitSSLInterface;
    except
      _SSLAvailable := False;
    end;
    _SSLChecked := True;
  end;
  Result := _SSLAvailable;
end;

{%EndRegion}

{%Region -fold Platform-specific downloaders}

function DownloadWithFPHTTP(const AUrl: string; AStream: TMemoryStream): boolean;
var
  Client: TFPHTTPClient;
begin
  Result := False;
  if AUrl.StartsWith('https://', True) and not IsSSLAvailable then
    Exit;
  try
    Client := TFPHTTPClient.Create(nil);
    try
      Client.AddHeader('User-Agent', 'PlaintoolDownloader');
      Client.AllowRedirect := True;
      Client.ConnectTimeout := 10000;
      Client.IOTimeout := 10000;
      Client.Get(AUrl, AStream);
      // Check HTTP status, only 2xx is success
      if (Client.ResponseStatusCode div 100) = 2 then
        Result := True
      else
        Result := False;
    finally
      Client.Free;
    end;
  except
    Result := False;
  end;
end;

{$IFDEF WINDOWS}

function DownloadWinInet(const AUrl: string; AStream: TMemoryStream): boolean;
var
  hInet, hUrl: HINTERNET;
  Buffer: array[0..8191] of Byte;
  BytesRead: DWORD = 0;
  status: DWORD;
  statusSize: DWORD;
begin
  Result := False;
  hInet := InternetOpen('PlaintoolDownloader', INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);
  if hInet = nil then
    Exit;
  try
    hUrl := InternetOpenUrl(hInet, PChar(AUrl), nil, 0,
                           INTERNET_FLAG_RELOAD or INTERNET_FLAG_SECURE or
                           INTERNET_FLAG_EXISTING_CONNECT, 0);
    if hUrl = nil then
      Exit;
    try
      while InternetReadFile(hUrl, @Buffer, SizeOf(Buffer), BytesRead) and (BytesRead > 0) do
      begin
        AStream.WriteBuffer(Buffer, BytesRead);
      end;

      statusSize := SizeOf(status);
      if HttpQueryInfo(hUrl, HTTP_QUERY_STATUS_CODE or HTTP_QUERY_FLAG_NUMBER,
                 @status, @statusSize, nil) then
      begin
        if (status div 100) = 2 then
          Result := True;
      end;
    finally
      InternetCloseHandle(hUrl);
    end;
  finally
    InternetCloseHandle(hInet);
  end;
end;

{$ELSE}

function DownloadWithCurl(const AUrl: string; AStream: TMemoryStream): boolean;
var
  Process: TProcess;
  Buffer: TBytes = nil;
  BytesRead: longint;
begin
  Result := False;
  SetLength(Buffer, 8192);
  Process := TProcess.Create(nil);
  try
    Process.Executable := 'curl';
    Process.Parameters.Add('-s');
    Process.Parameters.Add('-f');
    Process.Parameters.Add('-L');
    Process.Parameters.Add('-H');
    Process.Parameters.Add('User-Agent: PlaintoolDownloader');
    Process.Parameters.Add(AUrl);
    Process.Options := [poUsePipes, poNoConsole];
    Process.Execute;
    while Process.Running or (Process.Output.NumBytesAvailable > 0) do
    begin
      BytesRead := Process.Output.Read(Buffer[0], Length(Buffer));
      if BytesRead > 0 then
        AStream.WriteBuffer(Buffer[0], BytesRead);
    end;
    Process.WaitOnExit;
    Result := (Process.ExitStatus = 0);
  finally
    Process.Free;
  end;
end;

function DownloadWithWget(const AUrl: string; AStream: TMemoryStream): boolean;
var
  Process: TProcess;
  Buffer: TBytes = nil;
  BytesRead: longint;
begin
  Result := False;
  SetLength(Buffer, 8192);
  Process := TProcess.Create(nil);
  try
    Process.Executable := 'wget';
    Process.Parameters.Add('-q');
    Process.Parameters.Add('-O');
    Process.Parameters.Add('-');
    Process.Parameters.Add('--header=User-Agent: PlaintoolDownloader');
    Process.Parameters.Add(AUrl);
    Process.Options := [poUsePipes, poNoConsole];
    Process.Execute;
    while Process.Running or (Process.Output.NumBytesAvailable > 0) do
    begin
      BytesRead := Process.Output.Read(Buffer[0], Length(Buffer));
      if BytesRead > 0 then
        AStream.WriteBuffer(Buffer[0], BytesRead);
    end;
    Process.WaitOnExit;
    Result := (Process.ExitStatus = 0);
  finally
    Process.Free;
  end;
end;

function IsCurlAvailable: boolean;
var
  Process: TProcess;
begin
  Result := False;
  Process := TProcess.Create(nil);
  try
    Process.Executable := 'curl';
    Process.Parameters.Add('--version');
    Process.Options := [poWaitOnExit, poNoConsole];
    try
      Process.Execute;
      Process.WaitOnExit;
      Result := (Process.ExitStatus = 0);
    except
      Result := False;
    end;
  finally
    Process.Free;
  end;
end;

function IsWgetAvailable: boolean;
var
  Process: TProcess;
begin
  Result := False;
  Process := TProcess.Create(nil);
  try
    Process.Executable := 'wget';
    Process.Parameters.Add('--version');
    Process.Options := [poWaitOnExit, poNoConsole];
    try
      Process.Execute;
      Process.WaitOnExit;
      Result := (Process.ExitStatus = 0);
    except
      Result := False;
    end;
  finally
    Process.Free;
  end;
end;

{$ENDIF}

function DownloadFile(const AUrl: string; AStream: TMemoryStream): string;
var
  Ok: boolean;
begin
  Result := '';
  Ok := False;
  {$IFDEF WINDOWS}
  Ok := DownloadWinInet(AUrl, AStream);
  if not Ok then
    Ok := DownloadWithFPHTTP(AUrl, AStream);
  {$ELSE}
  Ok := DownloadWithFPHTTP(AUrl, AStream);
  if not Ok and IsCurlAvailable then
    Ok := DownloadWithCurl(AUrl, AStream);
  if not Ok and IsWgetAvailable then
    Ok := DownloadWithWget(AUrl, AStream);
  {$ENDIF}
  if not Ok then
    Result := downloaderror;
end;

{%EndRegion}

{%Region -fold TDownloadThread}

constructor TDownloadThread.Create(const AURLs: array of string);
var
  i: integer;
begin
  inherited Create(True); // suspended, user must Start
  SetLength(FURLs, Length(AURLs));
  for i := 0 to High(AURLs) do
    FURLs[i] := AURLs[i];
  SetLength(FStreams, Length(FURLs));
  SetLength(FErrors, Length(FURLs));
  for i := 0 to High(FStreams) do
  begin
    FStreams[i] := nil;
    FErrors[i] := '';
  end;
  FreeOnTerminate := True;
end;

destructor TDownloadThread.Destroy;
var
  i: integer;
begin
  for i := 0 to High(FStreams) do
    FStreams[i].Free;
  inherited Destroy;
end;

procedure TDownloadThread.Execute;
var
  i: integer;
begin
  for i := 0 to High(FURLs) do
  begin
    FStreams[i] := TMemoryStream.Create;
    try
      FErrors[i] := DownloadFile(FURLs[i], FStreams[i]);
      if FErrors[i] <> '' then
        FreeAndNil(FStreams[i]) // free failed stream, will remain nil
      else
        FStreams[i].Position := 0;
    except
      on E: Exception do
      begin
        FErrors[i] := E.Message;
        FreeAndNil(FStreams[i]);
      end;
    end;
  end;
  Synchronize(@DoComplete);
end;

procedure TDownloadThread.DoComplete;
var
  i: integer;
begin
  if Assigned(FOnComplete) then
    FOnComplete(Self, FStreams, FErrors)
  else
    // No handler assigned, free all streams to avoid memory leak
    for i := 0 to High(FStreams) do
      FreeAndNil(FStreams[i]);
end;

{%EndRegion}

{%Region -fold Public wrapper}

procedure DownloadFiles(const AURLs: array of string; AOnComplete: TDownloadCompleteEvent);
var
  Thread: TDownloadThread;
begin
  Thread := TDownloadThread.Create(AURLs);
  Thread.OnDownloadComplete := AOnComplete;
  Thread.Start;
end;

{%EndRegion}

end.
