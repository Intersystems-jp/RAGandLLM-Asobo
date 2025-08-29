--- 15種類の天気情報の VECTOR 型を利用する場合の例

--- Embedding用の関数準備
CREATE FUNCTION GetEmbedding(sentences VARCHAR(1000))
 RETURNS VECTOR(DOUBLE,768)
 FOR VectorSample.Utils
 PROCEDURE LANGUAGE Python
{
  import sentence_transformers
  model = sentence_transformers.SentenceTransformer('sentence-transformers/static-similarity-mrl-multilingual-v1')
  embeddings = model.encode(sentences)
  embeddingval=str(embeddings.tolist())[1:-1]
  return embeddingval
 }

--- テーブル準備
CREATE TABLE VectorSample.Tenki (
    Name VARCHAR(10),
    Info VARCHAR(1000),
    InfoVec VECTOR(DOUBLE,768)
)

--- インデックス準備
CREATE INDEX HNSWIndex ON TABLE VectorSample.Tenki (InfoVec)
     AS HNSW(Distance='Cosine')

---- データ登録
INSERT INTO VectorSample.Tenki (Name,Info,InfoVec)
 VALUES(?,?,TO_VECTOR(VectorSample.GetEmbedding(?),DOUBLE,768))

--- 検索
select top 3 Name,Info,
 VECTOR_COSINE(InfoVec, TO_VECTOR(VectorSample.GetEmbedding('傘がいらないぐらいの雨'), DOUBLE, 768)) as cos
 from VectorSample.Tenki ORDER BY cos desc