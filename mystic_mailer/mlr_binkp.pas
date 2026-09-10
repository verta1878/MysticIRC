// ====================================================================
// mystic_mailer : sample FidoNet mailer front-end for Mystic BBS A38
// ====================================================================
//
// This file is part of an optional add-on/sample for Mystic BBS and is
// released under the same GNU General Public License v3 as Mystic BBS.
// Mystic BBS is Copyright 1997-2013 By James Coyle.
//
// mlr_binkp - BinkP-over-modem detection and integration seam.
//
// BinkP (FTS-1026) was designed for TCP: a reliable, error-corrected,
// in-order byte stream.  A raw modem link is not that.  Running BinkP over
// a modem therefore RELIES ON THE MODEM'S OWN ERROR CORRECTION - V.42 / MNP
// with V.42bis compression - to present a clean stream to the protocol.  On
// two error-correcting modems over a decent line this works and BinkP's
// framing rides on top unchanged; on a noisy or non-EC link it is not safe.
// This assumption MUST hold on both ends.
//
// This unit does two things for the sample front-end:
//   1. Detection - recognise a BinkP caller from its opening frame so the
//      three-way detector can route {EMSI | BinkP | human}.
//   2. Seam - document/expose where the EXISTING Mystic BinkP engine would
//      take over, driven by a TIOSerial stream instead of a TIOSocket.  The
//      sample does NOT re-implement BinkP; Mystic already has a full BinkP
//      tosser/poller.  The real work to run it over the modem is the shared
//      TIOSerial class (also needed by the human/BBS path).
//
// BinkP frame format (for detection): each frame is a 2-byte big-endian
// header whose top bit flags command(1)/data(0), low 15 bits = length,
// followed by that many bytes.  A session opens with command frames
// M_NUL / M_ADR / M_PWD.  We sniff for a plausible command-frame header.
// ====================================================================

Unit mlr_Binkp;

{$IFDEF FPC}{$MODE OBJFPC}{$H+}{$ENDIF}

Interface

Uses
  mdm_Serial;

Const
  // BinkP command-frame message IDs.  These match Mystic's own BinkP engine
  // (mis_client_binkp.pas): M_NUL=0 M_ADR=1 M_PWD=2 M_FILE=3 M_OK=4 M_EOB=5
  // M_GOT=6 M_ERR=7 M_BSY=8.  Only the session-opening ids are needed here.
  BINKP_M_NUL  = 0;
  BINKP_M_ADR  = 1;
  BINKP_M_PWD  = 2;
  BINKP_M_FILE = 3;
  BINKP_M_OK   = 4;
  BINKP_M_EOB  = 5;

Type
  TBinkpDetect = Record
    IsBinkp   : Boolean;
    CmdId     : Byte;      // the message id in the opening command frame
    FrameLen  : Word;      // announced length of that frame
  End;

  TBinkpSeam = Class
  Private
    FSer : TModemSerial;
  Public
    Constructor Create (ASer: TModemSerial);

    // Detector: given the first bytes read after CONNECT, decide whether this
    // is a BinkP session opening.  Looks for a command frame (high bit set)
    // carrying a low message id (M_NUL/M_ADR are what sessions start with).
    Class Function LooksLikeBinkp (Const Sniff: String; Out D: TBinkpDetect): Boolean;

    // The integration seam.  In a real build this would construct a TIOSerial
    // over FSer and pass it to Mystic's existing BinkP engine (the same engine
    // used for BinkP-over-TCP), then run the session.  Here it only reports the
    // hand-off point - running real BinkP over serial needs the TIOSerial class.
    Function RunSessionStub (Const RemoteInfo: String): Boolean;

    Property Serial : TModemSerial Read FSer;
  End;

Implementation

Constructor TBinkpSeam.Create (ASer: TModemSerial);
Begin
  Inherited Create;
  FSer := ASer;
End;

Class Function TBinkpSeam.LooksLikeBinkp (Const Sniff: String; Out D: TBinkpDetect): Boolean;
Var
  B0, B1, MsgId : Byte;
Begin
  FillChar(D, SizeOf(D), 0);
  Result := False;
  If Length(Sniff) < 3 Then Exit;

  B0 := Ord(Sniff[1]);
  B1 := Ord(Sniff[2]);

  // Command frame: top bit of the 16-bit header is set.
  If (B0 and $80) = 0 Then Exit;

  D.FrameLen := ((Word(B0 and $7F)) shl 8) or B1;
  MsgId      := Ord(Sniff[3]);          // first byte of frame data = message id
  D.CmdId    := MsgId;

  // A BinkP session opens with M_NUL or M_ADR (occasionally M_PWD).
  If (MsgId = BINKP_M_NUL) or (MsgId = BINKP_M_ADR) or (MsgId = BINKP_M_PWD) Then Begin
    D.IsBinkp := True;
    Result    := True;
  End;
End;

Function TBinkpSeam.RunSessionStub (Const RemoteInfo: String): Boolean;
Begin
  // === INTEGRATION SEAM ==============================================
  // Real implementation (needs mdl/m_io_serial.pas : TIOSerial):
  //
  //   Line := TIOSerial.Create;
  //   Line.AttachHandle(FSer.Handle);        // wrap the open serial line
  //   Binkp := TBinkP.Create(..., Line, ...); // Mystic's existing engine
  //   Result := Binkp.RunSession;             // exchange mail, unchanged
  //   Binkp.Free; Line.Free;
  //
  // Because Mystic's BinkP talks to a TIOBase byte stream, swapping TIOSocket
  // for TIOSerial is all that is required on the protocol side - PROVIDED the
  // modems negotiated V.42/MNP so the stream is reliable.
  // ===================================================================
  WriteLn('  [binkp] detected BinkP caller: ', RemoteInfo);
  WriteLn('  [binkp] SEAM: would attach TIOSerial to the modem line and run');
  WriteLn('  [binkp]       Mystic''s existing BinkP engine over it (V.42 assumed).');
  Result := True;
End;

End.
