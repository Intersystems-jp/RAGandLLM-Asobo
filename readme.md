# 2025/9/9 開催「RAG + 生成AIであそぼう！」サンプルコード

説明に使用していたサンプルコードが含まれています。

ご参考：関連ウェビナー

- [2025/6/10 開催「IRISのベクトル検索を使って テキストから画像を検索してみよう」](https://www.youtube.com/watch?v=l2NuPYxgIgI&list=PLzSN_5VbNaxA8mOezO6Vcm126GXw_89oN)

- [2025/7/29 開催「ベクトルであそぼう！」](https://youtu.be/c285zESVmRQ?list=PLzSN_5VbNaxA8mOezO6Vcm126GXw_89oN)

説明内容|関連コード
--|--|
Embedding 用コード|[cliputil.py](/src/wsgi/cliputil.py)
IRIS の常駐プロセス（イベント）作成などのコード|[FishDetector.Event](/src/FishDetector/Event.cls)
ベクトル検索用テーブル作成用 SQL|[fish.sql](/src/sql/fish.sql)
生成 AI へのリクエストを行うREST API(Flask)|[fishapp.py](/src/wsgi/fishapp.py)
生成 AI へのリクエストを行うREST API(IRIS)|[FishDetector.REST](/src/FishDetector/REST.cls)
MCP サーバコード例|https://github.com/iijimam/RAGandLLM-MCP
---
<br>

その他（ウェビナーで説明していない内容も含まれます）
内容|ファイル
--|--
釣果／釣り場情報テーブル作成 SQL|[fishinfo](/src/sql/fish.sql)
参考：OpenAI の Embeddingを試すための SQL一式|[tenki-EMBEDDING.sql](/src/sql/tenki-EMBEDDING.sql)
参考：上記ベクトル検索と生成AIへのリクエストのサンプルコード|[tenkitest.py](/src/tenkitest.py)



## サンプル実行方法

コンテナ版 IRIS を利用しています。

### 1. 事前準備

- OpenAI の APIキーを以下ファイルに設定します。

    [config.py](/src/wsgi/config.py)

    ```
    # APIkey
    key="ここに設定してください"
    ```

- https 通信用の自己証明ファイルの用意

    server.crt、server.keyの名称で[webgateway](/webgateway/)以下に配置してください。

    http 通信とする場合は、[CSP.conf](/webgateway/CSP.conf) 23行目移行をコメントに変更し保存してください。

### 2. コンテナの操作

(1) コンテナビルド

```
docker compose build
```

(2)　コンテナ開始

```
docker compose up -d
```

(3) コンテナへログイン

```
docker exec -it irisrag bash
```

(4)　コンテナ停止

```
docker compose stop
```

(5)　コンテナ破棄

```
docker compose down
```

### 3. CLIPモデルのロード

コンテナを開始しログインした後、IRISにログインし、メソッドを実行します。

```
docker compose up -d
docker exec -it irisragasobo bash
iris session iris
do ##class(FishDetector.Event).createEvent()
```

作成したイベント（モデルのロードを行っている常駐プロセス）を停止したい場合は、以下実行します。
（IRISにログインした後実行します）
```
docker exec -it irisragasobo bash
iris session iris
do ##class(FishDetector.Event).EndEvent()
```


### 4. REST APIでテスト

2種類の REST APIを用意しています。

#### 魚の画像から魚名と釣り場情報・釣果を得る🐟

以下設定してPOST要求実行
ヘッダまたはキー|値
--|--
Content-Type|multipart/form-data
fish|Uploadファイルフルパス

- wsgi 版 URL

    https://localhost:9993/fish/upload


- IRIS RESTディスパッチクラス版 URL

    https://localhost:9993/fish2/upload


#### 魚名と釣り場情報・釣果＋ユーザ入力の魚の体長、釣れた数、好みからレシピを生成する🍳

uploadで返送されるJSON＋ユーザの好みをJSONに指定して実行

例
```
{
    "FishInfo": "2025-08-16 14:00:00　釣り場：木更津沖堤防の状況は、上げ潮、若潮、潮位は204.8cm　本日の前後1か月の過去5年間の釣り果情報は、最大数:7、最小数:1、最大長cm:108、最小長cm:45",
    "FishName": "タチウオ",
    "UserInput":"体長80センチを2匹釣りました。魚をさばいたことがありません"
}
```

- wsgi（OpenAI）

    https://localhost:9993/fish/recipe2
    
- wsgi（Ollama）

    https://localhost:9993/fish/recipe

- REST ディスパッチ(OpenAI)

    https://localhost:9993/fish2/recipe2

- REST ディスパッチ(Ollama)

    https://localhost:9993/fish2/recipe


#### 釣果登録🐟

uploadで返送されるJSON＋魚の体長、サイズ

送信するBody
```
{
  "FishID": "f010",
  "FishName": "タチウオ",
  "Size": "50",
  "FishCount": 1
}
```
- wsgi 版 URL

    https://localhost:9993/fish/choka


- IRIS RESTディスパッチクラス版 URL

    https://localhost:9993/fish2/choka

