#!/usr/bin/env bash
set -e

# 1GB 서버용 스왑 설정 (빌드/런타임 OOM 방지). 1회만 실행하면 됨.
if swapon --show | grep -q '/swapfile'; then
  echo "swap already active:"
  swapon --show
  free -h
  exit 0
fi

sudo fallocate -l 3G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=3072
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

if ! grep -q '/swapfile' /etc/fstab; then
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
fi

# swappiness 낮춰서 RAM 우선 사용 (스왑은 피크 때만)
sudo sysctl vm.swappiness=10 >/dev/null

echo "swap ready:"
swapon --show
free -h
