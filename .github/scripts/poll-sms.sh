#!/bin/bash
# 轮询 ntfy.sh 获取6位短信验证码
# 环境变量：NTFY_TOPIC（必须）、MAX_WAIT（可选，默认300秒）

MAX_WAIT=${MAX_WAIT:-300}
INTERVAL=5
ATTEMPTS=$(( MAX_WAIT / INTERVAL ))

echo "[SMS] 开始等待短信验证码，Topic: ${NTFY_TOPIC}..." >&2

for i in $(seq 1 $ATTEMPTS); do
  # 拉取最近3分钟内的消息
  response=$(curl -sf --max-time 10 \
    "https://ntfy.sh/${NTFY_TOPIC}/json?poll=1&since=3m" 2>/dev/null || true)

  if [ -n "$response" ]; then
    # 从 JSON 消息中提取6位数字验证码
    code=$(echo "$response" | python3 - <<'PYEOF'
import sys, re, json

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        msg = json.loads(line)
        text = msg.get('message', '') + ' ' + msg.get('title', '')
        m = re.search(r'\b([0-9]{6})\b', text)
        if m:
            print(m.group(1))
            sys.exit(0)
    except Exception:
        pass
PYEOF
    )

    if [ -n "$code" ]; then
      echo "[SMS] 获取到验证码！" >&2
      echo "$code"
      exit 0
    fi
  fi

  echo "[SMS] 等待中... ($i/$ATTEMPTS)" >&2
  sleep $INTERVAL
done

echo "[SMS] 超时：${MAX_WAIT}秒内未收到验证码" >&2
exit 1
