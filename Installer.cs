using System;
using System.IO;
using System.Reflection;
using System.Diagnostics;
using System.Windows.Forms;
class Installer {
 [STAThread] static void Main(){
  try {
   var dir=Path.Combine(Path.GetTempPath(),"TimeBuddy-"+Guid.NewGuid().ToString("N"));
   Directory.CreateDirectory(dir);
   foreach(var name in new[]{"Guard.ps1","Install.bat"}){
    using(var input=Assembly.GetExecutingAssembly().GetManifestResourceStream(name))
    using(var output=File.Create(Path.Combine(dir,name))) {input.CopyTo(output);}
   }
   var p=Process.Start(new ProcessStartInfo("cmd.exe", "/d /c \"\""+Path.Combine(dir,"Install.bat")+"\"\""){WorkingDirectory=dir,UseShellExecute=false});
   p.WaitForExit();
   if(p.ExitCode!=0) throw new Exception("Installation returned code "+p.ExitCode);
   Directory.Delete(dir,true);
   MessageBox.Show("설치가 완료되었습니다. 기존 버전이 실행 중이라면 종료 후 다시 로그인하세요.","TimeBuddy");
  }catch(Exception ex){MessageBox.Show(ex.Message,"Installation error");}
 }
}
