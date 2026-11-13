# Xuất bản Tỷ Phú Đất Việt: Windows (.exe) và Android (.apk) vào thư mục build/
#
#   powershell -ExecutionPolicy Bypass -File tools\build.ps1                 # cả hai
#   powershell -ExecutionPolicy Bypass -File tools\build.ps1 -WindowsOnly
#   powershell -ExecutionPolicy Bypass -File tools\build.ps1 -AndroidOnly
#   powershell -ExecutionPolicy Bypass -File tools\build.ps1 -WebOnly      # bản Web (iPhone / trình duyệt)
#   thêm -Godot "<đường dẫn Godot ..._console.exe>" nếu Godot ở chỗ khác
#
# Cài thẳng lên điện thoại (không phải gửi file): thêm -Install
#   powershell -ExecutionPolicy Bypass -File tools\build.ps1 -AndroidOnly -Install
#   powershell -ExecutionPolicy Bypass -File tools\build.ps1 -AndroidOnly -Install -Phone 192.168.1.23:41235
# Điện thoại cắm cáp USB (bật Gỡ lỗi USB) hoặc đã ghép "Gỡ lỗi không dây" — xem docs/PUBLISH.md.
#
# Android ký bằng khoá debug chuẩn (đủ để cài trực tiếp / gửi bạn bè). Muốn dùng khoá riêng của bạn
# (bắt buộc nếu đưa lên Google Play) thì đặt trước 3 biến môi trường:
#   GODOT_ANDROID_KEYSTORE_RELEASE_PATH, GODOT_ANDROID_KEYSTORE_RELEASE_USER, GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
param(
	[string]$Godot = "D:\Dowload\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe",
	[switch]$WindowsOnly,
	[switch]$AndroidOnly,
	[switch]$WebOnly,
	[switch]$Install,
	[string]$Phone = ""
)
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root
if (-not (Test-Path $Godot)) { throw "Không thấy Godot ở: $Godot (dùng tham số -Godot)" }

function Export-Preset([string]$preset, [string]$out) {
	Write-Host "== Xuất $preset -> $out"
	& $Godot --headless --path . --export-release $preset $out
	if (-not (Test-Path $out)) { throw "Xuất $preset thất bại (xem lỗi ở trên)." }
	$mb = [math]::Round((Get-Item $out).Length / 1MB, 1)
	Write-Host "   xong: $out ($mb MB)"
}

$doWin = -not ($AndroidOnly -or $WebOnly)
$doAndroid = -not ($WindowsOnly -or $WebOnly)
$doWeb = -not ($WindowsOnly -or $AndroidOnly)

if ($doWeb) {
	# Bản Web (chơi bằng trình duyệt, kể cả Safari trên iPhone): build\web\index.html + các tệp đi kèm
	if (Test-Path "build\web") { Remove-Item -Recurse -Force "build\web" }
	New-Item -ItemType Directory -Force "build\web" | Out-Null
	Export-Preset "Web" "build/web/index.html"
}

if ($doWin) {
	New-Item -ItemType Directory -Force "build\windows" | Out-Null
	Export-Preset "Windows Desktop" "build/windows/TyPhuDatViet.exe"
	# Kèm bản Web để server phát luôn trang web (iPhone mở http://<IP máy>:8912 là chơi)
	if (Test-Path "build\web\index.html") {
		if (Test-Path "build\windows\web") { Remove-Item -Recurse -Force "build\windows\web" }
		Copy-Item "build\web" "build\windows\web" -Recurse
		Write-Host "   đã chép bản Web vào build\windows\web"
	}
	# Tệp bật server ngay từ bản đã xuất (không cần cài Godot)
	$bat = @"
@echo off
chcp 65001 >nul
title Server Ty Phu Dat Viet
echo Dang bat server Ty Phu Dat Viet (cong 8910). Dong cua so nay de tat server.
echo iPhone / may khac cung Wi-Fi: mo trinh duyet vao dia chi http://IP-may-nay:8912 (xem dong ben duoi)
echo Choi qua Internet: mo them cua so chay  cloudflared tunnel --url http://localhost:8910
"%~dp0TyPhuDatViet.console.exe" --headless -- --server %*
pause
"@
	Set-Content -Path "build\windows\ChayServer.bat" -Value $bat -Encoding ASCII
	Copy-Item "docs\ONLINE.md" "build\windows\HuongDanOnline.md" -Force
	# Chia sẻ qua Internet (người ở xa, iPhone): ChiaSeInternet.bat -> bật server + đường hầm Cloudflare, in ra một link
	Copy-Item "tools\chia_se_internet.ps1" "build\windows\ChiaSeInternet.ps1" -Force
	Set-Content -Path "build\windows\ChiaSeInternet.bat" -Encoding ASCII -Value "@echo off`r`nchcp 65001 >nul`r`ntitle Chia se Ty Phu Dat Viet qua Internet`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"%~dp0ChiaSeInternet.ps1`"`r`npause"
	if (Test-Path "build\tools\cloudflared.exe") { Copy-Item "build\tools\cloudflared.exe" "build\windows\cloudflared.exe" -Force }
}

if ($doAndroid) {
	New-Item -ItemType Directory -Force "build\android" | Out-Null
	if (-not $env:JAVA_HOME) {
		$jbr = "C:\Program Files\Android\Android Studio\jbr"
		if (Test-Path $jbr) { $env:JAVA_HOME = $jbr } else { throw "Chưa có Java: cài Android Studio hoặc đặt JAVA_HOME." }
	}
	# Godot 4.7 cần "Java SDK Path" trong Editor Settings (không tự lấy JAVA_HOME): điền nếu đang trống
	$es = Join-Path $env:APPDATA "Godot\editor_settings-4.7.tres"
	if (Test-Path $es) {
		$txt = [System.IO.File]::ReadAllText($es)
		if ($txt -match 'export/android/java_sdk_path = ""') {
			$jp = $env:JAVA_HOME.Replace('\', '/')
			$txt = $txt -replace 'export/android/java_sdk_path = ""', ('export/android/java_sdk_path = "' + $jp + '"')
			[System.IO.File]::WriteAllText($es, $txt, (New-Object System.Text.UTF8Encoding($false)))
			Write-Host "   Đã đặt Java SDK Path trong Editor Settings: $jp"
		}
	}
	if (-not $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH) {
		# khoá debug chuẩn của Android (mật khẩu công khai "android"), Godot cũng tự tạo khoá này
		$ks = Join-Path $env:APPDATA "Godot\keystores\debug.keystore"
		if (-not (Test-Path $ks)) {
			New-Item -ItemType Directory -Force (Split-Path $ks) | Out-Null
			& "$env:JAVA_HOME\bin\keytool.exe" -genkeypair -keystore $ks -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
		}
		$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $ks
		$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = "androiddebugkey"
		$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = "android"
	}
	Export-Preset "Android" "build/android/TyPhuDatViet.apk"
	if ($Install) {
		# Cài đè lên điện thoại (giữ nguyên dữ liệu, cài đặt trong game) rồi mở game luôn
		$adb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
		if (-not (Test-Path $adb)) { throw "Không thấy adb ở $adb (cài Android SDK platform-tools)." }
		# bật adb server tách riêng (nếu để adb tự bật trong lệnh dưới, nó giữ luồng xuất và script bị treo)
		Start-Process -FilePath $adb -ArgumentList "start-server" -WindowStyle Hidden
		Start-Sleep -Seconds 3
		if ($Phone -ne "") {
			Write-Host "== Kết nối điện thoại qua Wi-Fi: $Phone"
			& $adb connect $Phone
		}
		$devices = (& $adb devices) | Select-String -Pattern "\tdevice$"
		if ($devices.Count -eq 0) {
			throw "Không thấy điện thoại. Cắm cáp USB (bật Gỡ lỗi USB) hoặc ghép Gỡ lỗi không dây rồi thêm -Phone <IP:cổng> (xem docs/PUBLISH.md)."
		}
		$serial = ($devices[0].Line -split "\t")[0]
		Write-Host "== Cài lên điện thoại $serial"
		& $adb -s $serial install -r "build\android\TyPhuDatViet.apk"
		if ($LASTEXITCODE -ne 0) { throw "Cài APK thất bại (xem lỗi ở trên)." }
		& $adb -s $serial shell monkey -p com.typhudatviet.game -c android.intent.category.LAUNCHER 1 | Out-Null
		Write-Host "   đã cài và mở game trên điện thoại."
	}
}
Write-Host "Hoàn tất. Kết quả ở thư mục build\"
