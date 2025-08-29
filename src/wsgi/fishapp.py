from flask import Flask,request,jsonify
import json
import requests
import os
#import sys
#sys.path += ["/usr/irissys/mgr/python","/usr/irissys/lib/python"]
import iris
import time,datetime
import config

#UPLOAD用フォルダ
UPLOAD_FOLDER = "/src/images/"

#生成AIのURL
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
    fishname=fishinfo[1]
    fishid=fishinfo[0]

    #釣り場情報を入手（釣り場情報今は固定）
    sql2="""
    SELECT SpotName||'の状況は、'||TideState||'、'|| TideCycle||'、潮位は'||TideHeightCmRelative||'cm' as result
      ,SpotID,CAST(DatetimeJst AS TIMESTAMP) FROM FishDetector.BayInfo WHERE SpotID='tb-001' AND DatetimeJst BETWEEN DATEADD(hour,-1,?) AND ?
    """
    now = str(datetime.datetime.now())
    stmt=iris.sql.prepare(sql2)
    stmt.Statement._SelectMode=1 #odbcモードの指定
    rs=stmt.execute(now,now)
    bayinfo=next(rs)
    spotinfo=bayinfo[2] + "　釣り場：" + bayinfo[0]

    #釣り果情報入手
    sql3="SELECT '最大数:'||MAX(FishCount)||'、最小数:'||MIN(FishCount)||'、最大長cm:'||MAX(Size)||'、最小長cm:'||MIN(Size) as result"\
     " FROM FishDetector.FishingInfo WHERE FishID=? AND SpotID='kb-001' AND (ReportDate >= DATEADD(yyyy,-2,?) AND (DATEPART(mm,ReportDate) BETWEEN DATEPART(mm,?)-1 AND DATEPART(mm,?)+1))"
    stmt=iris.sql.prepare(sql3)
    stmt.Statement._SelectMode=1 #odbcモードの指定
    rs=stmt.execute(fishid,now,now,now)
    fishinginfo=next(rs)

    #回答のJSONを作成
    ans= jsonify({"FishName":fishname,"FishInfo":spotinfo+"　本日の前後1か月の過去2年間の釣果情報は、"+fishinginfo[0],"FishID":fishid})

    return ans

# ------------------------------------------
# /recipe エンドポイント
# Bodyの中身
#  {
#  "UserInput":"ここにユーザが希望するレシピの内容",
#  "FishName":"魚名",
#  "FishInfo":"魚の画像ファイルから得られた補足情報"
# }
# ------------------------------------------
@app.route('/recipe',methods=['POST'])
def getrecipe():
    body = request.get_json()
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
                "content": f"魚名は{body["FishName"]}です{body["FishInfo"]}",
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
    answer=json.dumps({"Message":result["message"]["content"]},ensure_ascii=False)
    return answer


@app.route('/recipe2',methods=['POST'])
def getrecipe2():
    body = request.get_json()
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
                "content": f"魚名は{body["FishName"]}です{body["FishInfo"]}",
            },
            {
                "role": "user",
                "content": f"{body["UserInput"]}",
            }
        ]
    }

    response = requests.post(API_SERVER_URL, headers=headers, json=data)
    result = response.json()
    answer=json.dumps({"Message":result["choices"][0]["message"]["content"]},ensure_ascii=False)
    return answer

#------------------------------------------
# /choka エンドポイント
# ここではSpotIDはkb-001とする（木更津沖防波堤）
# Bodyの中身
#  {
#  "FishID":fishid,
#  "FishName":"魚名",
#  "Size":魚のサイズ,
#  "FishCount": 釣れた魚の数
#  }
#------------------------------------------
@app.route('/choka',methods=['POST'])
def choka():
    body = request.get_json()
    spotid='kb-001'
    repordate=datetime.datetime.now()
    sql="insert into FishDetector.FishingInfo (SpotID,FishID,ReportDate,Size,FishCount) VALUES(?,?,?,?,?)"
    stmt=iris.sql.prepare(sql)
    stmt.Statement._SelectMode=1 #odbcモードの指定
    rset=stmt.execute(spotid,body["FishID"],str(repordate.date()),body["Size"],body["FishCount"])
    if (rset.ResultSet._SQLCODE<0) :
        result={"Message":f"エラー：{rset.ResultSet._SQLCODE}, {rset.ResultSet._Message}"}
    else:
        result={"Message":f"{body["FishName"]}の釣果登録完了"}
    return result

if __name__ == "__main__":
    app.run(debug=False)