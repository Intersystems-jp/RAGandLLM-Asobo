--- *** LOAD SQL 文を使う場合は tenki.sqlを使用してください ***

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

--- テーブル定義作成
CREATE TABLE Embedding.Example (
  Description VARCHAR(200),
  Name VARCHAR(30),
  DescriptionEmbedding EMBEDDING('my-opanai-config','Description')
)

--- インデックス準備
CREATE INDEX HNSWIndex ON TABLE Embedding.Example (DescriptionEmbedding)
     AS HNSW(Distance='Cosine')

--- INSERT例
INSERT INTO Embedding.Example (Description,Name) VALUES('雲の量が1割以下で、青空が広がっている状態','快晴')
INSERT INTO Embedding.Example (Description,Name) VALUES('雲の量が2割以上8割以下の状態','晴れ')

--- 検索
SELECT TOP 3 Name,Description FROM Embedding.Example
  ORDER BY VECTOR_DOT_PRODUCT(DescriptionEmbedding, EMBEDDING('傘がいらないぐらいの雨')) DESC
