#!/usr/bin/env bash
# Tải các trang công khai của một website về thư mục để scan.sh quét.
#
#   scripts/fetch-site.sh <url> [thư-mục-đích]
#
# Chỉ tải những gì ai mở trình duyệt cũng thấy:
#   - trang chủ (kèm response header, để nhận biết hosting)
#   - tối đa 15 trang cùng tên miền được link từ trang chủ, có tên gợi ý chính sách,
#     điều khoản, liên hệ, sản phẩm, giỏ hàng, thanh toán, đăng nhập, đăng ký
#   - tối đa 20 file JavaScript cùng tên miền (site dựng bằng React/Next/Vue thường
#     chỉ lộ form, tracking trong file JS)
# Không gửi dữ liệu đi đâu ngoài các request GET tới chính website đó.

set -uo pipefail

URL="${1:-}"
OUT="${2:-$(mktemp -d)}"
MAX_PAGES=15
MAX_JS=20
UA="vn-law-check (+https://github.com/mhfed/vn-law-check)"
CURL=(curl -sSL --max-time 20 --max-filesize 5000000 -A "$UA")

if [[ ! "$URL" =~ ^https?:// ]]; then
  echo "Cách dùng: scripts/fetch-site.sh https://ten-mien.vn [thư-mục]" >&2
  exit 1
fi
command -v curl >/dev/null || { echo "Cần cài curl" >&2; exit 1; }

origin="$(printf '%s' "$URL" | sed -E 's|^(https?://[^/?#]+).*|\1|')"
scheme="${origin%%://*}"
mkdir -p "$OUT/pages" "$OUT/js"

# Đổi link tương đối thành URL đầy đủ, bỏ link sang tên miền khác
resolve() {
  local base="$1" href="$2"
  base="${base%%#*}"
  href="${href%%#*}"
  case "$href" in
    ""|mailto:*|tel:*|javascript:*|data:*) return ;;
    //*) href="$scheme:$href" ;;
    /*) href="$origin$href" ;;
    http://*|https://*) ;;
    \?*) href="${base%%\?*}$href" ;;
    *)
      base="${base%%\?*}"
      [ "$base" = "$origin" ] && base="$base/"
      href="${base%/*}/$href"
      ;;
  esac
  # Ranh giới authority: không nhận domain có cùng tiền tố, port khác hay userinfo @.
  case "$href" in
    "$origin"|"$origin/"*|"$origin?"*) printf '%s\n' "$href" ;;
  esac
}

safe_name() { printf '%s' "$1" | sed -E "s#^$origin##; s#[^A-Za-z0-9._-]+#_#g; s#^_##" | cut -c1-80; }

# Mỗi file JS được nối theo URL của trang chứa nó, không theo trang chủ.
scripts_from_page() {
  local file="$1" base="$2"
  grep -oE '<script[^>]+src="[^"]+"' "$file" | sed -E 's/.*src="//; s/"$//' \
    | while IFS= read -r src; do resolve "$base" "$src"; done
}

echo "Tải trang chủ: $URL"
if ! entry_url="$("${CURL[@]}" -w '%{url_effective}' -D "$OUT/response-headers.txt" "$URL" -o "$OUT/pages/index.html")"; then
  echo "Không tải được $URL" >&2
  exit 1
fi
# Sau redirect chuẩn hóa (HTTP -> HTTPS, www...), dùng origin thật của trang chủ.
origin="$(printf '%s' "$entry_url" | sed -E 's|^(https?://[^/?#]+).*|\1|')"
scheme="${origin%%://*}"

links="$(grep -oE 'href="[^"]+"|href='"'"'[^'"'"']+'"'" "$OUT/pages/index.html" | sed -E "s/^href=[\"']//; s/[\"']$//")"
pages="$(while IFS= read -r h; do resolve "$entry_url" "$h"; done <<< "$links" \
  | grep -iE 'chinh-sach|bao-mat|privacy|policy|dieu-khoan|terms|lien-he|contact|san-pham|product|cart|gio-hang|checkout|thanh-toan|login|dang-nhap|signin|register|dang-ky|signup' \
  | sort -u | head -n "$MAX_PAGES")"

scripts="$(scripts_from_page "$OUT/pages/index.html" "$entry_url")"
n=0
while read -r p; do
  [ -z "$p" ] && continue
  file="$OUT/pages/$(safe_name "$p").html"
  if page_url="$("${CURL[@]}" -w '%{url_effective}' "$p" -o "$file")"; then
    n=$((n + 1))
    scripts="$scripts
$(scripts_from_page "$file" "$page_url")"
  fi
done <<< "$pages"
echo "Tải thêm $n trang liên quan"

js="$(printf '%s\n' "$scripts" | sed '/^$/d' | sort -u | head -n "$MAX_JS")"

m=0
while read -r j; do
  [ -z "$j" ] && continue
  "${CURL[@]}" "$j" -o "$OUT/js/$(safe_name "$j").js" && m=$((m + 1))
done <<< "$js"
echo "Tải $m file JavaScript cùng tên miền"
echo "Đã lưu vào: $OUT"
