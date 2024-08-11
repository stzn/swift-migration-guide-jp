# Swift 6への移行

@Metadata {
  @TechnologyRoot
}

<!-- textlint-disable smarthr/sentence-length-->

@Options(scope: global) {
  @AutomaticSeeAlso(disabled)
  @AutomaticTitleHeading(disabled)
  @AutomaticArticleSubheading(disabled)
}

<!-- textlint-enable smarthr/sentence-length-->

|原文|[https://github.com/apple/swift-migration-guide/blob/main/Guide.docc/MigrationGuide.md](https://github.com/apple/swift-migration-guide/blob/main/Guide.docc/MigrationGuide.md)|
|---|---|
|更新日|2024/8/11(翻訳を最後に更新した日付)|
|ここまで反映|[https://github.com/apple/swift-migration-guide/commit/dcbcc0fdbc8138a48f6209c9ce6fed562f34ebe1](https://github.com/apple/swift-migration-guide/commit/dcbcc0fdbc8138a48f6209c9ce6fed562f34ebe1)|

## 概要

[Swift 5.5](https://www.swift.org/blog/swift-5.5-released/)で導入されたSwiftの並行処理システムは、非同期と並行処理のコードをより書きやすく理解しやすくします。Swift 6言語モードでは、コンパイラは並行プログラミングにデータ競合がないことを保証できるようになりました。Swift 6言語モードを有効にすると、以前は任意であったコンパイラの安全チェックが必須になります。

Swift 6言語モードの導入は、ターゲットごとに完全に制御できます。以前の言語モードでビルドされたターゲットや、Swiftに公開された他の言語のコードはすべて、Swift 6言語モードに移行したモジュールと相互運用できます。

あなたは、並行処理の機能が導入されるごとに、それらを段階的に導入してきているかもしれません。あるいは、使い始めるためにSwift 6のリリースを待っていたかもしれません。プロジェクトがどの段階にあるかに関係なく、このガイドでは移行をスムーズにするための概念と実用的なヘルプを提供します。

このガイドには、次のような記事とコード例が掲載されています。

- Swiftのデータ競合安全モデルで使用される概念を説明する
- 移行を開始するための可能な方法を概説する
- Swift 5プロジェクトの完全な並行性の確認を有効にする方法を示す
- Swift 6言語モードを有効にする方法を示す
- 頻出の問題を解決するための戦略を提示する
- 段階的な導入のための手法を提供する

> 重要: Swift 6言語モードはオプトインです。既存のプロジェクトは、構成を変更しない限り、このモードに切り替わりません。
> コンパイラのバージョンと言語モードには違いがあります。Swift 6コンパイラは、「6」、「5」、「4.2」、「4」の4つの異なる言語モードをサポートしています。

### コントリビューション

このガイドは活発に開発を進めています。ソースを眺めたり、完全なコード例を見たり、[リポジトリ][]で貢献する方法について学べます。次のような形での貢献をお待ちしております。

- 特定のコードパターンまたはガイドの追加セクションを網羅する[Issue][]を提出する
- Pull Requestを開いて既存のコンテンツを改善したり、新しいコンテンツを追加したりする
- 他のユーザーの[Pull Request][]をレビューして、記述とコード例の明確さと正確さを確認する

詳細については、[コントリビューションガイドライン][]を参照してください。

[リポジトリ]: https://github.com/apple/swift-migration-guide
[Issue]: https://github.com/stzn/swift-migration-guide-jp/issues
[Pull Request]: https://github.com/stzn/swift-migration-guide-jp/pulls
[コントリビューションガイドライン]: https://github.com/stzn/swift-migration-guide-jp/blob/main/CONTRIBUTING.md

## Topics

- <doc:DataRaceSafety>
- <doc:MigrationStrategy>
- <doc:CompleteChecking>
- <doc:Swift6Mode>
- <doc:CommonProblems>
- <doc:IncrementalAdoption>
- <doc:SourceCompatibility>

### Swift Concurrencyの詳細

- <doc:RuntimeBehavior>
