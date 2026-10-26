# howtolivebetter-lzcapp

[eternity4719/howtolivebetter](https://github.com/eternity4719/howtolivebetter) 的懒猫微服打包。

**高性价比人生指南**：用最少的钱、时间和精力，换回最多的寿命、金钱和人身自由。
767 条建议，每条写明花掉什么、换回什么、证据有多硬，来源只引期刊论文和官方文件。

## 交付方式（静态站，无容器镜像）

上游是纯静态站（GitHub Pages 风格），没有构建步骤，但 `index.html` 与
`selfcheck.html` 在浏览器里用 `fetch` 读取 `README.md` 和 `book/*.md`
（文件名从 README 的目录链接里解析），所以这些文件必须与页面同级。

[`build.sh`](build.sh)（`lzc-build.yml` 的 buildscript）：

1. 克隆上游
2. 拷贝站点所需文件到 `site/`：`index.html`、`selfcheck.html`、`README.md`、
   `updates.json`、`og.png`、`robots.txt`、`sitemap.xml`，以及 `book/`、`ads/`、`docs/`
3. 校验：页面、README、`book/` 目录必须在，且 `book/` 里的正文文件数不少于
   README 链接的条目数（缺一个文件就有一条在页面上读不出来）

打包后由平台内置文件服务提供页面
（`backend: file:///lzcapp/pkg/content/`，见 [`lzc-manifest.yml`](lzc-manifest.yml)）。

## 版本与发布

上游没有版本 tag（只有 `epub-latest` 这种滚动 tag），所以版本取**上游最新提交的
日期**：`2026.10.21`（合法的 SemVer 三段式）。

- 每日定时任务比对上游最新提交日期，有新提交就 bump `package.yml` 并发布
- 手动触发时可填 `version` 指定版本
- 仅发布到**喵喵（私有）商店**

## 版权

上游 [eternity4719/howtolivebetter](https://github.com/eternity4719/howtolivebetter)，
正文与页面采用 [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) 许可
（代码部分见上游 `LICENSE-CODE`）；本仓库仅为打包，不修改上游内容。
