{$MODE OBJFPC}
{$H+}
unit m_pdsauce;
{ PabloDraw Pascal — SAUCE Record Reader/Writer
  Converted from PabloDraw C# (SauceInfo.cs)
  Original: MIT License
  
  SAUCE = Standard Architecture for Universal Comment Extensions
  128-byte record appended to end of ANSI/ASCII art files. }

interface

uses Classes, SysUtils;

const
  SAUCE_ID    = 'SAUCE';
  SAUCE_SIZE  = 128;
  COMNT_ID    = 'COMNT';
  COMMENT_LEN = 64;

type
  TSauceDataType = (
    sdtNone       = 0,
    sdtCharacter  = 1,
    sdtBitmap     = 2,
    sdtVector     = 3,
    sdtAudio      = 4,
    sdtBinaryText = 5,
    sdtXBIN       = 6,
    sdtArchive    = 7,
    sdtExecutable = 8
  );

  TSauceRecord = class
  private
    FTitle:      String;
    FAuthor:     String;
    FGroup:      String;
    FDate:       String;
    FFileSize:   LongInt;
    FDataType:   Byte;
    FFileType:   Byte;
    FTInfo1:     Word;
    FTInfo2:     Word;
    FTInfo3:     Word;
    FTInfo4:     Word;
    FComments:   Byte;
    FFlags:      Byte;
    FTInfoS:     String;
    FCommentList: TStringList;
    FValid:      Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    
    function  LoadFromStream(S: TStream): Boolean;
    function  LoadFromFile(const FileName: String): Boolean;
    procedure SaveToStream(S: TStream);
    
    class function HasSauce(S: TStream): Boolean;
    class function GetFileSize(S: TStream): LongInt;
    
    function  GetWidth: Word;
    function  GetHeight: Word;
    function  GetICEColors: Boolean;
    function  GetLetterSpacing: Byte;
    function  GetAspectRatio: Byte;
    function  GetFontName: String;
    
    property Valid: Boolean read FValid;
    property Title: String read FTitle write FTitle;
    property Author: String read FAuthor write FAuthor;
    property Group: String read FGroup write FGroup;
    property DateStr: String read FDate write FDate;
    property FileSize: LongInt read FFileSize write FFileSize;
    property DataType: Byte read FDataType write FDataType;
    property FileType: Byte read FFileType write FFileType;
    property TInfo1: Word read FTInfo1 write FTInfo1;
    property TInfo2: Word read FTInfo2 write FTInfo2;
    property TInfo3: Word read FTInfo3 write FTInfo3;
    property TInfo4: Word read FTInfo4 write FTInfo4;
    property NumComments: Byte read FComments;
    property Flags: Byte read FFlags write FFlags;
    property TInfoS: String read FTInfoS write FTInfoS;
    property Comments: TStringList read FCommentList;
  end;

function TrimSauceField(const Buf: array of Byte; Len: Integer): String;

implementation

function TrimSauceField(const Buf: array of Byte; Len: Integer): String;
var I: Integer;
begin
  Result := '';
  for I := 0 to Len - 1 do
    Result := Result + Chr(Buf[I]);
  while (Length(Result) > 0) and (Result[Length(Result)] = ' ') do
    Delete(Result, Length(Result), 1);
end;

function PadSauceField(const S: String; Len: Integer): String;
begin
  Result := S;
  while Length(Result) < Len do Result := Result + ' ';
  if Length(Result) > Len then Result := Copy(Result, 1, Len);
end;

{ ---- TSauceRecord ---- }

constructor TSauceRecord.Create;
begin
  inherited;
  FCommentList := TStringList.Create;
  FValid := False;
  FTitle := '';
  FAuthor := '';
  FGroup := '';
  FDate := '';
  FTInfoS := '';
end;

destructor TSauceRecord.Destroy;
begin
  FCommentList.Free;
  inherited;
end;

class function TSauceRecord.HasSauce(S: TStream): Boolean;
var
  ID: array[0..4] of Char;
  SavePos: Int64;
begin
  Result := False;
  if S.Size <= SAUCE_SIZE + 1 then Exit;
  
  SavePos := S.Position;
  S.Seek(S.Size - SAUCE_SIZE, soFromBeginning);
  S.Read(ID, 5);
  S.Seek(SavePos, soFromBeginning);
  
  Result := (ID[0]='S') and (ID[1]='A') and (ID[2]='U') and
            (ID[3]='C') and (ID[4]='E');
end;

class function TSauceRecord.GetFileSize(S: TStream): LongInt;
var
  Sauce: TSauceRecord;
begin
  Sauce := TSauceRecord.Create;
  try
    if Sauce.LoadFromStream(S) then
      Result := Sauce.FileSize
    else
      Result := S.Size;
  finally
    Sauce.Free;
  end;
end;

function TSauceRecord.LoadFromStream(S: TStream): Boolean;
var
  ID: array[0..4] of Char;
  Version: array[0..1] of Char;
  TitleBuf: array[0..34] of Byte;
  AuthorBuf: array[0..19] of Byte;
  GroupBuf: array[0..19] of Byte;
  DateBuf: array[0..7] of Byte;
  TInfoSBuf: array[0..21] of Byte;
  NComments: Byte;
  SavePos: Int64;
  CommentPos: Int64;
  CommentID: array[0..4] of Char;
  CommentBuf: array[0..63] of Byte;
  EOF_Byte: Byte;
  I, ZeroIdx: Integer;
begin
  Result := False;
  FValid := False;
  
  if S.Size <= SAUCE_SIZE + 1 then Exit;
  
  SavePos := S.Position;
  try
    { Seek to SAUCE position (128 bytes from end + 1 for EOF marker) }
    S.Seek(S.Size - SAUCE_SIZE - 1, soFromBeginning);
    S.Read(EOF_Byte, 1);
    
    S.Read(ID, 5);
    if not ((ID[0]='S') and (ID[1]='A') and (ID[2]='U') and
            (ID[3]='C') and (ID[4]='E')) then Exit;
    
    S.Read(Version, 2);
    S.Read(TitleBuf, 35);
    S.Read(AuthorBuf, 20);
    S.Read(GroupBuf, 20);
    S.Read(DateBuf, 8);
    S.Read(FFileSize, 4);
    S.Read(FDataType, 1);
    S.Read(FFileType, 1);
    S.Read(FTInfo1, 2);
    S.Read(FTInfo2, 2);
    S.Read(FTInfo3, 2);
    S.Read(FTInfo4, 2);
    S.Read(NComments, 1);
    FComments := NComments;
    S.Read(FFlags, 1);
    S.Read(TInfoSBuf, 22);
    
    FTitle := TrimSauceField(TitleBuf, 35);
    FAuthor := TrimSauceField(AuthorBuf, 20);
    FGroup := TrimSauceField(GroupBuf, 20);
    FDate := TrimSauceField(DateBuf, 8);
    
    { TInfoS — zero-terminated }
    ZeroIdx := 22;
    for I := 0 to 21 do
      if TInfoSBuf[I] = 0 then begin ZeroIdx := I; Break; end;
    FTInfoS := TrimSauceField(TInfoSBuf, ZeroIdx);
    
    { Read comments }
    FCommentList.Clear;
    if NComments > 0 then begin
      CommentPos := S.Size - SAUCE_SIZE - 1 - 5 - (NComments * COMMENT_LEN);
      if CommentPos >= 0 then begin
        S.Seek(CommentPos, soFromBeginning);
        S.Read(CommentID, 5);
        if (CommentID[0]='C') and (CommentID[1]='O') and
           (CommentID[2]='M') and (CommentID[3]='N') and
           (CommentID[4]='T') then begin
          for I := 0 to NComments - 1 do begin
            S.Read(CommentBuf, COMMENT_LEN);
            FCommentList.Add(TrimSauceField(CommentBuf, COMMENT_LEN));
          end;
        end;
      end;
    end;
    
    { Calculate actual file size }
    FFileSize := S.Size - SAUCE_SIZE;
    if NComments > 0 then
      Dec(FFileSize, 5 + NumComments * COMMENT_LEN);
    if EOF_Byte = 26 then Dec(FFileSize);
    
    FValid := True;
    Result := True;
  finally
    S.Seek(SavePos, soFromBeginning);
  end;
end;

function TSauceRecord.LoadFromFile(const FileName: String): Boolean;
var F: TFileStream;
begin
  F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try
    Result := LoadFromStream(F);
  finally
    F.Free;
  end;
end;

procedure TSauceRecord.SaveToStream(S: TStream);
var
  Buf: array[0..63] of Byte;
  I: Integer;
  Line: String;
begin
  FFileSize := S.Position;
  
  { EOF marker }
  Buf[0] := 26;
  S.Write(Buf[0], 1);
  
  { Comments block }
  if FCommentList.Count > 0 then begin
    S.Write(COMNT_ID[1], 5);
    for I := 0 to FCommentList.Count - 1 do begin
      Line := PadSauceField(FCommentList[I], COMMENT_LEN);
      S.Write(Line[1], COMMENT_LEN);
    end;
    FComments := FCommentList.Count;
  end else
    FComments := 0;
  
  { SAUCE record }
  S.Write(SAUCE_ID[1], 5);
  S.Write('00', 2);
  
  Line := PadSauceField(FTitle, 35); S.Write(Line[1], 35);
  Line := PadSauceField(FAuthor, 20); S.Write(Line[1], 20);
  Line := PadSauceField(FGroup, 20); S.Write(Line[1], 20);
  Line := PadSauceField(FDate, 8); S.Write(Line[1], 8);
  
  S.Write(FFileSize, 4);
  S.Write(FDataType, 1);
  S.Write(FFileType, 1);
  S.Write(FTInfo1, 2);
  S.Write(FTInfo2, 2);
  S.Write(FTInfo3, 2);
  S.Write(FTInfo4, 2);
  S.Write(FComments, 1);
  S.Write(FFlags, 1);
  
  FillChar(Buf, 22, 0);
  if FTInfoS <> '' then
    Move(FTInfoS[1], Buf, Length(FTInfoS));
  S.Write(Buf, 22);
end;

{ Convenience accessors for Character type SAUCE }

function TSauceRecord.GetWidth: Word;
begin if FDataType = Byte(sdtCharacter) then Result := FTInfo1 else Result := 0; end;

function TSauceRecord.GetHeight: Word;
begin if FDataType = Byte(sdtCharacter) then Result := FTInfo2 else Result := 0; end;

function TSauceRecord.GetICEColors: Boolean;
begin Result := (FFlags and $01) <> 0; end;

function TSauceRecord.GetLetterSpacing: Byte;
begin Result := (FFlags shr 1) and $03; end;

function TSauceRecord.GetAspectRatio: Byte;
begin Result := (FFlags shr 3) and $03; end;

function TSauceRecord.GetFontName: String;
begin Result := FTInfoS; end;

end.
