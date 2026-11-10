# Mullvad Otomatik IP Degistirici & Halkbank Kontrolcusu
$TargetUrl = "https://sube.halkbank.com.tr/InternetBankingHost/HostLogin?CustomerType=Retail"
$SuccessWaitMinutes = 20
$CheckIntervalSeconds = 30
$OnlyFastEurope = $true

$MullvadExe = "C:\Program Files\Mullvad VPN\resources\mullvad.exe"
if (-not (Test-Path $MullvadExe)) {
    Write-Host "[HATA] Mullvad CLI bulunamadi: $MullvadExe" -ForegroundColor Red
    Pause
    exit 1
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "   MULLVAD HALKBANK KONTROLLU IP DEGISTIRICI        " -ForegroundColor Yellow
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "Hedef URL: $TargetUrl" -ForegroundColor Gray
Write-Host "Kural: Siteye girerse 20 dk tutulur, 30 sn'de bir kontrol edilir." -ForegroundColor Gray
Write-Host "Kural: Kesinti olursa hemen yeni calisan IP arayisina gecer." -ForegroundColor Gray
Write-Host "Sunucu listesi aliniyor..." -ForegroundColor Gray

$rawRelays = & $MullvadExe relay list
$allRelays = $rawRelays | Where-Object { $_ -match '^\s+([a-z]{2}-[a-z]{3}-wg-\d+)' } | ForEach-Object { $matches[1] }

if (-not $allRelays -or $allRelays.Count -eq 0) {
    Write-Host "[HATA] Sunucu listesi alinamadi!" -ForegroundColor Red
    Pause
    exit 1
}

if ($OnlyFastEurope) {
    $selectedRelays = @($allRelays | Where-Object { $_ -match '^(tr|de|nl|fr|gb|se|ch|at|be|ro|pl)-' })
} else {
    $selectedRelays = @($allRelays)
}

Write-Host "Toplam $($selectedRelays.Count) adet sunucu havuzu hazirlandi.`n" -ForegroundColor Green

function Test-HalkbankSite {
    param([string]$Url)
    try {
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls13
        
        $req = [System.Net.HttpWebRequest]::Create($Url)
        $req.Timeout = 10000
        $req.ReadWriteTimeout = 10000
        $req.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        $req.Method = "GET"
        
        $resp = $req.GetResponse()
        $code = [int]$resp.StatusCode
        $resp.Close()
        if ($code -ge 200 -and $code -lt 400) {
            return $true
        }
        return $false
    } catch {
        return $false
    }
}

function Connect-RandomRelay {
    $relay = $selectedRelays | Get-Random
    $timeStr = (Get-Date).ToString("HH:mm:ss")
    Write-Host "[$timeStr] Yeni sunucu seciliyor: $relay ..." -ForegroundColor Yellow
    
    & $MullvadExe relay set location $relay | Out-Null
    & $MullvadExe connect | Out-Null
    
    Start-Sleep -Seconds 4
    
    $status = & $MullvadExe status
    $locLine = ($status | Where-Object { $_ -match "Visible location:" }) -join " "
    $ipv4 = ""
    if ($status -join " " -match "IPv4:\s*([0-9\.]+)") {
        $ipv4 = $matches[1]
    }
    
    Write-Host "[$timeStr] BAGLANDI! IP: $ipv4 | Sunucu: $relay" -ForegroundColor Cyan
    if ($locLine) {
        Write-Host "           $($locLine.Trim())" -ForegroundColor DarkCyan
    }
    return $relay
}

# Calisan ve siteye giren bir VPN bulana kadar arayan ana fonksiyon
function Find-WorkingVPN {
    while ($true) {
        Connect-RandomRelay
        $timeStr = (Get-Date).ToString("HH:mm:ss")
        Write-Host "[$timeStr] Siteye erisim kontrol ediliyor ($TargetUrl)..." -ForegroundColor Gray
        
        $isAccessible = Test-HalkbankSite -Url $TargetUrl
        if ($isAccessible) {
            Write-Host "[$timeStr] [GIRDI - ONAYLANDI] Site basariyla acildi!" -ForegroundColor Green
            Write-Host "[$timeStr] Bu IP sabitlendi. 20 dakika boyunca tutulacak (30 sn'de bir kontrol edilecek)." -ForegroundColor Green
            return $true
        } else {
            Write-Host "[$timeStr] [GIRMEDI] Siteye girilemedi! Bu VPN elendi, hemen baska deneniyor..." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
}

# Ilk calisan VPN'i bul
Find-WorkingVPN

while ($true) {
    $stayUntil = (Get-Date).AddMinutes($SuccessWaitMinutes)
    $connectionDropped = $false
    
    # 20 dakika boyunca kal, ancak her 30 saniyede bir kesinti var mi diye kontrol et
    while ((Get-Date) -lt $stayUntil) {
        Start-Sleep -Seconds $CheckIntervalSeconds
        $innerTime = (Get-Date).ToString("HH:mm:ss")
        $remMinutes = [math]::Round(($stayUntil - (Get-Date)).TotalMinutes, 1)
        
        $stillOk = Test-HalkbankSite -Url $TargetUrl
        if ($stillOk) {
            Write-Host "[$innerTime] [GIRDI] Site erisimi sorunsuz aktif. (Kalan sure: $remMinutes dk)" -ForegroundColor DarkGreen
        } else {
            Write-Host "[$innerTime] [KESINTI TESPIT EDILDI!] Siteye erisim koptu! Hemen yeni calisan VPN aranıyor..." -ForegroundColor Red
            $connectionDropped = $true
            break
        }
    }
    
    if (-not $connectionDropped) {
        $endTime = (Get-Date).ToString("HH:mm:ss")
        Write-Host "`n[$endTime] 20 dakikalik sure doldu! Yeni calisan sunucu arayisina geciliyor..." -ForegroundColor Yellow
    }
    
    # Kesinti olduysa ya da 20 dk bittiyse aninda yeni calisan VPN bul
    Find-WorkingVPN
}
