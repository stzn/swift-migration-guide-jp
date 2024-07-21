# ランタイム時の動作


Swift concurrencyのランタイムのセマンティクスが、あなたが慣れ親しんでいる他のランタイムとどのように異なるかを学び、プログラム実行のセマンティクスという観点で同様の最終結果を達成するための一般的なパターンに慣れましょう。

|原文|[https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/runtimebehavior](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/runtimebehavior)|
|---|---|
|更新日|2024/7/14(翻訳を最後に更新した日付)|
|ここまで反映|[https://github.com/apple/swift-migration-guide/commit/96249774f73d9db641c1b6daaf2894eb9dbfc63b](https://github.com/apple/swift-migration-guide/commit/96249774f73d9db641c1b6daaf2894eb9dbfc63b)|

Swiftの並行処理モデルは、async/await、アクター、およびタスクに強く焦点を当てているため、他のライブラリや並行処理ランタイムからのいくつかのパターンは、この新しいモデルに直接変換されるわけではありません。
この章では、注意すべき一般的なパターンやランタイムの挙動の違いを探り、それらに対処しながらコードをSwiftの並行処理に移行する方法を探っていきましょう。

## タスクグループを使って同時並行処理数を制限する

処理するべき大量の作業リストを抱えていることもあるかもしれません。
次のように"すべて"の作業項目をタスクグループに追加することは、可能といえば可能です。

```swift
// 無駄が多い処理かも -- おそらく、このコードは数千のタスクを同時並行的に作成する（？！）
let lotsOfWork: [Work] = ...
await withTaskGroup(of: Something.self) { group in
  for work in lotsOfWork {
    // もしもこれが数千の項目であれば、ここで大量のタスクを作成することになるかもしれない。
    group.addTask {
      await work.work()
    }
  }

  for await result in group {
    process(result) // 必要に応じて、結果を何らかの方法で処理する。
  }
}
```

何百または何千もの項目を扱うつもりなら、それらをすべて一気にタスクグループに追加するのは非効率的かもしれません。
タスクを（`addTask`メソッドで）作成すると、そのタスクを中断して実行するためのメモリが割り当てられます。
各タスクに必要なメモリの量は大きくありませんが、すぐに実行されない何千ものタスクを作成する場合、そのメモリ量は無視できないものになります。

そのような状況に直面した場合、次のようにグループに同時に追加されるタスクの数を手動で調整できます。

```swift
let lotsOfWork: [Work] = ... 
let maxConcurrentWorkTasks = min(lotsOfWork.count, 10)
assert(maxConcurrentWorkTasks > 0)

await withTaskGroup(of: Something.self) { group in
    var submittedWork = 0
    for _ in 0..<maxConcurrentWorkTasks {
        group.addTask { // または 'addTaskUnlessCancelled'
            await lotsOfWork[submittedWork].work() 
        }
        submittedWork += 1
    }
    
    for await result in group {
        process(result) // 必要に応じて、結果を何らかの方法で処理する。
    
        // 結果が返ってくる度に、実行すべき追加の作業があるかどうかを確認しよう。
        if submittedWork < lotsOfWork.count, 
           let remainingWorkItem = lotsOfWork[submittedWork] {
            group.addTask { // または 'addTaskUnlessCancelled'
                await remainingWorkItem.work() 
            }  
            submittedWork += 1
        }
    }
}
```