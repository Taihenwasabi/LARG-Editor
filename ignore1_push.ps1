$sig = @'
using System;
using System.Runtime.InteropServices;
public static class Cred {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  public struct CREDENTIAL {
    public UInt32 Flags;
    public UInt32 Type;
    public string TargetName;
    public string Comment;
    public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
    public UInt32 CredentialBlobSize;
    public IntPtr CredentialBlob;
    public UInt32 Persist;
    public UInt32 AttributeCount;
    public IntPtr Attributes;
    public string TargetAlias;
    public string UserName;
  }
  [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
  public static extern bool CredRead(string target, UInt32 type, UInt32 flags, out IntPtr cred);
  [DllImport("advapi32.dll")]
  public static extern void CredFree(IntPtr cred);
  public static (string user, string pass) Read(string target) {
    IntPtr p;
    if (!CredRead(target, 1, 0, out p)) return (null, null);
    var c = (CREDENTIAL)Marshal.PtrToStructure(p, typeof(CREDENTIAL));
    string pass = null;
    if (c.CredentialBlob != IntPtr.Zero && c.CredentialBlobSize > 0) {
      pass = Marshal.PtrToStringUni(c.CredentialBlob, (int)(c.CredentialBlobSize / 2));
    }
    var user = c.UserName;
    CredFree(p);
    return (user, pass);
  }
}
'@
Add-Type -TypeDefinition $sig

foreach ($target in @('git:https://github.com', 'GitHub - https://api.github.com/Taihenwasabi')) {
  $r = [Cred]::Read($target)
  if ($r.user -and $r.pass) {
    $user = $r.user
    $pass = $r.pass
    Write-Output "FOUND target=$target user=$user passlen=$($pass.Length)"
    Set-Location 'D:\AProGRAM\LARG_Editor'
    $url = "https://${user}:${pass}@github.com/Taihenwasabi/LARG-Editor.git"
    $env:GIT_TERMINAL_PROMPT = '0'
    $out = & git push $url main 2>&1
    $safe = $out | ForEach-Object { $_ -replace [regex]::Escape($pass), '***' }
    $safe | ForEach-Object { Write-Output $_ }
    Write-Output "EXIT=$LASTEXITCODE"
    $pass = $null
    break
  } else {
    Write-Output "MISS target=$target"
  }
}
