#!/bin/bash
# 配布物の検査。リポのルートで実行する: bash tools/check.sh
#   1. 公開スクリプトの文法（bash -n）
#   2. 公開 URL の組み立て（--dry-run。surge は呼ばない）
#   3. docs/publishing.md が引いている行が、スクリプト・雛形に今もそのまま有るか
set -u

DEPLOY=".claude/skills/creating-visual-explainers/scripts/deploy-diagram.sh"
DOC="docs/publishing.md"
FAIL=0

fail() { echo "NG: $*" >&2; FAIL=1; }

# 1. 文法
bash -n "$DEPLOY" || fail "$DEPLOY の文法エラー"

# 2. URL の組み立て
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/output"
echo '<html></html>' > "$WORK/output/git.html"
ROOT="$PWD"
(
    cd "$WORK" || exit 1
    out="$(bash "$ROOT/$DEPLOY" output/git.html --name "Taro" --dry-run)" || { echo "NG: dry-run が失敗した" >&2; exit 1; }
    echo "$out" | grep -qE 'https://diagram-git-taro-[a-z0-9]{4}\.surge\.sh$' || { echo "NG: URL の形が違う: $out" >&2; exit 1; }
    [ ! -e .diagram-tool ] || { echo "NG: dry-run なのに .diagram-tool を作った" >&2; exit 1; }
    mkdir .diagram-tool && echo taro > .diagram-tool/name
    printf 'git\tdiagram-git-taro-k3x9.surge.sh\n' > .diagram-tool/domains.tsv
    out="$(bash "$ROOT/$DEPLOY" output/git.html --dry-run)"
    echo "$out" | grep -qF 'https://diagram-git-taro-k3x9.surge.sh' || { echo "NG: 同じ図なのに URL を使い回していない: $out" >&2; exit 1; }
    out="$(bash "$ROOT/$DEPLOY" output/git.html --new-url --dry-run)"
    echo "$out" | grep -qF 'k3x9' && { echo "NG: --new-url なのに同じ URL: $out" >&2; exit 1; }
    bash "$ROOT/$DEPLOY" output/git.html --name 名前 --dry-run >/dev/null 2>&1 && { echo "NG: ローマ字でない名前を通した" >&2; exit 1; }
    exit 0
) || FAIL=1

# 3. 資料の引用（<!-- quote: パス --> の直後のコードブロックの各行が、そのファイルに有るか）
src=""; in_block=0; want_block=0
while IFS= read -r line; do
    if [ "$in_block" = 1 ]; then
        if [[ "$line" == '```'* ]]; then in_block=0; continue; fi
        [ -n "$line" ] || continue
        grep -qF -- "$line" "$src" || fail "$DOC の引用が $src に見つからない: $line"
        continue
    fi
    if [[ "$line" =~ ^\<!--\ quote:\ (.+)\ --\>$ ]]; then
        src="${BASH_REMATCH[1]}"; want_block=1
        [ -f "$src" ] || fail "$DOC が引くファイルが無い: $src"
    elif [ "$want_block" = 1 ] && [[ "$line" == '```'* ]]; then
        in_block=1; want_block=0
    fi
done < "$DOC"

# robots.txt の中身: 資料の <!-- robots-txt --> のブロックと、スクリプトが実際に書く中身
fmt="$(sed -n 's/^ *printf "\(User-agent[^"]*\)" > "\$TEMP_DIR\/robots.txt"$/\1/p' "$DEPLOY")"
[ -n "$fmt" ] || fail "$DEPLOY に robots.txt を書く行が見つからない"
actual="$(printf "$fmt")"
documented="$(awk '/^<!-- robots-txt -->$/{f=1; next} f && /^```/{if (b) exit; b=1; next} f && b' "$DOC")"
[ "$actual" = "$documented" ] || fail "$DOC の robots.txt の中身がスクリプトとずれている"

if [ "$FAIL" = 0 ]; then echo "OK: すべての検査に通った"; fi
exit "$FAIL"
