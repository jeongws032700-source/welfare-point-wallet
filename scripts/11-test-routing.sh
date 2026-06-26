#!/usr/bin/env bash
set -e
curl -s -A "Mozilla/5.0 Windows" http://localhost:3000 | grep -o "복지포인트 운영" || true
curl -s -A "Mozilla/5.0 iPhone Mobile" http://localhost:3000 | grep -o "사내 복지포인트" || true
curl -s -A "Mozilla/5.0 iPhone Mobile" http://localhost:3000/action | grep -o "포인트 이용" || true
curl -s http://localhost:3000/api/health
