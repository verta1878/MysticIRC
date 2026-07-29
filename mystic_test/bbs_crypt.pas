// ====================================================================
// bbs_crypt.pas — Password hashing for Mystic BBS
// ====================================================================
//
// Copyright (C) 1997-2013 By James Coyle
// Copyright (C) 2025-2026 IRC Fork: verta1878, sysop/0, evga, kiddo, wrench
//
// Wraps m_crypt.pas (MD5/B64/HMAC) for BBS password operations.
//
// STRATEGY:
//   - New passwords stored as '{MD5}' + 32-char hex digest in PasswordHash
//   - Old passwords remain in Password (String[15]) for backward compat
//   - CheckPassword checks PasswordHash first, falls back to Password
//   - On successful login with old password, auto-upgrades to hash
//   - Password field is NOT cleared (so downgrade to old version works)
//
// DEPENDENCY: m_crypt.pas in mdl/
// ====================================================================

Unit bbs_crypt;

{$I M_OPS.PAS}

Interface

Const
  PW_MD5_PREFIX = '{MD5}';

Function  HashPassword      (const PlainText: String) : String;
Function  CheckPassword     (const Input, StoredHash, StoredPlain: String) : Boolean;
Function  IsHashedPassword  (const PW: String) : Boolean;

Implementation

Uses
  m_Crypt,
  m_Strings;

// Hash a plaintext password to MD5 prefix + hex digest (37 chars)
Function HashPassword (const PlainText: String) : String;
Begin
  Result := PW_MD5_PREFIX + Digest2String(MD5(strUpper(PlainText)));
End;

{ Check if a stored password is hashed }
Function IsHashedPassword (const PW: String) : Boolean;
Begin
  Result := Copy(PW, 1, Length(PW_MD5_PREFIX)) = PW_MD5_PREFIX;
End;

{ Compare input against stored password
  StoredHash = PasswordHash field (new MD5)
  StoredPlain = Password field (legacy plaintext)
  Checks hash first, falls back to plaintext }
Function CheckPassword (const Input, StoredHash, StoredPlain: String) : Boolean;
Begin
  If IsHashedPassword(StoredHash) Then
    Result := HashPassword(Input) = StoredHash
  Else If StoredPlain <> '' Then
    Result := strUpper(Input) = StoredPlain
  Else
    Result := False;
End;

End.
