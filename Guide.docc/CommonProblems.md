# 頻出のコンパイルエラー

本ページではSwift Concurrencyを使用した際によく目にする問題を特定し、理解し、対処します。

|原文|[https://github.com/apple/swift-migration-guide/blob/main/Guide.docc/CommonProblems.md](https://github.com/apple/swift-migration-guide/blob/main/Guide.docc/CommonProblems.md)|
|---|---|
|更新日|2024/6/30(翻訳を最後に更新した日付)|
|ここまで反映|[https://github.com/apple/swift-migration-guide/commit/6487820801552379ffdcb2b166ca0b97c73b697a](https://github.com/apple/swift-migration-guide/commit/6487820801552379ffdcb2b166ca0b97c73b697a)|

コンパイラによって保証されるデータ隔離はすべてのSwiftのコードに影響します。
これにより、完全な並行性の確認は、直接並行処理の言語機能を使用していないSwift 5のコードでも潜在的な問題を浮き彫りにすることがあります。
また、Swift 6言語モードをオンにすると、これらの潜在的な問題のいくつかがエラーとして扱われるようになります。

完全確認を有効にすると、多くのプロジェクトで大量の警告やエラーが発生する可能性があります。
圧倒されないでください！
警告やエラーをたどっていくと、そのほとんどが小さな根本的原因の積み重ねによるものだとわかります。
そして、その原因は共通のパターンによるもので、簡単に修正できるだけでなく、Swiftのデータ隔離モデルを理解するのにも役立ちます。

## 安全でないグローバルおよび静的変数

静的変数を含むグローバルな状態はプログラムのどこからでもアクセスできます。
この可視性により、グローバルな状態は特に同時アクセスの影響を受けやすくなります。
データ競合の安全性が確立される以前の環境でグローバル変数へアクセスする際は、プログラマーはコンパイラのサポートなしに自分で工夫してデータ競合を避けていました。

### Sendable型

```swift
var islandsInTheSea = 42
```

ここにグローバル変数を宣言しました。
このグローバル変数は隔離されておらず、 _かつ_ どの隔離ドメインからも変更可能です。Swift 6モードでこのコードをコンパイルするとエラーメッセージが表示されます。

```
1 | var islandsInTheSea = 42
  |              |- error: global variable 'islandsInTheSea' is not concurrency-safe because it is non-isolated global shared mutable state
  |              |- note: convert 'islandsInTheSea' to a 'let' constant to make the shared state immutable
  |              |- note: restrict 'islandsInTheSea' to the main actor if it will only be accessed from the main thread
  |              |- note: unsafely mark 'islandsInTheSea' as concurrency-safe if all accesses are protected by an external synchronization mechanism
2 |
```

異なる隔離ドメインを持つ2つの関数がこの変数にアクセスすると、データ競合のリスクがあります。次のコードでは、 `printIslands()` がメインアクター上で動作するのと同時に、別の隔離ドメインから `addIsland()` が呼び出される可能性があります。

```swift
@MainActor
func printIslands() {
    print("Islands in the sea of concurrency: ", islandsInTheSea)
}

func addIsland() {
    let island = Island()

    islandsInTheSea += 1

    addToMap(island)
}
```

問題に対処する1つの方法は、変数の隔離方法を変更することです。

```swift
@MainActor
var islandsInTheSea = 42
```

変数は可変のままですが、グローバルアクターに隔離されるようになります。
すべてのアクセスは1つの隔離ドメイン内でのみ起こるようになり、 `addIsland` 内での同期アクセスはコンパイル時に無効になります。

もし変数が定数であり変更されないのであれば、単純な解決策はそれをコンパイラに明示することです。
`var` を `let` に変更することでコンパイラは変更を静的に禁止でき、安全な読み取り専用アクセスを保証します。

```swift
let islandsInTheSea = 42
```

もしこの変数を保護するための同期機構があり、それがコンパイラに見えない場合は、`nonisolated(unsafe)` キーワードを使って `islandsInTheSea` のすべての隔離チェックを無効化できます。

```swift
/// `islandLock` を保持している間だけこの値にアクセスしてよい。
nonisolated(unsafe) var islandsInTheSea = 42
```

`nonisolated(unsafe)` は、ロックやディスパッチキューなどの外部同期機構で変数へのすべてのアクセスを慎重に保護している場合にのみ使用してください。

手動同期を表現するための他の多くのメカニズムについては、[隔離チェックのオプトアウト][]（近日公開予定）で説明しています。

[Opting-Out of Isolation Checking]: #

### 非Sendable型

先の例では、変数は `Int` 型で、本質的に `Sendable` である値型です。
グローバルな _参照_ 型は一般的に `Sendable` でないため、さらに困難を伴います。

```swift
class Chicken {
    let name: String
    var currentHunger: HungerLevel

    static let prizedHen = Chicken()
}
```

この `static let` 宣言の問題は、変数が変更可能かどうかには関係ありません。
問題は、 `Chicken` が非Sendable型であるため、その内部状態を異なる隔離ドメイン間で安全に共有できないことです。

```swift
func feedPrizedHen() {
    Chicken.prizedHen.currentHunger = .wellFed
}

@MainActor
class ChickenValley {
    var flock: [Chicken]

    func compareHunger() -> Bool {
        flock.contains { $0.currentHunger > Chicken.prizedHen.currentHunger }
    }
}
```

ここでは、`Chicken.prizedHen` の内部状態に同時にアクセスする可能性がある2つの関数を示しています。
コンパイラは、このような異なる隔離ドメイン間のアクセスをSendableな型に対してのみ許可します。
1つの選択肢として、グローバルアクターを使用して変数を単一のドメインに隔離することが考えられます。
しかし、代わりにSendableへの準拠を直接追加するのも有効です。

`Sendable` に準拠する方法の詳細については、[型をSendableにする方法][]（近日公開予定）の章を参照してください。

[Making Types Sendable]: #

> グローバルであり静的な変数のコードのさらなる例については、（パッケージ内の関連するSwiftファイルへのリンク）を参照してください。

## プロトコル準拠時の隔離不一致

プロトコルは、準拠する型が満たさなければならない要件を定義します。
Swiftは、プロトコルのクライアントがそのメソッドやプロパティと対話する際にデータの隔離を尊重するようにします。
このためには、プロトコル自体とその要件の両方が静的な隔離を指定する必要があります。
これにより、プロトコルの宣言と準拠する型の間に隔離の不一致が生じることがあります。

この種の問題に対してはさまざまな解決策が考えられますが、トレードオフを伴うことが多いです。
適切なアプローチを選ぶには、まず、そもそも _なぜ_ 不一致が発生するのかを理解する必要があります。

### 明示的に隔離されていないプロトコル

この問題で最も一般的に遭遇する形は、プロトコルに明示的な隔離がない場合です。
この場合、他のすべての宣言と同様に、 _非隔離_ であることを意味します。
非隔離のプロトコル要件は、どの隔離ドメインでもプロトコルで抽象化したコードから呼び出すことができます。もし要件が同期的であれば、準拠する型の実装がアクター隔離された状態にアクセスすることは無効です。

```swift
protocol Feedable {
    func eat(food: Pineapple)
}

@MainActor
class Chicken: Feedable {
    func eat(food: Pineapple) {
        // メインアクター隔離された状態へのアクセス
    }
}
```

上記のコードは、Swift 6モードで次のエラーを生成します。

```
 5 | @MainActor
 6 | class Chicken: Feedable {
 7 |     func eat(food: Pineapple) {
   |          |- error: main actor-isolated instance method 'eat(food:)' cannot be used to satisfy nonisolated protocol requirement
   |          `- note: add 'nonisolated' to 'eat(food:)' to make this instance method not isolated to the actor
 8 |         // メインアクター隔離された状態へのアクセス
 9 |     }
```

プロトコルは実際には _隔離されるべき_ 可能性もありますが、まだ並行処理に対応して更新されていないだけかもしれません。
正しい隔離を追加するために準拠する型を先に移行すると、不一致が発生します。

```swift
// このプロトコルは実際にはMainActor型から使用するのが適切だが、まだそれを反映するように更新されていない。
protocol Feedable {
    func eat(food: Pineapple)
}

// 準拠している型は現在正しく隔離されており、この不一致を明らかにした。
@MainActor
class Chicken: Feedable {
}
```

#### 隔離の追加

プロトコルの要件が常にメインアクターから呼び出される場合、 `@MainActor` を追加することが最適な解決策です。

プロトコルの要件をメインアクターに隔離する方法は2つあります。

```swift
// プロトコル全体
@MainActor
protocol Feedable {
    func eat(food: Pineapple)
}

// 要件ごと
protocol Feedable {
    @MainActor
    func eat(food: Pineapple)
}
```

プロトコルにグローバルアクター属性をつけると、すべてのプロトコル要件およびextensionメソッドに対してグローバルアクター隔離が適用されます。
また、準拠がextensionで宣言されていない場合、準拠する型にもグローバルアクターが推論されます。

推論は要件の実装にのみ適用されるため、要件ごとの隔離がアクター隔離の推論に与える影響はより限定的です。プロトコルのextensionや準拠型のその他のメソッドに対する隔離の推論には影響を与えません。
準拠型に同一のグローバルアクターが必ずしも結びつかないことに意味があるならこちらのアプローチが好ましいです。

いずれにせよ、プロトコルの隔離を変更すると、準拠する型の隔離に影響を与え、ジェネリックな要件でプロトコルを使用し抽象化したコードに制約を課す可能性があります。
そこで、 `@preconcurrency` を使うことで、プロトコルへグローバルアクター隔離を追加することで生じる診断を段階的に進めることができます。

```swift
@preconcurrency @MainActor
protocol Feedable {
    func eat(food: Pineapple)
}
```

> "プロトコル隔離"のコード例へのリンク

#### 非同期要件

同期プロトコル要件を実装するメソッドの場合、メソッドの隔離が要件の隔離と正確に一致するか、メソッドが `nonisolated` でなければなりません。 `nonisolated` にすることで任意の隔離ドメインからデータ競合のリスクなしに呼び出すことができます。
要件を非同期にすることで準拠する型の隔離に対してはるかに多くの柔軟性が提供されます。

```swift
protocol Feedable {
    func eat(food: Pineapple) async
}
```

`async` メソッドは実装中に対応するアクターに切り替わることで隔離を保証するため、非隔離の `async` プロトコル要件を隔離されたメソッドを用いて満たすことができます。

```swift
@MainActor
class Chicken: Feedable {
    var isHungry: Bool = true
    func eat(food: Pineapple) {
        // メインアクターの状態にアクセスする前に @MainActor に暗黙的に切り替わる

        isHungry.toggle()
    }
}
```

上記のコードは安全です。なぜなら、抽象化したコードは常に `eat(food:)` を非同期に呼び出さなければならず、これにより隔離された実装がアクター隔離状態にアクセスする前にアクターを切り替えることができるからです。

しかし、この柔軟性には代償があります。
メソッドを非同期に変更することは、すべての呼び出し箇所に大きな影響を与える可能性があります。
非同期コンテキストに加え、パラメータと戻り値の両方が隔離境界を越える必要があるかもしれません。
これらは大幅な構造変更を必要とすることがあります。
この方法が正しい解決策であるかもしれませんが、関与する型が少数であっても、その副作用を慎重に考慮する必要があります。

#### Preconcurrencyの活用

Swiftには、並行処理を段階的に導入し、まだ並行処理を全く使用していないコードと相互運用するための多くのメカニズムがあります。
これらのツールは、自分が所有していないコードはもちろん、所有しているが簡単に変更できないコードに対しても役立ちます。

```swift
@MainActor
class Chicken: Feedable {
    nonisolated func eat(food: Pineapple) {
        MainActor.assumeIsolated {
            // 本体の実装
        }
    }
}

// Swift 6のDynamicActorIsolationにより使いやすさと安全性が改善された
@MainActor
class Chicken: @preconcurrency Feedable {
    func eat(food: Pineapple) {
        // 本体の実装
    }
}
```

この技術は2つのステップからなります。
まず、不一致を引き起こしている静的な隔離を取り除きます。
次に、関数本体内で有効な作業を行なうために、隔離を動的に再導入します。
これによりコンパイルエラーの発生源に限った解決となります。
また、隔離の変更を段階的に行なう際の優れたオプションです。

> "preconcurrency protocols"のコード例へのリンク

### 隔離された準拠型

これまでに紹介した解決策は、隔離の不一致の原因が最終的にプロトコルの定義にあると仮定しています。
しかし、プロトコルの静的な隔離は適切で、準拠する型だけが問題の原因である可能性もあります。

#### 非隔離

完全に非隔離の関数でも、依然として有用である場合があります。

```swift
@MainActor
class Chicken: Feedable {
    nonisolated func eat(food: Pineapple) {
        // 多分この実装では他のメインアクター隔離状態を使用しない
    }
}
```

このような実装の欠点は、隔離された状態や関数が利用できなくなることです。
これは確かに大きな制約ですが、それでも適切である場合があります。特に、インスタンスに依存しない設定のソースとしてのみ使用される場合にはなおさらです。

#### プロキシによる準拠

静的隔離の違いに対処するために中間型が使用できます。
これは、プロトコルが準拠する型へ継承を要求する場合に特に効果的です。

```swift
class Animal {
}

protocol Feedable: Animal {
    func eat(food: Pineapple)
}

// アクターはクラスベースの継承を持つことができない
actor Island: Feedable {
}
```

新しい型を導入して間接的に準拠させることで、この状況を解決できます。
しかし、この解決策は `Island` の構造的な変更を必要とし、それに依存するコードにも影響を与える可能性があります。

```swift
struct LivingIsland: Feedable {
    func eat(food: Pineapple) {
    }
}
```

ここでは、必要な継承を満たすために新しい型を作成しました。
もしこの準拠した型（`LivingIsland`）が `Island` によって内部だけで使用されるのなら、`Island`の内部に含めるのがもっとも簡単な方法でしょう。

> "準拠型プロキシ"コード例へのリンク

> 次のような問題点に対するSwift 5.10コンパイラによる診断の例
>  
> `Actor-isolated instance method '_' cannot be used to satisfy nonisolated protocol requirement`  
>  
> `Main actor-isolated instance method '_' cannot be used to satisfy nonisolated protocol requirement`  
>  
> `main actor-isolated property '_' cannot be used to satisfy nonisolated protocol requirement`  
>  
> `actor-isolated property '_' cannot be used to satisfy nonisolated protocol requirement`  
>  
> `main actor-isolated static property '_' cannot be used to satisfy nonisolated protocol requirement`  
>  
> `main actor-isolated static method '_' cannot be used to satisfy nonisolated protocol requirement`  

