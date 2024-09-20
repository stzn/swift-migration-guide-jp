# 段階的な導入

Swiftの並行処理機能を段階的にプロジェクトへ導入する方法を学びましょう。

|原文|[https://github.com/apple/swift-migration-guide/blob/main/Guide.docc/IncrementalAdoption.md](https://github.com/apple/swift-migration-guide/blob/main/Guide.docc/IncrementalAdoption.md)|
|---|---|
|更新日|2024/7/26(翻訳を最後に更新した日付)|
|ここまで反映|[https://github.com/apple/swift-migration-guide/commit/93dddab3f5f25f24c03e7a7029b866dc22069812](https://github.com/apple/swift-migration-guide/commit/93dddab3f5f25f24c03e7a7029b866dc22069812)|

Swift 6言語モードへのプロジェクトの移行は、通常、段階的に行なわれます。
実際、多くのプロジェクトはSwift 6が利用可能になる前に移行プロセスを開始しました。
私たちは移行途中で出てくる問題に対処しながら並行処理機能を _徐々に_ 導入できます。
これにより、プロジェクト全体を邪魔することなく、段階的に移行を進めることができます。

Swiftには段階的に導入しやすくするための多くの言語機能と標準ライブラリAPIがあります。

## コールバックベース関数のラッピング

1つの関数を受け取って完了時に呼び出すAPIは、Swiftでは非常に一般的なパターンです。
非同期コンテキストから直接使えるバージョンの関数を作れます。

```swift
func updateStyle(backgroundColor: ColorComponents, completionHandler: @escaping () -> Void) {
    // ...
}
```

これはコールバックを使って呼び出し元に作業の完了を知らせる関数の例です。
いつどんなスレッドでコールバックが呼び出されるかは、ドキュメントを参照しなければ呼び出し元にはわかりません。

_継続_ を使うことでこの関数を非同期版にラップできます。

```swift
func updateStyle(backgroundColor: ColorComponents) async {
    await withCheckedContinuation { continuation in
        updateStyle(backgroundColor: backgroundColor) {
            // ... ここで作業を実行する ...

            continuation.resume()
        }
    }
}
```

> 注記: 継続は _ちょうど一度だけ再開する_ ように注意しなければなりません。
> 呼び出し損ねると、呼び出し元のタスクは永久に中断されたままになります。
> 一方、チェックされた継続（checked continuation）を2回以上再開すると、意図的にクラッシュが発生して未定義の動作を防ぎます。

非同期版には、もはや曖昧さはありません。
関数が完了した後、実行は常に開始時と同じコンテキストで再開されます。

```swift
await updateStyle(backgroundColor: color)
// スタイルが更新された
```

`withCheckedContinuation` 関数は、非同期ではないコードと非同期のコードをつなぎ合わせることを可能にするために存在する[一連の標準ライブラリAPI][continuation-apis]の1つです。

> 注記: プロジェクトに非同期コードを導入するとデータ隔離チェック違反を引き起こす場合があります。これを理解し、対処するには、[隔離境界の横断][Crossing Isolation Boundaries]を参照してください。

[Crossing Isolation Boundaries]: commonproblems#Crossing-Isolation-Boundaries
[continuation-apis]: https://developer.apple.com/documentation/swift/concurrency#continuations

## 動的隔離

アノテーションやその他の言語構造を使って、プログラムが静的に隔離されていることを表現できるなら、それが強力かつ簡潔です。
しかし、すべての依存関係を同時に更新せずに静的隔離を導入するのが難しい場合もあります。

動的隔離は、データの隔離を表現するためのフォールバックとして使用できる、ランタイム時のメカニズムを提供します。
動的隔離は、Swift 6のコンポーネントとまだ更新されていない別のコンポーネントを、（たとえそれらが _同じ_ モジュール内にあったとしても）つなぎ合わせるために不可欠なツールです。

### 内部のみの隔離

プロジェクト内のとある参照型を `MainActor` で静的に隔離することが最適と判断したとします。

```swift
@MainActor
class WindowStyler {
    private var backgroundColor: ColorComponents

    func applyStyle() {
        // ...
    }
}
```

この `MainActor` の隔離は _論理的には_ 正しいかもしれません。
しかし、まだ移行していない他の場所でこの型が使われている場合、ここに静的隔離を追加すると大量の追加の変更が必要になる可能性があります。
代替案として、スコープを制御するために動的隔離を使うという方法があります。

```swift
class WindowStyler {
    @MainActor
    private var backgroundColor: ColorComponents

    func applyStyle() {
        MainActor.assumeIsolated {
            // `MainActor` に隔離された他の状態を使用しやり取りする
        }
    }
}
```

ここでは、隔離はクラスの内部に取り込まれています。
これにより、変更はその型の中に局所化され、型の呼び出し元に影響を与えることなく変更を加えられます。

しかし、この方法の大きな欠点は、型の本当の隔離要件が見えないままであることです。
呼び出し元には、この公開APIにもとづいて変更すべきかどうか、あるいはどのように変更すべきかを判断する方法がありません。
この方法は一時的な解決策としてのみ、そして他の選択肢がない場合にのみ使うべきです。

### 使用箇所のみの隔離

型の内部だけで隔離することが現実的でないなら、その代わりにAPIを使う箇所だけカバーするように隔離を拡張できます。

そのためには、まず型に静的隔離を適用し、次にAPIの使用箇所へ動的隔離を適用します：

```swift
@MainActor
class WindowStyler {
    // ...
}

class UIStyler {
    @MainActor
    private let windowStyler: WindowStyler
    
    func applyStyle() {
        MainActor.assumeIsolated {
            windowStyler.applyStyle()
        }
    }
}
```

静的隔離と動的隔離を組み合わせることで、変更範囲を緩やかにするための強力なツールとなり得ます。

### 明示的なMainActorコンテキスト

`assumeIsolated` メソッドは同期型で、想定が間違っていた場合に実行を阻止することで隔離情報をランタイム時から型システムに回復させるために存在します。 `MainActor` 型には、非同期コンテキストにおいて隔離を手動で切り替えるために使用できるメソッドもあります。

```swift
// // MainActor であるべき型だが、まだ更新されていない
class PersonalTransportation {
}

await MainActor.run {
    // ここで MainActor に隔離されている
    let transport = PersonalTransportation()
    
    // ...
}
```

静的隔離のおかげでコンパイラは必要に応じて隔離を切り替えるというプロセスを検証し自動化できることを忘れないでください。
たとえ`MainActor.run`を静的隔離と組み合わせて使う場合でも、本当に `MainActor.run` が必要であるときを見極めるのは難しいかもしれません。
`MainActor.run` は移行の際に役立ちますが、システムの隔離要件を静的に表現するための代用品として使うべきではありません。
最終的な目標はやはり `@MainActor` を `PersonalTransportation` に適用することです。

## アノテーションがついていない場合

動的隔離は実行時の隔離を表現するツールを提供します。
しかし、移行していないモジュールから欠落した同期プロパティを記述しなければならないこともあるでしょう。

### アノテーションのない送信可能なクロージャ

クロージャの送信可能性（sendability）はコンパイラがクロージャ本体の隔離をどのように推論するかに影響を与えます。
実際には隔離境界を越えているにもかかわらず `Sendable` アノテーションが欠落しているコールバッククロージャは、並行処理システムの重要な不変条件に違反しています。

```swift
// Swift 6以前のモジュールで定義されている
extension JPKJetPack {
    // @Sendableの欠落に注目
    static func jetPackConfiguration(_ callback: @escaping () -> Void) {
        // 隔離ドメインを越える可能性がある
    }
}

@MainActor
class PersonalTransportation {
    func configure() {
        JPKJetPack.jetPackConfiguration {
            // MainActorに隔離されているとここで推論される
            self.applyConfiguration()
        }
    }

    func applyConfiguration() {
    }
}
```

`jetPackConfiguration` が別の隔離ドメインでクロージャを呼び出すことができるなら `@Sendable` をつける必要があります。
まだ移行していないモジュールが `@Sendable` をつけていない場合、アクターの推論が不正確に行なわれることになります。
このコードは問題なくコンパイルできますがランタイム時にクラッシュします。

> 注記: コンパイラは、コンパイラから見える情報の _欠落_ を検出あるいは診断することはできません。

これを回避するには、クロージャに手動で `@Sendable` のアノテーションをつけます。
これによりコンパイラは `MainActor` の隔離を推論しなくなります。
コンパイラはアクターの隔離が変わるかもしれないことを知っているため、呼び出し元でタスクを用意しタスク内で待機する必要があります。

```swift
@MainActor
class PersonalTransportation {
    func configure() {
        JPKJetPack.jetPackConfiguration { @Sendable in
            // Sendable なクロージャはアクター隔離を推論せず、
            // 非隔離であるとみなす
            Task {
                await self.applyConfiguration()
            }
        }
    }

    func applyConfiguration() {
    }
}
```

あるいは、コンパイラフラグ `-disable-dynamic-actor-isolation` を使ってモジュールに対する実行時の隔離アサーションを無効にできます。
これはランタイム時の動的アクター隔離の強制をすべて抑制します。

> 警告: このフラグの使用には注意が必要です。
> これらのランタイム時の確認を無効にするとデータ隔離違反を許すことになります。

## DispatchSerialQueueとアクターの統合

デフォルトでは、アクターが作業のスケジューリングと実行に使用するメカニズムはシステムで定義されています。
しかし、これを上書きしてカスタムの実装を提供できます。
`DispatchSerialQueue` 型はその機能をビルトインでサポートしています。

```swift
actor LandingSite {
    private let queue = DispatchSerialQueue(label: "something")

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }

    func acceptTransport(_ transport: PersonalTransportation) {
        // この関数はキュー上で実行される
    }
}
```

これは `DispatchQueue` に依存しているコードとの互換性を維持しながらアクターモデルへ型を移行したい場合に便利です。

## 後方互換性

静的隔離は、型システムの一部であるため、公開APIに影響を与えることを念頭に置くことが重要です。
しかし、Swift 6用にAPIを改良するという方法で既存のクライアントを *壊すことなく* 自分自身のモジュールを移行できます。

たとえば `WindowStyler` が公開APIだとします。 
本当は `MainActor` に隔離すべきですがクライアントのために後方互換性を確保したいと考えています。

```swift
@preconcurrency @MainActor
public class WindowStyler {
    // ...
}
```

このように `@preconcurrency` を使用すると、完全な並行性の確認が有効になっているクライアントモジュール上でのみ隔離のマーキングが働きます。
これにより、Swift 6をまだ導入しはじめていないクライアントとのソース互換性を維持できます。

## 依存関係

多くの場合、依存関係としてインポートする必要があるモジュールは制御できません。
それらのモジュールがまだSwift 6へ移行していない場合、解決が困難または不可能なエラーが発生する可能性があります。

移行されていないコードを使用することで生じる問題にはさまざまな種類が存在します。
`@preconcurrency` アノテーションは、そういった状況の多くで役に立ちます:

- [非Sendable型][Non-Sendable types]
- [プロトコル準拠時の隔離][protocol-conformance isolation]不一致

[Non-Sendable types]: commonproblems#Crossing-Isolation-Boundaries
[protocol-conformance isolation]: commonproblems#Crossing-Isolation-Boundaries

## C/Objective-C

アノテーションを使用することでCやObjective-CのAPIに対しSwiftの並行処理のサポートを公開できます。
これはClangの [並行処理固有のアノテーション][clang-annotations]を使うことで可能です：

[clang-annotations]: https://clang.llvm.org/docs/AttributeReference.html#customizing-swift-import

```
__attribute__((swift_attr(“@Sendable”)))
__attribute__((swift_attr(“@_nonSendable”)))
__attribute__((swift_attr("nonisolated")))
__attribute__((swift_attr("@UIActor")))

__attribute__((swift_async(none)))
__attribute__((swift_async(not_swift_private, COMPLETION_BLOCK_INDEX))
__attribute__((swift_async(swift_private, COMPLETION_BLOCK_INDEX)))
__attribute__((__swift_async_name__(NAME)))
__attribute__((swift_async_error(none)))
__attribute__((__swift_attr__("@_unavailableFromAsync(message: \"" msg "\")")))
```

Foundationをインポートできるプロジェクトを扱っているのなら、 `NSObjCRuntime.h` にある次のアノテーションマクロが使用できます：

```
NS_SWIFT_SENDABLE
NS_SWIFT_NONSENDABLE
NS_SWIFT_NONISOLATED
NS_SWIFT_UI_ACTOR

NS_SWIFT_DISABLE_ASYNC
NS_SWIFT_ASYNC(COMPLETION_BLOCK_INDEX)
NS_REFINED_FOR_SWIFT_ASYNC(COMPLETION_BLOCK_INDEX)
NS_SWIFT_ASYNC_NAME
NS_SWIFT_ASYNC_NOTHROW
NS_SWIFT_UNAVAILABLE_FROM_ASYNC(msg)
```

### Objective-Cライブラリで隔離アノテーションが欠落している場合の対処法

SDKやその他のObjective-Cライブラリは、Swiftの並行処理を導入することで進歩している一方、ドキュメントでしか説明されていなかった取り決めをコードで表現することになる場合があります。
例えば、Swiftに並行処理が導入される以前は、「これは常にメインスレッド上で呼び出される」というようなコメントでスレッドの動作をドキュメントとして記載しなければならないことがよくありました。

Swiftの並行処理により、これらのコードコメントはコンパイラとランタイム時に強制される隔離確認に変換でき、そのようなAPIを導入するときにSwiftが検証するようになります。

例えば、架空の `NSJetPack` プロトコルは通常メインスレッド上でデリゲートメソッドのすべてを呼び出すため、現在はメインアクターに隔離されています。

ライブラリの作者は `NS_SWIFT_UI_ACTOR` アトリビュートを使用してメインアクターに隔離されていることを示すことができます。
これはSwiftで `@MainActor` を使用し型にアノテーションすることと同じです：

```swift
NS_SWIFT_UI_ACTOR
@protocol NSJetPack // 架空のプロトコル
  // ...
@end
```

このおかげで、このプロトコルのすべてのメンバーメソッドは `@MainActor` 隔離を継承します。これはほとんどのメソッドにとって正しい状態です。

しかし、この例において、過去に次のようにドキュメントが記載されたメソッドを考えてみましょう：

```objc

NS_SWIFT_UI_ACTOR // SDKの作者は、最近の更新でメインアクターのアノテーションを付けた
@protocol NSJetPack // 架空のプロトコル
/* このジェットパックが高高度での飛行をサポートするならYESを返す！
 
 JetPackKitはこのメソッドをさまざまなタイミングで呼び出すが、常にメインスレッドで呼び出されるわけではない。例えば...
*/
@property(readonly) BOOL supportsHighAltitude;

@end
```

このメソッドの隔離は、属している型のアノテーションのせいで誤って `@MainActor` と推論されてしまいました。
メインアクターで呼び出される場合と呼び出されない場合があるという、異なるスレッド戦略が明確にドキュメントとして記載されていますが、メソッドへこれらのセマンティクスをアノテーションするのをうっかり忘れてしまいました。

これは架空のJetPackKitライブラリにおけるアノテーションの問題です。
具体的には、正しくそして期待通りの実行セマンティクスをSwiftに知らせるための、 `nonisolated` アノテーションがメソッドから欠落しています。

このライブラリを採用したSwiftのコードは次のようになるかもしれません：

```swift
@MainActor
final class MyJetPack: NSJetPack {
  override class var supportsHighAltitude: Bool { // Swift 6では実行時にクラッシュ
    true
  }
}
```

上記のコードはランタイム時確認でクラッシュします。この確認は、Objective-C上のSwiftの並行処理ではない領域からSwiftに移動するときに、メインアクターで実際に実行されていることを確認するために行なわれるものです。

これは、自動的にそのような問題を検出し、想定に違反した際にランタイム時にクラッシュするというSwift 6の機能です。
そのような問題を診断しないままにしておくと、現実の検出困難なデータ競合を実際に引き起こす恐れがあり、データ競合安全に関するSwift 6の保証を損ないます。

そのような不具合には次のようなバックトレースが出力されます：

```
* thread #5, queue = 'com.apple.root.default-qos', stop reason = EXC_BREAKPOINT (code=1, subcode=0x1004f8a5c)
  * frame #0: 0x00000001004..... libdispatch.dylib`_dispatch_assert_queue_fail + 120
    frame #1: 0x00000001004..... libdispatch.dylib`dispatch_assert_queue + 196
    frame #2: 0x0000000275b..... libswift_Concurrency.dylib`swift_task_isCurrentExecutorImpl(swift::SerialExecutorRef) + 280
    frame #3: 0x0000000275b..... libswift_Concurrency.dylib`Swift._checkExpectedExecutor(_filenameStart: Builtin.RawPointer, _filenameLength: Builtin.Word, _filenameIsASCII: Builtin.Int1, _line: Builtin.Word, _executor: Builtin.Executor) -> () + 60
    frame #4: 0x00000001089..... MyApp.debug.dylib`@objc static JetPack.supportsHighAltitude.getter at <compiler-generated>:0
    ...
    frame #10: 0x00000001005..... libdispatch.dylib`_dispatch_root_queue_drain + 404
    frame #11: 0x00000001005..... libdispatch.dylib`_dispatch_worker_thread2 + 188
    frame #12: 0x00000001005..... libsystem_pthread.dylib`_pthread_wqthread + 228
```

> 注記: このような問題に遭遇し、ドキュメントやAPIのアノテーションを調査して何か間違ったアノテーションがされていると判断したとき、問題の根本原因を解決する最善の方法はライブラリのメンテナに問題を報告することです。

見ての通り、ランタイムは呼び出しにエグゼキュータ確認を注入し、（メインアクター上で実行される）ディスパッチキューのアサーションに失敗しています。
これにより見えづらくデバッグしにくいデータ競合を防いでいます。

この問題に対する長期的な視点で正しい解決策は、 `nonisolated` をつけることでライブラリのメソッドのアノテーションを修正することです：

```objc
// APIを提供するライブラリ側の解決策：
@property(readonly) BOOL supportsHighAltitude NS_SWIFT_NONISOLATED;
````

ライブラリがアノテーションの問題を修正するまでは、次のように正しく `nonisolated` を用いてメソッドをオーバーライドすることで対処できます：

```swift
// Swift 6モードで実行したいクライアントコード側の解決策:
@MainActor
final class MyJetPack: NSJetPack {
  // 正しい
  override nonisolated class var readyForTakeoff: Bool {
    true
  }
}
```

こうすることで、Swiftは、メソッドがメインアクターの隔離を必要とするという誤った仮定を確認しないようになります。
