unit Token;

interface

function GetFirstToken(Line: String): String;
function GetNextToken: String;
function GetRemainingTokens: String;

implementation

var
  TokenString: String;

function GetFirstToken(Line: String): String;
begin
  TokenString := Line;
  Result := GetNextToken;
end;

function GetNextToken: String;
var
  i, j: Integer;
begin
  Result := '';
  if TokenString <> '' then
  begin
    i := 1;
    while TokenString[i] in [#9, #10, #13, ' '] do
      Inc(i);
    j := 0;
    while not (TokenString[i + j] in [#0, #9, #10, #13, ' ']) do
      Inc(j);
    Result := Copy(TokenString, i, j);
    TokenString := Copy(TokenString, i + j, High(Integer));
  end;
end;

function GetRemainingTokens: String;
var
  i: Integer;
begin
  Result := '';
  if TokenString <> '' then
  begin
    i := 1;
    while TokenString[i] in [#9, #10, #13, ' '] do
      Inc(i);
    Result := Copy(TokenString, i, High(Integer));
  end;
end;

end.
