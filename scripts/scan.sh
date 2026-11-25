#!/usr/bin/env bash
# Quét nhanh một website để gợi ý mức độ audit (xem references/00-triage.md).
#
#   scripts/scan.sh [thư-mục-code]       quét source code website hoặc mobile app (mặc định: thư mục hiện tại)
#   scripts/scan.sh https://ten-mien.vn  quét site đang chạy, khi không có source code
#   scripts/scan.sh --json [target]     xuất JSON schema v1 (cần Python 3)
#
# Với thư mục: chỉ đọc file, không gọi mạng.
# Với URL: gọi scripts/fetch-site.sh để tải các trang công khai của chính site đó
# (trang chủ, trang chính sách/liên hệ/giỏ hàng, file JS cùng tên miền) về thư mục tạm,
# rồi quét như source code. Không gửi dữ liệu đi đâu khác.
#
# Kết quả là GỢI Ý kèm bằng chứng (file:dòng:đoạn khớp). Agent vẫn phải xem lại
# bằng chứng trước khi kết luận.

set -uo pipefail

TARGET="."
JSON_MODE=0
target_set=0
literal=0
for arg in "$@"; do
  if [ "$literal" = 0 ]; then
    case "$arg" in
      --json) JSON_MODE=1; continue ;;
      --) literal=1; continue ;;
      -*) printf 'Tham số không hợp lệ: %s\nCách dùng: scan.sh [--json] [target]\n' "$arg" >&2; exit 2 ;;
    esac
  fi
  if [ "$target_set" = 1 ]; then
    printf 'Chỉ nhận một target. Cách dùng: scan.sh [--json] [target]\n' >&2
    exit 2
  fi
  TARGET="$arg"
  target_set=1
done

RESULTS=()
record_result() {
  if [ "$JSON_MODE" = 1 ]; then RESULTS+=("$1" "$2" "$3"); fi
}
if [ "$JSON_MODE" = 1 ]; then
  command -v python3 >/dev/null || { printf 'Chế độ --json cần Python 3.\n' >&2; exit 1; }
  # Giữ stdout gốc riêng cho JSON; không trộn báo cáo/progress text vào kết quả.
  exec 3>&1
  exec 1>/dev/null
fi
URL_MODE=0
if [[ "$TARGET" =~ ^https?:// ]]; then
  URL_MODE=1
  DIR="$(mktemp -d)"
  bash "$(dirname "$0")/fetch-site.sh" "$TARGET" "$DIR" || exit 1
  echo
else
  DIR="$TARGET"
  if [ ! -d "$DIR" ]; then
    echo "Không tìm thấy thư mục: $DIR" >&2
    exit 1
  fi
fi

# Chỉ quét file code/cấu hình, bỏ qua thư viện, build output, lockfile và chính bộ checklist
EXCLUDE_DIRS=(node_modules .git dist build out .next .nuxt .svelte-kit vendor coverage .vn-law-check
              Pods .dart_tool .gradle DerivedData .expo)
INCLUDE=(--include='*.html' --include='*.htm' --include='*.js' --include='*.mjs' --include='*.cjs'
         --include='*.jsx' --include='*.ts' --include='*.tsx' --include='*.vue' --include='*.svelte'
         --include='*.astro' --include='*.php' --include='*.py' --include='*.rb' --include='*.erb'
         --include='*.liquid' --include='*.twig' --include='*.json' --include='*.toml'
         --include='*.yml' --include='*.yaml' --include='*.env.example'
         --include='*.dart' --include='*.kt' --include='*.kts' --include='*.java' --include='*.swift'
         --include='*.m' --include='*.mm' --include='*.gradle' --include='AndroidManifest.xml'
         --include='Info.plist' --include='Podfile')

# -o: chỉ in đoạn khớp, để bằng chứng vẫn đọc được với file JS đã minify (cả file nằm trên 1 dòng)
EXCLUDE_ARGS=(--exclude='package-lock.json' --exclude='*.lock' --exclude='*.min.js')
for d in "${EXCLUDE_DIRS[@]}"; do EXCLUDE_ARGS+=(--exclude-dir="$d"); done
GREP_ARGS=(-rEIino "${INCLUDE[@]}" "${EXCLUDE_ARGS[@]}")

# Mỗi tín hiệu: tên | regex. Có thêm mẫu cho JSX đã compile (jsx("form", createElement("form")
# vì site React/Next chỉ lộ form trong file JS.
SIGNALS=(
  "FORM|<form[ >]|jsxs?\(\"form\"|createElement\(\"form\"|formspree\.io|getform\.io|data-netlify=|docs\.google\.com/forms|type=[\"']email[\"']|type:[[:space:]]*[\"']email[\"']|keyboardType=[\"'](email-address|phone-pad)[\"']|textContentType=[\"'](emailAddress|telephoneNumber)[\"']|TextInputType\.(emailAddress|phone)"
  "TRACKING|gtag\(|googletagmanager\.com|google-analytics\.com|fbq\(|connect\.facebook\.net|analytics\.tiktok\.com|clarity\.ms|hotjar|cdn\.segment\.com|plausible\.io|umami|cdn\.mxpnl\.com|api\.mixpanel\.com|cdn\.amplitude\.com|api2?\.amplitude\.com"
  "COMMERCE|add[-_ ]?to[-_ ]?cart|addToCart|/checkout|/cart[\"'/]|giỏ hàng|thêm vào giỏ|mua ngay|[\"'>][[:space:]]*(đặt|Đặt|ĐẶT) (hàng|HÀNG)|(đặt|Đặt|ĐẶT) (mua|MUA)|thanh toán|vnpay|momo|zalopay|\"stripe\"|stripe\.com|paypal|woocommerce|shopify"
  "AUTH|/login|/register|/signin|/signup|sign[-_ ]?in|đăng nhập|next-auth|nextauth|firebase/auth|supabase\.auth|passport|@clerk|auth0"
  "MARKETPLACE|multi[-_ ]?vendor|seller[-_ ]?(dashboard|register|signup|onboard)|vendor[-_ ]?(dashboard|register)|người bán|kênh người bán|đăng ký bán hàng"
  "AI|api\.openai\.com|\"openai\"|@anthropic-ai|api\.anthropic\.com|@ai-sdk|generativelanguage\.googleapis|@google/generative-ai|dialogflow|langchain|chatbot"
  "AD_CLAIM|(giá|sản phẩm|chất lượng|dịch vụ|hàng) (tốt|rẻ) nhất|rẻ nhất|uy tín nhất|duy nhất (tại|ở|trên thị trường) Việt Nam|số (1|một) (Việt Nam|thị trường|thế giới)|(uy tín|chất lượng|thương hiệu|đứng|xếp hạng) số (1|một)"
  "HEALTH_SUPPLEMENT|thực phẩm bảo vệ sức kh(ỏe|oẻ)|thực phẩm chức năng|TPBVSK|TPCN"
  "PERMISSIONS|android\.permission\.(ACCESS_FINE_LOCATION|ACCESS_COARSE_LOCATION|ACCESS_BACKGROUND_LOCATION|READ_CONTACTS|WRITE_CONTACTS|CAMERA|RECORD_AUDIO|READ_SMS|RECEIVE_SMS|READ_CALL_LOG|READ_PHONE_STATE|READ_MEDIA_IMAGES|READ_MEDIA_VIDEO|READ_EXTERNAL_STORAGE|BODY_SENSORS|ACTIVITY_RECOGNITION)|NS(LocationWhenInUse|LocationAlways|LocationAlwaysAndWhenInUse|Contacts|Camera|Microphone|PhotoLibrary|PhotoLibraryAdd|UserTracking|HealthShare|HealthUpdate|SpeechRecognition|Motion)UsageDescription|\"(ACCESS_FINE_LOCATION|ACCESS_COARSE_LOCATION|ACCESS_BACKGROUND_LOCATION|READ_CONTACTS|CAMERA|RECORD_AUDIO|READ_SMS)\""
  "SDK_TRACKING|firebase_analytics|@react-native-firebase/analytics|firebase-analytics|FirebaseAnalytics|react-native-fbsdk|facebook_app_events|FBSDKCoreKit|com\.facebook\.android|appsflyer|react-native-adjust|com\.adjust\.sdk|adjust_sdk|react-native-branch|io\.branch|mixpanel|amplitude|@segment/analytics-react-native|AppTrackingTransparency|app_tracking_transparency|react-native-tracking-transparency"
  "ADS_SDK|google_mobile_ads|react-native-google-mobile-ads|play-services-ads|Google-Mobile-Ads-SDK|GoogleMobileAds|applovin|unity-ads|unity_ads|ironsource|admob"
  "FOREIGN_HOST|amazonaws\.com|cloudfront\.net|firebaseio\.com|firebase\.json|\"firebase\"|firebase/firestore|vercel|netlify|wrangler|cloudflare|herokuapp|fly\.io|render\.com|azurewebsites"
)

# Dùng biến FOUND_<TÊN> thay cho mảng kết hợp, vì macOS mặc định là bash 3.2 (không có declare -A)
found() { local v="FOUND_$1"; [ "${!v:-0}" = 1 ]; }

# Nhận diện mobile app qua file đặc trưng của từng nền tảng
platforms=""
if [ "$URL_MODE" = 0 ]; then
  has() { [ -n "$(find "$DIR" \( -name node_modules -o -name Pods -o -name .dart_tool -o -name .git \) -prune -o "$@" -print 2>/dev/null | head -n 1)" ]; }
  has -name pubspec.yaml && platforms="$platforms Flutter"
  has -name package.json -exec grep -q '"react-native"' {} \; && platforms="$platforms React-Native"
  has -name package.json -exec grep -q '"expo"' {} \; && platforms="$platforms Expo"
  has -name AndroidManifest.xml && platforms="$platforms Android"
  { has -name Info.plist || has -name '*.xcodeproj'; } && platforms="$platforms iOS"
fi
platforms="${platforms# }"

echo "Quét: $([ "$URL_MODE" = 1 ] && echo "$TARGET" || echo "$DIR")"
echo

for entry in "${SIGNALS[@]}"; do
  name="${entry%%|*}"
  regex="${entry#*|}"
  limit=3; [ "$name" = PERMISSIONS ] && limit=10
  # Tín hiệu riêng của mobile app: chỉ xét khi thấy dấu hiệu app thật, tránh bắt nhầm thư viện web (mixpanel, amplitude...)
  case "$name" in PERMISSIONS|SDK_TRACKING|ADS_SDK)
    if [ -z "$platforms" ]; then
      record_result "$name" null ""
      echo "[không] $name   (chỉ xét với mobile app)"; continue
    fi ;;
  esac
  hits="$(grep "${GREP_ARGS[@]}" -e "$regex" "$DIR" 2>/dev/null | awk '!seen[$0]++' | head -n "$limit")"
  if [ "$name" = "FOREIGN_HOST" ] && [ -z "$hits" ]; then
    # Source code: nhận diện qua file cấu hình hosting
    hits="$(find "$DIR" -maxdepth 2 \( -name vercel.json -o -name netlify.toml -o -name firebase.json \
             -o -name wrangler.toml -o -name fly.toml -o -name render.yaml -o -name app.yaml \) 2>/dev/null | head -n 3)"
    # URL: nhận diện qua response header của trang chủ
    if [ -z "$hits" ] && [ -f "$DIR/response-headers.txt" ]; then
      hits="$(grep -iE '^(server|via|x-vercel-id|cf-ray|x-amz-cf-id|x-nf-request-id|x-served-by|x-github-request-id|x-powered-by):.*' "$DIR/response-headers.txt" \
              | grep -iE 'vercel|cloudflare|cf-ray|cloudfront|amazon|netlify|firebase|github|fly|render|heroku|azure|google' \
              | tr -d '\r' | sed 's/^/response-headers: /' | head -n 3)"
    fi
  fi
  if [ -n "$hits" ]; then
    printf -v "FOUND_$name" 1
    record_result "$name" true "$hits"
    echo "[có]    $name"
    echo "$hits" | sed "s#^$DIR/##" | cut -c1-160 | sed 's/^/          /'
  else
    record_result "$name" false ""
    echo "[không] $name"
  fi
done

# Tracking chạy ngay hay chờ đồng ý. Chỉ đọc code nên chỉ là dấu hiệu, không thay được việc mở trình duyệt kiểm tra.
consent="none"
static_hits=""
gate_hits=""
if found TRACKING; then
  # Thẻ <script src=tracker> viết thẳng trong HTML thì chạy ngay khi tải trang.
  # Bỏ qua thẻ type="text/plain": cách các thư viện đồng ý dùng để chặn script tới khi người dùng bấm đồng ý.
  static_hits="$(grep -rEIl --include='*.html' --include='*.htm' --include='*.php' --include='*.liquid' \
      "${EXCLUDE_ARGS[@]}" \
      -e '<script' "$DIR" 2>/dev/null \
      | while IFS= read -r file; do
          awk -f "$(dirname "$0")/tracking-preload.awk" "$file"
        done | awk '!seen[$0]++' | head -n 3)"
  gate_hits="$(grep "${GREP_ARGS[@]}" -e "cookiebot|onetrust|cookieyes|cookie-script\.com|klaro|iubenda|osano|termly|complianz|cookieconsent|gtag\([\"']consent[\"']|ad_storage[\"']?:[[:space:]]*[\"']denied|data-cookieconsent|data-category=[\"'](analytics|marketing)|cookie[_-]?consent|consent[_-]?(given|granted|accepted)|đồng ý cookie|chấp nhận cookie" "$DIR" 2>/dev/null | awk '!seen[$0]++' | head -n 3)"
  if [ -n "$static_hits" ]; then
    consent="static"
    echo "[có]    TRACKING_PRELOAD   (script theo dõi viết thẳng trong HTML, chạy ngay khi tải trang, trước khi người dùng đồng ý)"
    echo "$static_hits" | sed "s#^$DIR/##" | cut -c1-160 | sed 's/^/          /'
    if [ -n "$gate_hits" ]; then
      echo "          Có thư viện/banner đồng ý (ví dụ $(echo "$gate_hits" | head -n1 | sed "s#^$DIR/##" | cut -c1-80))."
      echo "          Một số thư viện tự chặn script (auto-blocking): mở trình duyệt kiểm tra trước khi kết luận."
    fi
  elif [ -n "$gate_hits" ]; then
    consent="gated"
    echo "[có]    CONSENT_GATE   (có dấu hiệu chỉ nạp tracking sau khi đồng ý; cần mở trình duyệt xác nhận, xem 01 mục C)"
    echo "$gate_hits" | sed "s#^$DIR/##" | cut -c1-160 | sed 's/^/          /'
  else
    consent="unknown"
    echo "[?]     CONSENT_GATE   (có tracking nhưng không thấy banner/cơ chế xin đồng ý; cần kiểm tra thủ công)"
  fi
fi
if found TRACKING; then
  preload=false; [ -n "$static_hits" ] && preload=true
  gated=false; [ -n "$gate_hits" ] && gated=true
  record_result TRACKING_PRELOAD "$preload" "$static_hits"
  record_result CONSENT_GATE "$gated" "$gate_hits"
else
  record_result TRACKING_PRELOAD null ""
  record_result CONSENT_GATE null ""
fi


# Thực phẩm bảo vệ sức khỏe: nội dung giới thiệu phải kèm câu khuyến cáo "không phải là thuốc" (05 mục F).
if found HEALTH_SUPPLEMENT; then
  warn="$(grep "${GREP_ARGS[@]}" -e "không phải là thuốc|không phải thuốc" "$DIR" 2>/dev/null | awk '!seen[$0]++' | head -n 2)"
  if [ -n "$warn" ]; then
    record_result HEALTH_WARNING true "$warn"
    echo "[có]    HEALTH_WARNING"
    echo "$warn" | sed "s#^$DIR/##" | cut -c1-160 | sed 's/^/          /'
  else
    record_result HEALTH_WARNING false ""
    echo "[không] HEALTH_WARNING   (có thực phẩm bảo vệ sức khỏe nhưng không thấy câu \"không phải là thuốc\", xem 05 mục F)"
  fi
else
  record_result HEALTH_WARNING null ""
fi

record_result ACCOUNT_DELETE null ""
if [ -n "$platforms" ]; then
  record_result MOBILE_APP true ""
  echo "[có]    MOBILE_APP"
  echo "          $platforms"
  # Chức năng xóa tài khoản chỉ cần kiểm tra khi app có đăng nhập
  if found AUTH; then
    del="$(grep "${GREP_ARGS[@]}" -e 'delete[-_ ]?account|deleteAccount|deleteUser|xóa tài khoản|xoá tài khoản|account[-_ ]deletion' "$DIR" 2>/dev/null | head -n 2)"
    if [ -n "$del" ]; then
      record_result ACCOUNT_DELETE true "$del"
      echo "[có]    ACCOUNT_DELETE"
      echo "$del" | sed "s#^$DIR/##" | cut -c1-160 | sed 's/^/          /'
    else
      record_result ACCOUNT_DELETE false ""
      echo "[không] ACCOUNT_DELETE   (app có đăng nhập nhưng không thấy chức năng xóa tài khoản, xem 09 mục C)"
    fi
  fi
else
  record_result MOBILE_APP false ""
  echo "[không] MOBILE_APP"
fi

# Gợi ý mức theo bảng trong references/00-triage.md
if found AUTH && found MARKETPLACE; then
  level=3; desc="nền tảng/SaaS quy mô. Áp dụng toàn bộ 01-08"
elif found COMMERCE; then
  level=2; desc="bán hàng/TMĐT. Áp dụng 01 + 02 + 04 (thêm 05/06 nếu có quảng cáo, hợp đồng điện tử)"
elif found FORM || found TRACKING || found AUTH || found AI || found PERMISSIONS || found SDK_TRACKING || found ADS_SDK; then
  # Chatbot AI nhận tin nhắn tự do của người dùng và gửi tới bên thứ ba → coi như có thu thập dữ liệu
  level=1; desc="thu thập nhẹ. Áp dụng 01 mục A, B, C"
else
  level=0; desc="tĩnh hoàn toàn. Không cần audit chi tiết"
fi

ai="no";   found AI && ai="yes"
host="no"; found FOREIGN_HOST && host="yes"
app="no";  [ -n "$platforms" ] && app="yes"

echo
echo "Gợi ý: mức $level, $desc"
[ "$ai" = yes ]   && echo "        + có dấu hiệu AI → thêm 07-ai-transparency"
[ "$app" = yes ]  && echo "        + là mobile app ($platforms) → thêm 09-mobile-app"
# Site mức 0 không lưu dữ liệu cá nhân nên nhúng CDN/host nước ngoài không phát sinh nghĩa vụ chuyển dữ liệu
[ "$host" = yes ] && [ "$level" -ge 1 ] && echo "        + có dấu hiệu host/dịch vụ nước ngoài → xem 01 mục D nếu có lưu dữ liệu cá nhân"
if [ "$URL_MODE" = 1 ]; then
  echo
  echo "Các trang đã tải nằm ở: $DIR"
  echo "Đọc trang chính sách trong pages/ để audit nội dung."
  echo "Quét qua URL không thấy được code phía server (chatbot gọi AI qua server, nơi lưu dữ liệu),"
  echo "nên cần xem thêm trực tiếp trên trang, ví dụ có khung chat nào không."
fi
echo
echo "LEVEL=$level AI=$ai FOREIGN_HOST=$host APP=$app TRACKING_CONSENT=$consent"

if [ "$JSON_MODE" = 1 ]; then
  # NUL giữ nguyên dấu nháy/newline; stdin tránh giới hạn độ dài argv với JS lớn.
  printf '%s\0' "$TARGET" "$DIR" "$URL_MODE" "$level" "$ai" "$host" "$app" \
    "$consent" "$platforms" "${RESULTS[@]}" \
    | python3 "$(dirname "$0")/scan-json.py" >&3
fi
