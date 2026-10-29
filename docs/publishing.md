# 図解を公開すると何が起きるか

> この資料は**答え合わせ用**です。先に自分で「surge.sh に公開すると、誰が見られるのか」「検索に出るのか」「消したらどうなるのか」を調べてから読んでください。

## 結論（3 つ）

1. **中身は検索に出ない** — 検索ロボットに「読まないで」「載せないで」と頼む仕掛けを、道具が 2 つ入れている
2. **URL を知っている人は見られる** — 鍵はかかっていない。URL がわかれば、だれでもブラウザで開ける
3. **消しても写しは消せない** — 公開したページを消せるのは、公開した本人の surge アカウントだけ。誰かが保存した写しやスクショは消せない

以下、それぞれの理由を、道具（スクリプトと雛形）の中身を引きながら説明します。

## 公開するときに道具がしていること

「この図解を公開して」と頼むと、AI は `.claude/skills/creating-visual-explainers/scripts/deploy-diagram.sh` を動かします。中でしていることは次の 3 つです。

**① 図解を `index.html` という名前で、一時フォルダにコピーする**

<!-- quote: .claude/skills/creating-visual-explainers/scripts/deploy-diagram.sh -->
```bash
cp "$HTML_FILE" "$TEMP_DIR/index.html"
```

**② 同じフォルダに `robots.txt` を置く**（後で説明する検索よけ その 2）

<!-- quote: .claude/skills/creating-visual-explainers/scripts/deploy-diagram.sh -->
```bash
printf "User-agent: *\nDisallow: /\n" > "$TEMP_DIR/robots.txt"
```

**③ そのフォルダを surge.sh に送る**

<!-- quote: .claude/skills/creating-visual-explainers/scripts/deploy-diagram.sh -->
```bash
if ! npx --yes surge "$TEMP_DIR" --domain "$DOMAIN" </dev/null; then
```

`--domain` に渡す公開先の名前は、次のように組み立てます。

<!-- quote: .claude/skills/creating-visual-explainers/scripts/deploy-diagram.sh -->
```bash
    RAND="$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c 4)"
    DOMAIN="diagram-${SLUG}-${NAME}-${RAND}.surge.sh"
```

たとえば `diagram-git-ueda-k3x9.surge.sh` です（`git` = 図の題名、`ueda` = 自分の名前、`k3x9` = ランダムな 4 文字）。ランダムな 4 文字は、題名から URL を当てられにくくするためと、同じ題名の図をほかの人が公開したときに名前がぶつからないようにするためのものです。**パスワードの代わりにはなりません**（URL が伝われば、誰でも開けます）。

## 検索よけ その 1: 雛形 HTML の `<meta name="robots">`

図解の雛形 `.claude/skills/creating-visual-explainers/references/base.html` の頭には、次の 2 行が入っています。

<!-- quote: .claude/skills/creating-visual-explainers/references/base.html -->
```html
  <meta name="robots" content="noindex, nofollow, noarchive, nosnippet, noimageindex">
  <meta name="googlebot" content="noindex, nofollow">
```

これは、**ページを読みに来た検索ロボットへの手紙**です。

| 言葉 | 意味 |
|---|---|
| `noindex` | このページを検索結果に載せないで |
| `nofollow` | このページの中のリンクをたどらないで |
| `noarchive` | このページの写し（キャッシュ）を残さないで |
| `nosnippet` | 検索結果に本文の抜き出しを出さないで |
| `noimageindex` | このページの画像を画像検索に載せないで |

2 行目の `googlebot` は、同じお願いを Google の検索ロボットあてに重ねて書いたものです。

ポイントは「**ページを読みに来たら**」効く、という点です。手紙はページの中に書いてあるので、ページを読まないロボットには届きません。

## 検索よけ その 2: 一緒に置く `robots.txt`

公開するフォルダには、図解と一緒に `robots.txt` というファイルを置いています（上の ②）。中身は次の 2 行です。

<!-- robots-txt -->
```text
User-agent: *
Disallow: /
```

- `User-agent: *` … すべての検索ロボットへ
- `Disallow: /` … このサイトのどのページも読みに来ないで

`robots.txt` は、サイトの**入口に貼る張り紙**です。行儀のよい検索ロボットは、ページを読む前にまずこの張り紙を見て、「読まないで」と書いてあればページを読みません。

## 2 つを合わせると、どうなるか（ここが大事）

張り紙（`robots.txt`）で断られたロボットは、**ページを読みません。だから、ページの中の手紙（`noindex`）も読みません。**

その結果、次のことが起こりえます。

- **中身は検索に出ない** … ロボットはページを読んでいないので、本文も画像も検索の材料になりません
- **URL だけが検索結果に出ることはある** … どこか公開の場所（ブログ、SNS、公開の掲示板など）に URL が貼られると、検索エンジンは「こういう URL がある」ことだけは知ります。その URL が、中身の説明なし（「このページの情報はありません」のような表示）で検索結果に出ることはありえます

もう一つ。`robots.txt` も `<meta name="robots">` も**お願い**であって、**鍵ではありません**。行儀のよい検索ロボットは守りますが、守らないプログラムを止める力はありません。

## URL を知っている人は見られる

surge.sh に置いたページには、パスワードなどの鍵はかかっていません。URL がわかれば、だれでもブラウザで開けます。

広がり方は、たいてい次の道です。

1. あなたが Slack などで URL を共有する
2. 受け取った人が、別の人に転送したり、別のチャンネルやメールに貼ったりする
3. それがいつか、誰でも見られる場所（公開の SNS、ブログ、公開の掲示板など）に貼られる

Slack などに URL を貼ると、図解の題名と説明文がプレビューとして表示されることもあります（雛形に `og:title` と `og:description` が入っているため）。

だから:

- **公開する図に、鍵（API キー、パスワード、トークンなど）は絶対に書かない。** 鍵は見える場所に貼らず、`.env` などの手元のファイルに置く
- **仕事の情報を載せるかどうか**は、各自と会社が判断する。迷ったら載せずに、手元の HTML や PDF で共有する

## 消しても写しは消せない

公開したページは、次で消せます。

```bash
npx surge teardown diagram-git-ueda-k3x9.surge.sh
```

ただし、

- 消せるのは、**そのページを公開した本人の surge アカウントだけ**です（ほかの人は消せません。逆に、ほかの人の公開も消せません）
- 消えるのは **surge に置いた本体だけ**です。誰かが保存した HTML、スクリーンショット、転送先のメッセージに残った内容は消せません

「公開したら、もう戻せない部分がある」と考えて、載せる内容を決めてください。

---

この資料が引いているスクリプトや雛形の行は、`tools/check.sh` が本物と一致しているかを確かめています（スクリプトを直したのに資料が古いまま、を防ぐため）。
