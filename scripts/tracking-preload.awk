# Đọc trọn thẻ mở, kể cả khi src và type nằm ở các dòng khác nhau.
# Vẫn giữ file:dòng gốc cho bằng chứng; đây là heuristic, không phải HTML parser.
BEGIN { RS = ">"; line = 1 }
{
  record = $0
  start = match(tolower(record), /<script[[:space:]]/)
  if (start) {
    prefix = substr(record, 1, start - 1)
    tag_line = line + gsub(/\n/, "", prefix)
    tag = substr(record, start)
    lower = tolower(tag)
    if (lower ~ /[[:space:]]src[[:space:]]*=[[:space:]]*["'][^"']*(googletagmanager\.com|google-analytics\.com|connect\.facebook\.net|analytics\.tiktok\.com|clarity\.ms|hotjar|cdn\.segment\.com)/ &&
        lower !~ /[[:space:]]type[[:space:]]*=[[:space:]]*["']text\/plain["']/) {
      gsub(/[[:space:]]+/, " ", tag)
      print FILENAME ":" tag_line ":" tag ">"
    }
  }
  line += gsub(/\n/, "", record)
}
