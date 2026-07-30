unit VortexCommon;

{ misc procedures and functions for use with vortex.
  StripCc was not made by me (joepezt)
  StripCc is used to remove annoying colorcodes from IRC lines.

  label1.caption := StripCc(Content); from IRC privmsg}


interface
uses sysutils;

implementation


function StripCc(Line : string):string;
var
  Token : string;
  i,StringLength,ColorCode : integer;

  function StrRemove(str:string;substr:string):string;
  begin
    while pos(substr,str) > 0 do
    delete(str,pos(substr,str),length(substr));
    result := str;
  end;
    
begin
  Token := Line;
  Token := StrRemove(Token,''); // Bold
  Token := StrRemove(Token,''); // Underline
  Token := StrRemove(Token,''); // Reverse
  Token := StrRemove(Token,''); // Plain
  while pos('',Token) > 0 do
  begin
    i := pos('',Token);
    StringLength := 1;
    if StrToIntDef(copy(Token,i+1,1),-1) > -1 then
    begin
      StringLength := StringLength+1;
      ColorCode := StrToInt(copy(Token,i+1,1));
      if ((ColorCode < 2) and (StrToIntDef(copy(Token,i+2,1),-1) > -1)) then
      begin
        StringLength := StringLength+1;
        if copy(Token,i+3,1) = ',' then
        begin
          StringLength := StringLength+1;
          if StrToIntDef(copy(Token,i+4,1),-1) > -1 then
          begin
            StringLength := StringLength+1;
            ColorCode := StrToIntDef(copy(Token,i+4,1),-1);
            if ((ColorCode < 2) and (StrToIntDef(copy(Token,i+5,1),-1) > -1)) then
              StringLength := StringLength+1
          end;
        end;
      end else
      if copy(Token,i+2,1) = ',' then
      begin
        StringLength := StringLength+1;
        if StrToIntDef(copy(Token,i+3,1),-1) > -1 then
        begin
          StringLength := StringLength+1;
          ColorCode := StrToIntDef(copy(Token,i+3,1),-1);
          if ((ColorCode < 2) and (StrToIntDef(copy(Token,i+4,1),-1) > -1)) then
          StringLength := StringLength+1
        end;
      end;
    end;
    Delete(Token,i,StringLength);
  end;
  result := Token;
end;


end.
 