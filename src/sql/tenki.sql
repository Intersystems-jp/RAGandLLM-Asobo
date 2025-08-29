--- *** LOAD SQL 文用ファイル：EMBEDDING 型利用例 ***

--- OpenAIを使うための構成情報登録
--- APIキーをご用意いただき、apiKey:"ここ"に設定してから実行してください。
INSERT INTO %Embedding.Config (Name, Configuration, EmbeddingClass, VectorLength, Description)
  VALUES ('my-opanai-config', 
          '{"apiKey":"", 
            "sslConfig": "webapi", 
            "modelName": "text-embedding-3-small"}',
          '%Embedding.OpenAI', 
          1536,  
          'a small embedding model provided by OpenAI') 
go

--- テーブル定義作成
CREATE TABLE Embedding.Example (
  Description VARCHAR(200),
  Name VARCHAR(30),
  DescriptionEmbedding EMBEDDING('my-opanai-config','Description')
)
go

--- インデックス準備
CREATE INDEX HNSWIndex ON TABLE Embedding.Example (DescriptionEmbedding)
     AS HNSW(Distance='Cosine')
go

--- INSERT例
INSERT INTO Embedding.Example (Description,Name) VALUES('雲の量が1割以下で、青空が広がっている状態','快晴')
go
INSERT INTO Embedding.Example (Description,Name) VALUES('雲の量が2割以上8割以下の状態','晴れ')
go
INSERT INTO Embedding.Example (Description,Name) VALUES('雲の量が9割以上で、上層の雲が主に見える状態','薄曇り')
go
INSERT INTO Embedding.Example (Description,Name) VALUES('雲の量が9割以上で、中・下層の雲が主に見える状態','曇り')
go
INSERT INTO Embedding.Example (Description,Name) VALUES('視程が1km未満で、水蒸気が凝結して細かい水滴が漂っている状態','霧')
go
INSERT INTO Embedding.Example (Description,Name) VALUES('細かい雨が降っている状態','霧雨')
go
INSERT INTO Embedding.Example (Description,Name) VALUES('比較的大きな水滴が降っている状態','雨')
go
INSERT INTO Embedding.Example (Description,Name) VALUES('雨と雪が混ざって降っている状態','みぞれ')
go
INSERT INTO Embedding.Example (Description,Name) VALUES('結晶状の氷の粒が降っている状態','雪')
go
INSERT INTO Embedding.Example (Description,Name) VALUES('小さな氷の粒が降っている状態','あられ')
go
INSERT INTO Embedding.Example (Description,Name) VALUES('直径5mm以上の氷の塊が降っている状態','ひょう')
go
INSERT INTO Embedding.Example (Description,Name) VALUES('雷鳴や雷光を伴う現象','雷')
go
INSERT INTO Embedding.Example (Description,Name) VALUES('砂や塵が激しく吹き荒れている状態','砂じん嵐')
go
INSERT INTO Embedding.Example (Description,Name) VALUES('雪が激しく吹き荒れている状態','地ふぶき')
go
INSERT INTO Embedding.Example (Description,Name) VALUES('煙や塵が空中に漂い、視程が低下している状態','煙霧')
go

