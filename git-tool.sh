#!/bin/bash
# see https://docs.github.com/en/developers/apps/building-github-apps/authenticating-with-github-apps
# Usage:
# git-tool jwt   <app-id> <private-key>
# git-tool token <access-token-url> [jwt (if not provided, this will be read from stdin)]
# Example: ./git-tool.sh jwt 309595 /path/to/my-private-key.pem | ./git-tool.sh token  https://api.github.com/app/installations/35633707/access_tokens

jwt() {
  _app=$1
  _key=$2
  _hdr=$(printf '{"alg":"RS256","typ":"JWT"}' | base64 | tr '+/' '-_' | tr -d '=')
  _pay=$(printf '{"iss":"%s","iat":%d,"exp":%d}' \
	  $_app \
	  $(expr $(date +%s) - 60) \
	  $(expr $(date +%s) + 300) \
	  | base64 | tr '+/' '-_' | tr -d '=')
  _dgst=$(printf '%s.%s' $_hdr $_pay | openssl dgst -sha256 -binary -sign $_key | base64 -w0 | tr '+/' '-_' | tr -d '=')
  if [ $? != 0 ]; then
    return 1
  fi
  printf "%s.%s.%s\n" $_hdr  $_pay $_dgst
}

token() {
  _url=$1
  _jwt=$2
  _rtn=$(curl -s -f --show-error -X POST -H "Authorization: Bearer ${_jwt}" -H "Accept: application/vnd.github+json" $_url)
  if [ $? != 0 ]; then
    echo "$_rtn" >&2
    return 1
  fi
  echo "$_rtn" | jq -r '.token'
}

case $1 in
  jwt)
    if [ -z "$2" ]; then
      echo "git-tool.jwt: github app ID required" >&2
      exit 1
    fi
    if [ -z "$3" ]; then
      echo "git-tool.jwt: private key required" >&2
      exit 1
    fi
    if [ -f "$3" ]; then
      jwt $2 $3
    else
      echo "git-tool.jwt: private key \"$3\" not found" >&2
      exit 1
    fi
    ;;
  token)
    if [ -z "$2" ]; then
      echo "git-tool.token: token URL required" >&2
      exit 1
    fi
    if [ -z "$3" ]; then #no arg passed - read from stdin
      while IFS= read line; do
        if [ -z $line ]; then
          echo "git-tool.token: empty JWT input" >&2
	  exit 1
        else
          token $2 $line
          exit $?
        fi
      done
      echo "git-tool.token: no JWT passed as an arg or via stdin" >&2
      exit 1
    else
      token $2 $3
      exit $?
    fi
    ;;
  *)
    printf "git-tool: unknown action \"$1\"\nvalid actions are:\njwt\ntoken\n" >&2
    exit 1
    ;;
esac
