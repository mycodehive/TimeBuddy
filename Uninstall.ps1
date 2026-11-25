Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$root = Join-Path $env:LOCALAPPDATA 'TimeBuddy'
$reg = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\TimeBuddy'
function Info($message) { [Windows.Forms.MessageBox]::Show($message,'TimeBuddy') | Out-Null }
$mutex = New-Object Threading.Mutex($false,'Local\TimeBuddy')
$owned = $false
try {
 try { $owned = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $owned = $true }
 if (!$owned) { Info '먼저 TimeBuddy 트레이에서 부모 비밀번호로 프로그램을 종료해 주세요.'; exit 1 }
 $settings = Join-Path $root 'settings.json'
 if (Test-Path -LiteralPath $settings) {
  $cfg = Get-Content -LiteralPath $settings -Raw | ConvertFrom-Json
  $form = New-Object Windows.Forms.Form
  $form.Text = 'TimeBuddy 삭제 - 부모 비밀번호'
  $form.StartPosition = 'CenterScreen'
  $form.ClientSize = New-Object Drawing.Size(350,110)
  $form.TopMost = $true
  $pwd = New-Object Windows.Forms.TextBox
  $pwd.SetBounds(15,15,320,25)
  $pwd.UseSystemPasswordChar = $true
  $form.Controls.Add($pwd)
  $button = New-Object Windows.Forms.Button
  $button.Text = '확인'
  $button.SetBounds(245,55,90,30)
  $button.DialogResult = 'OK'
  $form.Controls.Add($button)
  $form.AcceptButton = $button
  try {
   if ($form.ShowDialog() -ne 'OK') { exit 0 }
   $k = New-Object Security.Cryptography.Rfc2898DeriveBytes($pwd.Text,[Convert]::FromBase64String($cfg.salt),100000)
   try { $valid = [Convert]::ToBase64String($k.GetBytes(32)) -ceq $cfg.hash } finally { $k.Dispose() }
  } finally { $form.Dispose() }
  if (!$valid) { Info '비밀번호가 올바르지 않습니다.'; exit 1 }
 }
 $answer = [Windows.Forms.MessageBox]::Show('TimeBuddy를 제거할까요? 예: 설정과 기록도 삭제 / 아니요: 설정과 기록 보존 / 취소: 삭제하지 않음','TimeBuddy','YesNoCancel','Question')
 if ($answer -eq 'Cancel') { exit 0 }
 $startup = Join-Path ([Environment]::GetFolderPath('Startup')) 'TimeBuddy.lnk'
 $programs = Join-Path ([Environment]::GetFolderPath('Programs')) 'TimeBuddy'
 if (Test-Path -LiteralPath $startup) { Remove-Item -LiteralPath $startup -Force }
 if (Test-Path -LiteralPath $programs) { Remove-Item -LiteralPath $programs -Recurse -Force }
 foreach ($name in @('Guard.ps1','Guard.ps1.previous','Guard.ps1.download','Uninstall.ps1')) {
  $path = Join-Path $root $name
  if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
 }
 if ($answer -eq 'Yes' -and (Test-Path -LiteralPath $root)) { Remove-Item -LiteralPath $root -Recurse -Force }
 if (Test-Path -LiteralPath $reg) { Remove-Item -LiteralPath $reg -Recurse -Force }
 Info 'TimeBuddy를 제거했습니다.'
} catch { Info ('삭제 실패: ' + $_.Exception.Message); exit 1 }
finally { if ($owned) { $mutex.ReleaseMutex() }; $mutex.Dispose() }
