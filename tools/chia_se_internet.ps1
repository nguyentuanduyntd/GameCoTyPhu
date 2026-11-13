# Chia sẻ game qua Internet cho người ở xa (kể cả iPhone): bật server + đường hầm Cloudflare miễn phí,
# rồi in ra MỘT link để gửi. Chạy bằng ChiaSeInternet.bat (cùng thư mục với TyPhuDatViet.exe).
# Cần cloudflared.exe cùng thư mục (hoặc trong PATH). Đóng cửa sổ này là tắt hết.
#
# - Server game (cổng 8910) đi qua một đường hầm  -> wss://xxxx.trycloudflare.com
# - Bản Web (cổng 8912) đi qua đường hầm thứ hai  -> https://yyyy.trycloudflare.com
#   (nếu có tệp web_url.txt chứa link bản Web cố định, ví dụ trên GitHub Pages, thì dùng link đó)
# Link gửi đi: https://<trang web>/?server=wss://<server>  — mở là vào thẳng đúng server.
$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
Set-Location $here
$game = Join-Path $here "TyPhuDatViet.console.exe"
$cf = Join-Path $here "cloudflared.exe"
if (-not (Test-Path $cf)) {
	$cmd = Get-Command cloudflared -ErrorAction SilentlyContinue
	if ($cmd) { $cf = $cmd.Source } else { throw "Thiếu cloudflared.exe (tải bản Windows từ trang phát hành chính thức của Cloudflare, đặt cạnh tệp này)." }
}
$logs = Join-Path $env:TEMP "typhu_share"
New-Item -ItemType Directory -Force $logs | Out-Null
$procs = @()

function Wait-TunnelUrl([string]$logFile) {
	for ($i = 0; $i -lt 60; $i++) {
		Start-Sleep -Milliseconds 500
		if (Test-Path $logFile) {
			$m = Select-String -Path $logFile -Pattern "https://[a-z0-9-]+\.trycloudflare\.com" -AllMatches | Select-Object -First 1
			if ($m) { return $m.Matches[0].Value }
		}
	}
	throw "Không lấy được địa chỉ đường hầm (xem $logFile). Kiểm tra kết nối Internet."
}

function Start-Tunnel([string]$name, [int]$port) {
	$err = Join-Path $logs "$name.log"
	Remove-Item $err -ErrorAction SilentlyContinue
	$p = Start-Process -FilePath $cf -ArgumentList @("tunnel", "--no-autoupdate", "--url", "http://localhost:$port") `
		-RedirectStandardError $err -RedirectStandardOutput (Join-Path $logs "$name.out") -WindowStyle Hidden -PassThru
	$script:procs += $p
	return (Wait-TunnelUrl $err)
}

try {
	# 1) server game (bỏ qua nếu đã có server đang chạy ở cổng 8910)
	$busy = Get-NetTCPConnection -LocalPort 8910 -State Listen -ErrorAction SilentlyContinue
	if (-not $busy) {
		Write-Host "Đang bật server game..."
		$srv = Start-Process -FilePath $game -ArgumentList @("--headless", "--", "--server") `
			-RedirectStandardOutput (Join-Path $logs "server.log") -RedirectStandardError (Join-Path $logs "server.err") -WindowStyle Hidden -PassThru
		$procs += $srv
		Start-Sleep -Seconds 3
	} else {
		Write-Host "Đã có server đang chạy ở cổng 8910 — dùng luôn."
	}
	# 2) đường hầm cho server game
	Write-Host "Đang mở đường hầm cho server game..."
	$gameUrl = Start-Tunnel "game" 8910
	$wss = $gameUrl -replace "^https://", "wss://"
	# 3) trang web: link cố định (web_url.txt) hoặc đường hầm thứ hai
	$webFixed = Join-Path $here "web_url.txt"
	if (Test-Path $webFixed) {
		$webUrl = (Get-Content $webFixed -Raw).Trim().TrimEnd("/")
	} elseif (Test-Path (Join-Path $here "web\index.html")) {
		Write-Host "Đang mở đường hầm cho bản Web..."
		$webUrl = Start-Tunnel "web" 8912
	} else {
		$webUrl = ""
	}
	Write-Host ""
	Write-Host "================================================================"
	if ($webUrl -ne "") {
		$link = "$webUrl/?server=$wss"
		Write-Host " GỬI LINK NÀY cho người chơi ở xa (iPhone mở bằng Safari):"
		Write-Host ""
		Write-Host "   $link" -ForegroundColor Yellow
		try { Set-Clipboard -Value $link; Write-Host ""; Write-Host " (đã chép link vào clipboard — dán vào Zalo/Messenger là xong)" } catch {}
	}
	Write-Host ""
	Write-Host " Người dùng bản cài (Windows / Android): bấm Nhập mã phòng, ô Địa chỉ server nhập:"
	Write-Host "   $wss" -ForegroundColor Yellow
	Write-Host ""
	Write-Host " Bạn tạo phòng trên máy này như bình thường (để 'Máy này làm server')."
	Write-Host " Link chỉ chạy khi cửa sổ này còn mở; mỗi lần bật lại link sẽ khác."
	Write-Host "================================================================"
	Write-Host " Đóng cửa sổ này (hoặc Ctrl+C) để tắt."
	while ($true) {
		Start-Sleep -Seconds 5
		foreach ($p in $procs) { if ($p.HasExited) { throw "Một tiến trình đã dừng (xem log ở $logs)." } }
	}
} finally {
	foreach ($p in $procs) { if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } }
}
