# 完全な並行性の確認を有効にする

プロジェクト内で診断を警告として有効にして、段階的にデータ競合安全性の問題に対処しよう。

|原文|[https://github.com/apple/swift-migration-guide/blob/main/Guide.docc/CompleteChecking.md](https://github.com/apple/swift-migration-guide/blob/main/Guide.docc/CompleteChecking.md)|
|---|---|
|更新日|2024/8/12(翻訳を最後に更新した日付)|
|ここまで反映|[https://github.com/apple/swift-migration-guide/commit/354d6ee8242b4fde41f9a0cb86ac7fdc1bfb6d30](https://github.com/apple/swift-migration-guide/commit/354d6ee8242b4fde41f9a0cb86ac7fdc1bfb6d30)|

Swift 6言語モードにおけるデータ競合安全性は段階的な移行できるように設計されています。プロジェクトのモジュール単位で、データ競合安全性の問題に対処できます。また、Swift 5言語モードでは、コンパイラのアクター隔離と`Sendable`チェックを警告として有効にできます。さらに、データ競合の排除に対する進捗を評価しながら、Swift 6言語モードを有効にする前に準備を整えることができます。

Swift 5言語モードで`-strict-concurrency`コンパイラフラグを使用することで、完全なデータ競合安全確認を警告として有効にできます。

## Swiftコンパイラを使う

`swift`または`swiftc`を直接コマンドラインで実行する際に、完全な並行性の確認を有効にするには、`-strict-concurrency=complete`を渡します。

```
~ swift -strict-concurrency=complete main.swift
```

## SwiftPM(SPM)を使う

### SwiftPMのコマンドライン呼び出し内

`-strict-concurrency=complete`をSwiftパッケージマネージャーのコマンドライン呼び出しに渡すには、`-Xswiftc`フラグを使用します。

```
~ swift build -Xswiftc -strict-concurrency=complete
~ swift test -Xswiftc -strict-concurrency=complete
```

これは、次のセクションで説明するように、フラグをパッケージマニフェストに永続的に追加する前に、並行処理の警告の量を測定するのに役立ちます。

### SwiftPMパッケージマニフェスト内

Swift 5.9またはSwift 5.10のツールを使用して完全な並行性の確認を有効にするには、ターゲットのswiftSettingsで、[`SwiftSetting.enableExperimentalFeature`](https://developer.apple.com/documentation/packagedescription/swiftsetting/enableexperimentalfeature(_:_:))を使用します。

```swift
.target(
  name: "MyTarget",
  swiftSettings: [
    .enableExperimentalFeature("StrictConcurrency")
  ]
)
```

Swift 6.0以降のツールを使用している場合は、Swift 6以前の言語モードのターゲットに対し、swiftSettingsで[`SwiftSetting.enableUpcomingFeature`](https://developer.apple.com/documentation/packagedescription/swiftsetting/enableupcomingfeature(_:_:))使用してください。

```swift
.target(
  name: "MyTarget",
  swiftSettings: [
    .enableUpcomingFeature("StrictConcurrency")
  ]
)
```

## Xcodeを使う

Xcodeプロジェクトで完全な並行性の確認を有効にするには、Xcodeのビルド設定で「Strict Concurrency Checking」の設定を「Complete」にしてください。あるいは、xcconfigファイルで`SWIFT_STRICT_CONCURRENCY`を`complete`にも設定できます。

```
// Settings.xcconfig内

SWIFT_STRICT_CONCURRENCY = complete;
```
