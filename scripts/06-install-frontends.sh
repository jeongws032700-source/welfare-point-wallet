#!/usr/bin/env bash
set -e
# 1GB 서버: next build 힙 제한으로 OOM 방지
export NODE_OPTIONS=--max-old-space-size=512
for APP in frontend-admin frontend-mobile-view frontend-mobile-action; do
  echo "install/build $APP"
  cd "$APP"
  npm install
  npm run build
  cd ..
done
