#!/bin/sh
set -eu

cd "$(dirname "$0")"

for f in forgejo/secrets.env woodpecker/secrets.env; do
    [ -f "$f" ] || { echo "missing $f, copy it from $f.template and fill it in" >&2; exit 1; }
done

create() {
    kubectl create secret generic "$1" --from-env-file="$2" \
        --dry-run=client -o yaml | kubectl apply -f -
}

create forgejo-db forgejo/secrets.env
create forgejo forgejo/secrets.env
create woodpecker-db woodpecker/secrets.env
create woodpecker woodpecker/secrets.env
