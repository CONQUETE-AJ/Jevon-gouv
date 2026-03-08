#!/usr/bin/env bash
#  Copyright 2021 Collate
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#  http://www.apache.org/licenses/LICENSE-2.0
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${ROOT_DIR}/docker/enterprise/docker-compose.yml"
ENV_EXAMPLE="${ROOT_DIR}/docker/enterprise/.env.example"
ENV_FILE="$ENV_EXAMPLE"
CUSTOM_ENV_FILE=0

COMMAND="up"
WITH_INGESTION=0
CLEAN=0
SEARCH_ENGINE="elasticsearch"
SEARCH_TYPE="elasticsearch"
SEARCH_PROFILE="search-elasticsearch"
SEARCH_HOST="elasticsearch"

usage() {
  cat <<'USAGE'
Usage:
  ./start.sh [up|start|down|stop|restart|logs|ps|pull] [--search elasticsearch|opensearch] [--with-ingestion] [--clean] [--env-file <path>]

Commands:
  up          Start stack in background (default)
  start       Alias of up
  down        Stop services and remove containers
  stop        Stop services
  restart     Restart services
  logs        Stream logs
  ps          Show service status
  pull        Pull latest images

Options:
  --search elasticsearch|opensearch  Choose the search backend (default: elasticsearch)
  --with-ingestion                  Enable Airflow ingestion runtime
  --clean                           Clean all volumes before up/start
  --env-file                        Env file to load (default: docker/enterprise/.env.example)
  --help, -h                        Show this help
USAGE
}

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker not found in PATH"
  exit 1
fi

while (( "$#" )); do
  case "$1" in
  up|start|down|stop|restart|logs|ps|pull)
      COMMAND="$1"
      shift
      ;;
    --with-ingestion)
      WITH_INGESTION=1
      shift
      ;;
    --clean)
      CLEAN=1
      shift
      ;;
    --search)
      [[ "${2:-}" != "" ]] || { echo "--search requires elasticsearch or opensearch"; usage; exit 2; }
      SEARCH_ENGINE="$2"
      shift 2
      ;;
    --search=*)
      SEARCH_ENGINE="${1#--search=}"
      shift
      ;;
    --env-file)
      [[ "${2:-}" != "" ]] || { echo "--env-file requires a path"; usage; exit 2; }
      ENV_FILE="$2"
      CUSTOM_ENV_FILE=1
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 2
      ;;
  esac
done

if (( CUSTOM_ENV_FILE == 0 )); then
  LEGACY_ENV_FILE="${ROOT_DIR}/docker/enterprise/.env"
  if [[ -f "$LEGACY_ENV_FILE" ]]; then
    if grep -qE 'docker\.getcollate\.io/openmetadata/(server|ingestion|postgresql):1\.12\.0-SNAPSHOT' "$LEGACY_ENV_FILE"; then
      echo "Ignoring legacy docker/enterprise/.env with unavailable snapshot images."
      echo "Using docker/enterprise/.env.example."
    else
      ENV_FILE="$LEGACY_ENV_FILE"
    fi
  fi
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Env file not found: $ENV_FILE"
  exit 1
fi

case "$SEARCH_ENGINE" in
  elasticsearch)
    SEARCH_TYPE="elasticsearch"
    SEARCH_PROFILE="search-elasticsearch"
    SEARCH_HOST="elasticsearch"
    ;;
  opensearch)
    SEARCH_TYPE="opensearch"
    SEARCH_PROFILE="search-opensearch"
    SEARCH_HOST="opensearch"
    ;;
  *)
    echo "Unsupported search engine: $SEARCH_ENGINE"
    echo "Allowed values: elasticsearch, opensearch"
    exit 2
    ;;
esac

COMPOSE_ARGS=(
  -f "$COMPOSE_FILE"
  --env-file "$ENV_FILE"
  --project-name openmetadata-enterprise
  --profile "$SEARCH_PROFILE"
)

if (( WITH_INGESTION == 1 )); then
  COMPOSE_ARGS+=(--profile ingestion)
fi

export SEARCH_TYPE SEARCH_HOST

if [[ "$COMMAND" == "up" || "$COMMAND" == "start" || "$COMMAND" == "restart" || "$COMMAND" == "pull" ]]; then
  if (( CLEAN == 1 )); then
    docker compose "${COMPOSE_ARGS[@]}" down -v
  fi
fi

case "$COMMAND" in
  up)
    docker compose "${COMPOSE_ARGS[@]}" up -d
    ;;
  start)
    docker compose "${COMPOSE_ARGS[@]}" up -d
    ;;
  down)
    docker compose "${COMPOSE_ARGS[@]}" down
    ;;
  stop)
    docker compose "${COMPOSE_ARGS[@]}" stop
    ;;
  restart)
    docker compose "${COMPOSE_ARGS[@]}" restart
    ;;
  logs)
    docker compose "${COMPOSE_ARGS[@]}" logs -f
    ;;
  ps)
    docker compose "${COMPOSE_ARGS[@]}" ps
    ;;
  pull)
    docker compose "${COMPOSE_ARGS[@]}" pull
    ;;
  *)
    usage
    exit 2
    ;;
esac
