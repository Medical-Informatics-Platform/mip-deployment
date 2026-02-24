#!/bin/env bash
set -a
source ./.env
set +a

docker compose down -v
docker compose up -d
