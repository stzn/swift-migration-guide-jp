# Library Evolution

ソース互換性およびABI互換性を維持しつつ、ライブラリAPIに並行性の注釈をつけましょう。

|原文|[https://github.com/apple/swift-migration-guide/blob/main/Guide.docc/LibraryEvolution.md](https://github.com/apple/swift-migration-guide/blob/main/Guide.docc/LibraryEvolution.md)|
|---|---|
|更新日|2025/2/1(翻訳を最後に更新した日付)|
|ここまで反映|[https://github.com/apple/swift-migration-guide/commit/38a0e88a23ee9555fc69861328218001e303aac5](https://github.com/apple/swift-migration-guide/commit/38a0e88a23ee9555fc69861328218001e303aac5)|


`@MainActor`や`@Sendable`などの並行性のアノテーションは、ソースやABI互換性に影響を与える可能性があります。ライブラリの作成者は、既存のAPIに注釈をつける際に、これらの影響に注意する必要があります。

## preconcurrencyアノテーション

`@preconcurrency`属性をライブラリAPIへ直接使用すると、クライアントのソースやABI互換性を損なうことなく、コンパイル時にチェックされる新しい並行性要件を段階的に導入できます。

```swift
@preconcurrency @MainActor
struct S { ... }

@preconcurrency
public func performConcurrently(
  completion: @escaping @Sendable () -> Void
) { ... }
```

新しいエラーを抑制するために、クライアント側で`@preconcurrency import`を使用する必要はありません。クライアントが、最小限の並行性の確認(minimal)でビルドされている場合、`@preconcurrency`の付いたAPIから発生するエラーは抑制されます。完全な並行性の確認、またはSwift 6言語モードでビルドされている場合、エラーは警告になります。

ABI互換性のために、`@preconcurrency`をつけると並行性のアノテーションがない状態でシンボル名をマングリングします。しかし、あるAPIをいくつかの並行性のアノテーションをつけて導入し、あとで追加の並行性のアノテーションを含むように更新した場合は、`@preconcurrency`をつけるだけだと、マングル化された名前を維持できません。並行性のアノテーションのマングリングをより正確に制御する必要がある場合は、`@_silgen_name`を使用できます。

C、C++、およびObjective-CからインポートされたすべてのAPIは、自動的に`@preconcurrency`がついていると見なされることに注意してください。`__attribute__((__swift_attr__("<attribute name>")))`を使用することで、ソースまたはABI互換性を損なうことなく、いつでも並行性の属性をそれらのAPIへ適用できます。

## Sendable

### 具象型の準拠

具象型に対する`Sendable`への準拠の追加(条件付き準拠を含む)は、実際のところは、通常はソース互換性のある変更です。

**ソース互換性とABI互換性のある変更**:

```diff
- public struct S { ... }
+ public struct S: Sendable { ... }
```

他の準拠と同様に、具象型がより特殊化(specialization)された要件を満たしている場合は、`Sendable`への準拠を追加すると、オーバーロードの解決が変わることがあります。ただし、`Sendable`への準拠によって、オーバーロードするAPIがソース互換性やプログラムの動作を損なうような方法で型推論を変えてしまう可能性は低いです。

具象型の`Sendable`への準拠の追加(かつ、その型パラメータの1つではない場合)は、常にABI互換性のある変更です。

## ジェネリック要件

`Sendable`への準拠要件をジェネリック型または関数に追加すると、クライアントから渡されるジェネリック引数に制限が課されるため、ソース互換性のない変更となります。

**ソース互換性とABI互換性のない変更**:

```diff
-public func generic<T>
+public func generic<T> where T: Sendable
```

**解決方法:** 型または関数の宣言に`@preconcurrency`をつけてエラーを警告に下げ、ABIを維持します:

```swift
@preconcurrency
public func generic<T> where T: Sendable { ... }
```

### 関数型

ジェネリック要件と同様に、関数型に`@Sendable`を追加すると、ソース互換性とABI互換性のない変更になります:

**ソース互換性とABI互換性のない変更**:

```diff
-public func performConcurrently(completion: @escaping () -> Void)
+public func performConcurrently(completion: @escaping @Sendable () -> Void)
```

**解決方法:** 関数の宣言に`@preconcurrency`をつけてエラーを警告に下げ、ABIを維持します:

```swift
@preconcurrency
public func performConcurrently(completion: @escaping @Sendable () -> Void)
```

## MainActorアノテーション

### プロトコルと型

プロトコルまたは型宣言に`@MainActor`を追加すると、ソース互換性とABI互換性のない変更になります。

**ソース互換性とABI互換性のない変更**:

```diff
-public protocol P
+@MainActor public protocol P

-public class C
+@MainActor public class C
```

プロトコルと型宣言に`@MainActor`を追加すると、他の並行性のアノテーションよりも影響が大きくなります。これは、`@MainActor`が、プロトコル準拠、サブクラス、`extension`内のメソッドなど、クライアントコード全体で推論されることがあるためです。

プロトコルまたは型宣言に`@preconcurrency`をつけると、並行性の確認レベルに基づき、アクター隔離違反によるエラーが抑制されます。ただし、`@preconcurrency @MainActor`が、クライアントコード内の他の宣言から推論される可能性がある場合、`@preconcurrency`だけではクライアントのABI互換性を維持できません。例えば、クライアントライブラリの次のAPIについて考えてみましょう。

```swift
extension P {
  public func onChange(action: @escaping @Sendable () -> Void)
}
```

`P`が遡及的(retroactive)に`@preconcurrency @MainActor`でアノテーションされる場合、このアノテーションは、`extension`内のメソッドにおいても推論されます。`extension`内のメソッドが、ABI互換性の制約を持つライブラリの一部である場合、`@preconcurrency`は、並行性関連のすべてのアノテーションを名前マングリングから削除します。この問題は、クライアントライブラリで適切な隔離を設定することで回避できます。例えば、次のようになります。

```swift
extension P {
  nonisolated public func onChange(action: @escaping @Sendable () -> Void)
}
```

宣言のABIを正確に制御するための言語機能が[開発中](https://forums.swift.org/t/pitch-controlling-the-abi-of-a-declaration/75123)です。

### 関数の宣言と型

関数の宣言または関数の型に`@MainActor`を追加すると、ソース互換性とABI互換性のない変更になります。

**ソース互換性とABI互換性のない変更**:

```diff
-public func runOnMain()
+@MainActor public func runOnMain()

-public func performConcurrently(completion: @escaping () -> Void)
+public func performConcurrently(completion: @escaping @MainActor () -> Void)
```

**解決方法:** 関数の宣言に`@preconcurrency`をつけてエラーを警告に下げ、ABIを維持します:

```swift
@preconcurrency @MainActor
public func runOnMain() { ... }

@preconcurrency
public func performConcurrently(completion: @escaping @MainActor () -> Void) { ... }
```

## `sending`パラメータと戻り値

戻り値に`sending`を追加すると、クライアントコードの制限が解除され、常にソース互換性とABI互換性のある変更になります。

**ソース互換性とABI互換性のある変更**:

```diff
-public func getValue() -> NotSendable
+public func getValue() -> sending NotSendable
```

しかし、パラメータに`sending`を追加すると、呼び出し側でより制限が厳しくなります。

**ソース互換性とABI互換性のない変更**:

```diff
-public func takeValue(_: NotSendable)
+public func takeValue(_: sending NotSendable)
```

今のところ、ソース互換性を損なわずにパラメータに新しく`sending`を導入する方法はありません。

### `@Sendable`を`sending`に置き換える

クロージャのパラメータの既存の`@Sendable`を`sending`に置き換えると、ソース互換性はありますが、ABI互換性のない変更になります。

**ソース互換性はあるが、ABI互換性のない変更**:

```diff
-public func takeValue(_: @Sendable @escaping () -> Void)
+public func takeValue(_: sending @escaping () -> Void)
```

**解決方法:** パラメータに`sending`を追加すると名前のマングリングが変更されるため、導入する場合は、`@_silgen_name`を使用してマングル化された名前を維持する必要があります。また、パラメータの位置で`sending`を導入する場合、パラメータの所有権規約(ownership convention)を維持する必要があります。パラメータにすでに所有権修飾子(modifier)を明示的に指定している場合、追加のアノテーションは必要ありません。イニシャライザを除くすべての関数において、所有権規約を維持するために`__shared sending`を使用します:

```swift
public func takeValue(_: __shared sending NotSendable)
```

イニシャライザの場合、`sending`はデフォルトの所有権規約を維持するため、イニシャライザのパラメータに`sending`を導入する場合は、所有権修飾子を指定する必要はありません:

```swift
public class C {
  public init(ns: sending NotSendable)
}
```