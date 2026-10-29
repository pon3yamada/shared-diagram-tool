#!/bin/bash
# 図解 HTML を surge.sh に公開する。
#
# 使い方: deploy-diagram.sh <HTMLファイル> [スラッグ] [--name 名前] [--new-url] [--dry-run]
#
# 公開 URL の形: https://diagram-<スラッグ>-<名前>-<ランダム4文字>.surge.sh
#   - 名前: URL に入れる自分の名前（ローマ字）。初回に --name で渡すと
#           .diagram-tool/name に覚え、次からは省略できる
#   - ランダム4文字: 題名から URL を当てられないように、また同じ題名の図を
#           別の人が公開しても surge の名前がぶつからないように付ける
#   - 同じスラッグの図を公開し直すと、.diagram-tool/domains.tsv に覚えた
#     同じ URL を使い回す（--new-url で新しい URL に変える）
#   - --dry-run: URL を組み立てて表示するだけで、surge は呼ばない・何も保存しない
set -e

STATE_DIR=".diagram-tool"
NAME_FILE="$STATE_DIR/name"
DOMAINS_FILE="$STATE_DIR/domains.tsv"

HTML_FILE=""
SLUG=""
NAME=""
NEW_URL=false
DRY_RUN=false

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

usage() {
    echo "使い方: deploy-diagram.sh <HTMLファイル> [スラッグ] [--name 名前] [--new-url] [--dry-run]" >&2
    exit 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --name) NAME="${2:-}"; [ -n "$NAME" ] || usage; shift 2 ;;
        --new-url) NEW_URL=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        -*) usage ;;
        *)
            if [ -z "$HTML_FILE" ]; then HTML_FILE="$1"
            elif [ -z "$SLUG" ]; then SLUG="$1"
            else usage
            fi
            shift ;;
    esac
done
[ -n "$HTML_FILE" ] || usage

# URL に使える文字（英小文字・数字・ハイフン）だけを残す
to_label() {
    printf '%s' "$1" | tr 'A-Z' 'a-z' | LC_ALL=C sed -e 's/[^a-z0-9-]/-/g' -e 's/--*/-/g' -e 's/^-//' -e 's/-$//' | cut -c "1-$2" | sed 's/-$//'
}

if [ ! -f "$HTML_FILE" ]; then
    echo -e "${RED}エラー: $HTML_FILE が見つかりません${NC}" >&2
    echo "先に図解を生成してください。" >&2
    exit 1
fi

# スラッグを省略したら HTML のファイル名（output/git.html → git）を使う
[ -n "$SLUG" ] || SLUG="$(basename "$HTML_FILE" .html)"
SLUG="$(to_label "$SLUG" 30)"
[ -n "$SLUG" ] || SLUG="diagram"

# 名前: --name で渡されたもの → 前に覚えたもの の順に使う
if [ -z "$NAME" ] && [ -f "$NAME_FILE" ]; then
    NAME="$(head -n 1 "$NAME_FILE")"
fi
NAME="$(to_label "$NAME" 16)"
if [ -z "$NAME" ]; then
    echo -e "${RED}エラー: URL に入れる名前が決まっていません${NC}" >&2
    echo "ローマ字の名前を --name で渡してください（例: --name ueda）。一度渡せば次からは省略できます。" >&2
    exit 1
fi

# 同じスラッグを前に公開していれば、その URL を使い回す
DOMAIN=""
if [ "$NEW_URL" = false ] && [ -f "$DOMAINS_FILE" ]; then
    DOMAIN="$(awk -F '\t' -v s="$SLUG" '$1 == s { d = $2 } END { print d }' "$DOMAINS_FILE")"
fi
if [ -z "$DOMAIN" ]; then
    RAND="$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c 4)"
    DOMAIN="diagram-${SLUG}-${NAME}-${RAND}.surge.sh"
fi

if [ "$DRY_RUN" = true ]; then
    echo "公開先（dry-run・surge は呼んでいません）: https://${DOMAIN}"
    exit 0
fi

if ! command -v node &>/dev/null; then
    echo -e "${RED}エラー: Node.js がインストールされていません${NC}" >&2
    echo "Node.js をインストールしてから、もう一度試してください。" >&2
    exit 1
fi

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

cp "$HTML_FILE" "$TEMP_DIR/index.html"
printf "User-agent: *\nDisallow: /\n" > "$TEMP_DIR/robots.txt"

# HTML と同じ階層に assets/ がある場合は一緒に公開する
HTML_DIR="$(dirname "$HTML_FILE")"
if [ -d "$HTML_DIR/assets" ]; then
    cp -R "$HTML_DIR/assets" "$TEMP_DIR/assets"
fi

mkdir -p "$STATE_DIR"
printf '%s\n' "$NAME" > "$NAME_FILE"

echo -e "${YELLOW}公開中...${NC}"
# 入力を受け付けない（未ログインのときにメール・パスワードを聞かれて止まるのを防ぐ）
if ! npx --yes surge "$TEMP_DIR" --domain "$DOMAIN" </dev/null; then
    echo -e "${RED}公開できませんでした${NC}" >&2
    echo "surge のアカウントの「最初の設定」がまだなら、自分のターミナルのアプリで npx surge login を実行してから、もう一度試してください。" >&2
    exit 1
fi

if ! grep -qxF "$(printf '%s\t%s' "$SLUG" "$DOMAIN")" "$DOMAINS_FILE" 2>/dev/null; then
    printf '%s\t%s\n' "$SLUG" "$DOMAIN" >> "$DOMAINS_FILE"
fi

touch deploy-history.log
echo "$(date '+%Y-%m-%d %H:%M:%S') | https://${DOMAIN}" >> deploy-history.log

echo ""
echo -e "${GREEN}完了！${NC}"
echo "URL: https://${DOMAIN}"

if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "https://${DOMAIN}" | pbcopy
    echo -e "${GREEN}URLをクリップボードにコピーしました${NC}"
    open "https://${DOMAIN}"
elif command -v clip.exe &>/dev/null; then
    echo -n "https://${DOMAIN}" | clip.exe
    echo -e "${GREEN}URLをクリップボードにコピーしました${NC}"
    start "https://${DOMAIN}" 2>/dev/null || true
elif command -v xdg-open &>/dev/null; then
    xdg-open "https://${DOMAIN}"
fi

echo -e "${YELLOW}削除するとき: npx surge teardown ${DOMAIN}${NC}"
