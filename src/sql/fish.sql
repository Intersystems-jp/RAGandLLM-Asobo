--- 魚の画像から魚名を得るデモ用SQL
--- CLIPモデルのロードとEmbeddingはcliputil.pyに

--- ベクトル検索用魚テーブル
CREATE TABLE FishDetector.Fish (
    FishID VARCHAR(10),
    FishName VARCHAR(50),
    FishNameVec VECTOR(DOUBLE,512),
    CONSTRAINT FishPK PRIMARY KEY (FishID)
)
go

--- インデックス準備
CREATE INDEX HNSWIndex ON TABLE FishDetector.Fish (FishNameVec)
     AS HNSW(Distance='Cosine')
go


--- INSERT（FishDetector.GetEmbedding('T',魚の名前)）
---INSERT INTO FishDetector.Fish (FishID,FishName,FishNameVec)
--- VALUES('f099','アオヤガラ',TO_VECTOR(FishDetector.GetEmbedding('T','アオヤガラ'),DOUBLE,512))

--- 検索実行（FishDetector.GetEmbedding('I',画像ファイルフルパス)）
---select top 1 FishID,FishName,
--- VECTOR_COSINE(FishNameVec, 
---  TO_VECTOR(FishDetector.GetEmbedding('I',?), DOUBLE, 512)) as cos
--- FROM FishDetector.Fish ORDER BY cos desc
