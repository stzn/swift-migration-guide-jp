## 参加方法

## 開発準備

まず始めに以下のコマンドを実行してください。

```text
npm install
```

### Issueを探す/立てる

1. [Issues](https://github.com/stzn/swift-migration-guide-jp/issues)の中から解決したいIssueを選択(あるいは作成)してください
2. 選択したIssueのAssigneesに自身を設定してください 

※ 誤字脱字などの微細な修正のみであれば不要です。その場合は直接PRを作成してください。

### PRを開く

1. まずこのリポジトリをforkしてください
2. 作業用のブランチを作成し、変更をコミット&プッシュしてください
3. このリポジトリの `main` ブランチに対してPRを開いてください

※ お願い  

原文と翻訳の更新状況を把握しやすくするために、翻訳の冒頭に以下のようなコメントを追加してください。

```markdown

原文: https://github.com/apple/swift-migration-guide/blob/main/Guide.docc/DataRaceSafety.md

更新日: 2024/6/19(翻訳を最後に更新した日付)

ここまで反映: https://github.com/apple/swift-migration-guide/commit/96249774f73d9db641c1b6daaf2894eb9dbfc63b(翻訳した最新のコミットID)

```

また、すでに存在しているドキュメントを更新する際は、最新のコミットと反映済みのコミットを比較して差分を確認してください。

```
https://github.com/apple/swift-migration-guide/compare/(翻訳に反映済みのコミットID)...(最新のコミットID)
```

例:  
https://github.com/apple/swift-migration-guide/compare/1a734010d363947797e80b18008e3c4695e119a6...96249774f73d9db641c1b6daaf2894eb9dbfc63b

頻出の単語は[辞書](dictionary.md)にまとめています。翻訳の際に参考にしてください。追加や修正があれば[issue](https://github.com/stzn/swift-migration-guide-jp/issues)を立て、翻訳しているブランチとは別でPRを出してください。  

### ビルド方法

リポジトリのルートディレクトリで `docc preview Guide.docc` を実行します。

DocCを実行した後、`docc` が出力するリンクを開いて、ブラウザでローカルプレビューを表示します。

> 注意:
>
> Swift.org から toolchain をダウンロードして DocC をインストールした場合、
> `docc` は toolchain のインストールパスを基準とした `usr/bin/` にあります。
> シェルの `PATH` 環境変数にそのディレクトリが含まれていることを確認してください。
> 
> Xcode をダウンロードして DocC をインストールした場合は、
> 代わりに `xcrun docc` を使用してください。

### PRのレビューについて

このガイドは、Swiftコミュニティーの多くの方のご意見を取り入れたいと考えています。そこでレビューは以下のステップで進めます。

1. PRが開かれると、担当者(※)がレビュー期間を設定し、SNSや勉強会などで告知する
2. レビュー期間中は適宜提案や修正をする
3. 期間終了後、担当者が最終的なレビューを実施し、Approve後マージする

※ 担当者: リポジトリオーナー、コラボレーター、もしくはIssueを立てた人(複数可)

## 翻訳時のルール

通常は「ですます」調で記載してください。ただし、箇条書きとソースコメントは「である」調で記載してください。