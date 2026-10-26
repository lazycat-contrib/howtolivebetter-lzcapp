#!/usr/bin/env bash
# 高性价比人生指南 静态站构建：克隆上游 → 挑选站点所需文件 → 组装 site/
# 由 LazyCat GitHub Action 的 buildscript 在每次构建时执行
set -euo pipefail

VERSION="${LAZYCAT_VERSION:-${VERSION:-}}"
echo "==> building howtolivebetter version: ${VERSION:-<default branch>}"

# 上游没有版本 tag（只有 epub-latest 这类滚动 tag），版本只用于标注与商店记录
UPSTREAM_REF=""
if [ -n "$VERSION" ]; then
  UPSTREAM_REF="v${VERSION}"
fi

rm -rf upstream site

clone_upstream() {
  local ref_args=()
  if [ -n "$1" ]; then
    ref_args=(--branch "$1")
  fi
  git clone --depth 1 "${ref_args[@]}" \
    https://github.com/eternity4719/howtolivebetter.git upstream
}

CLONE_OK=0
if [ -n "$UPSTREAM_REF" ]; then
  echo "==> cloning upstream ref ${UPSTREAM_REF}"
  if clone_upstream "$UPSTREAM_REF" 2>&1 | sed 's/^/    /'; then
    CLONE_OK=1
  else
    echo "    ref ${UPSTREAM_REF} unavailable, falling back to the default branch"
    rm -rf upstream
  fi
fi
if [ "$CLONE_OK" != "1" ]; then
  echo "==> cloning upstream default branch"
  clone_upstream ""
fi
cd upstream
echo "    upstream commit: $(git rev-parse --short HEAD)"

# ---- 组装静态站 ----
# index.html 与 selfcheck.html 用 fetch 读取 README.md 和 book/*.md（文件名从
# README 的目录链接里解析），所以这些文件必须与页面同级。
echo "==> assembling the static site"
SITE_DIR="$(cd .. && pwd)/site"
rm -rf "$SITE_DIR"
mkdir -p "$SITE_DIR"
cp -R index.html selfcheck.html README.md updates.json og.png robots.txt sitemap.xml "$SITE_DIR/"
cp -R book ads docs "$SITE_DIR/"

# 把正文文件名改成纯 ASCII，并同步改写 README 里的链接。
# 页面用 fetch(路径) 读正文，路径来自 README 里的链接；中文路径要经过
# URL 编码，能否被静态文件后端正确还原没有保证，所以这里直接在打包时
# 换成 ASCII 文件名。链接的文字（章节标题）保持中文不变。
echo "==> renaming the book files to ASCII names"
python3 - "$SITE_DIR" <<'PY'
import os, re, sys

site = sys.argv[1]
readme = os.path.join(site, "README.md")
book_dir = os.path.join(site, "book")
docs_dir = os.path.join(site, "docs")

with open(readme, encoding="utf-8") as f:
    text = f.read()

# 取出 README 里引用的 book 路径，保持出现顺序
paths = sorted(set(re.findall(r"\]\((book/[^)]+\.md)\)", text)))
if len(paths) < 30:
    raise SystemExit(f"ERROR: only {len(paths)} book links found in README.md")

renames = {}
for path in paths:
    name = os.path.basename(path)
    stem, ext = os.path.splitext(name)
    # "01-不要早死" -> "01"（章节号）；短横线必须保留：selfcheck.html 用
    # `book/${sec}-` 前缀来挑章节（见 selfcheck.html 的 GROUPS 过滤）
    m = re.match(r"^(\d+)", stem)
    section = m.group(1) if m else "00"
    ascii_name = f"{section}-.md"
    source = os.path.join(site, path)
    if not os.path.isfile(source):
        raise SystemExit(f"ERROR: README links {path} but the file is missing")
    target = os.path.join(book_dir, ascii_name)
    if os.path.exists(target):
        raise SystemExit(f"ERROR: duplicate ASCII name {ascii_name}")
    os.rename(source, target)
    renames[path] = f"book/{ascii_name}"

# docs/ 下的中文文件名保持原样：页面把 docs/*.md 拼成 GitHub 链接
# （index.html 的 dmHref），改名会让那些外链失效。它们也不会被本地加载。

for old, new in renames.items():
    text = text.replace(f"]({old})", f"]({new})")

with open(readme, "w", encoding="utf-8") as f:
    f.write(text)
print(f"==> renamed {len(renames)} book files to ASCII names")
PY

# 完整性校验：页面与正文缺一不可，否则 fail（避免发布坏包）
for required in index.html selfcheck.html README.md updates.json book; do
  if [ ! -e "$SITE_DIR/$required" ]; then
    echo "ERROR: missing build output: site/${required}" >&2
    ls -R "$SITE_DIR" 2>&1 | head -30 >&2
    exit 1
  fi
done

# 正文文件名必须全是 ASCII，否则 URL 编码可能取不到
python3 - "$SITE_DIR" <<'PY'
import os, re, sys

site = sys.argv[1]
bad = []
for root, _dirs, files in os.walk(os.path.join(site, "book")):
    for name in files:
        if not name.isascii():
            bad.append(os.path.join(root, name))
if bad:
    raise SystemExit("ERROR: non-ASCII file names left in site/book:\n  " + "\n  ".join(bad[:10]))
print("==> all book file names are ASCII")

# README 里引用的 book 链接必须全是 ASCII（页面会 fetch 它们）
with open(os.path.join(site, "README.md"), encoding="utf-8") as f:
    readme = f.read()
local = [p for p in re.findall(r"\]\((book/[^)]+)\)", readme) if not p.isascii()]
if local:
    raise SystemExit("ERROR: non-ASCII book links left in README.md:\n  " + "\n  ".join(local[:10]))
print("==> all book links in README.md are ASCII")
PY

# index.html 会按 README 里的 book/ 链接逐个 fetch，缺一个文件就有一条读不出来
BOOK_COUNT="$(find "$SITE_DIR/book" -name '*.md' | wc -l)"
LINK_COUNT="$(grep -oE '\]\(book/[^)]+\.md\)' "$SITE_DIR/README.md" | sort -u | wc -l)"
echo "==> book files: ${BOOK_COUNT}, linked from README: ${LINK_COUNT}"
if [ "$BOOK_COUNT" -lt 30 ]; then
  echo "ERROR: too few book files (${BOOK_COUNT})" >&2
  exit 1
fi
if [ "$BOOK_COUNT" -lt "$LINK_COUNT" ]; then
  echo "ERROR: README links ${LINK_COUNT} book files but only ${BOOK_COUNT} are present" >&2
  exit 1
fi

FILE_COUNT="$(find "$SITE_DIR" -type f | wc -l)"
echo "==> site built: $(du -sh "$SITE_DIR" | cut -f1), ${FILE_COUNT} files"
