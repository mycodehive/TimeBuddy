Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$ErrorActionPreference='Stop'
$root=Join-Path $env:LOCALAPPDATA 'TimeBuddy'
[IO.Directory]::CreateDirectory($root)|Out-Null
$file=Join-Path $root 'settings.json'
$mutex=New-Object Threading.Mutex($false,'Local\TimeBuddy')
if(!$mutex.WaitOne(0)){exit}
function Hash($p,$salt){$k=New-Object Security.Cryptography.Rfc2898DeriveBytes($p,[Convert]::FromBase64String($salt),100000);try{[Convert]::ToBase64String($k.GetBytes(32))}finally{$k.Dispose()}}
function Save { $script:cfg | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $file -Encoding UTF8 }
function Password($caption){
 $f=New-Object Windows.Forms.Form; $f.Text=$caption;$f.Size=New-Object Drawing.Size(380,155);$f.StartPosition='CenterScreen';$f.TopMost=$true;$f.FormBorderStyle='FixedDialog';$f.MaximizeBox=$false
 $t=New-Object Windows.Forms.TextBox;$t.Location=New-Object Drawing.Point(20,15);$t.Width=325;$t.UseSystemPasswordChar=$true;$f.Controls.Add($t)
 $b=New-Object Windows.Forms.Button;$b.Text='확인';$b.Location=New-Object Drawing.Point(230,50);$b.DialogResult='OK';$f.Controls.Add($b);$f.AcceptButton=$b
 $r=$f.ShowDialog();$v=$t.Text;$f.Dispose();if($r -eq 'OK'){return $v};return $null
}
function NewPassword($p){$s=New-Object byte[] 16;$rng=[Security.Cryptography.RandomNumberGenerator]::Create();$rng.GetBytes($s);$rng.Dispose();$script:cfg.salt=[Convert]::ToBase64String($s);$script:cfg.hash=Hash $p $script:cfg.salt}
function Verify($p){return ($p -and ((Hash $p $script:cfg.salt) -ceq $script:cfg.hash))}
if(Test-Path $file){$script:cfg=Get-Content $file -Raw | ConvertFrom-Json}else{
 $p=Password '최초 설정 - 부모 비밀번호 (8자 이상)';if(!$p -or $p.Length -lt 8){[Windows.Forms.MessageBox]::Show('8자 이상의 비밀번호가 필요합니다.');exit}
 $p2=Password '비밀번호 다시 입력';if($p -cne $p2){[Windows.Forms.MessageBox]::Show('비밀번호가 일치하지 않습니다.');exit}
 $script:cfg=[pscustomobject]@{salt='';hash='';token='';chat='';extra=30;days=@(0..6|ForEach-Object{[pscustomobject]@{enabled=$true;start='16:00';end='19:00'}})};NewPassword $p;Save
 $script:first=$true
}
# Upgrade existing settings without losing password or Telegram credentials.
foreach($item in @{limit=120;remote=$false;intervals=@();offset=0;manualLock=$false}.GetEnumerator()){if(!$script:cfg.PSObject.Properties[$item.Key]){$script:cfg | Add-Member -NotePropertyName $item.Key -NotePropertyValue $item.Value}}
Save
$usageFile=Join-Path $root 'usage.json'
$script:usage=@{}
if(Test-Path $usageFile){try{$u=Get-Content $usageFile -Raw|ConvertFrom-Json;foreach($prop in $u.PSObject.Properties){$script:usage[$prop.Name]=[double]$prop.Value}}catch{}}
function SaveUsage {$script:usage|ConvertTo-Json|Set-Content -LiteralPath $usageFile -Encoding UTF8}
function Used($date){$key=$date.ToString('yyyy-MM-dd');if($script:usage.ContainsKey($key)){return [double]$script:usage[$key]};return 0}
function Extend($minutes){$script:cfg.manualLock=$false;$script:until=(Get-Date).AddMinutes($minutes);Save;HideLocks}
function RemoteSettings {
 $f=New-Object Windows.Forms.Form;$f.Text='고급 사용 관리';$f.Size=New-Object Drawing.Size(600,520);$f.StartPosition='CenterScreen';$f.TopMost=$true
 $l=New-Object Windows.Forms.Label;$l.Text='하루 최대 사용시간(분, 0=제한 없음)';$l.SetBounds(15,15,330,25);$f.Controls.Add($l)
 $n=New-Object Windows.Forms.NumericUpDown;$n.SetBounds(350,15,100,25);$n.Maximum=1440;$n.Value=[int]$script:cfg.limit;$f.Controls.Add($n)
 $c=New-Object Windows.Forms.CheckBox;$c.Text='텔레그램 원격 제어 허용 (개인 채팅 ID만 사용)';$c.SetBounds(15,50,550,25);$c.Checked=$script:cfg.remote;$f.Controls.Add($c)
 $l2=New-Object Windows.Forms.Label;$l2.Text='추가 허용 시간대 (기존 요일별 시간에 추가)';$l2.SetBounds(15,80,550,25);$f.Controls.Add($l2)
 $g=New-Object Windows.Forms.DataGridView;$g.SetBounds(15,110,550,300);$g.AutoSizeColumnsMode='Fill';$g.RowHeadersVisible=$false
 $null=$g.Columns.Add('day','요일 (일=0, 월=1 ... 토=6)');$null=$g.Columns.Add('start','시작 HH:mm');$null=$g.Columns.Add('end','종료 HH:mm');foreach($r in $script:cfg.intervals){$null=$g.Rows.Add($r.day,$r.start,$r.end)};$f.Controls.Add($g)
 $b=New-Object Windows.Forms.Button;$b.Text='저장';$b.SetBounds(450,425,100,35);$b.DialogResult='OK';$f.Controls.Add($b)
 while($f.ShowDialog() -eq 'OK'){$g.EndEdit();$rows=@();$ok=$true;foreach($r in $g.Rows){if($r.IsNewRow){continue};$d=[string]$r.Cells[0].Value;$a=[string]$r.Cells[1].Value;$z=[string]$r.Cells[2].Value;if($d -notmatch '^[0-6]$' -or $a -notmatch '^(?:[01]\d|2[0-3]):[0-5]\d$' -or $z -notmatch '^(?:[01]\d|2[0-3]):[0-5]\d$' -or $a -eq $z){$ok=$false;break};$rows+=@([pscustomobject]@{day=[int]$d;start=$a;end=$z;enabled=$true})};if(!$ok -or ($c.Checked -and ($script:cfg.chat -notmatch '^[1-9][0-9]*$' -or !$script:cfg.token))){[Windows.Forms.MessageBox]::Show('시간 형식 또는 개인 Telegram Chat ID / 토큰을 확인하세요.')|Out-Null;continue};if($c.Checked -and !$script:cfg.remote){$script:cfg.offset=0;$script:remoteReady=$false};$script:cfg.limit=[int]$n.Value;$script:cfg.remote=$c.Checked;$script:cfg.intervals=$rows;Save;break};$f.Dispose()
}
function UsageReport {
 $now=Get-Date;$day=Used $now;$week=0;$month=0;$start=$now.Date.AddDays(-(([int]$now.DayOfWeek+6)%7));foreach($key in $script:usage.Keys){$d=[datetime]::ParseExact($key,'yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture);if($d -ge $start -and $d -le $now){$week+=$script:usage[$key]};if($d.Year -eq $now.Year -and $d.Month -eq $now.Month){$month+=$script:usage[$key]}}
 return ('오늘: {0:N1}분 / 이번 주: {1:N1}분 / 이번 달: {2:N1}분' -f ($day/60),($week/60),($month/60))
}
$script:remoteJob=$null;$script:remoteReady=$false;$script:nextPoll=[datetime]::MinValue
function PollRemote {
 if($script:remoteJob -and $script:remoteJob.State -in @('Completed','Failed','Stopped')){
  $updates=@(Receive-Job $script:remoteJob -ErrorAction SilentlyContinue);Remove-Job $script:remoteJob -Force;$script:remoteJob=$null
  foreach($u in $updates){if(!$u.update_id){continue};$script:cfg.offset=[long]$u.update_id+1;Save;if(!$script:cfg.remote -or !$script:remoteReady){continue};$m=$u.message;if(!$m -or $m.chat.type -ne 'private' -or [string]$m.chat.id -ne [string]$script:cfg.chat -or [string]$m.from.id -ne [string]$script:cfg.chat){continue};if([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()-[long]$m.date -gt 120){continue};switch -Regex ([string]$m.text){'^/lock$' {$script:cfg.manualLock=$true;$script:until=[datetime]::MinValue;Save;LockScreens;Telegram '원격 잠금 완료'} '^/unlock$' {Extend ([int]$script:cfg.extra);Telegram '일시 잠금 해제 완료'} '^/extend (10|30|60)$' {$mins=[int]$Matches[1];$base=Get-Date;$currentEnd=AllowedEnd $base;if($currentEnd -gt $base){$base=$currentEnd};if($script:until -gt $base){$base=$script:until};$script:cfg.manualLock=$false;$script:until=$base.AddMinutes($mins);Save;HideLocks;Telegram ("추가 허용: $mins 분")} '^/status$' {Telegram ((UsageReport)+" / 잠금: "+($script:locks.Count -gt 0))} '^/help$' {Telegram '/lock /unlock /extend 10 /extend 30 /extend 60 /status'}}}
  if($script:cfg.remote){$script:remoteReady=$true}
 }
 if(!$script:cfg.remote -or !$script:cfg.token -or $script:remoteJob -or (Get-Date) -lt $script:nextPoll){return};$script:nextPoll=(Get-Date).AddSeconds(5)
 try{$sec=ConvertTo-SecureString $script:cfg.token;$ptr=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec);try{$token=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)}finally{[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)};$script:remoteJob=Start-Job -ScriptBlock {param($t,$o) try{$r=Invoke-RestMethod -Uri ('https://api.telegram.org/bot'+$t+'/getUpdates') -Method Post -Body @{offset=$o;timeout=0;allowed_updates='["message"]'} -TimeoutSec 12;if($r.ok){$r.result}}catch{}} -ArgumentList $token,$script:cfg.offset}catch{}
}
function Telegram($msg){if(!$script:cfg.token -or !$script:cfg.chat){return};try{$token=[Runtime.InteropServices.Marshal]::PtrToStringBSTR(($ptr=[Runtime.InteropServices.Marshal]::SecureStringToBSTR((ConvertTo-SecureString $script:cfg.token))));[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr);$null=Start-Job -ScriptBlock {param($t,$c,$m) try{Invoke-RestMethod -Uri ('https://api.telegram.org/bot'+$t+'/sendMessage') -Method Post -Body @{chat_id=$c;text=$m} -TimeoutSec 15 -ErrorAction Stop|Out-Null}catch{throw '텔레그램 전송 실패'}} -ArgumentList $token,$script:cfg.chat,$msg}catch{}}
$script:until=[datetime]::MinValue;$script:warned='';$script:locks=@();$script:closing=$false;$script:fail=0;$script:retry=[datetime]::MinValue;$script:warning=$null
function AllowedEnd($now){
 if($script:cfg.manualLock){return [datetime]::MinValue}
 if($script:until -gt $now){return $script:until}
 $best=[datetime]::MinValue;$ranges=@()
 foreach($date in @($now.Date.AddDays(-1),$now.Date,$now.Date.AddDays(1))){$idx=[int]$date.DayOfWeek;$entries=@($script:cfg.days[$idx])+@($script:cfg.intervals|Where-Object {$_.day -eq $idx});foreach($d in $entries){if(!$d.enabled){continue};$a=$date.Add([timespan]::Parse($d.start));$b=$date.Add([timespan]::Parse($d.end));if($b -le $a){$b=$b.AddDays(1)};$ranges+=@([pscustomobject]@{a=$a;b=$b})}}
 foreach($r in ($ranges|Sort-Object a)){if(($r.a -le $now -and $r.b -gt $now) -or ($best -gt $now -and $r.a -le $best -and $r.b -gt $best)){if($r.b -gt $best){$best=$r.b}}}
 if([int]$script:cfg.limit -gt 0){$remain=[int]$script:cfg.limit*60-(Used $now);if($remain -le 0){return [datetime]::MinValue};$cap=$now.AddSeconds($remain);if($cap -lt $best){$best=$cap}}
 return $best
}
function HideLocks {$script:closing=$true;foreach($f in $script:locks){$f.Close();$f.Dispose()};$script:locks=@();$script:closing=$false}
function Unlock($p){if((Get-Date) -lt $script:retry){return};if(Verify $p){$script:fail=0;Extend ([int]$script:cfg.extra)}else{$script:fail++;if($script:fail -ge 5){$script:retry=(Get-Date).AddSeconds(30);$script:fail=0};[Windows.Forms.MessageBox]::Show('비밀번호가 올바르지 않습니다. 반복 실패 시 30초간 대기합니다.','TimeBuddy')|Out-Null}}
function LockScreens {
 if($script:locks.Count -gt 0){return};foreach($screen in [Windows.Forms.Screen]::AllScreens){$f=New-Object Windows.Forms.Form;$f.FormBorderStyle='None';$f.StartPosition='Manual';$f.Bounds=$screen.Bounds;$f.TopMost=$true;$f.BackColor=[Drawing.Color]::FromArgb(18,28,48);$f.ForeColor=[Drawing.Color]::White;$f.ShowInTaskbar=$false;$f.Add_FormClosing({param($s,$e) if(!$script:closing){$e.Cancel=$true}})
 $panel=New-Object Windows.Forms.FlowLayoutPanel;$panel.FlowDirection='TopDown';$panel.WrapContents=$false;$panel.Size=New-Object Drawing.Size(420,260);$panel.Location=New-Object Drawing.Point(([math]::Max(0,($screen.Bounds.Width-420)/2)),([math]::Max(0,($screen.Bounds.Height-260)/2)));$f.Controls.Add($panel)
 $l=New-Object Windows.Forms.Label;$l.Text='오늘도 약속을 잘 지켰어요!';$l.Font=New-Object Drawing.Font('Malgun Gothic',18);$l.AutoSize=$true;$panel.Controls.Add($l)
 $l2=New-Object Windows.Forms.Label;$l2.Text='잠시 쉬어가는 시간이에요. 부모님과 함께 시간을 늘릴 수 있어요.';$l2.AutoSize=$true;$panel.Controls.Add($l2)
 $t=New-Object Windows.Forms.TextBox;$t.UseSystemPasswordChar=$true;$t.Width=350;$t.Font=New-Object Drawing.Font('Malgun Gothic',15);$panel.Controls.Add($t)
 $b=New-Object Windows.Forms.Button;$b.Text='부모님과 함께 시간 늘리기';$b.Width=350;$b.Height=45;$b.ForeColor=[Drawing.Color]::Black;$b.Tag=$t;$b.Add_Click({param($sender,$e) $v=$sender.Tag.Text;$sender.Tag.Clear();Unlock $v});$panel.Controls.Add($b);$f.AcceptButton=$b;$script:locks+=@($f);$f.Show();if($screen.Primary){$f.Activate();$t.Focus()}}
}
function Settings {
 $f=New-Object Windows.Forms.Form;$f.Text='TimeBuddy - 부모 설정';$f.Size=New-Object Drawing.Size(570,580);$f.StartPosition='CenterScreen';$f.TopMost=$true
 $g=New-Object Windows.Forms.DataGridView;$g.Location=New-Object Drawing.Point(15,15);$g.Size=New-Object Drawing.Size(520,245);$g.AllowUserToAddRows=$false;$g.AllowUserToDeleteRows=$false;$g.RowHeadersVisible=$false;$g.AutoSizeColumnsMode='Fill'
 $null=$g.Columns.Add('day','요일');$g.Columns[0].ReadOnly=$true;$c=New-Object Windows.Forms.DataGridViewCheckBoxColumn;$c.HeaderText='허용';$null=$g.Columns.Add($c);$null=$g.Columns.Add('start','시작 HH:mm');$null=$g.Columns.Add('end','종료 HH:mm');$names=@('일','월','화','수','목','금','토');for($i=0;$i -lt 7;$i++){$d=$script:cfg.days[$i];$null=$g.Rows.Add($names[$i],$d.enabled,$d.start,$d.end)};$f.Controls.Add($g)
 function Field($label,$y,$value){$l=New-Object Windows.Forms.Label;$l.Text=$label;$l.Location=New-Object Drawing.Point(15,$y);$l.Width=150;$f.Controls.Add($l);$t=New-Object Windows.Forms.TextBox;$t.Location=New-Object Drawing.Point(170,$y);$t.Width=350;$t.Text=$value;$f.Controls.Add($t);return $t}
 $token=Field '텔레그램 Bot Token (변경 시)' 275 '';$token.UseSystemPasswordChar=$true;$chat=Field 'Telegram Chat ID' 310 $script:cfg.chat;$extra=Field '추가 사용시간 (분)' 345 $script:cfg.extra;$new=Field '새 비밀번호 (선택)' 380 '';$new.UseSystemPasswordChar=$true
 $clear=New-Object Windows.Forms.CheckBox;$clear.Text='텔레그램 토큰 삭제';$clear.Location=New-Object Drawing.Point(15,415);$clear.Width=220;$f.Controls.Add($clear)
 $save=New-Object Windows.Forms.Button;$save.Text='저장';$save.Location=New-Object Drawing.Point(420,455);$save.DialogResult='OK';$f.Controls.Add($save);$f.AcceptButton=$save
 while($f.ShowDialog() -eq 'OK'){ $g.EndEdit();$valid=$true;$days=@();foreach($r in $g.Rows){$a=[string]$r.Cells[2].Value;$b=[string]$r.Cells[3].Value;if($a -notmatch '^(?:[01]\d|2[0-3]):[0-5]\d$' -or $b -notmatch '^(?:[01]\d|2[0-3]):[0-5]\d$' -or $a -eq $b){$valid=$false};$days+=@([pscustomobject]@{enabled=[bool]$r.Cells[1].Value;start=$a;end=$b})};$n=0;if(!$valid -or ![int]::TryParse($extra.Text,[ref]$n) -or $n -lt 1 -or $n -gt 720 -or ($new.Text -and $new.Text.Length -lt 8)){[Windows.Forms.MessageBox]::Show('시간 형식, 서로 다른 시작/종료 시간, 추가시간 1~720분, 비밀번호 8자 이상을 확인하세요.')|Out-Null;continue};$script:cfg.days=$days;$script:cfg.extra=$n;$script:cfg.chat=$chat.Text.Trim();if($clear.Checked){$script:cfg.token=''}elseif($token.Text){$script:cfg.token=ConvertFrom-SecureString (ConvertTo-SecureString $token.Text.Trim() -AsPlainText -Force)};if($new.Text){NewPassword $new.Text};Save;break};$f.Dispose()
}
$tray=New-Object Windows.Forms.NotifyIcon;$tray.Icon=[Drawing.SystemIcons]::Shield;$tray.Text='TimeBuddy 0.1.0';$tray.Visible=$true;$menu=New-Object Windows.Forms.ContextMenuStrip
$null=$menu.Items.Add('부모 설정',$null,{if(Verify (Password '부모 비밀번호')){Settings}})
 $null=$menu.Items.Add('고급 사용 관리',$null,{if(Verify (Password '부모 비밀번호')){RemoteSettings}})
$null=$menu.Items.Add('나의 시간 기록',$null,{if(Verify (Password '부모 비밀번호')){[Windows.Forms.MessageBox]::Show((UsageReport),'나의 시간 기록')|Out-Null}})
$null=$menu.Items.Add('텔레그램 테스트',$null,{if(Verify (Password '부모 비밀번호')){Telegram 'TimeBuddy 테스트 알림'}})
$null=$menu.Items.Add('프로그램 종료',$null,{if(Verify (Password '부모 비밀번호')){HideLocks;$timer.Stop();$tray.Visible=$false;[Windows.Forms.Application]::ExitThread()}});$tray.ContextMenuStrip=$menu
if($script:first){Settings};Telegram ('컴퓨터 사용 시작: '+$env:COMPUTERNAME+' / '+(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
$timer=New-Object Windows.Forms.Timer;$timer.Interval=1000
$script:lastTick=Get-Date;$script:lastSave=Get-Date;$script:wasAllowed=$false
$timer.Add_Tick({$now=Get-Date;$delta=($now-$script:lastTick).TotalSeconds;$script:lastTick=$now;if($script:wasAllowed -and $delta -gt 0 -and $delta -le 5){$key=$now.ToString('yyyy-MM-dd');$script:usage[$key]=(Used $now)+$delta};if(($now-$script:lastSave).TotalSeconds -ge 10){SaveUsage;$script:lastSave=$now};PollRemote;Get-Job|Where-Object {$_.Id -ne $(if($script:remoteJob){$script:remoteJob.Id}else{-1}) -and $_.State -in @('Completed','Failed','Stopped')}|Remove-Job -Force -ErrorAction SilentlyContinue;$end=AllowedEnd $now;$script:wasAllowed=$end -gt $now;if($end -le $now){$script:warned='';LockScreens;if($script:warning){$script:warning.Close();$script:warning.Dispose();$script:warning=$null}}else{if($script:locks.Count){HideLocks};if(($end-$now).TotalSeconds -gt 300){$script:warned='';if($script:warning){$script:warning.Close();$script:warning.Dispose();$script:warning=$null}};if(($end-$now).TotalSeconds -le 300 -and $script:warned -ne 'yes'){$script:warned='yes';$w=New-Object Windows.Forms.Form;$w.Text='시간 약속 안내';$w.Size=New-Object Drawing.Size(430,150);$w.StartPosition='CenterScreen';$w.TopMost=$true;$l=New-Object Windows.Forms.Label;$l.Dock='Fill';$l.TextAlign='MiddleCenter';$l.Font=New-Object Drawing.Font('Malgun Gothic',14);$l.Text=('이제 곧 쉬어갈 시간이에요!'+[Environment]::NewLine+'종료 예정: '+$end.ToString('HH:mm')+[Environment]::NewLine+'작업을 저장해 주세요.');$w.Controls.Add($l);$script:warning=$w;$w.Show()}}})
$timer.Start();try{[Windows.Forms.Application]::Run()}finally{SaveUsage;if($script:remoteJob){Remove-Job $script:remoteJob -Force -ErrorAction SilentlyContinue};$tray.Dispose();$mutex.ReleaseMutex();$mutex.Dispose()}
