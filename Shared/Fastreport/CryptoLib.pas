unit CryptoLib;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, httpapp,
  System.NetEncoding;

const
  Key1 = 3567;
  c1 = 52845;
  c2 = 22719;

function Encrypt(eText: AnsiString): AnsiString;
function Decrypt(eText: AnsiString): AnsiString;
implementation
Type
  TByteArray = Array [0 .. 0] of byte;

Function AsHexString(p: Pointer; cnt: Integer): String;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to cnt do
    Result := Result + '$' + IntToHex(TByteArray(p^)[i], 2);
end;

Procedure MoveHexString2Dest(Dest: Pointer; Const HS: String);
var
  i: Integer;
begin
  i := 1;
  while i < Length(HS) do
  begin
    TByteArray(Dest^)[i div 3] := StrToInt(Copy(HS, i, 3));
    i := i + 3;
  end;
end;

function EncryptV1(const s: string; Key: Word): string;
var
  i: smallint;
  ResultStr: string;
  UCS: WIDEString;
begin
  Result := s;
  if Length(s) > 0 then
  begin
    for i := 1 to (Length(s)) do
    begin
      Result[i] := Char(byte(s[i]) xor (Key shr 8));
      Key := (smallint(Result[i]) + Key) * c1 + c2
    end;
    UCS := Result;
    Result := AsHexString(@UCS[1], Length(UCS) * 2 - 1)
  end;
end;

function DecryptV1(const s: string; Key: Word): string;
var
  i: smallint;
  sb: String;
  UCS: WIDEString;
begin
  if Length(s) > 0 then
  begin
    SetLength(UCS, Length(s) div 3 div 2);
    MoveHexString2Dest(@UCS[1], s);
    sb := UCS;
    SetLength(Result, Length(sb));
    for i := 1 to (Length(sb)) do
    begin
      Result[i] := Char(byte(sb[i]) xor (Key shr 8));
      Key := (smallint(sb[i]) + Key) * c1 + c2
    end;
  end
  else
    Result := s;
end;

function _Encrypt(eText: AnsiString): AnsiString;
// Verschlüsselt einen AnsiString, codiert ihn nach base64 und führt eine URL-codierung durch
var
  text: AnsiString;
begin
  text := eText;
  text := EncryptV1(text, Key1);
  Result := HttpEncode(TNetEncoding.Base64.Encode(text));
end;

function _Decrypt(eText: AnsiString): AnsiString;
// Entschlüsselt einen AnsiString, decodiert ihn von base64 und führ eine URL-Decodierung durch
var
  text: AnsiString;
begin
  text := HttpDecode(eText);
  text := TNetEncoding.Base64.Decode(text);
  text := DecryptV1(text, Key1);
  Result := text;
end;
{ * Extern sichtbare Funktion * }

function Decrypt(eText: AnsiString): AnsiString;
begin
  try
    Result := _Decrypt(eText);
  except
    Result := '';
  end;
end;

function Encrypt(eText: AnsiString): AnsiString;
begin
  try
    Result := _Encrypt(eText);
  except
    Result := '';
  end;
end;

end.
