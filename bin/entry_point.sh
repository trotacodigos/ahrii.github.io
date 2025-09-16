#!/usr/bin/env bash
set -Eeuo pipefail

echo "[entrypoint] starting…"

CONFIG_FILE="_config.yml"
HOST="0.0.0.0"
PORT="${PORT:-8080}"
LRPORT="${LRPORT:-35729}"

JEKYLL_PID=""

cleanup() {
  if [[ -n "${JEKYLL_PID}" ]] && kill -0 "${JEKYLL_PID}" 2>/dev/null; then
    echo "[entrypoint] stopping jekyll (pid=${JEKYLL_PID})"
    kill -TERM "${JEKYLL_PID}" || true
    wait "${JEKYLL_PID}" || true
  fi
}
trap cleanup EXIT INT TERM

manage_gemfile_lock() {
  git config --global --add safe.directory '*' || true
  if command -v git >/dev/null 2>&1 && [[ -f Gemfile.lock ]]; then
    if git ls-files --error-unmatch Gemfile.lock >/dev/null 2>&1; then
      echo "[entrypoint] Gemfile.lock is tracked; keeping it"
      git restore Gemfile.lock 2>/dev/null || true
    else
      echo "[entrypoint] Gemfile.lock is untracked; removing it"
      rm -f Gemfile.lock
    fi
  fi
}

prepare_bundler() {
  # vendor/bundle 캐시 활용
  bundle check || bundle install --path vendor/bundle || true
}

check_imagemagick() {
  if ! command -v convert >/dev/null 2>&1; then
    echo "[entrypoint] WARNING: ImageMagick(convert) not found."
    echo "  - Responsive WebP 생성이 비활성화됩니다. (imagemagick.enabled: false 권장)"
  else
    convert -version | head -n1
  fi
}

start_jekyll() {
  manage_gemfile_lock
  prepare_bundler
  check_imagemagick

  echo "[entrypoint] launching jekyll on ${HOST}:${PORT} (livereload ${LRPORT})"
  # --trace/--verbose는 필요시 환경변수로 토글
  bundle exec jekyll serve \
    --host "${HOST}" \
    --port "${PORT}" \
    --livereload \
    --livereload-port "${LRPORT}" \
    --watch \
    --force_polling \
    --verbose \
    --trace &
  JEKYLL_PID=$!
  echo "[entrypoint] jekyll pid=${JEKYLL_PID}"
}

restart_jekyll() {
  if [[ -n "${JEKYLL_PID}" ]] && kill -0 "${JEKYLL_PID}" 2>/dev/null; then
    echo "[entrypoint] restarting jekyll (pid=${JEKYLL_PID})"
    kill -TERM "${JEKYLL_PID}" || true
    wait "${JEKYLL_PID}" || true
  fi
  start_jekyll
}

# 1) 최초 기동
start_jekyll

# 2) _config.yml 변경 감지 → 재시작 (디바운스 0.5s)
while true; do
  inotifywait -q -e modify,move,create,delete "${CONFIG_FILE}" || true
  # 짧은 시간 내 다발 이벤트 묶기
  sleep 0.5
  echo "[entrypoint] change detected in ${CONFIG_FILE}"
  restart_jekyll
done