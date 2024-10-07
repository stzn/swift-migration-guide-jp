# Swift 6言語モードを有効化する

Swift 6言語モードを有効化して、コードにデータ競合が発生しないことを保証しましょう。

|原文|[https://github.com/apple/swift-migration-guide/blob/main/Guide.docc/Swift6Mode.md](https://github.com/apple/swift-migration-guide/blob/main/Guide.docc/Swift6Mode.md)|
|---|---|
|更新日|2024/10/7(翻訳を最後に更新した日付)|
|ここまで反映|[https://github.com/apple/swift-migration-guide/commit/7ceaf9183065ce7dbe9a5ade1dc36b4df48796e0](https://github.com/apple/swift-migration-guide/commit/7ceaf9183065ce7dbe9a5ade1dc36b4df48796e0)|

## Swiftコンパイラを利用する

コマンドラインで`swift`または`swiftc`を直接実行するときに完全な並行処理確認を有効にするには、`-swift-version 6`を渡します。

```bash
~ swift -swift-version 6 main.swift
```

## SwiftPMを利用する

### コマンドラインからの呼び出し

Swiftパッケージマネージャー（SPM）のコマンドライン呼び出しでは、`-Xswiftc`フラグを使用して`-swift-version 6`を渡すことができます。

```swift
~ swift build -Xswiftc -swift-version -Xswiftc 6
~ swift test -Xswiftc -swift-version -Xswiftc 6
```

### パッケージマニフェスト

`swift-tools-version: 6.0`を使用する`Package.swift`ファイルは、すべてのターゲットに対してSwift 6言語モードを有効にします。
引き続き`Package`の`swiftLanguageModes`プロパティを使用して、パッケージ全体の言語モードを設定できます。
さらに、新しい`swiftLanguageMode`ビルド設定を使用して、必要に応じてターゲットごとに言語モードを変更できるようにもなりました。

```swift
// swift-tools-version: 6.0

let package = Package(
    name: "MyPackage",
    products: [
        // ...
    ],
    targets: [
        // デフォルトのツール言語モード(6)を利用する
        .target(
            name: "FullyMigrated",
        ),
        // まだSwift 5言語モードが必要
        .target(
            name: "NotQuiteReadyYet",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
```

パッケージが以前のバージョンのSwiftツールチェーンをサポートし続けなければならず、ターゲットごとに`swiftLanguageMode`を設定したい場合は、6以前のツールチェーンのためのバージョン固有のマニフェストを作成する必要があります。例えば、5.9以降のツールチェーンをサポートし続けたいなら`Package@swift-5.9.swift`を用意します:
```swift
// swift-tools-version: 5.9

let package = Package(
    name: "MyPackage",
    products: [
        // ...
    ],
    targets: [
        .target(
            name: "FullyMigrated",
        ),
        .target(
            name: "NotQuiteReadyYet",
        )
    ]
)
```

そしてSwiftツールチェーン6.0以上のためのもう1つの`Package.swift`を用意します:
```swift
// swift-tools-version: 6.0

let package = Package(
    name: "MyPackage",
    products: [
        // ...
    ],
    targets: [
        // デフォルトのツール言語モード(6)を利用する
        .target(
            name: "FullyMigrated",
        ),
        // まだSwift 5言語モードが必要
        .target(
            name: "NotQuiteReadyYet",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
```

一方、Swift 6言語モードを利用したいだけで、それが（より古いモードのサポートを維持しつつ）利用可能なら、単一の`Package.swift`のまま互換性のある方法でバージョンを指定できます:
```swift
// swift-tools-version: 5.9

let package = Package(
    name: "MyPackage",
    products: [
        // ...
    ],
    targets: [
        .target(
            name: "FullyMigrated",
        ),
    ],
    // 6.0以前のswift-tools-versionをサポートするための`swiftLanguageVersions`と`.version("6")`
    swiftLanguageVersions: [.version("6"), .v5]
)
```

## Xcodeを利用する

### ビルド設定

「Swift Language Version」のビルド設定を「Swift 6」に設定することで、Xcodeプロジェクトまたはターゲットの言語モードを制御できます。

## XCConfig

xcconfigファイルで`SWIFT_VERSION`設定を`6`に設定できます。

```
// Settings.xcconfig内

SWIFT_VERSION = 6;
```