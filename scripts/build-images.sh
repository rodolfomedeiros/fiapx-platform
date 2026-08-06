#!/usr/bin/env bash
# Constrói as imagens dos quatro serviços com as tags que os manifestos esperam.
#
#   ./scripts/build-images.sh
#
# Em cluster local (kind/minikube), carregue as imagens depois de construir:
#   kind load docker-image fiapx/auth-service:latest
#   minikube image load fiapx/auth-service:latest
set -euo pipefail

raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tag="${TAG:-latest}"

servicos=(
  "auth-service:fiapx-auth-service"
  "video-management-service:fiapx-video-management-service"
  "video-processor-worker:fiapx-video-processor-worker"
  "notification-service:fiapx-notification-service"
)

for servico in "${servicos[@]}"; do
  imagem="fiapx/${servico%%:*}:${tag}"
  diretorio="${raiz}/${servico##*:}"
  if [[ ! -d "$diretorio" ]]; then
    echo "pulando ${imagem}: ${diretorio} não existe neste checkout" >&2
    continue
  fi
  echo "==> ${imagem}"
  docker build -t "$imagem" "$diretorio"
done

echo "pronto: $(docker images --format '{{.Repository}}:{{.Tag}}' | grep -c '^fiapx/') imagens fiapx/*"
