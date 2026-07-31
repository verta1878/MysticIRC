{ ===========================================================================
  OpenOLMS — Open Offline Mail System
  Pending licence — with permission from Peter Rocca.
  =========================================================================== }

unit OL_Filter;
{ ===========================================================================
  OpenOLMS — keyword filtering and twit list
  ---------------------------------------------------------------------------
  OLMS's distinguishing feature: per-user keyword filters that reduce
  QWK packet size by including only messages matching the user's interests,
  and twit lists that exclude messages from specific senders.

  From OLMS.DOC: "OLMS has the power to set up filters and keywords to
  make your users bundles much smaller, and more on topic with what they
  want."

  Keyword scan checks the Subject and Body of each message.
  Twit list checks the MsgFrom field (case-insensitive).

  Files:
    <user>.KEY  — keyword list (one per line)
    <user>.TWT  — twit list (one name per line)

  Both are plain text, editable by the user through the door or by
  the sysop through CONFIG.EXE / olmscfg.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

type
  TFilterMode = (fmNone, fmInclude, fmExclude);

  TKeywordFilter = record
    Keywords : array of String;
    Mode     : TFilterMode;
    { fmInclude: only pack messages containing a keyword
      fmExclude: skip messages containing a keyword
      fmNone:    pack everything (no filtering) }
  end;

  TTwitList = record
    Names : array of String;
  end;

{ Load keywords from a file (one per line) }
function LoadKeywords(const Filename: String;
  var Filter: TKeywordFilter): Boolean;

{ Save keywords to a file }
procedure SaveKeywords(const Filename: String;
  const Filter: TKeywordFilter);

{ Load twit list from a file (one name per line) }
function LoadTwitList(const Filename: String;
  var Twit: TTwitList): Boolean;

{ Save twit list }
procedure SaveTwitList(const Filename: String;
  const Twit: TTwitList);

{ Check if a message matches the keyword filter.
  Returns True if the message should be INCLUDED in the packet. }
function KeywordMatch(const Filter: TKeywordFilter;
  const Subject, Body: String): Boolean;

{ Check if a sender is on the twit list.
  Returns True if the message should be EXCLUDED. }
function IsTwit(const Twit: TTwitList; const SenderName: String): Boolean;

{ Combined filter check: returns True if message should be packed }
function ShouldPack(const Filter: TKeywordFilter;
  const Twit: TTwitList;
  const MsgFrom, Subject, Body: String): Boolean;

implementation

uses SysUtils;

function LoadKeywords(const Filename: String;
  var Filter: TKeywordFilter): Boolean;
var
  F: Text;
  S: String;
begin
  Result := False;
  SetLength(Filter.Keywords, 0);
  Filter.Mode := fmNone;
  if not FileExists(Filename) then Exit;

  AssignFile(F, Filename);
  {$I-} Reset(F); {$I+}
  if IOResult <> 0 then Exit;

  try
    { First line is the mode: INCLUDE or EXCLUDE }
    if not EOF(F) then
    begin
      ReadLn(F, S);
      S := UpperCase(Trim(S));
      if S = 'INCLUDE' then
        Filter.Mode := fmInclude
      else if S = 'EXCLUDE' then
        Filter.Mode := fmExclude
      else
        Filter.Mode := fmInclude;  { default to include if unspecified }
    end;

    { Remaining lines are keywords }
    while not EOF(F) do
    begin
      ReadLn(F, S);
      S := Trim(S);
      if (S <> '') and (S[1] <> ';') then  { skip comments }
      begin
        SetLength(Filter.Keywords, Length(Filter.Keywords) + 1);
        Filter.Keywords[High(Filter.Keywords)] := LowerCase(S);
      end;
    end;

    Result := Length(Filter.Keywords) > 0;
  finally
    CloseFile(F);
  end;
end;

procedure SaveKeywords(const Filename: String;
  const Filter: TKeywordFilter);
var
  F: Text;
  I: Integer;
begin
  AssignFile(F, Filename);
  Rewrite(F);
  try
    case Filter.Mode of
      fmInclude: WriteLn(F, 'INCLUDE');
      fmExclude: WriteLn(F, 'EXCLUDE');
    else
      WriteLn(F, 'INCLUDE');
    end;
    for I := 0 to High(Filter.Keywords) do
      WriteLn(F, Filter.Keywords[I]);
  finally
    CloseFile(F);
  end;
end;

function LoadTwitList(const Filename: String;
  var Twit: TTwitList): Boolean;
var
  F: Text;
  S: String;
begin
  Result := False;
  SetLength(Twit.Names, 0);
  if not FileExists(Filename) then Exit;

  AssignFile(F, Filename);
  {$I-} Reset(F); {$I+}
  if IOResult <> 0 then Exit;

  try
    while not EOF(F) do
    begin
      ReadLn(F, S);
      S := Trim(S);
      if (S <> '') and (S[1] <> ';') then
      begin
        SetLength(Twit.Names, Length(Twit.Names) + 1);
        Twit.Names[High(Twit.Names)] := LowerCase(S);
      end;
    end;
    Result := Length(Twit.Names) > 0;
  finally
    CloseFile(F);
  end;
end;

procedure SaveTwitList(const Filename: String;
  const Twit: TTwitList);
var
  F: Text;
  I: Integer;
begin
  AssignFile(F, Filename);
  Rewrite(F);
  try
    for I := 0 to High(Twit.Names) do
      WriteLn(F, Twit.Names[I]);
  finally
    CloseFile(F);
  end;
end;

function KeywordMatch(const Filter: TKeywordFilter;
  const Subject, Body: String): Boolean;
var
  I: Integer;
  LSubject, LBody: String;
begin
  if Filter.Mode = fmNone then
  begin
    Result := True;
    Exit;
  end;

  if Length(Filter.Keywords) = 0 then
  begin
    Result := True;
    Exit;
  end;

  LSubject := LowerCase(Subject);
  LBody := LowerCase(Body);

  for I := 0 to High(Filter.Keywords) do
  begin
    if (Pos(Filter.Keywords[I], LSubject) > 0) or
       (Pos(Filter.Keywords[I], LBody) > 0) then
    begin
      { Keyword found }
      if Filter.Mode = fmInclude then
      begin
        Result := True;  { include this message }
        Exit;
      end
      else begin
        Result := False;  { exclude this message }
        Exit;
      end;
    end;
  end;

  { No keyword matched }
  if Filter.Mode = fmInclude then
    Result := False   { include mode: no match = skip }
  else
    Result := True;   { exclude mode: no match = keep }
end;

function IsTwit(const Twit: TTwitList; const SenderName: String): Boolean;
var
  I: Integer;
  LSender: String;
begin
  Result := False;
  if Length(Twit.Names) = 0 then Exit;
  LSender := LowerCase(SenderName);
  for I := 0 to High(Twit.Names) do
    if Twit.Names[I] = LSender then
    begin
      Result := True;
      Exit;
    end;
end;

function ShouldPack(const Filter: TKeywordFilter;
  const Twit: TTwitList;
  const MsgFrom, Subject, Body: String): Boolean;
begin
  { Check twit list first — fastest rejection }
  if IsTwit(Twit, MsgFrom) then
  begin
    Result := False;
    Exit;
  end;

  { Then check keyword filter }
  Result := KeywordMatch(Filter, Subject, Body);
end;

end.
