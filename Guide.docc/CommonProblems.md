# 頻出のコンパイルエラー

本ページではSwiftでconcurrencyを使用した際によく目にする問題を特定し、理解し、対処します。

コンパイラによって保証されるデータ隔離はすべてのSwiftのコードに影響します。
これは、たとえ対象がconcurrencyの言語機能を直接使用しないSwift 5のコードであっても、その中の潜在的な問題をcomplete concurrency checkingが明るみに出せることを意味します。
そして、Swift 6言語モードがオンになると、それらの潜在的な問題のいくつかがエラーになる可能性があります。

complete checkingを有効にすると、多くのプロジェクトにおいて大量の警告やエラーが発生する可能性があります。
圧倒されてはいけません！
ほとんどの警告やエラーは、より小さな根本的原因まで突き止めることができます。
そしてそれらの原因は、修正がとても簡単であるというだけでなく、Swiftのデータ隔離モデルの理解に役立つ非常に有益な頻出パターンの結果であることがしばしばあります。

## 安全でない大域的静的変数

静的変数を含む大域的状態はプログラムのどこからでもアクセスできます。
その可視性から、大域的状態は並行アクセスの影響を特に受けやすくなっています。
データ競合安全が導入される以前のグローバル変数パターンでは、プログラマーはコンパイラの助けなしにデータ競合を回避するというやり方で大域的状態へ慎重にアクセスしていました。

### Sendable型

```swift
var islandsInTheSea = 42
```

ここにグローバル変数の宣言があります。
このグローバル変数は隔離されておらず、 _かつ_ どの隔離ドメインからも変更可能です。Swift 6モードで上記コードをコンパイルするとエラーメッセージが表示されます。

```
1 | var islandsInTheSea = 42
  |              |- error: global variable 'islandsInTheSea' is not concurrency-safe because it is non-isolated global shared mutable state
  |              |- note: convert 'islandsInTheSea' to a 'let' constant to make the shared state immutable
  |              |- note: restrict 'islandsInTheSea' to the main actor if it will only be accessed from the main thread
  |              |- note: unsafely mark 'islandsInTheSea' as concurrency-safe if all accesses are protected by an external synchronization mechanism
2 |
```

異なる隔離ドメインでこの変数にアクセスする2つの関数はデータ競合を起こす危険性があります。次のコードでは、異なる隔離ドメインからの `addIsland()` の呼び出しと並行して `printIslands()` がメインアクター上で実行される可能性があります。

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

この問題に対処する方法の1つが、変数の隔離を変更することです。

```swift
@MainActor
var islandsInTheSea = 42
```

この変数は変更可能なままですがグローバルアクターに隔離されました。
すべてのアクセスは1つの隔離ドメイン内でしか起こらなくなり、 `addIsland` 内での同期アクセスはコンパイル時に無効になります。

もし変数が定数であるべきで一切変更されないのなら、コンパイラにそのことを伝えるのが率直な解決方法です。
`var` を `let` に変更することでコンパイラは変更を静的に禁止でき、安全な読み取り専用アクセスが保証されます。

```swift
let islandsInTheSea = 42
```

コンパイラから見えない方法でこの変数を保護するための同期をとっているなら、 `nonisolated(unsafe)` キーワードを使うことで `islandsInTheSea` に対するすべての隔離チェックを無効化できます。

```swift
/// `islandLock` を保持している間だけこの値にアクセスしてよい。
nonisolated(unsafe) var islandsInTheSea = 42
```

変数への全アクセスをロックやディスパッチキューといった外部同期メカニズムを使って慎重に管理しているときのみ `nonisolated(unsafe)` を使用してください。

手動で同期を表すためのメカニズムは他にもたくさんあり、[Opting-Out of Isolation Checking][]（近日公開予定）で説明しています。

[Opting-Out of Isolation Checking]: #

### 非Sendable型

先の例では、変数は `Int` 型で、本質的に `Sendable` である値型です。
大域的 _参照_ 型は一般的に `Sendable` でないため、さらに困難を伴います。

```swift
class Chicken {
    let name: String
    var currentHunger: HungerLevel

    static let prizedHen = Chicken()
}
```

`static let` 宣言を伴うこちらの問題は、変数の変更可能性とは関係がありません。
問題は `Chicken` が非Sendable型であるために隔離ドメイン間で内部状態を共有することが安全でないことです。

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

ここに、 `Chicken.prizedHen` の内部状態に並行してアクセスしうる2つの関数があります。
コンパイラは、このように隔離をまたいでのアクセスは `Sendable` 型でのみ許可しています。
選択肢の1つとして、グローバルアクターを使用して変数を単一のドメインに隔離する方法があります。
しかし、その代わりに `Sendable` に直接準拠することも理にかなっています。

`Sendable` に準拠する方法の詳細については、[Making Types Sendable][]（近日公開予定）の章を参照してください。

[Making Types Sendable]: #

> 大域的静的変数のコードのさらなる例については、（パッケージ内の関連するSwiftファイルへのリンク）を参照してください。

## プロトコル準拠時の隔離不一致

プロトコルは準拠型が満たすべき要件を定義しています。
Swiftは、プロトコルの使用者がデータ隔離を尊重する方法でメソッドやプロパティと関わることを保証します。
そのためには、プロトコル自身と要件の両方が静的隔離を指定する必要があります。
その結果、プロトコルの宣言と準拠型の間で隔離の不一致が生じる可能性があります。

この種の問題に対してはさまざまな解決策が考えられますが、トレードオフを伴うことが多いです。
適切なアプローチを選ぶには、まず、そもそも _なぜ_ 不一致が発生するのかを理解する必要があります。

### 規定が不十分なプロトコル

この問題で最もよく遭遇するのは、プロトコルに明確な隔離がない場合です。
この場合、他の宣言と同様、_隔離されない_ ことを暗示します。
隔離されていないプロトコルの要件は、どんな隔離ドメイン内の一般的なコードからも呼び出すことができます。もし要件が同期的であるなら、準拠型の実装からアクター隔離された状態へのアクセスは無効になります。

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

プロトコルは実際には隔離されている _はず_ という可能性もありますが、concurrencyのための更新がなされていないだけです。
もし正しい隔離を追加するために準拠型をマイグレーションしたら不一致が発生するでしょう。

```swift
// これはメインアクターの型から使用することにしか本当に意味がないのだが、それを反映するアップデートがまだなされていない。
protocol Feedable {
    func eat(food: Pineapple)
}

// 現在は正しく隔離されている準拠型が不一致を露呈した。
@MainActor
class Chicken: Feedable {
}
```

#### 隔離の追加

もしプロトコルの要件が常にメインアクターから呼び出されるならば、 `@MainActor` を追加することが最善の解決策です。

プロトコルの要件をメインアクターに隔離する方法は2つあります。

```swift
// プロトコル全体に対して
@MainActor
protocol Feedable {
    func eat(food: Pineapple)
}

// 要件ごとに対して
protocol Feedable {
    @MainActor
    func eat(food: Pineapple)
}
```

グローバルアクター属性でプロトコルをマーキングすることは、すべてのプロトコル要件と拡張メソッドがグローバルアクター隔離されることを意味します。
拡張内で準拠が宣言されていない場合は、準拠型もグローバルアクターであると推論されます。

推論は要件の実装にのみ適用されるため、要件ごとの隔離がアクター隔離の推論に与える影響はより限定的です。プロトコルの拡張や準拠型のその他のメソッドについて推測する隔離には影響を与えません。
準拠型に同一のグローバルアクターが必ずしも結びつかないことに意味があるならこちらのアプローチが好ましいです。

いずれにせよ、プロトコルの隔離を変更することは準拠型の隔離に影響を与え、それにより一般的な要件においてプロトコルを使う一般的なコードに制限を課すことができます。
`@preconcurrency` を使うことで、プロトコルへグローバルアクター隔離を追加することで生じる診断を段階的に進めることができます。

```swift
@preconcurrency @MainActor
protocol Feedable {
    func eat(food: Pineapple)
}
```

> "プロトコル隔離"のコード例へのリンク

#### 非同期要件

同期プロトコルの要件を実装するメソッドについては、メソッドの隔離が要件の隔離と完全に一致するかメソッドが `nonisolated` でなければならない、つまりデータ競合のリスクなしに他の隔離ドメインから呼び出すことができることを意味します。
要件を非同期にすることで準拠型の隔離に対してより多くの柔軟性が提供されます。

```swift
protocol Feedable {
    func eat(food: Pineapple) async
}
```

`async` メソッドは実装内の対応するアクターに切り替えることで隔離を保障するため、隔離されていない `async` プロトコルの要件を隔離されたメソッドを用いて満たすことができます。

```swift
@MainActor
class Chicken: Feedable {
    var isHungry: Bool = true
    func eat(food: Pineapple) {
        // メインアクターの状態にアクセスする前に @MainActor に暗黙的に切り替える

        isHungry.toggle()
    }
}
```

一般的なコードは常に `eat(food:)` を非同期で呼び出さなければならないため上記のコードは安全であり、隔離された実装はアクター隔離された状態へアクセスする前にアクターを切り替えることができます。

しかしこの柔軟性にはコストがかかります。
メソッドを非同期に変更するとあらゆる呼び出し元に大きな影響が出る可能性があります。
非同期コンテキストに加え、パラメータと戻り値の両方で隔離境界を越える必要があるかもしれません。
これらを合わせると、対応のために大幅な構造の変更が必要になる可能性があります。
これでも正しい解決かもしれませんが、たとえ関係する型が少数であってもその副作用をまず注意深く考慮すべきです。

#### Preconcurrencyの使用

Swiftには、段階的にconcurrencyを導入し、まだ全くconcurrencyを使用していないコードと相互運用するのを助ける多くのメカニズムがあります。
これらのツールは、あなたが所有していないコードはもちろん、あなたが所有しているが簡単に変更できないコードの両方に役立ちます。

```swift
@MainActor
class Chicken: Feedable {
    nonisolated func eat(food: Pineapple) {
        MainActor.assumeIsolated {
            // 本体の実装
        }
    }
}

// Swift 6のDynamicActorIsolationによる人間工学と安全性の向上
@MainActor
class Chicken: @preconcurrency Feedable {
    func eat(food: Pineapple) {
        // 本体の実装
    }
}
```

このテクニックには2つのステップがあります。
まず、不一致の原因であるあらゆる静的隔離を取り除きます。
次に、関数本体のなかで有用な作業ができるように、隔離を動的に再導入します。
これによりコンパイルエラーの原因を局所的に解決できます。
また、これは隔離の変更を段階的に行なうときにも最適な選択肢です。

> "preconcurrency protocols"のコード例へのリンク

### 隔離された準拠型

今までのところ、提示した解決策は隔離の不一致の原因が最終的にはプロトコルの定義にあることを前提としています。
しかし、プロトコルの静的隔離は適切だが準拠型によってのみ問題が引き起こされるということもあり得ます。

#### 未隔離

完全に隔離されていない関数も依然として役に立つことがあります。

```swift
@MainActor
class Chicken: Feedable {
    nonisolated func eat(food: Pineapple) {
        // おそらく、他のメインアクター隔離の状態とこの実装は関係がない
    }
}
```

このような実装の欠点は、隔離されている状態と関数が利用できなくなることです。
これは間違いなく大きな制約ですが、特にインスタンスに依存しない設定の情報源としてのみ利用するならそれでも適切かもしれません。

#### プロキシによる準拠

静的隔離の違いへの対処を促進するために中間型が使用可能でしょう。
これはプロトコルが準拠型による継承を必要としているなら特に有効です。

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

間接的に準拠するための新しい型を導入することでこの状況を解決できます。
しかし、この解決方法は `Island` の構造的な変更が必要になり、それに依存するコードにも波及する可能性があります。

```swift
struct LivingIsland: Feedable {
    func eat(food: Pineapple) {
    }
}
```

ここでは、必要な継承を満たすような新しい型を作成しました、
もしこの準拠が `Island` によって内部的にだけ使用されるのなら合体するのがもっとも簡単でしょう。

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

