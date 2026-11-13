# Đăng bản Web (build\web) lên GitHub Pages: đẩy lên nhánh gh-pages của repo (luôn chỉ 1 commit,
# thay mới mỗi lần — repo không phình ra). Link cố định: https://<chủ repo>.github.io/<tên repo>/
#
#   powershell -ExecutionPolicy Bypass -File tools\build.ps1 -WebOnly     # xuất bản Web trước
#   powershell -ExecutionPolicy Bypass -File tools\publish_web.ps1        # rồi đăng
#
# Lần đầu: nếu link chưa chạy sau vài phút, vào repo trên GitHub → Settings → Pages →
# Source: Deploy from a branch, Branch: gh-pages / (root) → Save.
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root
if (-not (Test-Path "build\web\index.html")) { throw "Chưa có bản Web: chạy tools\build.ps1 -WebOnly trước." }
$origin = (git remote get-url origin).Trim()
if ($origin -notmatch "github\.com[:/]([^/]+)/([^/.]+)") { throw "Remote origin không phải GitHub: $origin" }
$owner = $Matches[1]
$repo = $Matches[2]
$url = "https://$($owner.ToLower()).github.io/$repo/"
$version = (Select-String -Path "project.godot" -Pattern 'config/version="([^"]+)"').Matches[0].Groups[1].Value

$tmp = Join-Path $env:TEMP "typhu_gh_pages"
if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
New-Item -ItemType Directory $tmp | Out-Null
Copy-Item "build\web\*" $tmp -Recurse
New-Item -ItemType File (Join-Path $tmp ".nojekyll") | Out-Null   # phục vụ tệp nguyên dạng, không qua Jekyll
Push-Location $tmp
try {
	git init -q
	git checkout -q -b gh-pages
	git add -A
	git commit -q -m "Bản Web $version ($(Get-Date -Format 'yyyy-MM-dd HH:mm'))"
	Write-Host "== Đẩy bản Web lên nhánh gh-pages của $owner/$repo ..."
	git push -q --force $origin gh-pages
	if ($LASTEXITCODE -ne 0) { throw "Đẩy lên GitHub thất bại." }
} finally {
	Pop-Location
	Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
Set-Content -Path "tools\web_url.txt" -Value $url -Encoding ASCII
Write-Host "Xong. Bản Web: $url  (GitHub cần khoảng 1-2 phút để cập nhật)"
Write-Host "Link gửi bạn bè ở xa: chạy ChiaSeInternet.bat — nó tự ghép link này với địa chỉ server."
