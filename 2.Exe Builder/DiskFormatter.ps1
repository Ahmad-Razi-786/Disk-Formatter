$global:LogFile = Join-Path $env:TEMP 'DiskFormatter_log.txt'
function Log($m) { try { Add-Content -Path $global:LogFile -Value ('[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $m) -Encoding ASCII } catch { } }
try { Set-Content -Path $global:LogFile -Value ('DiskFormatter v3.5 started ' + (Get-Date)) -Encoding ASCII } catch { }
trap {
    Log ('FATAL: ' + ($_ | Out-String))
    try {
        Add-Type -AssemblyName PresentationFramework
        [void][Windows.MessageBox]::Show(('Disk Formatter had a problem:' + "`n`n" + $_.Exception.Message + "`n`nLog file: " + $global:LogFile), 'Disk Formatter')
    } catch { }
    break
}
try {
    Add-Type -Namespace Win32 -Name DpiAware -MemberDefinition '[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
    [void][Win32.DpiAware]::SetProcessDPIAware()
} catch { }
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase

# ------------------------------------------------------------ helpers
$bc = New-Object Windows.Media.BrushConverter
function B($c) { $bc.ConvertFromString($c) }
function Col($c) { [Windows.Media.ColorConverter]::ConvertFromString($c) }
function Th($l, $t = $l, $r = $l, $b = $l) { New-Object Windows.Thickness($l, $t, $r, $b) }
function CR($r) { New-Object Windows.CornerRadius($r) }
function AddTo($p, $c) { [void]$p.Children.Add($c) }
function Grad($c1, $c2) {
    $g = New-Object Windows.Media.LinearGradientBrush
    $g.StartPoint = New-Object Windows.Point(0, 0)
    $g.EndPoint = New-Object Windows.Point(1, 1)
    [void]$g.GradientStops.Add((New-Object Windows.Media.GradientStop((Col $c1), 0)))
    [void]$g.GradientStops.Add((New-Object Windows.Media.GradientStop((Col $c2), 1)))
    $g
}
function Glow($color, $blur = 30, $op = 0.5) {
    $e = New-Object Windows.Media.Effects.DropShadowEffect
    $e.Color = (Col $color); $e.BlurRadius = $blur; $e.ShadowDepth = 0; $e.Opacity = $op
    $e
}
function Anim($from, $to, $ms) {
    $a = New-Object Windows.Media.Animation.DoubleAnimation
    if ($from -ne $null) { $a.From = [double]$from }
    $a.To = [double]$to
    $a.Duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds($ms))
    $a
}
function Forever($a) { $a.RepeatBehavior = [Windows.Media.Animation.RepeatBehavior]::Forever; $a }
function Tb($text, $size = 20, $color = '#FFFFFF', $weight = 'Normal') {
    $t = New-Object Windows.Controls.TextBlock
    $t.Text = $text; $t.FontSize = $size; $t.Foreground = (B $color)
    $t.FontWeight = [Windows.FontWeights]::$weight
    $t.TextWrapping = 'Wrap'
    $t
}
function Fmt($b) {
    if ($b -ge 1TB) { '{0:N2} TB' -f ($b / 1TB) }
    elseif ($b -ge 1GB) { '{0:N1} GB' -f ($b / 1GB) }
    else { '{0:N0} MB' -f ($b / 1MB) }
}
function Pulse($el, $from, $to, $ms) {
    $a = Anim $from $to $ms
    $a.AutoReverse = $true
    [void](Forever $a)
    $el.BeginAnimation([Windows.UIElement]::OpacityProperty, $a)
}

# symbols (kept as codes so this file stays plain ASCII)
$sDisk = [char]::ConvertFromUtf32(0x1F4BD); $sUsb = [char]::ConvertFromUtf32(0x1F50C)
$sSave = [char]::ConvertFromUtf32(0x1F4BE); $sPart = [char]::ConvertFromUtf32(0x1F9E9)
$sLetter = [char]::ConvertFromUtf32(0x1F524)
$sDot = [char]0x2022; $sDash = [char]0x2014; $sCheck = [char]0x2713; $sRefresh = [char]0x21BB; $sWarn = [char]0x26A0

# ------------------------------------------------------------ window
$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Disk Formatter" WindowStartupLocation="Manual" WindowStyle="None" ResizeMode="NoResize" BorderBrush="#4A5A99" BorderThickness="1"
        FontFamily="Segoe UI" UseLayoutRounding="True" TextOptions.TextFormattingMode="Ideal">
  <Window.Background>
    <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
      <GradientStop Color="#070B1F" Offset="0"/>
      <GradientStop Color="#141040" Offset="0.55"/>
      <GradientStop Color="#2A0F3F" Offset="1"/>
    </LinearGradientBrush>
  </Window.Background>
  <Viewbox Stretch="Uniform">
    <Grid Width="720" Height="660" ClipToBounds="True">
      <Canvas>
        <Ellipse Name="O1" Width="520" Height="520" Canvas.Left="-120" Canvas.Top="-100">
          <Ellipse.Fill><RadialGradientBrush><GradientStop Color="#775B8CFF" Offset="0"/><GradientStop Color="#005B8CFF" Offset="1"/></RadialGradientBrush></Ellipse.Fill>
          <Ellipse.Effect><BlurEffect Radius="60"/></Ellipse.Effect>
        </Ellipse>
        <Ellipse Name="O2" Width="560" Height="560" Canvas.Left="420" Canvas.Top="300">
          <Ellipse.Fill><RadialGradientBrush><GradientStop Color="#77B14CFF" Offset="0"/><GradientStop Color="#00B14CFF" Offset="1"/></RadialGradientBrush></Ellipse.Fill>
          <Ellipse.Effect><BlurEffect Radius="60"/></Ellipse.Effect>
        </Ellipse>
        <Ellipse Name="O3" Width="420" Height="420" Canvas.Left="200" Canvas.Top="-180">
          <Ellipse.Fill><RadialGradientBrush><GradientStop Color="#5519E3C2" Offset="0"/><GradientStop Color="#0019E3C2" Offset="1"/></RadialGradientBrush></Ellipse.Fill>
          <Ellipse.Effect><BlurEffect Radius="60"/></Ellipse.Effect>
        </Ellipse>
      </Canvas>
      <Grid>
        <Grid.RowDefinitions>
          <RowDefinition Height="172"/>
          <RowDefinition Height="*"/>
          <RowDefinition Height="44"/>
        </Grid.RowDefinitions>
        <StackPanel Name="LogoPanel" Background="Transparent" Orientation="Horizontal" Margin="24,14,0,0" VerticalAlignment="Top" HorizontalAlignment="Left">
          <Image Name="Logo" Width="56" Height="56" Margin="0,0,14,0" VerticalAlignment="Center"/>
          <StackPanel>
            <TextBlock Text="DISK FORMATTER" FontSize="32" FontWeight="Bold">
              <TextBlock.Foreground>
                <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                  <GradientStop Color="#7FA2FF" Offset="0"/><GradientStop Color="#FF7AD9" Offset="1"/>
                </LinearGradientBrush>
              </TextBlock.Foreground>
            </TextBlock>
            <TextBlock Text="Powered by DiskPart  |  v3.5" FontSize="22" Foreground="#A3AEDB"/>
          </StackPanel>
        </StackPanel>
        <StackPanel Name="Dots" Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Top" Margin="0,92,0,0"/>
        <Border Name="MinBtn" Width="44" Height="44" CornerRadius="22" Background="#22FFFFFF" Cursor="Hand"
                HorizontalAlignment="Right" VerticalAlignment="Top" Margin="0,14,74,0">
          <TextBlock Text="&#x2014;" FontSize="20" Foreground="White" HorizontalAlignment="Center" VerticalAlignment="Center"/>
        </Border>
        <Border Name="CloseBtn" Width="44" Height="44" CornerRadius="22" Background="#22FFFFFF" Cursor="Hand"
                HorizontalAlignment="Right" VerticalAlignment="Top" Margin="0,14,20,0">
          <TextBlock Text="&#x2715;" FontSize="22" Foreground="White" HorizontalAlignment="Center" VerticalAlignment="Center"/>
        </Border>
        <Grid Name="Stage" Grid.Row="1"/>
        <TextBlock Name="Footer" Grid.Row="2" Text="Formatting erases data permanently."
                   Foreground="#AEB9E3" FontSize="20" TextWrapping="Wrap" TextAlignment="Center" Margin="20,0" HorizontalAlignment="Center" VerticalAlignment="Center"/>
      </Grid>
    </Grid>
  </Viewbox>
</Window>
'@
$win = [Windows.Markup.XamlReader]::Parse($xaml)
$Stage = $win.FindName('Stage')
$Dots = $win.FindName('Dots')
$CloseBtn = $win.FindName('CloseBtn')
$Footer = $win.FindName('Footer')

# ---- logo
$logoB64 = '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'
try {
    $bytes = [Convert]::FromBase64String($logoB64)
    $ms = New-Object IO.MemoryStream(, $bytes)
    $bmp = New-Object Windows.Media.Imaging.BitmapImage
    $bmp.BeginInit(); $bmp.CacheOption = 'OnLoad'; $bmp.StreamSource = $ms; $bmp.EndInit(); $bmp.Freeze()
    $logoEl = $win.FindName('Logo'); $logoEl.Source = $bmp
    $logoEl.Effect = New-Object Windows.Media.Effects.DropShadowEffect -Property @{ Color = [Windows.Media.ColorConverter]::ConvertFromString('#8B5CFF'); BlurRadius = 30; ShadowDepth = 0; Opacity = 0.8 }
    $win.Icon = $bmp
} catch { }

# ---- floating background orbs
function Float($el, $prop, $from, $to, $sec) {
    $a = Anim $from $to ($sec * 1000)
    $a.AutoReverse = $true
    $a.EasingFunction = New-Object Windows.Media.Animation.SineEase
    [void](Forever $a)
    $el.BeginAnimation($prop, $a)
}
$L = [Windows.Controls.Canvas]::LeftProperty; $T = [Windows.Controls.Canvas]::TopProperty
Float $win.FindName('O1') $L -120 300 17;  Float $win.FindName('O1') $T -100 150 13
Float $win.FindName('O2') $L 420 100 15;  Float $win.FindName('O2') $T 300 60 19
Float $win.FindName('O3') $L 200 500 21;  Float $win.FindName('O3') $T -180 -40 16

# ---- close button
$CloseBtn.Add_MouseEnter({ $this.Background = (B '#CCFF4D6D') })
$CloseBtn.Add_MouseLeave({ $this.Background = (B '#22FFFFFF') })
$CloseBtn.Add_MouseLeftButtonUp({ $win.Close() })
$MinBtn = $win.FindName('MinBtn')
$MinBtn.Add_MouseEnter({ $this.Background = (B '#44FFFFFF') }); $MinBtn.Add_MouseLeave({ $this.Background = (B '#22FFFFFF') })
$MinBtn.Add_MouseLeftButtonUp({ $win.WindowState = 'Minimized' })

# fixed size and position: top-left corner of the screen, about 32% of its width and 52% of its height
$wa = [Windows.SystemParameters]::WorkArea
$ww = [math]::Round($wa.Width * 0.32); $wh = [math]::Round($wa.Height * 0.52)
if ($ww -lt 480) { $ww = 480 }
if ($wh -lt 440) { $wh = 440 }
$win.Width = $ww; $win.Height = $wh
$win.Left = $wa.Left; $win.Top = $wa.Top

# ------------------------------------------------------------ UI building blocks
function Set-Page($el) {
    $Stage.Children.Clear()
    $el.Opacity = 0
    $tt = New-Object Windows.Media.TranslateTransform(0, 50)
    $el.RenderTransform = $tt
    [void]$Stage.Children.Add($el)
    $el.BeginAnimation([Windows.UIElement]::OpacityProperty, (Anim 0 1 450))
    $b = Anim 50 0 550
    $b.EasingFunction = New-Object Windows.Media.Animation.CubicEase
    $tt.BeginAnimation([Windows.Media.TranslateTransform]::YProperty, $b)
}

function Page-Root($title, $sub) {
    $p = New-Object Windows.Controls.StackPanel
    $p.HorizontalAlignment = 'Center'; $p.VerticalAlignment = 'Center'
    $h = Tb $title 38 '#FFFFFF' 'Bold'; $h.HorizontalAlignment = 'Center'; $h.TextAlignment = 'Center'; $h.MaxWidth = 680
    $s = Tb $sub 24 '#C4CEF2'; $s.HorizontalAlignment = 'Center'; $s.TextAlignment = 'Center'
    $s.Margin = (Th 0 2 0 10); $s.MaxWidth = 670
    AddTo $p $h; AddTo $p $s
    $p
}

function New-Card($icon, $title, $sub, $badge, $badgeColor, $enabled, $action, $arg = $null) {
    $c = New-Object Windows.Controls.Border
    $c.Width = 680; $c.MinHeight = 92; $c.Margin = (Th 5); $c.CornerRadius = (CR 18); $c.Padding = (Th 16 10 16 10)
    $c.Background = (B '#D0141B3D'); $c.BorderBrush = (B '#3B4A8F'); $c.BorderThickness = (Th 1.5)
    $c.RenderTransformOrigin = New-Object Windows.Point(0.5, 0.5)
    $c.RenderTransform = New-Object Windows.Media.ScaleTransform(1, 1)
    $g = New-Object Windows.Controls.Grid
    $cd1 = New-Object Windows.Controls.ColumnDefinition; $cd1.Width = [Windows.GridLength]::Auto
    $cd2 = New-Object Windows.Controls.ColumnDefinition; $cd2.Width = [Windows.GridLength]::new(1, [Windows.GridUnitType]::Star)
    $cd3 = New-Object Windows.Controls.ColumnDefinition; $cd3.Width = [Windows.GridLength]::Auto
    [void]$g.ColumnDefinitions.Add($cd1); [void]$g.ColumnDefinitions.Add($cd2); [void]$g.ColumnDefinitions.Add($cd3)
    $ic = Tb $icon 44; $ic.Margin = (Th 0 0 14 0); $ic.VerticalAlignment = 'Center'
    [Windows.Controls.Grid]::SetColumn($ic, 0)
    $mid = New-Object Windows.Controls.StackPanel; $mid.VerticalAlignment = 'Center'
    [Windows.Controls.Grid]::SetColumn($mid, 1)
    $tt = Tb $title 28 '#FFFFFF' 'SemiBold'
    $tt.TextWrapping = 'NoWrap'; $tt.TextTrimming = 'CharacterEllipsis'
    $st = Tb $sub 22 '#C4CEF2'; $st.Margin = (Th 0 2 0 0)
    AddTo $mid $tt; AddTo $mid $st
    $bd = New-Object Windows.Controls.Border
    $bd.CornerRadius = (CR 10); $bd.Padding = (Th 12 4 12 4); $bd.VerticalAlignment = 'Center'; $bd.Margin = (Th 12 0 0 0)
    $bd.Background = (B ('#33' + $badgeColor.Substring(1)))
    $bd.Child = (Tb $badge 18 $badgeColor 'Bold')
    [Windows.Controls.Grid]::SetColumn($bd, 2)
    AddTo $g $ic; AddTo $g $mid; AddTo $g $bd
    $c.Child = $g
    if ($enabled) {
        $c.Cursor = [Windows.Input.Cursors]::Hand
        $c.Tag = @{ A = $action; V = $arg }
        $c.Add_MouseEnter({
            $s = $this.RenderTransform
            $s.BeginAnimation([Windows.Media.ScaleTransform]::ScaleXProperty, (Anim $null 1.03 160))
            $s.BeginAnimation([Windows.Media.ScaleTransform]::ScaleYProperty, (Anim $null 1.03 160))
            $this.BorderBrush = (B '#7FA2FF')
            $this.Effect = (Glow '#5B8CFF' 30 0.6)
        })
        $c.Add_MouseLeave({
            $s = $this.RenderTransform
            $s.BeginAnimation([Windows.Media.ScaleTransform]::ScaleXProperty, (Anim $null 1 160))
            $s.BeginAnimation([Windows.Media.ScaleTransform]::ScaleYProperty, (Anim $null 1 160))
            $this.BorderBrush = (B '#3B4A8F')
            $this.Effect = $null
        })
        $c.Add_MouseLeftButtonUp({ $t = $this.Tag; & $t.A $t.V })
    } else {
        $c.Opacity = 0.75
    }
    $c
}

function New-Btn($text, $kind, $onClick) {
    $b = New-Object Windows.Controls.Border
    $b.CornerRadius = (CR 16); $b.Padding = (Th 22 10 22 10); $b.Margin = (Th 6)
    $b.Cursor = [Windows.Input.Cursors]::Hand
    $b.RenderTransformOrigin = New-Object Windows.Point(0.5, 0.5)
    $b.RenderTransform = New-Object Windows.Media.ScaleTransform(1, 1)
    switch ($kind) {
        'primary' { $b.Background = (Grad '#4F7CFF' '#9B5CFF') }
        'danger'  { $b.Background = (Grad '#FF4D6D' '#FF8A3D') }
        default   { $b.Background = (B '#22FFFFFF'); $b.BorderBrush = (B '#4A5A99'); $b.BorderThickness = (Th 1.5) }
    }
    $b.Child = (Tb $text 24 '#FFFFFF' 'SemiBold')
    $b.Tag = $onClick
    $b.Add_MouseEnter({
        $s = $this.RenderTransform
        $s.BeginAnimation([Windows.Media.ScaleTransform]::ScaleXProperty, (Anim $null 1.06 140))
        $s.BeginAnimation([Windows.Media.ScaleTransform]::ScaleYProperty, (Anim $null 1.06 140))
    })
    $b.Add_MouseLeave({
        $s = $this.RenderTransform
        $s.BeginAnimation([Windows.Media.ScaleTransform]::ScaleXProperty, (Anim $null 1 140))
        $s.BeginAnimation([Windows.Media.ScaleTransform]::ScaleYProperty, (Anim $null 1 140))
    })
    $b.Add_MouseLeftButtonUp({ & $this.Tag })
    $b
}

function Btn-Row($buttons) {
    $r = New-Object Windows.Controls.WrapPanel
    $r.MaxWidth = 700; $r.Orientation = 'Horizontal'; $r.HorizontalAlignment = 'Center'; $r.Margin = (Th 0 12 0 0)
    foreach ($b in $buttons) { AddTo $r $b }
    $r
}

function Card-Wrap($cards) {
    $w = New-Object Windows.Controls.WrapPanel
    $w.HorizontalAlignment = 'Center'; $w.MaxWidth = 700
    foreach ($c in $cards) { AddTo $w $c }
    $w
}

# ---- progress dots across the top
$labels = 'Disk', 'Confirm', 'Partition', 'Layout', 'Letter', 'Done'
$global:dotC = @(); $global:dotT = @(); $global:dotL = @()
for ($k = 0; $k -lt $labels.Count; $k++) {
    $item = New-Object Windows.Controls.StackPanel; $item.Margin = (Th 6 0 6 0)
    $ci = New-Object Windows.Controls.Border; $ci.Width = 44; $ci.Height = 44; $ci.CornerRadius = (CR 22); $ci.HorizontalAlignment = 'Center'
    $tx = Tb ([string]($k + 1)) 22 '#FFFFFF' 'Bold'; $tx.HorizontalAlignment = 'Center'; $tx.VerticalAlignment = 'Center'
    $ci.Child = $tx
    $lb = Tb $labels[$k] 22 '#B4BFEA'; $lb.HorizontalAlignment = 'Center'; $lb.Margin = (Th 0 4 0 0)
    AddTo $item $ci; AddTo $item $lb; AddTo $Dots $item
    $global:dotC += $ci; $global:dotT += $tx; $global:dotL += $lb
}
function Set-Dots($i) {
    for ($k = 0; $k -lt $global:dotC.Count; $k++) {
        $ci = $global:dotC[$k]; $tx = $global:dotT[$k]; $lb = $global:dotL[$k]
        if ($k -lt $i) {
            $ci.Background = (Grad '#4F7CFF' '#2EC4FF'); $ci.Effect = $null; $tx.Text = [string]$sCheck; $lb.Foreground = (B '#C4CEF2')
        } elseif ($k -eq $i) {
            $ci.Background = (Grad '#8B5CFF' '#FF4FD8'); $ci.Effect = (Glow '#B14CFF' 36 0.9); $tx.Text = [string]($k + 1); $lb.Foreground = (B '#FFFFFF')
            Pulse $ci 0.7 1 800
        } else {
            $ci.BeginAnimation([Windows.UIElement]::OpacityProperty, $null); $ci.Opacity = 1
            $ci.Background = (B '#22FFFFFF'); $ci.Effect = $null; $tx.Text = [string]($k + 1); $lb.Foreground = (B '#9AA7D6')
        }
        if ($k -ne $i) { $ci.BeginAnimation([Windows.UIElement]::OpacityProperty, $null); $ci.Opacity = 1 }
    }
}

# ---- progress page (spinner + real progress bar)
function Set-Progress($pct, $msg) {
    if ($pct -gt 100) { $pct = 100 }
    $global:pctNow = $pct
    if ($global:pctT) { $global:pctT.Text = ('{0}%' -f [int][math]::Floor($pct)) }
    if ($global:fill) { $global:fill.BeginAnimation([Windows.FrameworkElement]::WidthProperty, (Anim $null (5.6 * $pct) 350)) }
    if ($msg -and $global:statT) { $global:statT.Text = $msg }
}
function Show-Working($title, $status) {
    $p = New-Object Windows.Controls.StackPanel
    $p.HorizontalAlignment = 'Center'; $p.VerticalAlignment = 'Center'
    $g = New-Object Windows.Controls.Grid; $g.Width = 130; $g.Height = 130; $g.Margin = (Th 0 0 0 8)
    $track0 = New-Object Windows.Shapes.Ellipse
    $track0.Width = 118; $track0.Height = 118; $track0.StrokeThickness = 8; $track0.Stroke = (B '#22FFFFFF')
    AddTo $g $track0
    $r1 = New-Object Windows.Shapes.Ellipse
    $r1.Width = 118; $r1.Height = 118; $r1.StrokeThickness = 8; $r1.Stroke = (Grad '#4F7CFF' '#2EC4FF')
    $r1.StrokeDashCap = 'Round'
    $r1.StrokeDashArray = New-Object Windows.Media.DoubleCollection
    $r1.StrokeDashArray.Add(10); $r1.StrokeDashArray.Add(36)
    $r1.RenderTransformOrigin = New-Object Windows.Point(0.5, 0.5)
    $rt1 = New-Object Windows.Media.RotateTransform(0); $r1.RenderTransform = $rt1
    $rt1.BeginAnimation([Windows.Media.RotateTransform]::AngleProperty, (Forever (Anim 0 360 1300)))
    AddTo $g $r1
    $r2 = New-Object Windows.Shapes.Ellipse
    $r2.Width = 86; $r2.Height = 86; $r2.StrokeThickness = 6; $r2.Stroke = (Grad '#FF4FD8' '#8B5CFF')
    $r2.StrokeDashCap = 'Round'
    $r2.StrokeDashArray = New-Object Windows.Media.DoubleCollection
    $r2.StrokeDashArray.Add(7); $r2.StrokeDashArray.Add(14)
    $r2.RenderTransformOrigin = New-Object Windows.Point(0.5, 0.5)
    $rt2 = New-Object Windows.Media.RotateTransform(0); $r2.RenderTransform = $rt2
    $rt2.BeginAnimation([Windows.Media.RotateTransform]::AngleProperty, (Forever (Anim 360 0 1900)))
    AddTo $g $r2
    $ic = Tb $sSave 34; $ic.HorizontalAlignment = 'Center'; $ic.VerticalAlignment = 'Center'
    Pulse $ic 0.45 1 700
    AddTo $g $ic
    $h = Tb $title 36 '#FFFFFF' 'Bold'; $h.HorizontalAlignment = 'Center'; $h.TextAlignment = 'Center'; $h.MaxWidth = 680
    $pc = Tb '0%' 72 '#FFFFFF' 'Bold'; $pc.HorizontalAlignment = 'Center'; $pc.Margin = (Th 0 2 0 2)
    $pc.Effect = (Glow '#7FA2FF' 30 0.7)
    $trk = New-Object Windows.Controls.Border
    $trk.Width = 560; $trk.Height = 24; $trk.CornerRadius = (CR 12); $trk.Background = (B '#22FFFFFF'); $trk.ClipToBounds = $true
    $fl = New-Object Windows.Controls.Border
    $fl.Width = 0; $fl.Height = 24; $fl.CornerRadius = (CR 12); $fl.HorizontalAlignment = 'Left'
    $fl.Background = (Grad '#4F7CFF' '#FF4FD8'); $fl.Effect = (Glow '#B14CFF' 18 0.9)
    $trk.Child = $fl
    $s = Tb $status 24 '#C4CEF2'; $s.HorizontalAlignment = 'Center'; $s.TextAlignment = 'Center'; $s.Margin = (Th 0 14 0 0); $s.MaxWidth = 640
    $global:pctT = $pc; $global:fill = $fl; $global:statT = $s; $global:pctNow = 0
    AddTo $p $g; AddTo $p $h; AddTo $p $pc; AddTo $p $trk; AddTo $p $s
    Set-Page $p
}

# ---- run DiskPart in the background so the animation keeps playing
function Read-Shared($path) {
    try {
        $fs = [IO.File]::Open($path, 'Open', 'Read', 'ReadWrite')
        $sr = New-Object IO.StreamReader($fs); $t = $sr.ReadToEnd(); $sr.Close(); $t
    } catch { '' }
}
function Run-Dp($lines, $cb) {
    $f = Join-Path $env:TEMP 'dp_gui_script.txt'
    $o = Join-Path $env:TEMP 'dp_gui_out.txt'
    Set-Content -Path $f -Value $lines -Encoding ASCII
    if (Test-Path $o) { Remove-Item $o -Force -ErrorAction SilentlyContinue }
    $global:dpCb = $cb; $global:dpOut = $o
    Log ('DiskPart script: ' + ($lines -join ' | '))
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = $env:ComSpec
    $psi.Arguments = '/c diskpart.exe /s "' + $f + '" > "' + $o + '" 2>&1'
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $global:dpProc = [Diagnostics.Process]::Start($psi)
    $global:dpTimer = New-Object Windows.Threading.DispatcherTimer
    $global:dpTimer.Interval = [TimeSpan]::FromMilliseconds(300)
    $global:dpTimer.Add_Tick({
        if ($global:dpProc.HasExited) {
            $global:dpTimer.Stop()
            $txt = ''
            if (Test-Path $global:dpOut) { $txt = [string](Get-Content $global:dpOut -Raw) }
            Log ('DiskPart output: ' + $txt.Trim())
            & $global:dpCb $txt
        } elseif ($global:dpTick) {
            & $global:dpTick
        }
    })
    $global:dpTimer.Start()
}
# ---- run several DiskPart stages one after another, moving the percent bar
function Run-Pipeline($stages, $done) {
    $global:stg = $stages; $global:stgI = 0; $global:stgDone = $done; $global:canContinue = $false
    Next-Stage
}
function Next-Stage {
    if ($global:stgI -ge $global:stg.Count) {
        $global:dpTick = $null
        Set-Progress 100 'Finished!'
        $tm = New-Object Windows.Threading.DispatcherTimer
        $tm.Interval = [TimeSpan]::FromMilliseconds(900)
        $tm.Add_Tick({ $this.Stop(); & $global:stgDone })
        $tm.Start()
        return
    }
    $s = $global:stg[$global:stgI]
    $global:cur = $s; $global:t0 = Get-Date
    Set-Progress $s.From $s.Label
    $global:dpTick = {
        $s = $global:cur
        $el = ((Get-Date) - $global:t0).TotalSeconds
        $pct = $s.From + ($s.To - $s.From - 1) * (1 - [math]::Exp(-$el / $s.Tau))
        if ($s.Real) {
            $m = [regex]::Matches((Read-Shared $global:dpOut), '(\d+)\s+percent')
            if ($m.Count -gt 0) {
                $r = [int]$m[$m.Count - 1].Groups[1].Value
                $pct = $s.From + ($s.To - $s.From) * $r / 100
            }
        }
        if ($pct -gt $global:pctNow) { Set-Progress $pct $null }
    }
    Run-Dp $s.Lines {
        param($t)
        if ((Has-Err $t) -or ($global:cur.Ok -and ($t -notmatch $global:cur.Ok))) { $global:dpTick = $null; $global:canContinue = (-not (Has-Err $t)); Show-Error $t }
        else { Set-Progress $global:cur.To $null; $global:stgI++; Next-Stage }
    }
}
function Has-Err($t) { $t -match 'encountered an error|Virtual Disk Service error|Access is denied|is not valid|cannot' }

# ------------------------------------------------------------ steps
$global:Quick = $true; $global:Disk = $null; $global:Part = 1; $global:FS = 'NTFS'; $global:ack = $false

function Pick-Disk($d) { $global:Disk = $d; Log ('Selected disk ' + $d.Number); Show-Confirm }
function Pick-Part($n) { $global:Part = $n; Log ('Selected partition ' + $n); Show-Layouts }
function Pick-FS($n) { $global:FS = $n; Log ('Selected file system ' + $n); Show-Mode }
function Stop-AutoClose { if ($global:closeTimer) { $global:closeTimer.Stop() } }
function Continue-Anyway { Show-Working 'Continuing' 'Continuing...'; $global:stgI++; Next-Stage }

# Step 1: choose disk
function Show-Disks {
    Stop-AutoClose
    Set-Dots 0
    $p = Page-Root 'Select a disk' 'Pick the drive to erase. Your system disk is locked.'
    $cards = @()
    $disks = @(Get-Disk -ErrorAction SilentlyContinue | Sort-Object Number)
    foreach ($d in $disks) {
        $sys = ($d.IsSystem -or $d.IsBoot)
        $icon = if ($d.BusType -eq 'USB') { $sUsb } else { $sDisk }
        $name = if ($d.FriendlyName) { $d.FriendlyName } else { 'Unknown disk' }
        $sub = ('{0}  {1}  {2}  {3}  {4}' -f (Fmt $d.Size), $sDot, $d.BusType, $sDot, $d.PartitionStyle)
        $title = ('Disk {0}  {1}  {2}' -f $d.Number, $sDash, $name)
        $dd = $d
        if ($sys) {
            $cards += (New-Card $icon $title $sub 'LOCKED' '#FF6B81' $false $null)
        } else {
            $cards += (New-Card $icon $title $sub 'READY' '#2EE6A6' $true 'Pick-Disk' $dd)
        }
    }
    if ($cards.Count -eq 0) {
        $e = Tb 'No disks were found.' 28 '#FF6B81' 'SemiBold'; $e.HorizontalAlignment = 'Center'
        AddTo $p $e
    } else {
        $sv = New-Object Windows.Controls.ScrollViewer
        $sv.VerticalScrollBarVisibility = 'Auto'; $sv.MaxHeight = 260; $sv.HorizontalAlignment = 'Center'
        $sv.Content = (Card-Wrap $cards)
        AddTo $p $sv
    }
    AddTo $p (Btn-Row @(
        (New-Btn "$sRefresh  Refresh list" 'ghost' { Show-Disks }),
        (New-Btn 'Exit' 'ghost' { $win.Close() })))
    Set-Page $p
}

# Step 2: confirm erase
function Show-Confirm {
    if (-not $global:Disk) { Show-Disks; return }
    Set-Dots 1
    $d = $global:Disk; $global:ack = $false
    $p = New-Object Windows.Controls.StackPanel
    $p.HorizontalAlignment = 'Center'; $p.VerticalAlignment = 'Center'
    $w = Tb $sWarn 56 '#FF6B81'; $w.HorizontalAlignment = 'Center'
    $w.Effect = (Glow '#FF4D6D' 50 0.9)
    Pulse $w 0.4 1 650
    $h = Tb ('ALL DATA on Disk {0} will be ERASED!' -f $d.Number) 36 '#FFFFFF' 'Bold'; $h.HorizontalAlignment = 'Center'; $h.TextAlignment = 'Center'; $h.MaxWidth = 680
    $nm = if ($d.FriendlyName) { $d.FriendlyName } else { 'Unknown disk' }
    $s = Tb ('{0}  {1}  {2}' -f $nm, $sDot, (Fmt $d.Size)) 24 '#C4CEF2'; $s.HorizontalAlignment = 'Center'; $s.Margin = (Th 0 6 0 14)
    AddTo $p $w; AddTo $p $h; AddTo $p $s

    $chk = New-Object Windows.Controls.Border
    $chk.CornerRadius = (CR 16); $chk.Padding = (Th 18 10 18 10); $chk.HorizontalAlignment = 'Center'
    $chk.Background = (B '#22FFFFFF'); $chk.Cursor = [Windows.Input.Cursors]::Hand
    $chkT = Tb ('[  ]  I understand all data on this disk will be deleted.') 22 '#FFFFFF' 'SemiBold'
    $chkT.MaxWidth = 650; $chk.Child = $chkT
    $global:chkT = $chkT
    $chk.Add_MouseLeftButtonUp({
        $global:ack = -not $global:ack
        if ($global:ack) {
            $global:chkT.Text = ('[ ' + [char]0x2713 + ' ]  I understand all data on this disk will be deleted.')
            $global:goBtn.IsEnabled = $true; $global:goBtn.Opacity = 1
        } else {
            $global:chkT.Text = '[  ]  I understand all data on this disk will be deleted.'
            $global:goBtn.IsEnabled = $false; $global:goBtn.Opacity = 0.35
        }
    })
    AddTo $p $chk
    $go = New-Btn 'Erase and continue' 'danger' { Start-Clean }
    $go.IsEnabled = $false; $go.Opacity = 0.35
    $global:goBtn = $go
    AddTo $p (Btn-Row @((New-Btn 'Cancel' 'ghost' { Show-Disks }), $go))
    Set-Page $p
}

# Step 3: clean + create partition
function Start-Clean {
    if (-not $global:Disk) { Show-Error 'No disk was selected. Please go back and pick a disk.'; return }
    $n = $global:Disk.Number
    Show-Working ('Preparing Disk {0}' -f $n) 'Starting...'
    Run-Pipeline @(
        @{ Label = 'Cleaning the disk...'; Ok = 'succeeded in cleaning'; Lines = @("select disk $n", 'clean'); From = 0; To = 70; Tau = 4; Real = $false },
        @{ Label = 'Creating the primary partition...'; Ok = 'succeeded in creating'; Lines = @("select disk $n", 'create partition primary'); From = 70; To = 100; Tau = 2; Real = $false }
    ) { Show-Parts }
}

# Step 4: choose partition
function Show-Parts {
    Set-Dots 2
    $n = $global:Disk.Number
    Update-HostStorageCache -ErrorAction SilentlyContinue
    $parts = @(Get-Partition -DiskNumber $n -ErrorAction SilentlyContinue | Where-Object { $_.Type -ne 'Reserved' })
    $p = Page-Root 'Select a partition' ('Disk {0}: choose the partition to format.' -f $n)
    $cards = @()
    if ($parts.Count -eq 0) {
        $cards += (New-Card $sPart 'Partition 1' 'Primary partition' 'NEW' '#2EE6A6' $true 'Pick-Part' 1)
    } else {
        foreach ($pt in $parts) {
            $pn = $pt.PartitionNumber
            $sub = ('{0}  {1}  {2}' -f (Fmt $pt.Size), $sDot, $pt.Type)
            $cards += (New-Card $sPart ('Partition {0}' -f $pn) $sub 'SELECT' '#2EE6A6' $true 'Pick-Part' $pn)
        }
    }
    AddTo $p (Card-Wrap $cards)
    Set-Page $p
}

# Step 5: choose file system
function Show-Layouts {
    Set-Dots 3
    $n = $global:Disk.Number; $pn = $global:Part
    $sf = Join-Path $env:TEMP 'dp_gui_fs.txt'
    Set-Content -Path $sf -Value @("select disk $n", "select partition $pn", 'filesystems') -Encoding ASCII
    $txt = (& diskpart.exe /s $sf) -join "`n"
    $fmts = @(); $flag = $false
    foreach ($l in ($txt -split "`n")) {
        if ($l -match 'Supported for Formatting') { $flag = $true }
        if ($flag -and $l -match '^\s*Type\s*:\s*(NTFS|exFAT|FAT32)(\s*\(Default\))?') {
            $fmts += [pscustomobject]@{ Name = $Matches[1]; Def = [bool]$Matches[2] }
        }
    }
    if ($fmts.Count -eq 0) {
        $fmts = @([pscustomobject]@{ Name = 'NTFS'; Def = $true }, [pscustomobject]@{ Name = 'exFAT'; Def = $false }, [pscustomobject]@{ Name = 'FAT32'; Def = $false })
    }
    $desc = @{
        'NTFS'  = 'Best for Windows, big files'
        'exFAT' = 'USB drives, Windows + Mac'
        'FAT32' = 'Old devices, 4 GB file limit'
    }
    $p = Page-Root 'Choose a format layout' 'Which file system should the partition use?'
    $cards = @()
    foreach ($f in $fmts) {
        $nm = $f.Name
        $badge = if ($f.Def) { 'DEFAULT' } else { 'AVAILABLE' }
        $bcol = if ($f.Def) { '#FFD166' } else { '#7FA2FF' }
        $cards += (New-Card $sLetter $nm $desc[$nm] $badge $bcol $true 'Pick-FS' $nm)
    }
    AddTo $p (Card-Wrap $cards)
    Set-Page $p
}

# Step 5b: quick or full
function Show-Mode {
    $p = Page-Root 'Quick or full format?' 'Quick takes seconds. Full also scans the disk.'
    $c1 = New-Card $sSave 'Quick format' 'Recommended. Finishes in seconds.' 'RECOMMENDED' '#2EE6A6' $true ({ $global:Quick = $true; Start-Format })
    $c2 = New-Card $sDisk 'Full format' 'Slow, shows live percent.' 'THOROUGH' '#FFD166' $true ({ $global:Quick = $false; Start-Format })
    AddTo $p (Card-Wrap @($c1, $c2))
    Set-Page $p
}

# Step 6: format + set active
function Start-Format {
    $n = $global:Disk.Number; $pn = $global:Part; $fs = $global:FS
    $q = ''; $tau = 300; $real = $true
    if ($global:Quick) { $q = ' quick'; $tau = 3; $real = $false }
    Show-Working ('Formatting as {0}' -f $fs) 'Starting...'
    Run-Pipeline @(
        @{ Label = ('Formatting Partition {0} as {1}...' -f $pn, $fs); Ok = 'successfully formatted'; Lines = @("select disk $n", "select partition $pn", "format fs=$fs$q"); From = 0; To = 90; Tau = $tau; Real = $real },
        @{ Label = 'Marking the partition active...'; Ok = 'marked the current partition as active'; Lines = @("select disk $n", "select partition $pn", 'active'); From = 90; To = 100; Tau = 1; Real = $false }
    ) { Show-Letter }
}

# Step 7: assign letter?
function Show-Letter {
    Set-Dots 4
    $p = Page-Root 'Assign a new drive letter?' 'A letter (like E:) makes it show in File Explorer.'
    $c1 = New-Card $sLetter 'Yes, assign a letter' 'Windows picks the next free letter.' 'RECOMMENDED' '#2EE6A6' $true ({ Start-Assign })
    $c2 = New-Card $sSave 'No, skip this' 'Leave the partition as it is.' 'OPTIONAL' '#7FA2FF' $true ({ Show-Done })
    AddTo $p (Card-Wrap @($c1, $c2))
    Set-Page $p
}
function Start-Assign {
    $n = $global:Disk.Number; $pn = $global:Part
    Show-Working 'Assigning drive letter' 'Starting...'
    Run-Pipeline @(
        @{ Label = 'Assigning a drive letter...'; Lines = @("select disk $n", "select partition $pn", 'assign'); From = 0; To = 100; Tau = 1.5; Real = $false }
    ) { Show-Done }
}

# Step 8: done
function Show-Done {
    Set-Dots 5
    $n = $global:Disk.Number; $pn = $global:Part
    Update-HostStorageCache -ErrorAction SilentlyContinue
    $letter = ''
    $pt = Get-Partition -DiskNumber $n -PartitionNumber $pn -ErrorAction SilentlyContinue
    if ($pt -and $pt.DriveLetter) { $letter = ('  {0}  Drive {1}:' -f $sDot, $pt.DriveLetter) }
    $p = New-Object Windows.Controls.StackPanel
    $p.HorizontalAlignment = 'Center'; $p.VerticalAlignment = 'Center'
    $ring = New-Object Windows.Controls.Border
    $ring.Width = 96; $ring.Height = 96; $ring.CornerRadius = (CR 48); $ring.Background = (Grad '#19E3C2' '#2EE67A')
    $ring.Effect = (Glow '#19E3C2' 60 0.8); $ring.Margin = (Th 0 0 0 14)
    $ring.RenderTransformOrigin = New-Object Windows.Point(0.5, 0.5)
    $sc = New-Object Windows.Media.ScaleTransform(0, 0); $ring.RenderTransform = $sc
    $ck = Tb ([string]$sCheck) 58 '#FFFFFF' 'Bold'; $ck.HorizontalAlignment = 'Center'; $ck.VerticalAlignment = 'Center'
    $ring.Child = $ck
    $be = New-Object Windows.Media.Animation.BackEase; $be.EasingMode = 'EaseOut'; $be.Amplitude = 0.7
    foreach ($prop in @([Windows.Media.ScaleTransform]::ScaleXProperty, [Windows.Media.ScaleTransform]::ScaleYProperty)) {
        $a = Anim 0 1 800; $a.EasingFunction = $be; $a.BeginTime = [TimeSpan]::FromMilliseconds(250)
        $sc.BeginAnimation($prop, $a)
    }
    $vol = $null
    try { $vol = Get-Partition -DiskNumber $n -PartitionNumber $pn -ErrorAction Stop | Get-Volume -ErrorAction Stop } catch { }
    if ($vol -and $vol.FileSystem) {
        $dl = 'no drive letter'
        if ($vol.DriveLetter) { $dl = ('Drive ' + $vol.DriveLetter + ':') }
        $verify = ('Verified on the disk: {0}  {1}  {2}  {3}  {4}' -f $vol.FileSystem, $sDot, (Fmt $vol.Size), $sDot, $dl)
        $vcol = '#2EE6A6'
    } else {
        $verify = 'Could not verify the result. Please check File Explorer.'
        $vcol = '#FFD166'
    }
    Log ('Result: ' + $verify)
    $h = Tb 'All done!' 46 '#FFFFFF' 'Bold'; $h.HorizontalAlignment = 'Center'
    $s = Tb ('Disk {0}  {1}  Partition {2}  {1}  {3}{4}' -f $n, $sDot, $pn, $global:FS, $letter) 26 '#C4CEF2'
    $s.HorizontalAlignment = 'Center'; $s.Margin = (Th 0 6 0 0)
    $vt = Tb $verify 24 $vcol 'SemiBold'; $vt.HorizontalAlignment = 'Center'; $vt.Margin = (Th 0 8 0 0); $vt.MaxWidth = 660; $vt.TextAlignment = 'Center'
    $cl = Tb 'This window will close automatically in 10 seconds.' 22 '#B4BFEA'
    $cl.HorizontalAlignment = 'Center'; $cl.Margin = (Th 0 10 0 0)
    $global:closeTxt = $cl; $global:closeLeft = 10
    Stop-AutoClose
    $global:closeTimer = New-Object Windows.Threading.DispatcherTimer
    $global:closeTimer.Interval = [TimeSpan]::FromSeconds(1)
    $global:closeTimer.Add_Tick({
        $global:closeLeft--
        if ($global:closeLeft -le 0) { $global:closeTimer.Stop(); $win.Close() }
        else { $global:closeTxt.Text = ('This window will close automatically in {0} seconds.' -f $global:closeLeft) }
    })
    $global:closeTimer.Start()
    AddTo $p $ring; AddTo $p $h; AddTo $p $s; AddTo $p $vt; AddTo $p $cl
    AddTo $p (Btn-Row @(
        (New-Btn 'Format another disk' 'primary' { Show-Disks }),
        (New-Btn 'Keep open' 'ghost' { Stop-AutoClose; $global:closeTxt.Text = 'Auto-close cancelled.' }),
        (New-Btn 'Exit' 'ghost' { $win.Close() })))
    Set-Page $p
    Remove-Item (Join-Path $env:TEMP 'dp_gui_script.txt'), (Join-Path $env:TEMP 'dp_gui_out.txt'), (Join-Path $env:TEMP 'dp_gui_fs.txt') -Force -ErrorAction SilentlyContinue
}

# Error page
function Show-Error($t) {
    $t = [string]$t
    Log ('ERROR PAGE: ' + $t.Trim())
    $p = New-Object Windows.Controls.StackPanel
    $p.HorizontalAlignment = 'Center'; $p.VerticalAlignment = 'Center'
    $x = Tb ([string][char]0x2715) 48 '#FF6B81' 'Bold'; $x.HorizontalAlignment = 'Center'; $x.Effect = (Glow '#FF4D6D' 50 0.9)
    $h = Tb 'DiskPart reported a problem' 36 '#FFFFFF' 'Bold'; $h.HorizontalAlignment = 'Center'
    $log = New-Object Windows.Controls.TextBox
    $log.Text = $t.Trim(); $log.IsReadOnly = $true; $log.Width = 660; $log.Height = 110; $log.Margin = (Th 0 12 0 0)
    $log.FontFamily = New-Object Windows.Media.FontFamily('Consolas'); $log.FontSize = 17
    $log.Background = (B '#CC0A0E24'); $log.Foreground = (B '#C9D3FF'); $log.BorderBrush = (B '#3B4A8F')
    $log.Padding = (Th 16); $log.VerticalScrollBarVisibility = 'Auto'
    AddTo $p $x; AddTo $p $h
    if ($global:canContinue) {
        $note = Tb 'No success message from DiskPart. If the drive changed, press Continue anyway.' 21 '#FFD166'
        $note.HorizontalAlignment = 'Center'; $note.TextAlignment = 'Center'; $note.MaxWidth = 660; $note.Margin = (Th 0 14 0 0)
        AddTo $p $note
    }
    AddTo $p $log
    $btns = @((New-Btn 'Back to start' 'primary' { Show-Disks }), (New-Btn 'Open log' 'ghost' { Start-Process notepad.exe $global:LogFile }))
    if ($global:canContinue) { $btns += (New-Btn 'Continue anyway' 'ghost' { Continue-Anyway }) }
    $btns += (New-Btn 'Exit' 'ghost' { $win.Close() })
    AddTo $p (Btn-Row $btns)
    Set-Page $p
}

# ------------------------------------------------------------ go
$global:errSeen = $global:Error.Count
$errTimer = New-Object Windows.Threading.DispatcherTimer
$errTimer.Interval = [TimeSpan]::FromMilliseconds(600)
$errTimer.Add_Tick({
    $c = $global:Error.Count
    if ($c -gt $global:errSeen) {
        $k = $c - $global:errSeen; if ($k -gt 10) { $k = 10 }
        for ($i = 0; $i -lt $k; $i++) { Log ('ERROR: ' + ($global:Error[$i] | Out-String).Trim()) }
        $global:errSeen = $c
        $Footer.Text = 'Internal note saved to the log file.'
        $Footer.Foreground = (B '#FFB86B')
    }
})
$errTimer.Start()
$win.Add_Loaded({ Log 'Window loaded'; Show-Disks })
[void]$win.ShowDialog()
Log 'Window closed'
