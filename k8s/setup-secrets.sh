#!/bin/sh
set -eu

cd "$(dirname "$0")"

usage() {
    echo "usage: $0 [forgejo|woodpecker]" >&2
    exit 1
}

create() {
    kubectl create secret generic "$1" --from-env-file="$2" \
        --dry-run=client -o yaml | kubectl apply -f -
}

setup() {
    app=$1
    file=$app/secrets.env
    [ -f "$file" ] || { echo "missing $file, copy it from $file.template and fill it in" >&2; exit 1; }
    create "$app-db" "$file"
    create "$app" "$file"
}

case ${1:-all} in
    forgejo|woodpecker) setup "$1" ;;
    all) setup forgejo; setup woodpecker ;;
    *) usage ;;
esac
