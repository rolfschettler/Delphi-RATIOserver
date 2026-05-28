unit uJWTUtils;

interface

uses
  System.SysUtils,
  System.Classes,
  System.DateUtils,
  System.IniFiles,
  JOSE.Core.JWT,
  JOSE.Core.Builder,
  JOSE.Core.JWK;

type
  TJWTUtils = class
  private
    class var FSecret: string;
    class var FIssuer: string;
    class procedure LoadConfig;
  public
    class constructor Create;
    class function CreateToken(const AUserId, ARole: string; AExpireMinutes: Integer = 60): string;
    class function VerifyToken(const ACompactToken: string; out AClaims: TJWT): Boolean;
  end;

implementation

{ TJWTUtils }

uses webUtils;

class constructor TJWTUtils.Create;
begin

end;

class procedure TJWTUtils.LoadConfig;
begin
  FSecret := TConfigFile.GetConfigValue('security', 'jwt_secret');
  FIssuer := TConfigFile.GetConfigValue('security', 'issuer');

end;

class function TJWTUtils.CreateToken(const AUserId, ARole: string; AExpireMinutes: Integer): string;
var
  Token: TJWT;

begin
  LoadConfig;
  Token := TJWT.Create;
  try
    Token.Claims.Issuer := FIssuer;
    Token.Claims.Subject := AUserId;
    Token.Claims.IssuedAt := Now;
    Token.Claims.Expiration := IncMinute(Now, AExpireMinutes);
    Token.Claims.JSON.AddPair('role', ARole);
    Result := TJOSE.SHA256CompactToken(FSecret, Token);
  finally
    Token.Free;
  end;
end;


// Folgende Routine prüft OHNE berücksichtigung ob Token abgelaufen
(*
  class function TJWTUtils.VerifyToken(const ACompactToken: string; out AClaims: TJWT): Boolean;
  var
  Key: TJWK;
  begin
  Result := False;
  AClaims := nil;
  Key := TJWK.Create(FSecret);
  try
  AClaims := TJOSE.Verify(Key, ACompactToken);
  if Assigned(AClaims) and AClaims.Verified then
  Result := True
  else
  FreeAndNil(AClaims);
  finally
  Key.Free;
  end;
  end;
*)

class function TJWTUtils.VerifyToken(const ACompactToken: string; out AClaims: TJWT): Boolean;
var
  Key: TJWK;
  Expiration: TDateTime;
begin
  LoadConfig;
  Result := False;
  AClaims := nil;

  if FSecret = '' then
    raise Exception.Create('JWT Secret ist leer — Prüfen Sie die Config.');

  Key := TJWK.Create(FSecret);
  try
    try
      AClaims := TJOSE.Verify(Key, ACompactToken);
      if not Assigned(AClaims) then
        Exit;

      // Prüfe Signatur
      if not AClaims.Verified then
      begin
        FreeAndNil(AClaims);
        Exit;
      end;

      // Ablaufdatum prüfen
      Expiration := AClaims.Claims.Expiration;
      if (Expiration <> 0) and (Now > Expiration) then
      begin
        FreeAndNil(AClaims);
        Exit;
      end;

      // "Not Before" prüfen (optional)
      if (AClaims.Claims.NotBefore <> 0) and (Now < AClaims.Claims.NotBefore) then
      begin
        FreeAndNil(AClaims);
        Exit;
      end;

      // Wenn alles OK:
      Result := True;
    except
      on e: Exception do
        raise Exception.Create('fehlerhafter Token: ' + e.message)
    end;

  finally
    Key.Free;
  end;
end;

end.
