# 頻出のコンパイルエラー

本ページではSwift Concurrencyを使用した際によく目にしうる問題を特定し、理解し、対処します。

|原文|[https://github.com/apple/swift-migration-guide/blob/main/Guide.docc/CommonProblems.md](https://github.com/apple/swift-migration-guide/blob/main/Guide.docc/CommonProblems.md)|
|---|---|
|更新日|2024/7/17(翻訳を最後に更新した日付)|
|ここまで反映|[https://github.com/apple/swift-migration-guide/commit/c6d956efcddbe2a8888ed6ed77b0a516a53f0d16](https://github.com/apple/swift-migration-guide/commit/c6d956efcddbe2a8888ed6ed77b0a516a53f0d16)|

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

> 検証: これらのコード例をパッケージの形式で提供しています。[Globals.swift][Globals]で試してみてください。

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

計算プロパティでもグローバルな値を表現できます。
そのようなプロパティが一貫して同じ定数値を返すなら、観測可能な値/主作用に関する限りでは、これは `let` 定数と意味的に等価です：

```swift
var supportedStyleCount: Int {
    42
}
```

もし、この変数を保護するための同期が、コンパイラからは見えない形で行われている場合、`nonisolated(unsafe)` を使って `supportedStyleCount` の隔離確認をすべて無効化できます。

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

> 検証: これらのコード例をパッケージの形式で提供しています。
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

#### 並行処理を使用していない要件への準拠

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

> 注記: 段階的な導入と動的隔離の詳細については[動的隔離][]を参照してください。

[動的隔離]: incrementaladoption#Dynamic-Isolation

### 隔離された準拠型

これまでに紹介した解決策は、隔離の不一致の原因が最終的にプロトコルの定義にあると仮定しています。
しかしプロトコルの静的隔離は適切で、準拠する型だけが問題の原因である可能性もあります。

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

#### プロキシを介した準拠

静的隔離の違いに対処するために中間型が使用できます。
これは、プロトコルが準拠する型へ継承を要求する場合に特に効果的です。

```swift
class UIStyler {
}

protocol Styler: UIStyler {
    func applyStyle()
}

// アクターはクラスベースの継承ができない
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

## 隔離境界の横断

コンパイラは、データ競合を起こさないと証明できる場合にのみ、ある隔離ドメインから他のドメインへ値が移動することを許可します。
隔離境界を越える可能性のあるコンテキストでこの要件を満たさない値を使うことはごくありふれた問題です。
そして、ライブラリやフレームワークはSwiftの並行処理機能を使うためにアップデートされる可能性があるため、自分のコードを変更していなくてもこれらの問題が発生する可能性があります。

> 検証: これらのコード例をパッケージの形式で提供しています。[Boundaries.swift][Boundaries]で試してみてください。

[Boundaries]: https://github.com/apple/swift-migration-guide/blob/main/Sources/Examples/Boundaries.swift

### 暗黙的なSendable型

多くの値型は `Sendable` なプロパティのみで構成されています。
コンパイラはそのような型を暗黙的に `Sendable` として扱いますが、それはpublicでない場合 _のみ_ です。

```swift
public struct ColorComponents {
    public let red: Float
    public let green: Float
    public let blue: Float
}

@MainActor
func applyBackground(_ color: ColorComponents) {
}

func updateStyle(backgroundColor: ColorComponents) async {
    await applyBackground(backgroundColor)
}
```

`Sendable` への準拠は型の公開APIの取り決めの一部であり、定義するかどうかは自分次第です。
`ColorComponents` には `public` がついているため、 `Sendable` への暗黙的な準拠を行ないません。
これは次のようなエラーになります：

```
 6 | 
 7 | func updateStyle(backgroundColor: ColorComponents) async {
 8 |     await applyBackground(backgroundColor)
   |           |- error: sending 'backgroundColor' risks causing data races
   |           `- note: sending task-isolated 'backgroundColor' to main actor-isolated global function 'applyBackground' risks causing data races between main actor-isolated and task-isolated uses
 9 | }
10 | 
```

簡単な解決策は、型の `Sendable` への準拠を明示的に行なうことです：

```swift
public struct ColorComponents: Sendable {
    // ...
}
```

たとえ些細な場合でも、 `Sendable` へ準拠は常に注意して行なうべきです。
`Sendable` はスレッド安全の保証であり準拠をやめることはAPIの破壊的な変更であることを忘れないでください。

### 並行処理を使用していないモジュールのインポート

他のモジュール内の型が実際には `Sendable` であったとしても、いつもその定義を変更できるとは限りません。
その場合は `@preconcurrency import` を使うことでライブラリがアップデートされるまで診断を格下げできます。

```swift
// ColorComponentsはこのモジュールに定義されている
@preconcurrency import UnmigratedModule

func updateStyle(backgroundColor: ColorComponents) async {
    // ここで隔離ドメインを横断している
    await applyBackground(backgroundColor)
}
```

`@preconcurrency import` を追加したため、 `ColorComponents` は依然として非 `Sendable` なままです。
しかしコンパイラのふるまいは変更されます。
Swift 6言語モードを使用しているなら、ここで生成されるエラーは警告に格下げされます。
Swift 5言語モードの場合、診断は全く生成されません。

### 潜在的な隔離

時として、`Sendable` 型が必要と _思われる_ ことが、実はより根本的な隔離の問題の兆候であることがあります。

型が `Sendable` でなければならない唯一の理由は隔離境界を越えるためです。
境界を一切越えないようにすると、よりシンプルに、かつシステムの本質をよりよく反映したものになることはよくあります。

```swift
@MainActor
func applyBackground(_ color: ColorComponents) {
}

func updateStyle(backgroundColor: ColorComponents) async {
    await applyBackground(backgroundColor)
}
```

この `updateStyle(backgroundColor:)` 関数は非隔離です。
これは非 `Sendable` な引数も非隔離であることを意味します。
`applyBackground(_:)` が呼ばれると、実装はこの非隔離ドメインから `MainActor` へただちに横断します。

`updateStyle(backgroundColor:)` は `MainActor` 隔離された関数および非 `Sendable` な型を直接操作しているため、単に `MainActor` 隔離を適用するほうが適切かもしれません。

```swift
@MainActor
func updateStyle(backgroundColor: ColorComponents) async {
    applyBackground(backgroundColor)
}
```

これで、非 `Sendable` 型が隔離境界を越えることはもうありません。
そしてこのケースでは、問題を解決するだけでなく非同期呼び出しの必要性もなくなりました。
潜在的な隔離の問題を解決することでAPIをさらに簡略化できる可能性があります。

このような `MainActor` 隔離の不足は、間違いなく、潜在的な隔離の最もありふれたタイプです。
開発者がこれを解決策として用いることを躊躇するのも非常によくあることです。
UIを持つプログラムが `MainActor` 隔離された大きな一連の状態を持つことは全く普通のことです。
_非同期_ 作業の長時間実行に関する懸念は、対象を絞ったわずかな `nonisolated` 関数により対処できることがよくあります。

### 計算して得られる値

境界を越えて非 `Sendable` 型を渡そうとする代わりに、必要な値を生成する `Sendable` 関数を使うことができるかもしれません。

```swift
func updateStyle(backgroundColorProvider: @Sendable () -> ColorComponents) async {
    await applyBackground(using: backgroundColorProvider)
}
```

ここでは `ColorComponents` が　`Sendable` でないことは問題になりません。
その値を計算可能な `@Sendable` 関数を使用することで、送信可能性の不足を完全に回避できます。

### 引数の送信

安全に実行できると証明できれば、コンパイラは非 `Sendable` な値が隔離境界を越えることを許可します。
それが必要だと明示的に宣言した関数は、より少ない制限の下、実装のなかで値を使用できます。

```swift
func updateStyle(backgroundColor: sending ColorComponents) async {
    // この境界横断はあらゆるケースで安全だと証明できる
    await applyBackground(backgroundColor)
}
```

`sending` 引数により、呼び出し元にいくつかの制限がかかります。
しかし、これは `Sendable` に準拠するよりも依然としてより簡単で適切です。
このテクニックは自分で管理していない型に対しても有効です。

### Sendableへの準拠

隔離ドメインの横断に関する問題に遭遇したときに、 `Sendable` への準拠を追加しようとすることはごく自然な反応です。
型を `Sendable` にする方法は4つあります。

#### グローバル隔離

任意の型にグローバル隔離を追加すると自動的に `Sendable` になります。

```swift
@MainActor
public struct ColorComponents {
    // ...
}
```

この型を `MainActor` に隔離したため、他の隔離ドメインからのアクセスは非同期に行なわなければなりません。
これによりドメイン間でインスタンスを安全に渡すことが可能になります。

#### アクター

アクターはプロパティがアクター隔離によって保護されるため暗黙的に `Sendable` へ準拠します。

```swift
actor Style {
    private var background: ColorComponents
}
```

`Sendable` への準拠を得ることに加えて、アクターは独自の隔離ドメインを持ちます。
これによりアクターは内部で他の非 `Sendable` 型を自由に扱うことができます。
これは大きな利点ですがトレードオフもあります。

アクターに隔離されたメソッドはすべて非同期でなければならないので、その型にアクセスする場所は非同期のコンテキストを必要とするかもしれません。
それだけでもこのような変更を慎重に行なう理由になります。
しかしさらに、アクターに入出力されるデータ自体が隔離境界を越える必要が出てくるかもしれません。
その結果さらに多くの `Sendable` 型が必要になる可能性があります。

```swift
actor Style {
    private var background: ColorComponents

    func applyBackground(_ color: ColorComponents) {
        // ここで非Sendableなデータを使用する
    }
}
```

非Sendableなデータ _および_ データに対する操作の両方をアクター内に移動することで、越えなければならない隔離境界がなくなります。
こうすることで、どの非同期コンテキストからも自由にアクセス可能な `Sendable` インターフェースが操作に対して提供されます。

#### 手動での同期

すでに手動で同期をとっている型があるなら、 `Sendable` への準拠に `unchecked` とつけることでそのことをコンパイラに示すことができます。

```swift
class Style: @unchecked Sendable {
    private var background: ColorComponents
    private let queue: DispatchQueue
}
```

Swiftの並行処理システムと統合するためにキューやロックあるいはその他の手動による同期の方式の使用をやめるよう強いられたと感じる必要はありません。
しかし、ほとんどの型は本質的にスレッド安全ではありません。
一般的なルールとして、もし型がまだスレッド安全でないなら、最初のアプローチとして型を `Sendable` にしようとするべきではありません。
最初に他のテクニックを試し、本当に必要なときのみ手動での同期に戻ってくるほうが簡単なことが多いです。

#### Sendableへの遡及的な準拠

依存先が手動での同期を用いた型を公開している場合もあります。
普通これはドキュメントを通してのみ見ることができます。
このケースでも `@unchecked Sendable` 準拠を追加できます。

```swift
extension ColorComponents: @retroactive @unchecked Sendable {
}
```

`Sendable` はマーカープロトコルなので、遡及的な準拠はバイナリの互換性の問題に直接影響しません。
しかし細心の注意を払って使用する必要があります。
手動での同期を用いる型には、 `Sendable` のセマンティクスと完全に一致しないような安全性への条件や例外が存在する可能性があります。
さらに、システムの公開APIの一部であるような型にこのテクニックを使用する場合には _特に_ 注意する必要があります。

> 注記: 遡及的な準拠についての詳細は、関連する[Swift evolutionのプロポーザル][SE-0364]を参照してください。

[SE-0364]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0364-retroactive-conformance-warning.md

#### Sendableな参照型

`unchecked` 修飾子なしに参照型を `Sendable` として有効にできますが、これは非常に限られた状況下でのみ可能です。

コンパイラが `Sendable` 準拠を確認できるようにするためには、クラスは

- `final` でなければなりません
- `NSObject` 以外のクラスを継承してはいけません
- 非隔離の可変なプロパティを持ってはいけません

```swift
public struct ColorComponents: Sendable {
    // ...
}

final class Style: Sendable {
    private let background: ColorComponents
}
```

`Sendable` に準拠する参照型は、値型が望ましいことの表れであることがあります。
しかし、参照セマンティクスを保持しなければならない場面やSwift/Objective-Cが混在するコードベースが必要な場面があります。

#### 組み合わせの使用

参照型を `Sendable` にするためのテクニックを1つだけ選ぶ必要はありません。
1つの型の内部で多くのテクニックを使うことができます。

```swift
final class Style: Sendable {
    private nonisolated(unsafe) var background: ColorComponents
    private let queue: DispatchQueue

    @MainActor
    private var foreground: ColorComponents
}
```

`foreground` プロパティがアクター隔離を使う一方で、 `background` プロパティは手動による同期で保護されています。
これら2つのテクニックを組み合わせることで、内部的なセマンティクスをより良く表現した型になります。
またこのようにすることで、コンパイラは型の隔離確認を引き続き自動で行なってくれます。

### 非隔離の初期化

アクター隔離された型が非隔離のコンテキストで初期化されたときに問題が発生することがあります。

これは、型がデフォルト値の式の中やプロパティの初期化で使用される場合に頻繁に発生します。

> 注記: これらの問題は[latent isolation](#Latent-Isolation)や[under-specified protocol](#Under-Specified-Protocol)の兆候である可能性があります。

ここでは非隔離の `Stylers` 型が `MainActor` 隔離されているイニシャライザを呼び出しています。

```swift
@MainActor
class WindowStyler {
    init() {
    }
}

struct Stylers {
    static let window = WindowStyler()
}
```

このコードは次のようなエラーになります。

```
 7 | 
 8 | struct Stylers {
 9 |     static let window = WindowStyler()
   |                `- error: main actor-isolated default value in a nonisolated context
10 | }
11 | 
```

グローバル隔離された型は、実際にはイニシャライザでどのグローバルアクターの状態も参照する必要がないことがあります。
`init` メソッドを `nonisolated` にすることで、どのような隔離ドメインからも自由に呼び出せます。
これは、任意の *隔離された* 状態が `MainActor` からのみアクセス可能であるとコンパイラが保証しているため安全なままです。

```swift
@MainActor
class WindowStyler {
    private var viewStyler = ViewStyler()
    private var primaryStyleName: String

    nonisolated init(name: String) {
        self.primaryStyleName = name
        // 型はここで完全に初期化される
    }
}
```

すべての `Sendable` なプロパティはこの `init` メソッドのなかで依然として安全にアクセスできます。
また、 非 `Sendable` なプロパティは初期化できないもののデフォルト式を使えば初期化できます。

### デイニシャライゼーションは非隔離

アクター隔離を持つ型であっても、デイニシャライザは _常に_ 非隔離です。

```swift
actor BackgroundStyler {
    // もう1つのアクター隔離された型
    private let store = StyleStore()

    deinit {
        // これは非隔離
        store.stopNotifications()
    }
}
```

このコードは次のエラーを発生させます：

```
error: call to actor-isolated instance method 'stopNotifications()' in a synchronous nonisolated context
 5 |     deinit {
 6 |         // this is non-isolated
 7 |         store.stopNotifications()
   |               `- error: call to actor-isolated instance method 'stopNotifications()' in a synchronous nonisolated context
 8 |     }
 9 | }
```

この型がアクターであるため意外に感じられるかもしれませんが、これは新しい制約になっていません。
デイニシャライザを実行するスレッドが過去に保証されたことはなく、Swiftのデータ隔離が今その事実を表面化させただけです。

多くの場合、 `deinit` 内で行なわれる作業が同期的である必要はありません。
解決策は、構造化されていない `Task` を使用し、隔離された値をキャプチャしたのちに操作することです。
このテクニックを使用する際は、暗黙的にでも `self` をキャプチャしないようにすることが _重要_ です。

```swift
actor BackgroundStyler {
    // もう1つのアクター隔離された型
    private let store = StyleStore()

    deinit {
        // ここにアクター隔離はないので、タスクに引き継がれる隔離コンテキストもない
        Task { [store] in
            await store.stopNotifications()
        }
    }
}
```

> 重要: `deinit` 内から `self` のライフタイムを延長 **しないで** ください。実行時にクラッシュします。
