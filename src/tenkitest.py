#天気情報テスト用
from sqlalchemy import create_engine,text
import requests

def getAns(word):
    sql="""
    SELECT TOP 1 Name,Description FROM Embedding.Example
     ORDER BY VECTOR_DOT_PRODUCT(DescriptionEmbedding, EMBEDDING(:word)) DESC
    """
    
    engine = create_engine("iris://SuperUser:SYS@localhost:1972/USER",echo=True)
    conn = engine.connect()
    rset = conn.execute(text(sql), dict(word=word))
    row=next(rset)
    input=row[0]
    print(f"***ベクトル検索の結果：{input}***")

    # 以下生成AIへの問い合わせ（OpenAI版）
    # APIキーを入手後、変数にセットしてから実行してください。
    APIKey=""
    API_BASE_URL="https://api.openai.com/v1/chat/completions"
    headers={
        "Content-Type":"application/json;charset=utf-8",
        "Authorization": f"Bearer {APIKey}",
    }
    # 送信するJSONボディを組み立て
    body = {
        "model":"gpt-4",
        "messages":[
            {"role": "system", "content": "あなたは自転車に乗る場合の注意点を伝えるアシスタントです。注意すべき乗り方や場所があれば詳しく説明してください"},
            {"role": "user", "content": input}
        ]
    }

    response = requests.post(API_BASE_URL, headers=headers, json=body)
    result = response.json()
    answer=result["choices"][0]["message"]["content"]
    print(answer)
    conn.close()

