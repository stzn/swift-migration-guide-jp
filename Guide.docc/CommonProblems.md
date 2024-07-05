# 頻出のコンパイルエラー

本ページではSwift Concurrencyを使用した際によく目にしうる問題を特定し、理解し、対処します。

|原文|[https://github.com/apple/swift-migration-guide/blob/main/Guide.docc/CommonProblems.md](https://github.com/apple/swift-migration-guide/blob/main/Guide.docc/CommonProblems.md)|
|---|---|
|更新日|2024/6/30(翻訳を最後に更新した日付)|
|ここまで反映|[https://github.com/apple/swift-migration-guide/commit/6487820801552379ffdcb2b166ca0b97c73b697a](https://github.com/apple/swift-migration-guide/commit/6487820801552379ffdcb2b166ca0b97c73b697a)|

コンパイラによって保証されるデータ隔離はすべてのSwiftのコードに影響します。
これにより、完全な並行性の確認は、直接並行処理の言語機能を使用していないSwift 5のコードでも潜在的な問題を浮き彫りにすることがあります。
Swift 6言語モードを有効にすると、これらの潜在的な問題のいくつかがエラーとして扱われるようにもなります。

完全確認を有効にすると、多くのプロジェクトで大量の警告やエラーが発生する可能性があります。
圧倒されないでください！
警告やエラーをたどっていくと、そのほとんどが小さな根本的原因の積み重ねによるものだとわかります。
そして、その原因は共通のパターンによるもので、簡単に修正できるだけでなく、Swiftの並行処理システムについて学ぶ際に非常に役立ちます。

## 安全でないグローバルおよび静的変数

静的変数を含むグローバルな状態はプログラムのどこからでもアクセスできます。
この可視性により、グローバルな状態は特に同時アクセスの影響を受けやすくなります。
データ競合の安全性が確立される以前の環境でグローバル変数へアクセスする際は、プログラマーはコンパイラのサポートなしに自分で工夫してデータ競合を避けていました。

> Experiment: これらのコード例をパッケージの形式で提供しています。[Globals.swift][Globals]で試してみてください。

[Globals]: https://github.com/apple/swift-migration-guide/blob/main/Sources/Examples/Globals.swift

### Sendable型

```swift
var supportedStyleCount = 42
```

ここにグローバル変数を宣言しました。
このグローバル変数は隔離されておらず、 _かつ_ どの隔離ドメインからも変更可能です。Swift 6モードでこのコードをコンパイルするとエラーメッセージが表示されます。

```
1 | var supportedStyleCount = 42
  |              |- error: global variable 'supportedStyleCount' is not concurrency-safe because it is non-isolated global shared mutable state
  |              |- note: convert 'supportedStyleCount' to a 'let' constant to make the shared state immutable
  |              |- note: restrict 'supportedStyleCount' to the main actor if it will only be accessed from the main thread
  |              |- note: unsafely mark 'supportedStyleCount' as concurrency-safe if all accesses are protected by an external synchronization mechanism
2 |
```

異なる隔離ドメインを持つ2つの関数がこの変数にアクセスすると、データ競合のリスクがあります。次のコードでは、 `printSupportedStyles()` がメインアクター上で動作するのと同時に、別の隔離ドメインから `addNewStyle()` が呼び出される可能性があります。

```swift
@MainActor
func printSupportedStyles() {
    print("Supported styles: ", supportedStyleCount)
}

func addNewStyle() {
    let style = Style()

    supportedStyleCount += 1

    storeStyle(style)
}
```

問題に対処する1つの方法は、この変数の隔離方法を変更することです。

```swift
@MainActor
var supportedStyleCount = 42
```

変数は可変のままですが、グローバルアクターに隔離されるようになります。
すべてのアクセスは1つの隔離ドメイン内でのみ起こるようになり、 `addNewStyle` 内での同期アクセスはコンパイル時に無効になります。

もし変数が定数であり変更されないのであれば、単純な解決策はそれをコンパイラに明示することです。
`var` を `let` に変更することでコンパイラは変更を静的に禁止でき、安全な読み取り専用アクセスを保証します。

```swift
let supportedStyleCount = 42
```

もしこの変数を保護するための同期機構があり、それがコンパイラに見えない場合は、`nonisolated(unsafe)` を使って `supportedStyleCount` のすべての隔離確認を無効化できます。

```swift
/// `styleLock` を保持している間だけこの値にアクセスしてよい。
nonisolated(unsafe) var supportedStyleCount = 42
```

`nonisolated(unsafe)` は、ロックやディスパッチキューなどの外部同期機構で変数へのすべてのアクセスを慎重に保護している場合にのみ使用してください。

### 非Sendable型

先の例では、変数は `Int` 型で、本質的に `Sendable` である値型です。
グローバルな _参照_ 型は一般的に `Sendable` でないため、さらに困難を伴います。

```swift
class WindowStyler {
    var background: ColorComponents

    static let defaultStyler = WindowStyler()
}
```

この `static let` 宣言の問題は、変数が変更可能かどうかには関係ありません。
問題は、 `WindowStyler` が非 `Sendable` 型であるため、その内部状態を異なる隔離ドメイン間で安全に共有できないことです。

```swift
func resetDefaultStyle() {
    WindowStyler.defaultStyler.background = ColorComponents(red: 1.0, green: 1.0, blue: 1.0)
}

@MainActor
class StyleStore {
    var stylers: [WindowStyler]

    func hasDefaultBackground() -> Bool {
        stylers.contains { $0.background == WindowStyler.defaultStyler.background }
    }
}
```

ここでは、`WindowStyler.defaultStyler` の内部状態に同時にアクセスする可能性がある2つの関数を示しています。
コンパイラは、このような異なる隔離ドメイン間のアクセスを `Sendable` な型に対してのみ許可します。
1つの選択肢として、グローバルアクターを使用して変数を単一のドメインに隔離することが考えられます。
あるいは、 `Sendable` への準拠を直接追加するのも有効かもしれません。

## プロトコル準拠時の隔離不一致

プロトコルは、静的隔離を含む、準拠する型が満たさなければならない要件を定義します。
これにより、プロトコルの宣言と準拠する型の間に隔離の不一致が生じることがあります。

この種の問題に対してはさまざまな解決策が考えられますが、トレードオフを伴うことが多いです。
適切なアプローチを選ぶには、まず、そもそも _なぜ_ 不一致が発生するのかを理解する必要があります。

> Experiment: これらのコード例をパッケージの形式で提供しています。
[ConformanceMismatches.swift][ConformanceMismatches]で試してみてください。

[ConformanceMismatches]: https://github.com/apple/swift-migration-guide/blob/main/Sources/Examples/ConformanceMismatches.swift

### 明示的に隔離されていないプロトコル

この問題で最も一般的に遭遇する形は、プロトコルに明示的な隔離がない場合です。
この場合、他のすべての宣言と同様に、 _非隔離_ であることを意味します。
非隔離のプロトコル要件は、どの隔離ドメインでもプロトコルで抽象化したコードから呼び出すことができます。もし要件が同期的であれば、準拠する型の実装がアクター隔離された状態にアクセスすることは無効です。

```swift
protocol Styler {
    func applyStyle()
}

@MainActor
class WindowStyler: Styler {
    func applyStyle() {
        // メインアクター隔離された状態へのアクセス
    }
}
```

上記のコードは、Swift 6モードで次のエラーを生成します。

```
 5 | @MainActor
 6 | class WindowStyler: Styler {
 7 |     func applyStyle() {
   |          |- error: main actor-isolated instance method 'applyStyle()' cannot be used to satisfy nonisolated protocol requirement
   |          `- note: add 'nonisolated' to 'applyStyle()' to make this instance method not isolated to the actor
 8 |         // メインアクター隔離された状態へのアクセス
 9 |     }
```

プロトコルは実際には _隔離されるべき_ 可能性もありますが、まだ並行処理に対応して更新されていないのかもしれません。
正しい隔離を追加するために準拠する型を先に移行すると、不一致が発生します。

```swift
// このプロトコルは実際にはMainActor型から使用するのが適切だが、まだそれを反映するように更新されていない。
protocol Styler {
    func applyStyle()
}

// 準拠している型は現在正しく隔離されており、この不一致を明らかにした。
@MainActor
class WindowStyler: Styler {
}
```

#### 隔離の追加

プロトコルの要件が常にメインアクターから呼び出される場合、 `@MainActor` を追加することが最適な解決策です。

プロトコルの要件をメインアクターに隔離する方法は2つあります。

```swift
// プロトコル全体
@MainActor
protocol Styler {
    func applyStyle()
}

// 要件ごと
protocol Styler {
    @MainActor
    func applyStyle()
}
```

プロトコルにグローバルアクター属性をつけると、その準拠のスコープ全体に対する隔離を推論します。
プロトコルの準拠がextensionで宣言されていないなら、これを準拠する型全体に適用できます。

要件ごとの隔離は、特定の要件の実装にのみ適用されることから、アクター隔離の推論に与える影響がより限定的になります。プロトコルのextensionや準拠型のその他のメソッドに対する隔離の推論には影響を与えません。
準拠型に同一のグローバルアクターが必ずしも結びつかないことに意味があるならこちらのアプローチが好ましいです。

いずれにせよ、プロトコルの隔離を変更すると、準拠する型の隔離に影響を与え、プロトコルを使用し抽象化したコードに制約を課す可能性があります。

そこで、 `@preconcurrency` を使うことで、プロトコルへグローバルアクター隔離を追加することで生じる診断を段階的に進めることができます。
これにより、まだ並行処理を導入しはじめていないクライアントとのソース互換性が保たれます。

```swift
@preconcurrency @MainActor
protocol Styler {
    func applyStyle()
}
```

#### 非同期要件

同期プロトコル要件を実装するメソッドのために、実装の隔離は正確に一致している必要があります。
要件を _非同期_ にすることで、準拠する型に対してより柔軟性が提供されます。

```swift
protocol Styler {
    func applyStyle() async
}
```

非同期の `async` プロトコル要件は隔離されたメソッドで満たすことができます。

```swift
@MainActor
class WindowStyler: Styler {
    // 同期的でアクター隔離されていたとしても一致する
    func applyStyle() {
    }
}
```

上記のコードは安全です。なぜなら、抽象化したコードは常に `applyStyle()` を非同期に呼び出さなければならず、これにより隔離された実装がアクター隔離状態にアクセスする前にアクターを切り替えることができるからです。

しかし、この柔軟性には代償があります。
メソッドを非同期に変更することは、すべての呼び出し箇所に大きな影響を与える可能性があります。
非同期コンテキストに加え、パラメータと戻り値の両方が隔離境界を越える必要があるかもしれません。
これらは大幅な構造変更を必要とすることがあります。
この方法が正しい解決策であるかもしれませんが、関与する型が少数であっても、その副作用を慎重に考慮する必要があります。

#### Preconcurrencyによる準拠

Swiftには、並行処理を段階的に導入し、まだ並行処理を全く使用していないコードと相互運用するための多くのメカニズムがあります。
これらのツールは、自分が所有していないコードはもちろん、所有しているが簡単に変更できないコードに対しても役立ちます。

プロトコルの準拠に `@preconcurrency` のアノテーションをつけると、隔離不一致に関するエラーを抑制できます。

```swift
@MainActor
class WindowStyler: @preconcurrency Styler {
    func applyStyle() {
        // 本体の実装
    }
}
```

これは、準拠するクラスの静的隔離が常に強制されることを保証するための実行時確認を挿入します。

> Note: 段階的な導入と動的隔離の詳細については[動的隔離][]を参照してください。

[動的隔離]: incrementaladoption#Dynamic-Isolation

### 隔離された準拠型

これまでに紹介した解決策は、隔離の不一致の原因が最終的にプロトコルの定義にあると仮定しています。
しかしプロトコルの静的な隔離は適切で、準拠する型だけが問題の原因である可能性もあります。

#### 非隔離

完全に非隔離の関数でも、依然として有用である場合があります。

```swift
@MainActor
class WindowStyler: Styler {
    nonisolated func applyStyle() {
        // 多分この実装では他のメインアクター隔離状態を使用しない
    }
}
```

この実装に対する制約は、隔離された状態や関数が利用できなくなることです。
特にインスタンスに依存しない設定のソースとして関数を使用する場合なら、これはまだ適切な解決策となりえます。

#### プロキシによる準拠

静的隔離の違いに対処するために中間型が使用できます。
これは、プロトコルが準拠する型へ継承を要求する場合に特に効果的です。

```swift
class UIStyler {
}

protocol Styler: UIStyler {
    func applyStyle()
}

// アクターはクラスベースの継承を持つことができない
actor WindowStyler: Styler {
}
```

新しい型を導入して間接的に準拠させることで、この状況を解決できます。
しかし、この解決策は `WindowStyler` の構造的な変更を必要とし、それに依存するコードにも影響を与える可能性があります。

```swift
// 必要なスーパークラスを継承したクラス
class CustomWindowStyle: UIStyler {
}

// 今なら準拠が可能
extension CustomWindowStyle: Styler {
    func applyStyle() {
    }
}
```

ここでは、必要な継承を満たすために新しい型を作成しました。
もしこの準拠した型（`CustomWindowStyle`）が `WindowStyler` によって内部だけで使用されるのなら、`WindowStyler`の内部に含めるのがもっとも簡単な方法でしょう。
