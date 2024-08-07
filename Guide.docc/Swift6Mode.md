# Swift 6言語モードを有効化する

Swift 6言語モードを有効化して、コードにデータ競合が発生しないことを保証しましょう。

|原文|[https://github.com/apple/swift-migration-guide/blob/main/Guide.docc/Swift6Mode.md](https://github.com/apple/swift-migration-guide/blob/main/Guide.docc/Swift6Mode.md)|
|---|---|
|更新日|2024/8/3(翻訳を最後に更新した日付)|
|ここまで反映|[https://github.com/apple/swift-migration-guide/commit/19d63f2d91811b11f5cc832f72d4374ae4b83f1f](https://github.com/apple/swift-migration-guide/commit/19d63f2d91811b11f5cc832f72d4374ae4b83f1f)|

## Swiftコンパイラを利用する

コマンドラインで`swift`または`swiftc`を直接実行するときに完全な並行処理確認を有効にするには、`-swift-version 6`を渡します。

```bash
~ swift -swift-version 6 main.swift
```

## SwiftPMを利用する

### コマンドラインからの呼び出し

Swiftパッケージマネージャーのコマンドライン呼び出しでは、`-Xswiftc`フラグを使用して`-swift-version 6`を渡すことができます。

```swift
~ swift build -Xswiftc -swift-version -Xswiftc 6
~ swift test -Xswiftc -swift-version -Xswiftc 6
```

### パッケージマニフェスト

`swift-tools-version: 6.0`を使用する`Package.swift`ファイルは、すべてのターゲットに対してSwift 6言語モードを有効にします。
`Package`の`swiftLanguageVersions`プロパティを使用して、パッケージ全体の言語モードを設定できます。
ただし、新しい`swiftLanguageVersion`ビルド設定を使用して、必要に応じてターゲットごとに言語モードを変更できるようになりました。

```swift
// swift-tools-version: 6.0

let package = Package(
    name: "MyPackage",
    products: [
        // ...
    ],
    targets: [
        // デフォルトのツール言語モードを利用する
        .target(
            name: "FullyMigrated",
        ),
        // まだSwift 5言語モードが必要
        .target(
            name: "NotQuiteReadyYet",
            swiftSettings: [
                .swiftLanguageVersion(.v5)
            ]
        )
    ]
)
```

## Xcodeを利用する

### ビルド設定

「Swift Language Version」のビルド設定を「6」に設定することで、Xcodeプロジェクトまたはターゲットの言語モードを制御できます。

## XCConfig

xcconfigファイルで`SWIFT_VERSION`設定を`6`に設定できます。

```
// Settings.xcconfig内

SWIFT_VERSION = 6;
```