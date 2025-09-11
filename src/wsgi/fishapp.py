from flask import Flask,request,jsonify
import json
import requests
import os
#import sys
#sys.path += ["/usr/irissys/mgr/python","/usr/irissys/lib/python"]
import iris
import datetime
import config

#UPLOAD用フォルダ
UPLOAD_FOLDER = "/src/images/"

#オープンソースLLMのURL（仮）
API_SERVER_URL = "http://176.34.0.93/api/chat"

app = Flask(__name__)


@app.route('/', methods=['GET'])
def meetup():
    name = "Hello FishDetector!"
    return name


# ------------------------------------------
# /upload エンドポイント
# ------------------------------------------
@app.route('/upload',methods=['POST'])
def upload():
    #画像ファイルを指定ディレクトリにUpload
    file = request.files['fish']
    filefullpath=os.path.join(UPLOAD_FOLDER, file.filename)
    file.save(filefullpath)
    #画像のEmbedding (メソッド呼び出しの場合)
    #embedding=iris.cls("FishDetector.Event").GetEmbedding(filefullpath)
    #ベクトル検索
    sql="select top 1 FishID,FishName,VECTOR_COSINE(FishNameVec, TO_VECTOR(FishDetector.GetEmbedding('I',?), DOUBLE, 512)) as cos from FishDetector.Fish ORDER BY cos desc"
    stmt=iris.sql.prepare(sql)
    #rs=stmt.execute(embedding)
    rs=stmt.execute(filefullpath)
    fishinfo=next(rs)

    #回答のJSONを作成
    ans= jsonify({"FishID":fishinfo[0],"FishName":fishinfo[1]})
    return ans

# ------------------------------------------
# /recipe　ローカル LLMにレシピ生成を依頼
# Bodyの中身
#  {
#  "UserInput":"ここにユーザが希望するレシピの内容",
#  "FishName":"魚名"
#  "FishID":"f001"
#  }
#
# 魚名をキーに生成AIに渡す独自データをデータベースから入手
# 独自データ＝その釣り場の潮位情報と釣果データ（デモでは釣り場は固定値を置いています）
# ------------------------------------------
@app.route('/recipe',methods=['POST'])
def getrecipe():
    body = request.get_json()
    fishinfo=get_fishinfo(body["FishID"])
    headers = {"Content-Type": "application/json;charset=utf-8"}
    data = {
        "model": "pakachan/elyza-llama3-8b",
        "messages": [
            {
                "role": "system",
                "content": "あなたは釣りのスペシャリストで釣り場の潮位や季節ごとに釣れる魚情報に詳しく地元料理についても詳しいです。本日釣った魚名、体長、ユーザの状況、過去の釣果情報、釣り場の潮位情報を参考として30分程度で作れる釣り場の地元レシピを教えてください。"
            },
            {
                "role": "system",
                "content": f"魚名は{body["FishName"]}です。{fishinfo}",
            },
            {
                "role": "user",
                "content": f"{body["UserInput"]}",
            }
        ],
        "stream": False
    }
    response = requests.post(API_SERVER_URL, headers=headers, json=data)

    result = response.json()
    answer=json.dumps({"Message":result["message"]["content"],"FishInfo":fishinfo},ensure_ascii=False)

    return answer
    #for line in response.iter_lines():
    #    decoded_line = json.loads(line.decode('utf-8'))
    #    answer_text+=decoded_line['message']['content']

# ------------------------------------------
# /recipe2 OpenAIにレシピ生成を依頼する
# Bodyの中身
#  {
#  "UserInput":"ここにユーザが希望するレシピの内容",
#  "FishName":"魚名"
#  "FishID":"f001"
# }
#
# 魚名をキーに生成AIに渡す独自データをデータベースから入手
# 独自データ＝その釣り場の潮位情報と釣果データ（デモでは釣り場は固定値を置いています）
# ------------------------------------------
@app.route('/recipe2',methods=['POST'])
def getrecipe2():
    body = request.get_json()
    fishinfo=get_fishinfo(body["FishID"])

    API_SERVER_URL="https://api.openai.com/v1/chat/completions"
    headers={
        "Content-Type":"application/json;charset=utf-8",
        "Authorization": f"Bearer {config.key}",
    }
    data = {
        "model": "gpt-4o",
        "messages": [
            {
                "role": "system",
                "content": "あなたは釣りのスペシャリストで釣り場の潮位や季節ごとに釣れる魚情報に詳しく地元料理についても詳しいです。本日釣った魚名、体長、ユーザの状況、過去の釣果情報、釣り場の潮位情報を参考として30分程度で作れる釣り場の地元レシピを教えてください。"
            },
            {
                "role": "system",
                "content": f"魚名は{body["FishName"]}です。{fishinfo}",
            },
            {
                "role": "user",
                "content": f"{body["UserInput"]}",
            }
        ]
    }

    response = requests.post(API_SERVER_URL, headers=headers, json=data)
    result = response.json()
    answer=json.dumps({"Message":result["choices"][0]["message"]["content"],"FishInfo":fishinfo},ensure_ascii=False)
    return answer


#------------------------------------------
# 魚名から特定の釣り場の情報（潮位情報）と過去の釣果データを入手
# 引数：魚名
# 戻り値：特定された釣り場の情報（潮位情報）と過去の釣果データの文字列
# デモでは釣り場は木更津沖堤防：SpotID='tb-001' の固定データとしています
#------------------------------------------
def get_fishinfo(fishid): 
    #釣り場情報を入手（釣り場情報今は固定）
    sql2="SELECT SpotName||'の状況は、'||TideState||'、'|| TideCycle||'、潮位は'||TideHeightCmRelative||'cm' as result ,SpotID,CAST(DatetimeJst AS TIMESTAMP)"\
     " FROM FishDetector.BayInfo WHERE SpotID='tb-001' AND (DatetimeJst BETWEEN DATEADD(hour,-1,?) AND ?)"
    now = str(datetime.datetime.now())
    stmt=iris.sql.prepare(sql2)
    stmt.Statement._SelectMode=1  #odbcモードの指定
    rs=stmt.execute(now,now)
    bayinfo=next(rs,None)
    if bayinfo is None:
        #サンプルデータが2026/9/9までしか登録がないのでそれ以降はダミーを設定して返す
        spotinfo="★サンプルデータ範囲外のためダミーデータを返送★ 釣り場：木更津沖堤防 下げ潮、若潮、潮位は28.5cm"
    
    else :
        spotinfo=bayinfo[2] + "　釣り場：" + bayinfo[0]

    #釣果情報入手
    sql3="SELECT '最大数:'||MAX(FishCount)||'、最小数:'||MIN(FishCount)||'、最大長cm:'||MAX(Size)||'、最小長cm:'||MIN(Size) as result"\
     " FROM FishDetector.FishingInfo WHERE FishID=? AND SpotID='tb-001' AND (ReportDate >= DATEADD(yyyy,-2,?) AND (DATEPART(mm,ReportDate) BETWEEN DATEPART(mm,?)-1 AND DATEPART(mm,?)+1))"
    stmt=iris.sql.prepare(sql3)
    rs=stmt.execute(fishid,now,now,now)
    fishinginfo=next(rs,None)

    if fishinginfo is None:
        #サンプルデータが実行日付に合わない場合のダミーデータ
        fishinginfo="★サンプルデータ範囲外のためダミーデータを返送★ 最大数:115、最小数:1、最大長cm:87、最小長cm:8"
        answer=f"{spotinfo}　本日の前後1か月の過去2年間の釣果情報は、{fishinginfo}"
    
    else :
        answer=f"{spotinfo}　本日の前後1か月の過去2年間の釣果情報は、{fishinginfo[0]}"

    #文字列を戻す
    return answer



#------------------------------------------
# /choka エンドポイント
# ここではSpotIDはtb-001とする（木更津沖防波堤）
# Bodyの中身
#  {
#  "FishID":"f001" 
#  "FishName":"魚名",
#  "Size":魚のサイズ,
#  "FishCount": 釣れた魚の数
#  }
#------------------------------------------
@app.route('/choka',methods=['POST'])
def choka():
    body = request.get_json()
    fishid = body["FishID"]
    spotid='tb-004'
    repordate=datetime.datetime.now()
    sql="insert into FishDetector.FishingInfo (SpotID,FishID,ReportDate,Size,FishCount) VALUES(?,?,?,?,?)"
    stmt=iris.sql.prepare(sql)
    stmt.Statement._SelectMode=1 #odbcモードの指定
    rset=stmt.execute(spotid,fishid,str(repordate.date()),body["Size"],body["FishCount"])
    if (rset.ResultSet._SQLCODE<0) :
        result={"Message":f"エラー：{rset.ResultSet._SQLCODE}, {rset.ResultSet._Message}"}
    else:
        result={"Message":f"{body["FishName"]}の釣果登録完了"}
    return result

if __name__ == "__main__":
    app.run(debug=False)
