Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$ErrorActionPreference='Stop'
$script:version = [version]'0.1.2'
$script:inTick = $false
$root=Join-Path $env:LOCALAPPDATA 'TimeBuddy'
[IO.Directory]::CreateDirectory($root)|Out-Null
$file=Join-Path $root 'settings.json'
$mutex=New-Object Threading.Mutex($false,'Local\TimeBuddy')
if(!$mutex.WaitOne(0)){exit}
function Hash($p,$salt){$k=New-Object Security.Cryptography.Rfc2898DeriveBytes($p,[Convert]::FromBase64String($salt),100000);try{[Convert]::ToBase64String($k.GetBytes(32))}finally{$k.Dispose()}}
function WriteJson($path, $data) {
 $temp = $path + '.tmp'
 try {
  $data | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $temp -Encoding UTF8
  if ([IO.File]::Exists($path)) {
   [IO.File]::Replace($temp, $path, ($path + '.previous'))
  } else {
   [IO.File]::Move($temp, $path)
  }
 } finally {
  if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) }
 }
}
function Save { WriteJson $file $script:cfg }
function LogError($area) {
 try {
  $log = Join-Path $root 'timebuddy.log'
  if ((Test-Path -LiteralPath $log) -and (Get-Item -LiteralPath $log).Length -gt 262144) {
   Clear-Content -LiteralPath $log
  }
  Add-Content -LiteralPath $log -Encoding UTF8 -Value ('{0:s} {1}' -f (Get-Date), $area)
 } catch {}
}
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
foreach($item in @{limit=120;remote=$false;intervals=@();offset=0;manualLock=$false;autoUpdate=$true}.GetEnumerator()){if(!$script:cfg.PSObject.Properties[$item.Key]){$script:cfg | Add-Member -NotePropertyName $item.Key -NotePropertyValue $item.Value}}
Save
$usageFile=Join-Path $root 'usage.json'
$script:usage=@{}
if (Test-Path -LiteralPath $usageFile) {
 try {
  $savedUsage = Get-Content -LiteralPath $usageFile -Raw | ConvertFrom-Json
  foreach ($entry in $savedUsage.PSObject.Properties) {
   $date = [datetime]::MinValue
   $seconds = 0.0
   if ([datetime]::TryParseExact($entry.Name, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture,
       [Globalization.DateTimeStyles]::None, [ref]$date) -and
       [double]::TryParse([string]$entry.Value, [ref]$seconds) -and
       $seconds -ge 0 -and -not [double]::IsInfinity($seconds)) {
    $script:usage[$entry.Name] = $seconds
   }
  }
 } catch {
  LogError 'usage-read'
  Move-Item -LiteralPath $usageFile -Destination ($usageFile + '.' + (Get-Date -Format 'yyyyMMddHHmmssfff') + '.bak')
 }
}
function SaveUsage { WriteJson $usageFile $script:usage }
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
 while($f.ShowDialog() -eq 'OK'){$g.EndEdit();$rows=@();$ok=$true;foreach($r in $g.Rows){if($r.IsNewRow){continue};$d=[string]$r.Cells[0].Value;$a=[string]$r.Cells[1].Value;$z=[string]$r.Cells[2].Value;if($d -notmatch '^[0-6]$' -or $a -notmatch '^(?:[01]\d|2[0-3]):[0-5]\d$' -or $z -notmatch '^(?:[01]\d|2[0-3]):[0-5]\d$' -or $a -eq $z){$ok=$false;break};$rows+=@([pscustomobject]@{day=[int]$d;start=$a;end=$z;enabled=$true})};if(!$ok -or ($c.Checked -and ($script:cfg.chat -notmatch '^[1-9][0-9]*$' -or !$script:cfg.token))){[Windows.Forms.MessageBox]::Show('시간 형식 또는 개인 Telegram Chat ID / 토큰을 확인하세요.')|Out-Null;continue};if($c.Checked -ne $script:cfg.remote){ResetRemote};$script:cfg.limit=[int]$n.Value;$script:cfg.remote=$c.Checked;$script:cfg.intervals=$rows;Save;break};$f.Dispose()
}
function UsageReport {
 $now=Get-Date;$day=Used $now;$week=0;$month=0;$start=$now.Date.AddDays(-(([int]$now.DayOfWeek+6)%7));foreach($key in $script:usage.Keys){$d=[datetime]::ParseExact($key,'yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture);if($d -ge $start -and $d -le $now){$week+=$script:usage[$key]};if($d.Year -eq $now.Year -and $d.Month -eq $now.Month){$month+=$script:usage[$key]}}
 return ('오늘: {0:N1}분 / 이번 주: {1:N1}분 / 이번 달: {2:N1}분' -f ($day/60),($week/60),($month/60))
}
$script:remoteJob = $null
$script:sendJobs = @()
$script:remoteReady = $false
$script:nextPoll = [datetime]::MinValue
$script:pollDelay = 2

function ResetRemote {
 if ($script:remoteJob) {
  Remove-Job $script:remoteJob -Force -ErrorAction SilentlyContinue
  $script:remoteJob = $null
 }
 $script:cfg.offset = 0
 $script:remoteReady = $false
 $script:pollDelay = 2
 $script:nextPoll = [datetime]::MinValue
}

function ReadBotToken {
 $secret = ConvertTo-SecureString $script:cfg.token
 $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
 try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
 finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
  $secret.Dispose()
 }
}

function Telegram($message) {
 if (!$script:cfg.token -or $script:cfg.chat -notmatch '^[1-9][0-9]*$' -or $script:sendJobs.Count -ge 4) { return }
 try {
  $script:sendJobs += Start-Job -ScriptBlock {
   param($token, $chat, $message)
   try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $response = Invoke-RestMethod -Uri "https://api.telegram.org/bot${token}/sendMessage" -Method Post -Body @{
     chat_id = $chat
     text = $message
    } -TimeoutSec 12 -ErrorAction Stop
    [bool]$response.ok
   } catch { $false }
  } -ArgumentList (ReadBotToken), $script:cfg.chat, $message
 } catch { LogError 'telegram-send' }
}

function InvokeParentCommand($message) {
 if (!$message -or $message.chat.type -ne 'private' -or $message.from.is_bot -or
     [string]$message.chat.id -ne [string]$script:cfg.chat -or
     [string]$message.from.id -ne [string]$script:cfg.chat) { return }
 $age = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - [long]$message.date
 if ($age -lt -30 -or $age -gt 120) { return }
 switch -Regex (([string]$message.text).Trim()) {
  '^/lock$' {
   $script:cfg.manualLock = $true
   $script:until = [datetime]::MinValue
   Save
   LockScreens
   Telegram '쉬는 시간으로 전환했어요.'
  }
  '^/unlock(?:\s+([1-9][0-9]{0,2}))?$' {
   $minutes = [int]$script:cfg.extra
   if ($Matches[1]) { $minutes = [int]$Matches[1] }
   if ($minutes -gt 720) { Telegram '잠금 해제 시간은 1~720분이에요.'; break }
   Extend $minutes
   Telegram "잠금 해제: $minutes 분"
  }
  '^/extend\s+([1-9][0-9]{0,2})$' {
   $minutes = [int]$Matches[1]
   if ($minutes -gt 120) { Telegram '한 번에 1~120분 연장할 수 있어요.'; break }
   $now = Get-Date
   $end = AllowedEnd $now
   if ($end -lt $now) { $end = $now }
   $script:cfg.manualLock = $false
   $script:until = $end.AddMinutes($minutes)
   Save
   HideLocks
   Telegram ('{0}까지 사용 시간을 연장했어요.' -f $script:until.ToString('MM-dd HH:mm'))
  }
  '^/usage$' { Telegram (UsageReport) }
  '^/status$' {
   $now = Get-Date
   $end = AllowedEnd $now
   $status = if ($end -gt $now) { '사용 가능 · {0}까지' -f $end.ToString('MM-dd HH:mm') } else { '쉬는 시간' }
   Telegram ($status + "`n" + (UsageReport))
  }
  '^/help$' { Telegram "/lock · /unlock [1~720] · /extend 1~120`n/status · /usage · /help" }
  '^/' { Telegram '명령어를 확인하려면 /help를 보내 주세요.' }
 }
}

function PollRemote {
 $active = @()
 foreach ($job in $script:sendJobs) {
  if ($job.State -in 'Completed','Failed','Stopped') {
   if ((Receive-Job $job -ErrorAction SilentlyContinue) -ne $true) { LogError 'telegram-send' }
   Remove-Job $job -Force -ErrorAction SilentlyContinue
  } else { $active += $job }
 }
 $script:sendJobs = $active
 if ($script:remoteJob -and $script:remoteJob.State -in 'Completed','Failed','Stopped') {
  $response = Receive-Job $script:remoteJob -ErrorAction SilentlyContinue
  Remove-Job $script:remoteJob -Force -ErrorAction SilentlyContinue
  $script:remoteJob = $null
  if ($response.ok) {
   foreach ($update in @($response.result)) {
    if ($null -eq $update -or $null -eq $update.update_id) { continue }
    $script:cfg.offset = [long]$update.update_id + 1
    Save
    if ($script:remoteReady) { InvokeParentCommand $update.message }
   }
   $script:remoteReady = $true
   $script:pollDelay = 2
  } else {
   LogError 'telegram-poll'
   $script:pollDelay = [Math]::Min(60, $script:pollDelay * 2)
  }
  $script:nextPoll = (Get-Date).AddSeconds($script:pollDelay)
 }
 if (!$script:cfg.remote -or !$script:cfg.token -or $script:remoteJob -or (Get-Date) -lt $script:nextPoll) { return }
 $offset = if ($script:remoteReady) { $script:cfg.offset } else { -1 }
 $script:nextPoll = (Get-Date).AddSeconds(5)
 try {
  $script:remoteJob = Start-Job -ScriptBlock {
   param($token, $offset)
   try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-RestMethod -Uri "https://api.telegram.org/bot${token}/getUpdates" -Method Post -Body @{
     offset = $offset
     timeout = 5
     allowed_updates = '["message"]'
    } -TimeoutSec 12 -ErrorAction Stop
   } catch {}
  } -ArgumentList (ReadBotToken), $offset
 } catch { LogError 'telegram-poll' }
}
$script:until=[datetime]::MinValue;$script:warned='';$script:locks=@();$script:closing=$false;$script:fail=0;$script:retry=[datetime]::MinValue;$script:warning=$null;$script:previewUntil=[datetime]::MinValue
function AllowedEnd($now){
 if($script:cfg.manualLock){return [datetime]::MinValue}
 $approvedUntil = $script:until
 $best=[datetime]::MinValue;$ranges=@()
 foreach($date in @($now.Date.AddDays(-1),$now.Date,$now.Date.AddDays(1))){$idx=[int]$date.DayOfWeek;$entries=@($script:cfg.days[$idx])+@($script:cfg.intervals|Where-Object {$_.day -eq $idx});foreach($d in $entries){if(!$d.enabled){continue};$a=$date.Add([timespan]::Parse($d.start));$b=$date.Add([timespan]::Parse($d.end));if($b -le $a){$b=$b.AddDays(1)};$ranges+=@([pscustomobject]@{a=$a;b=$b})}}
 foreach($r in ($ranges|Sort-Object a)){if(($r.a -le $now -and $r.b -gt $now) -or ($best -gt $now -and $r.a -le $best -and $r.b -gt $best)){if($r.b -gt $best){$best=$r.b}}}
 if([int]$script:cfg.limit -gt 0){$remain=[int]$script:cfg.limit*60-(Used $now);if($remain -le 0){$best=[datetime]::MinValue}else{$cap=$now.AddSeconds($remain);if($cap -lt $best){$best=$cap}}}
 if ($approvedUntil -gt $best) { return $approvedUntil }
 return $best
}
function HideLocks {$script:closing=$true;foreach($f in $script:locks){$f.Close();$f.Dispose()};$script:locks=@();$script:closing=$false}
function Unlock($p){if((Get-Date) -lt $script:retry){return};if(Verify $p){$script:fail=0;$script:previewUntil=[datetime]::MinValue;Extend ([int]$script:cfg.extra)}else{$script:fail++;if($script:fail -ge 5){$script:retry=(Get-Date).AddSeconds(30);$script:fail=0};[Windows.Forms.MessageBox]::Show('비밀번호가 올바르지 않습니다. 반복 실패 시 30초간 대기합니다.','TimeBuddy')|Out-Null}}
function NewBuddyLabel($text, $size, $height, $bold = $false) {
 $label = New-Object Windows.Forms.Label
 $label.Text = $text
 $label.Width = 360
 $label.Height = $height
 $label.Font = New-Object Drawing.Font('Malgun Gothic', $size, $(if ($bold) { 'Bold' } else { 'Regular' }))
 $label.TextAlign = 'MiddleCenter'
 return $label
}

function ShowUsage {
 Add-Type -AssemblyName System.Windows.Forms.DataVisualization
 $form = New-Object Windows.Forms.Form
 $form.Text = 'TimeBuddy · 나의 시간 기록'
 $form.StartPosition = 'CenterScreen'
 $form.ClientSize = New-Object Drawing.Size(700, 430)
 $form.MinimumSize = New-Object Drawing.Size(540, 390)
 $form.BackColor = [Drawing.Color]::FromArgb(246, 251, 247)
 $form.Font = New-Object Drawing.Font('Malgun Gothic', 10)
 $summary = NewBuddyLabel (UsageReport) 11 48 $true
 $summary.Dock = 'Top'
 $period = New-Object Windows.Forms.ComboBox
 $period.DropDownStyle = 'DropDownList'
 $period.Dock = 'Top'
 $period.AccessibleName = '그래프 기간'
 $period.Items.AddRange(@('최근 7일', '최근 30일'))
 $chart = New-Object Windows.Forms.DataVisualization.Charting.Chart
 $chart.Dock = 'Fill'
 $chart.AccessibleName = '날짜별 사용 시간 (분)'
 $area = New-Object Windows.Forms.DataVisualization.Charting.ChartArea('days')
 $area.AxisX.MajorGrid.Enabled = $false
 $area.AxisY.Title = '사용 시간 (분)'
 $area.AxisY.Minimum = 0
 $null = $chart.ChartAreas.Add($area)
 $series = New-Object Windows.Forms.DataVisualization.Charting.Series('사용 시간')
 $series.ChartType = 'Column'
 $series.Color = [Drawing.Color]::FromArgb(32, 126, 106)
 $null = $chart.Series.Add($series)
 $chart.Tag = @{ Series = $series; Area = $area }
 $period.Tag = $chart
 $period.Add_SelectedIndexChanged({
  param($sender, $event)
  $state = $sender.Tag.Tag
  $count = if ($sender.SelectedIndex -eq 0) { 7 } else { 30 }
  $today = (Get-Date).Date
  $state.Series.Points.Clear()
  $state.Area.AxisX.Interval = if ($count -eq 7) { 1 } else { 5 }
  for ($i = $count - 1; $i -ge 0; $i--) {
   $date = $today.AddDays(-$i)
   $minutes = [Math]::Round((Used $date) / 60, 1)
   $index = $state.Series.Points.AddXY($date.ToString('MM-dd'), $minutes)
   $state.Series.Points[$index].ToolTip = '{0:MM-dd}: {1}분' -f $date, $minutes
  }
 })
 $form.Controls.Add($chart)
 $form.Controls.Add($period)
 $form.Controls.Add($summary)
 $period.SelectedIndex = 0
 try { $null = $form.ShowDialog() } finally { $form.Dispose() }
}

function LockScreens {
 $screens = @([Windows.Forms.Screen]::AllScreens)
 if ($script:locks.Count -eq $screens.Count) {
  $sameLayout = $true
  for ($i = 0; $i -lt $screens.Count; $i++) {
   if ($script:locks[$i].IsDisposed -or !$script:locks[$i].Visible -or $script:locks[$i].Bounds -ne $screens[$i].Bounds) { $sameLayout = $false; break }
  }
  if ($sameLayout) { return }
 }
 if ($script:locks.Count) { HideLocks }
 foreach ($screen in $screens) {
  $form = New-Object Windows.Forms.Form
  $form.FormBorderStyle = 'None'
  $form.StartPosition = 'Manual'
  $form.AutoScaleMode = 'None'
  $form.WindowState = 'Normal'
  $form.Bounds = $screen.Bounds
  $form.TopMost = $true
  $form.BackColor = [Drawing.Color]::FromArgb(235, 249, 239)
  $form.ForeColor = [Drawing.Color]::FromArgb(24, 64, 54)
  $form.ShowInTaskbar = $false
  $form.Add_FormClosing({ param($sender,$event) if (!$script:closing) { $event.Cancel = $true } })
  $panel = New-Object Windows.Forms.FlowLayoutPanel
  $panel.FlowDirection = 'TopDown'
  $panel.WrapContents = $false
  $panel.Size = New-Object Drawing.Size(370, 255)
  $panel.Location = New-Object Drawing.Point(([int][Math]::Max(0, ($screen.Bounds.Width - 370) / 2)), ([int][Math]::Max(0, ($screen.Bounds.Height - 255) / 2)))
  $form.Controls.Add($panel)

  $buddy = New-Object Windows.Forms.Panel
  $buddy.Size = New-Object Drawing.Size(360, 91)
  $buddy.Add_Paint({
   param($sender,$event)
   $g = $event.Graphics
   $g.SmoothingMode = 'AntiAlias'
   $fur = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(237, 174, 103))
   $snout = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(255, 223, 172))
   $smile = New-Object Drawing.Pen([Drawing.Color]::FromArgb(76, 49, 38), 2)
   try {
    $g.FillEllipse($fur, 145, 6, 23, 26)
    $g.FillEllipse($fur, 192, 6, 23, 26)
    $g.FillEllipse($fur, 143, 17, 74, 67)
    $g.FillEllipse($snout, 161, 47, 38, 30)
    $g.FillEllipse([Drawing.Brushes]::SaddleBrown, 163, 38, 6, 8)
    $g.FillEllipse([Drawing.Brushes]::SaddleBrown, 191, 38, 6, 8)
    $g.FillEllipse([Drawing.Brushes]::SaddleBrown, 176, 53, 8, 5)
    $g.DrawArc($smile, 172, 53, 16, 16, 20, 140)
   } finally { $fur.Dispose(); $snout.Dispose(); $smile.Dispose() }
  })
  $panel.Controls.Add($buddy)
  $panel.Controls.Add((NewBuddyLabel '버디와 함께 쉬어가요!' 21 43 $true))
  $panel.Controls.Add((NewBuddyLabel '물 한 잔 마시고 몸을 쭉 펴 볼까요?' 12 32))
  $button = New-Object Windows.Forms.Button
  $button.Text = '부모님과 함께 시간 늘리기'
  $button.Size = New-Object Drawing.Size(360, 43)
  $button.BackColor = [Drawing.Color]::White
  $button.Add_Click({
   if ((Get-Date) -lt $script:retry) { return }
   $password = Password '부모님 비밀번호'
   if ($null -ne $password) { Unlock $password }
  })
  $panel.Controls.Add($button)
  $form.AcceptButton = $button
  try {
   $form.Show()
   $form.Bounds = $screen.Bounds
   $script:locks += $form
   if ($screen.Primary) { $form.Activate() }
  } catch { $form.Dispose(); throw }
 }
}
function Settings {
 $f=New-Object Windows.Forms.Form;$f.Text='TimeBuddy - 부모 설정';$f.Size=New-Object Drawing.Size(570,580);$f.StartPosition='CenterScreen';$f.TopMost=$true
 $g=New-Object Windows.Forms.DataGridView;$g.Location=New-Object Drawing.Point(15,15);$g.Size=New-Object Drawing.Size(520,245);$g.AllowUserToAddRows=$false;$g.AllowUserToDeleteRows=$false;$g.RowHeadersVisible=$false;$g.AutoSizeColumnsMode='Fill'
 $null=$g.Columns.Add('day','요일');$g.Columns[0].ReadOnly=$true;$c=New-Object Windows.Forms.DataGridViewCheckBoxColumn;$c.HeaderText='허용';$null=$g.Columns.Add($c);$null=$g.Columns.Add('start','시작 HH:mm');$null=$g.Columns.Add('end','종료 HH:mm');$names=@('일','월','화','수','목','금','토');for($i=0;$i -lt 7;$i++){$d=$script:cfg.days[$i];$null=$g.Rows.Add($names[$i],$d.enabled,$d.start,$d.end)};$f.Controls.Add($g)
 function Field($label,$y,$value){$l=New-Object Windows.Forms.Label;$l.Text=$label;$l.Location=New-Object Drawing.Point(15,$y);$l.Width=150;$f.Controls.Add($l);$t=New-Object Windows.Forms.TextBox;$t.Location=New-Object Drawing.Point(170,$y);$t.Width=350;$t.Text=$value;$f.Controls.Add($t);return $t}
 $token=Field '텔레그램 Bot Token (변경 시)' 275 '';$token.UseSystemPasswordChar=$true;$chat=Field 'Telegram Chat ID' 310 $script:cfg.chat;$extra=Field '추가 사용시간 (분)' 345 $script:cfg.extra;$new=Field '새 비밀번호 (선택)' 380 '';$new.UseSystemPasswordChar=$true
 $clear=New-Object Windows.Forms.CheckBox;$clear.Text='텔레그램 토큰 삭제';$clear.Location=New-Object Drawing.Point(15,415);$clear.Width=220;$f.Controls.Add($clear)
 $save=New-Object Windows.Forms.Button;$save.Text='저장';$save.Location=New-Object Drawing.Point(420,455);$save.DialogResult='OK';$f.Controls.Add($save);$f.AcceptButton=$save
 while($f.ShowDialog() -eq 'OK'){ $g.EndEdit();$valid=$true;$days=@();foreach($r in $g.Rows){$a=[string]$r.Cells[2].Value;$b=[string]$r.Cells[3].Value;if($a -notmatch '^(?:[01]\d|2[0-3]):[0-5]\d$' -or $b -notmatch '^(?:[01]\d|2[0-3]):[0-5]\d$' -or $a -eq $b){$valid=$false};$days+=@([pscustomobject]@{enabled=[bool]$r.Cells[1].Value;start=$a;end=$b})};$n=0;if(!$valid -or ![int]::TryParse($extra.Text,[ref]$n) -or $n -lt 1 -or $n -gt 720 -or ($new.Text -and $new.Text.Length -lt 8)){[Windows.Forms.MessageBox]::Show('시간 형식, 서로 다른 시작/종료 시간, 추가시간 1~720분, 비밀번호 8자 이상을 확인하세요.')|Out-Null;continue};$nextChat = $chat.Text.Trim()
 if ($nextChat -and $nextChat -notmatch '^[1-9][0-9]*$') {
  [Windows.Forms.MessageBox]::Show('개인 채팅의 숫자 ID를 입력해 주세요.') | Out-Null
  continue
 }
 if (($nextChat -ne $script:cfg.chat) -or $clear.Checked -or $token.Text) { ResetRemote }
 $script:cfg.days=$days;$script:cfg.extra=$n;$script:cfg.chat=$nextChat;if($clear.Checked){$script:cfg.token=''}elseif($token.Text){$script:cfg.token=ConvertFrom-SecureString (ConvertTo-SecureString $token.Text.Trim() -AsPlainText -Force)};if (!$script:cfg.token -or !$script:cfg.chat) { $script:cfg.remote = $false }
 if($new.Text){NewPassword $new.Text};Save;break};$f.Dispose()
}
$script:updateJob = $null
$script:nextUpdateCheck = (Get-Date).AddMinutes(1)
$script:updateReady = $false
$script:checkNow = $false
$script:runningPath = $PSCommandPath
$script:installPath = Join-Path $root 'Guard.ps1'

function ShowUpdateSettings {
 if ($script:runningPath -ne $script:installPath) {
  [Windows.Forms.MessageBox]::Show('자동 업데이트를 사용하려면 Install.bat으로 TimeBuddy를 설치해 주세요.') | Out-Null
  return
 }
 $answer = [Windows.Forms.MessageBox]::Show(
  '매일 새 버전을 확인하고 다음 실행 때 적용할까요? 예를 선택하면 지금도 확인합니다.',
  'TimeBuddy 업데이트', 'YesNoCancel', 'Question')
 if ($answer -eq 'Cancel') { return }
 $script:cfg.autoUpdate = $answer -eq 'Yes'
 Save
 if ($script:cfg.autoUpdate) {
  $script:nextUpdateCheck = Get-Date
  $script:checkNow = $true
 }
}

function PollUpdate {
 if ($script:runningPath -ne $script:installPath -or $script:updateReady) { return }
 if ($script:updateJob -and $script:updateJob.State -in 'Completed','Failed','Stopped') {
  $result = Receive-Job $script:updateJob -ErrorAction SilentlyContinue
  Remove-Job $script:updateJob -Force -ErrorAction SilentlyContinue
  $script:updateJob = $null
  $candidate = $script:installPath + '.download'
  try {
   if ($script:cfg.autoUpdate -and $result -eq 'ready') {
    [IO.File]::Replace($candidate, $script:installPath, ($script:installPath + '.previous'))
    $script:updateReady = $true
    $tray.ShowBalloonTip(5000, 'TimeBuddy 업데이트', '다음 실행 때 새 버전이 적용돼요.', 'Info')
   } elseif ($script:cfg.autoUpdate -and $script:checkNow) {
    $message = if ($result -eq 'current') { '현재 버전이 최신이에요.' } else { '지금은 새 버전을 확인할 수 없어요.' }
    $tray.ShowBalloonTip(5000, 'TimeBuddy 업데이트', $message, 'Info')
   }
  } catch { LogError 'update-install' } finally {
   $script:checkNow = $false
   if ([IO.File]::Exists($candidate)) { [IO.File]::Delete($candidate) }
  }
 }
 if (!$script:cfg.autoUpdate -or $script:updateJob -or $script:updateReady -or (Get-Date) -lt $script:nextUpdateCheck) { return }
 $script:nextUpdateCheck = (Get-Date).AddDays(1)
 $script:updateJob = Start-Job -ArgumentList ([string]$script:version), ($script:installPath + '.download') -ScriptBlock {
  param($currentVersion, $candidate)
  try {
   [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
   $headers = @{ 'User-Agent' = 'TimeBuddy'; Accept = 'application/vnd.github+json' }
   $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/mycodehive/TimeBuddy/releases/latest' -Headers $headers -TimeoutSec 15 -ErrorAction Stop
   if ($release.draft -or $release.prerelease -or $release.tag_name -cnotmatch '^v([0-9]+\.[0-9]+\.[0-9]+)$') { return 'unavailable' }
   $updatedVersion = [version]$Matches[1]
   if ($updatedVersion -le [version]$currentVersion) { return 'current' }
   $assets = @($release.assets | Where-Object { $_.name -ceq 'Guard.ps1' })
   if ($assets.Count -ne 1) { return 'unavailable' }
   $asset = $assets[0]
   $url = 'https://github.com/mycodehive/TimeBuddy/releases/download/{0}/Guard.ps1' -f $release.tag_name
   if ($asset.browser_download_url -cne $url -or $asset.digest -notmatch '^sha256:[a-fA-F0-9]{64}$' -or
       $asset.size -lt 1 -or $asset.size -gt 1048576) { return 'unavailable' }
   Invoke-WebRequest -UseBasicParsing -Uri $url -Headers @{ 'User-Agent' = 'TimeBuddy' } -OutFile $candidate -TimeoutSec 30 -ErrorAction Stop
   if ((Get-Item -LiteralPath $candidate).Length -ne $asset.size -or
       (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash -ine $asset.digest.Substring(7)) { return 'unavailable' }
   $tokens = $null
   $errors = $null
   $null = [Management.Automation.Language.Parser]::ParseFile($candidate, [ref]$tokens, [ref]$errors)
   if ($errors) { return 'unavailable' }
   $declaredVersion = '\$script:version\s*=\s*\[version\]''{0}''' -f [regex]::Escape([string]$updatedVersion)
   if ((Get-Content -LiteralPath $candidate -Raw) -notmatch $declaredVersion) { return 'unavailable' }
   'ready'
  } catch { 'unavailable' }
 }
}
$tray=New-Object Windows.Forms.NotifyIcon;$tray.Icon=[Drawing.SystemIcons]::Shield;$tray.Text="TimeBuddy $script:version";$tray.Visible=$true;$menu=New-Object Windows.Forms.ContextMenuStrip
$null=$menu.Items.Add('부모 설정',$null,{if(Verify (Password '부모 비밀번호')){Settings}})
 $null=$menu.Items.Add('고급 사용 관리',$null,{if(Verify (Password '부모 비밀번호')){RemoteSettings}})
$null=$menu.Items.Add('나의 시간 기록',$null,{ShowUsage})
$null=$menu.Items.Add('텔레그램 테스트',$null,{if(Verify (Password '부모 비밀번호')){Telegram 'TimeBuddy 테스트 알림'}})
$null = $menu.Items.Add('업데이트 설정', $null, {
 if (Verify (Password '부모 비밀번호')) { ShowUpdateSettings }
})
$null=$menu.Items.Add('잠금화면 테스트 (10초)', $null, {
 if (Verify (Password '부모 비밀번호')) {
  $script:previewUntil=(Get-Date).AddSeconds(10)
  try { LockScreens } catch {
   $script:previewUntil=[datetime]::MinValue
   HideLocks
   LogError ('lock-preview: ' + $_.Exception.GetType().Name + ' line ' + $_.InvocationInfo.ScriptLineNumber)
   [Windows.Forms.MessageBox]::Show('잠금화면 표시 실패. timebuddy.log를 확인하세요.','TimeBuddy') | Out-Null
  }
 }
})
$null=$menu.Items.Add('프로그램 삭제 안내', $null, {
 if (Verify (Password '부모 비밀번호')) {
  [Windows.Forms.MessageBox]::Show('먼저 프로그램 종료 메뉴에서 종료하고 Windows 설정 > 앱 > 설치된 앱 > TimeBuddy > 제거를 선택하세요.','TimeBuddy') | Out-Null
 }
})
$null=$menu.Items.Add('프로그램 종료',$null,{if(Verify (Password '부모 비밀번호')){HideLocks;$timer.Stop();$tray.Visible=$false;[Windows.Forms.Application]::ExitThread()}});$tray.ContextMenuStrip=$menu
if($script:first){Settings};Telegram ('컴퓨터 사용 시작: '+$env:COMPUTERNAME+' / '+(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
$timer=New-Object Windows.Forms.Timer;$timer.Interval=1000
$script:lastTick=Get-Date;$script:lastSave=Get-Date;$script:wasAllowed=$false
function CloseWarning {
 if ($script:warning) {
  $script:warning.Dispose()
  $script:warning = $null
 }
}

$timer.Add_Tick({
 if ($script:inTick) { return }
 $script:inTick = $true
 try {
  $now = Get-Date
  $last = $script:lastTick
  $delta = ($now - $last).TotalSeconds
  $script:lastTick = $now
  if ($script:wasAllowed -and $delta -gt 0 -and $delta -le 5) {
   if ($last.Date -ne $now.Date) {
    $beforeMidnight = ($now.Date - $last).TotalSeconds
    $script:usage[$last.ToString('yyyy-MM-dd')] = (Used $last) + $beforeMidnight
    $delta -= $beforeMidnight
   }
   $script:usage[$now.ToString('yyyy-MM-dd')] = (Used $now) + $delta
  }
  $end = AllowedEnd $now
  $script:wasAllowed = $end -gt $now
  if (!$script:wasAllowed -or $now -lt $script:previewUntil) {
   $script:warned = ''
   CloseWarning
   LockScreens
  } else {
   if ($script:locks.Count) { HideLocks }
   if (($end - $now).TotalMinutes -gt 5) {
    $script:warned = ''
    CloseWarning
   } elseif (!$script:warned) {
    $script:warned = 'yes'
    $warning = New-Object Windows.Forms.Form
    $warning.Text = 'TimeBuddy · 시간 약속'
    $warning.ClientSize = New-Object Drawing.Size(380, 110)
    $warning.StartPosition = 'CenterScreen'
    $warning.TopMost = $true
    $label = NewBuddyLabel ("이제 곧 쉬어갈 시간이에요!`n{0}까지 작업을 저장해 주세요." -f $end.ToString('HH:mm')) 13 85
    $label.Dock = 'Fill'
    $warning.Controls.Add($label)
    $script:warning = $warning
    $warning.Show()
   }
  }
 } catch { LogError ('timer: ' + $_.Exception.GetType().Name + ' line ' + $_.InvocationInfo.ScriptLineNumber) } finally {
  try {
   if (((Get-Date) - $script:lastSave).TotalSeconds -ge 10) {
    $script:lastSave = Get-Date
    try { SaveUsage } catch { LogError 'usage-write' }
   }
   try { PollRemote } catch { LogError 'telegram' }
   try { PollUpdate } catch { LogError 'update' }
  } finally { $script:inTick = $false }
 }
})
try { if ((AllowedEnd (Get-Date)) -le (Get-Date)) { LockScreens } } catch { LogError ('initial-lock: ' + $_.Exception.GetType().Name + ' line ' + $_.InvocationInfo.ScriptLineNumber) }
$timer.Start()
try { [Windows.Forms.Application]::Run() } finally {
 try { SaveUsage } catch { LogError 'usage-write' }
 foreach ($job in @($script:remoteJob, $script:updateJob) + @($script:sendJobs)) {
  if ($job) { Remove-Job $job -Force -ErrorAction SilentlyContinue }
 }
 $timer.Dispose()
 $tray.Dispose()
 $menu.Dispose()
 $mutex.ReleaseMutex()
 $mutex.Dispose()
}
