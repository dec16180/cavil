#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Upload an artifact to Cavil for review via the bot API (POST /packages/upload).
#
#   tools/upload.sh [-n name] [-p priority] [-l external_link] <file|directory|docker:image>
#
# Files are uploaded as is, directories are packed into a tarball first, and "docker:<image>" exports a
# local container image with "docker save". The server and bot token default to the staging instance and
# can be changed with CAVIL_URL and CAVIL_TOKEN.

set -euo pipefail

url=${CAVIL_URL:-http://localhost:3000}
token=${CAVIL_TOKEN:-staging:123}
name=''
priority=5
link=''

usage() {
  sed -n '6,12s/^# \{0,1\}//p' "$0" >&2
  exit 1
}

while getopts 'n:p:l:h' opt; do
  case $opt in
    n) name=$OPTARG ;;
    p) priority=$OPTARG ;;
    l) link=$OPTARG ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))
[ $# -eq 1 ] || usage
src=$1

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

if [[ $src == docker:* ]]; then
  image=${src#docker:}
  file=$tmp/image.tar
  echo "Exporting container image $image" >&2
  docker save -o "$file" "$image"
  default_name=${image%%:*}
elif [ -d "$src" ]; then
  file=$tmp/source.tar.gz
  echo "Packing directory $src" >&2
  tar -czf "$file" -C "$(dirname "$src")" "$(basename "$src")"
  default_name=$(basename "$src")
elif [ -f "$src" ]; then
  file=$src
  default_name=$(basename "$src")
  default_name=${default_name%%.tar*}
  default_name=${default_name%.*}
else
  echo "Not a file, directory or docker:<image>: $src" >&2
  exit 1
fi

# Package names may only contain letters, digits, "-" and "."
name=${name:-$default_name}
name=$(printf '%s' "$name" | tr -c 'A-Za-z0-9.-' '-')

checksum=$(md5sum "$file" | cut -d' ' -f1)
echo "Uploading $(du -h "$file" | cut -f1) as \"$name\" to $url" >&2

args=(-F "name=$name" -F "priority=$priority" -F "checksum=$checksum" -F "tarball=@$file")
[ -n "$link" ] && args+=(-F "external_link=$link")

curl -sS --fail-with-body -X POST "$url/packages/upload" -H "Authorization: Token $token" "${args[@]}"
echo
