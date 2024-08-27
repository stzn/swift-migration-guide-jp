# The Swift Concurrency Migration Guide 日本語訳

## 概要

[The Swift Concurrency Migration Guide][swift-migration-guide]の日本語訳リポジトリです。

このリポジトリには、[Swift-DocC][docc] を使ってビルドされたThe Swift Concurrency Migration Guideのソースが含まれています。


## 目的

英語のドキュメントを読むことに負担を感じている日本語メインのSwiftエンジニアが、この日本語訳を通じてドキュメントの内容を理解し、Swift6への移行をスムーズに進めていけるようになることを目指しています。

## URL

https://swift-migration-guide.jp/documentation/migrationguide/

## コントリビューションについて

The Swift Concurrency Migration Guideに貢献する方法については、[CONTRIBUTING.md][contributing]をご参照ください。

## ビルド方法

リポジトリのルートディレクトリで `docc preview Guide.docc` を実行します。

DocCを実行した後、`docc` が出力するリンクを開いて、ブラウザでローカルプレビューを表示します。

> 注意:
>
> Swift.org から toolchain をダウンロードして DocC をインストールした場合、
> `docc` は toolchain のインストールパスを基準とした `usr/bin/` にあります。
> シェルの `PATH` 環境変数にそのディレクトリが含まれていることを確認してください。
> 
> Xcode をダウンロードして DocC をインストールした場合は、
> 代わりに `xcrun docc` を使用してください。

[swift-migration-guide]: https://github.com/apple/swift-migration-guide
[contributing]: https://github.com/stzn/swift-migration-guide-jp/blob/main/CONTRIBUTING.md
[docc]: https://github.com/apple/swift-docc
[conduct]: https://www.swift.org/code-of-conduct

## コントリビューター

<!-- readme: contributors -start -->
<!-- readme: contributors -end -->