$sig = @'
using System;
using System.Runtime.InteropServices;
public static class Cred2 {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  public struct CREDENTIAL {
    public UInt32 Flags; public UInt32 Type; public string TargetName; public string Comment;
    public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
    public UInt32 CredentialBlobSize; public IntPtr CredentialBlob;
    public UInt32 Persist; public UInt32 AttributeCount; public IntPtr Attributes;
    public string TargetAlias; public string UserName;
  }
  [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
  public static extern bool CredRead(string target, UInt32 type, UInt32 flags, out IntPtr cred);
  [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
  public static extern bool CredEnumerate(string filter, UInt32 flags, out UInt32 count, out IntPtr pCreds);
  [DllImport("advapi32.dll")]
  public static extern void CredFree(IntPtr cred);
  public static string Dump() {
    UInt32 n; IntPtr arr;
    if (!CredEnumerate(null, 0, out n, out arr)) return "ENUM_FAIL " + Marshal.GetLastWin32Error();
    var sb = new System.Text.StringBuilder();
    for (int i=0;i<n;i++) {
      var p = Marshal.ReadIntPtr(arr, i*IntPtr.Size);
      var c = (CREDENTIAL)Marshal.PtrToStructure(p, typeof(CREDENTIAL));
      sb.AppendLine(c.TargetName + " | type=" + c.Type + " | user=" + c.UserName + " | blob=" + c.CredentialBlobSize);
    }
    return sb.ToString();
  }
}
'@
Add-Type -TypeDefinition $sig
Write-Output ([Cred2]::Dump())
