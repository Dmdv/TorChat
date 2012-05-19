{ TorChat - Connection class, representing a connection via Tor

  Copyright (C) 2012 Bernd Kreuss <prof7bit@gmail.com>

  This source is free software; you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free
  Software Foundation; either version 3 of the License, or (at your option)
  any later version.

  This code is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
  details.

  A copy of the GNU General Public License is available on the World Wide Web
  at <http://www.gnu.org/copyleft/gpl.html>. You can also obtain it by writing
  to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
  MA 02111-1307, USA.
}
unit tc_conn;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  tc_interface,
  tc_conn_rcv,
  tc_sock;

type

  { THiddenConnection }
  THiddenConnection = class(TInterfacedObject, IHiddenConnection)
  strict protected
    FOnTCPFailHasFinishedEvent: PRTLEvent;
    FTCPStream: TTCPStream;
    FClient: IClient;
    FBuddy: IBuddy;
    FReceiver: TAReceiver;
    FDebugInfoDefault: String;
    procedure NotifyOthersAboutDeath; virtual;
  public
    constructor Create(AClient: IClient; AStream: TTCPStream; ABuddy: IBuddy);
    destructor Destroy; override;
    procedure Send(AData: String); virtual;
    procedure SendLine(AEncodedLine: String); virtual;
    procedure OnTCPFail; virtual;
    procedure DoClose; virtual;
    procedure SetBuddy(ABuddy: IBuddy); virtual;
    function IsOutgoing: Boolean; virtual;
    function DebugInfo: String; virtual;
    function Buddy: IBuddy;
    function Client: IClient;
    function Stream: TTCPStream;
  end;

implementation

{ THiddenConnection }

procedure THiddenConnection.NotifyOthersAboutDeath;
begin
  Client.UnregisterConnection(Self);
  if Assigned(FBuddy) then begin
    if IsOutgoing then
      FBuddy.SetOutgoing(nil)
    else
      FBuddy.SetIncoming(nil);
  end;
end;

constructor THiddenConnection.Create(AClient: IClient; AStream: TTCPStream; ABuddy: IBuddy);
begin
  FOnTCPFailHasFinishedEvent := RTLEventCreate;
  FTCPStream := AStream;
  FClient := AClient;
  FBuddy := ABuddy;
  FReceiver := TReceiver.Create(Self); // this will have FreeOnTerminate=True
  FDebugInfoDefault := '(unknown incoming)';
  WriteLn('THiddenConnection.Create() ' + DebugInfo);
  // This object will free all its stuff in OnTCPFail().
  // Never call Connection.Free() directly. There is only one way
  // to get rid of a THiddenConnection object: call the method
  // Connection.DoClose(); This will trigger the same events
  // that also happen when the TCP connection fails: It will call the
  // buddie's OnXxxxFail method and then free itself automatically.
end;

destructor THiddenConnection.Destroy;
begin
  RTLeventdestroy(FOnTCPFailHasFinishedEvent);
  inherited Destroy;
  WriteLn('THiddenConnection.Destroy() finished');
end;

procedure THiddenConnection.Send(AData: String);
begin
  FTCPStream.Write(AData[1], Length(AData));
end;

procedure THiddenConnection.SendLine(AEncodedLine: String);
begin
  Send(AEncodedLine + #10);
end;

procedure THiddenConnection.OnTCPFail;
begin
  WriteLn('THiddenConnection.OnTCPFail()' + DebugInfo);
  NotifyOthersAboutDeath;
  FTCPStream.Free;
  WriteLn('THiddenConnection.OnTCPFail()' + DebugInfo + ' setting event');
  RTLeventSetEvent(FOnTCPFailHasFinishedEvent);
end;

procedure THiddenConnection.DoClose;
begin
  WriteLn('THiddenConnection.DoClose()' + DebugInfo + ' closing socket');
  Stream.DoClose;
  WriteLn('THiddenConnection.DoClose()' + DebugInfo + ' waiting event');
  RTLeventWaitFor(FOnTCPFailHasFinishedEvent);
  WriteLn('THiddenConnection.DoClose()' + DebugInfo + ' got event');
end;

procedure THiddenConnection.SetBuddy(ABuddy: IBuddy);
begin
  FBuddy := ABuddy;
end;

function THiddenConnection.IsOutgoing: Boolean;
begin
  if not Assigned(FBuddy) then
    Exit(False);
  if FBuddy.ConnOutgoing = IHiddenConnection(Self) then
    Exit(True);
  if (FBuddy.ConnIncoming = nil) and (FBuddy.ConnOutgoing = nil) then
    Exit(True);
  Result := False;
end;

function THiddenConnection.DebugInfo: String;
begin
  if Assigned(FBuddy) then begin
    Result := ' (' + FBuddy.ID;
    if IsOutgoing then
      Result := Result + ' outgoing)'
    else
      Result := Result + ' incoming)';
  end
  else
    Result := FDebugInfoDefault;
end;

function THiddenConnection.Buddy: IBuddy;
begin
  Result := FBuddy;
end;

function THiddenConnection.Client: IClient;
begin
  Result := FClient;
end;

function THiddenConnection.Stream: TTCPStream;
begin
  Result := FTCPStream;
end;

end.

