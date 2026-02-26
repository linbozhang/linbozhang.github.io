# linbozhang.github.io

个人主页，使用 [mdBook](https://rust-lang.github.io/mdBook/)（Rust 编写的文档/书生成器）构建，并部署到 GitHub Pages。

## 本地开发

1. 安装 mdBook：
   ```bash
   cargo install mdbook
   ```
   或从 [Releases](https://github.com/rust-lang/mdBook/releases) 下载二进制。

2. 在仓库根目录执行：
   ```bash
   mdbook serve
   ```
   浏览器打开 http://localhost:3000 预览。

3. 构建静态站点（输出到 `book/`）：
   ```bash
   mdbook build
   ```

## 目录说明

- `book.toml` — mdBook 配置
- `src/` — 所有 Markdown 源文件
- `src/SUMMARY.md` — 目录结构（侧边栏章节）
- `src/README.md` — 首页内容

## 部署

推送代码到 `main` 分支后，GitHub Actions 会自动构建并发布到 [GitHub Pages](https://linbozhang.github.io)。

需在仓库 **Settings → Pages → Build and deployment** 中选择 **GitHub Actions** 作为 Source。
