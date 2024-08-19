# ソース互換性

潜在的なソース互換性問題の概要を確認しましょう。

|原文|[https://github.com/apple/swift-migration-guide/blob/main/Guide.docc/SourceCompatibility.md](https://github.com/apple/swift-migration-guide/blob/main/Guide.docc/SourceCompatibility.md)|
|---|---|
|更新日|2024/8/12(翻訳を最後に更新した日付)|
|ここまで反映|[https://github.com/apple/swift-migration-guide/commit/540c604a7241ea42c12058cf53b625b02ea1a7ce](https://github.com/apple/swift-migration-guide/commit/540c604a7241ea42c12058cf53b625b02ea1a7ce)|

Swift 6には、ソース互換性に影響を与える可能性のあるいくつかのSwift Evolutionのプロポーザルが含まれています。これらはすべて、Swift 5言語モードにおいてはオプトインです。

> 注記: 前回リリースの移行ガイドについては、[Migrating to Swift 5][swift5]を参照してください。

[swift5]: https://www.swift.org/migration-guide-swift5/

## 将来の列挙型ケースの処理

[SE-0192][]: `NonfrozenEnumExhaustivity`

必須である`@unknown default`がない場合、警告からエラーに変わりました。

[SE-0192]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0192-non-exhaustive-enums.md

## 簡潔なマジックファイル名

[SE-0274][]: `ConciseMagicFile`

特別な式である`#file`が、ファイル名とモジュール名を含むヒューマンリーダブルな文字列に変わりました。

[SE-0274]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0274-magic-file.md

## 末尾クロージャに対する前方スキャン一致

[SE-0286][]: `ForwardTrailingClosures`

複数のデフォルト値を持つクロージャーパラメータを含むコードに影響を与える可能性があります。

[SE-0286]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0286-forward-scan-trailing-closures.md

## 並行確認への段階的移行

[SE-0337][]: `StrictConcurrency`

データ競合のリスクがあるコードはエラーになります。

[SE-0337]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0337-support-incremental-migration-to-concurrency-checking.md

> 注記: この機能は、暗黙的に[`IsolatedDefaultValues`](#Isolated-default-value-expressions)、
[`GlobalConcurrency`](#Strict-concurrency-for-global-variables)と[`RegionBasedIsolation`](#Region-based-Isolation)も有効にします。

## 暗黙的に開かれる存在型

[SE-0352][]: `ImplicitOpenExistentials`

存在型とジェネリック型の両方を含む関数のオーバーロードの解決に影響を与える可能性があります。

[SE-0352]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0352-implicit-open-existentials.md

## 正規表現リテラル

[SE-0354][]: `BareSlashRegexLiterals`

素のスラッシュを過去に使用していたコードの解析に影響を与える可能性があります。

[SE-0354]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0354-regex-literals.md

## @UIApplicationMainと@NSApplicationMainの非推奨

[SE-0383][]: `DeprecateApplicationMain`

まだ `@main` へ移行していないコードに対して、エラーを提示するようになります。

[SE-0383]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0383-deprecate-uiapplicationmain-and-nsapplicationmain.md

## 前方宣言(Forward Declared)されたObjective-Cインターフェイスとプロトコルのインポート

[SE-0384][]: `ImportObjcForwardDeclarations`

以前は見えなかった(Objective-Cの)型が露出し、既存のソースと衝突する可能性があります。

[SE-0384]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0384-importing-forward-declared-objc-interfaces-and-protocols.md

## プロパティラッパーが行なうアクター隔離の推論の削除

[SE-0401][]: `DisableOutwardActorInference`

型およびそのメンバーの推論される隔離が変わる可能性があります。

[SE-0401]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0401-remove-property-wrapper-isolation.md

## 隔離されたデフォルト値式

[SE-0411][]: `IsolatedDefaultValues`

データ競合のリスクがあるコードはエラーになります。

[SE-0411]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0411-isolated-default-values.md

##  グローバル変数に対する厳密な並行性の確認

[SE-0412][]: `GlobalConcurrency`

データ競合のリスクがあるコードはエラーになります。

[SE-0412]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0412-strict-concurrency-for-global-variables.md

## リージョンベース隔離

[SE-0414][]: `RegionBasedIsolation`

`Actor.assumeIsolated`関数の制約が増加します。

[SE-0414]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0414-region-based-isolation.md

## `Sendable`メソッドおよびkey pathリテラルの推論

[SE-0418][]: `InferSendableFromCaptures`

送信可能性(Sendability)のみが異なる関数のオーバーロードの解決に影響を与える可能性があります。

[SE-0418]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0418-inferring-sendable-for-methods.md

## 厳密な並行性ではないコンテキストからの動的アクター隔離の強制

[SE-0423][]: `DynamicActorIsolation`

ランタイム時の隔離が期待と一致しない場合、既存のコードに影響を与える可能性のある新しいアサーションを導入します。

[SE-0423]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0423-dynamic-actor-isolation.md

## グローバルアクターに隔離された型の有用性

[SE-0434][]: `GlobalActorIsolatedTypesUsability`

グローバルに隔離されているけれども`@Sendable`ではない関数に対する型推論とオーバーロードの解決に影響を与える可能性があります。

[SE-0434]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0434-global-actor-isolated-types-usability.md