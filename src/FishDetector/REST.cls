Class FishDetector.REST Extends %CSP.REST
{

Parameter CONTENTTYPE = "application/json";

Parameter CHARSET = "utf-8";

Parameter CONVERTINPUTSTREAM = 1;

Property key As %String(MAXLEN = "");

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/recipe" Method="POST" Call="recipe" Cors="true"/>
<Route Url="/recipe2" Method="POST" Call="recipe2" Cors="true"/>
<Route Url="/upload" Method="POST" Call="upload" Cors="true"/>
<Route Url="/choka" Method="POST" Call="choka" Cors="true"/>
<Route Url="/hello" Method="GET" Call="hello" Cors="true"/>
</Routes>
}

/// 魚の画像はfishで送る
ClassMethod upload() As %Status
{
    #dim %request As %CSP.Request
    set basepath="/src/images/"
    set upstream=$get(%request.MimeData("fish", 1))
    set fname=%request.MimeData("fish",1).FileName
    set fo=##class(%Stream.FileBinary).%New()
    do fo.LinkToFile(basepath_fname)
    do fo.CopyFrom(upstream)
    set status=fo.%Save()
    if $$$ISERR(status) {
        // ファイル保存失敗
        return status
    }
    // embedding メソッド呼び出しの場合
    //set embedval=##class(FishDetector.Event).GetEmbedding(basepath_fname)
    // ここから画像検索
    //set sql="select top 1 FishName,FishInfo,VECTOR_COSINE(FishNameVec, TO_VECTOR(?, DOUBLE, 512)) as cos from FishDetector.Fish ORDER BY cos desc"
    set sql="select top 1 FishID,FishName,VECTOR_COSINE(FishNameVec, TO_VECTOR(FishDetector.GetEmbedding('I',?), DOUBLE, 512)) as cos from FishDetector.Fish ORDER BY cos desc"
    set stmt=##class(%SQL.Statement).%New()
    set status=stmt.%Prepare(sql)
    //set rset=stmt.%Execute(embedval)
    set rset=stmt.%Execute(basepath_fname)
    do rset.%Next()

    //　JSON作成
    set json={}
    set json.FishName=rset.%Get("FishName")
    set fishid=rset.%Get("FishID")

    // 釣り場の情報を取得（木更津沖堤防固定情報：SpotID='tb-001'）
    set sql2="SELECT SpotName||'の状況は、'||TideState||'、'|| TideCycle||'、潮位は'||TideHeightCmRelative||'cm' as result ,SpotID,DatetimeJst"
    set sql2=sql2_" FROM FishDetector.BayInfo WHERE SpotID='tb-001' AND DatetimeJst BETWEEN DATEADD(hour,-1,?) AND ?"
    // 現在のローカルタイムスタンプ
    set ts=##class(%UTC).NowLocal()
    set stmt.%SelectMode=1  //ODBCモード
    set status=stmt.%Prepare(sql2)
    set rset=stmt.%Execute(ts,ts)
    do rset.%Next()
    set spotinfo=rset.DatetimeJst_" 釣り場："_rset.%Get("result")

    // 過去の釣り情報（木更津沖堤防固定情報：SpotID='kb-001'）
    // 過去2年、指定日付の月前後1か月の釣り情報
    set sql3="SELECT '最大数:'||MAX(FishCount)||'、最小数:'||MIN(FishCount)||'、最大長cm:'||MAX(Size)||'、最小長cm:'||MIN(Size) as result"
    set sql3=sql3_" FROM FishDetector.FishingInfo WHERE FishID=? AND SpotID='kb-001' AND (ReportDate >= DATEADD(yyyy,-2,?) AND (DATEPART(mm,ReportDate) BETWEEN DATEPART(mm,?)-1 AND DATEPART(mm,?)+1))"
    set status=stmt.%Prepare(sql3)
    set now=$ZDATE($Horolog,3)
    set rset=stmt.%Execute(fishid,now,now,now)
    do rset.%Next()
    set fishinginfo=rset.%Get("result")
    set json.FishInfo=$Get(spotinfo)
    set ^iijimaz=fishinginfo
    if $GET(fishinginfo)'="" {
        set json.FishInfo=$Get(spotinfo)_"　本日の前後1か月の過去2年間の釣果情報は、"_$Get(fishinginfo)
    }
    do json.%ToJSON()
    return $$$OK
}

/// 釣果登録
/// SpotIDは固定：kb-001
/// Body
/// {
///  "FishID":"f001",
///  "FishName":"アジ",
///  "Size":20,
///  "FishCount": 2
/// }
ClassMethod choka() As %Status
{
    #dim %request As %CSP.Request
    set body={}.%FromJSON(%request.Content)
    set sql="insert into FishDetector.FishingInfo (SpotID,FishID,ReportDate,Size,FishCount) VALUES(?,?,?,?,?)"
    set stmt=##class(%SQL.Statement).%New()
    set status=stmt.%Prepare(sql)
    set stmt.%SelectMode=1
    set rset=stmt.%Execute("kb-001",body.FishID,$ZDATE($H,3),body.Size,body.FishCount)
    set j={}
    set j.Message=body.FishName_"の釣果登録完了"
    do j.%ToJSON()
    return $$$OK
}

/// Ollama用
/// POSTのボディ
/// {
///  "UserInput":"ここにユーザが希望するレシピの内容",
///  "FishName":"魚名",
///  "FishInfo":"魚の画像ファイルから得られた補足情報"
/// }
ClassMethod recipe() As %Status
{
    #dim %request As %CSP.Request
    set body={}.%FromJSON(%request.Content)
    set status=##class(FishDetector.REST).AskLLM(1,.body,.ans)
    do ans.%ToJSON()
    return $$$OK
}

/// OpenAI用
/// POSTのボディ
/// {
///  "UserInput":"ここにユーザが希望するレシピの内容",
///  "FishName":"魚名",
///  "FishInfo":"魚の画像ファイルから得られた補足情報"
/// }
ClassMethod recipe2() As %Status
{
    #dim %request As %CSP.Request
    set body={}.%FromJSON(%request.Content)
    set status=##class(FishDetector.REST).AskLLM(0,.body,.ans)
    do ans.%ToJSON()
    return $$$OK
}

ClassMethod hello() As %Status
{
    set json={}
    set json.RetMessage="あいうえお"
    do json.%ToJSON()
    return $$$OK
}

ClassMethod AskLLM(flg As %Boolean = 1, body As %DynamicAbstractObject, ByRef ans As %DynamicAbstractObject) As %DynamicAbstractObject
{
    #dim ex As %Exception.AbstractException
    set status=$$$OK
    set ans={}
    set ans.Message=""
    try {
        //送信メッセージの準備
        set sendjson={}
        set sendjson.messages=[]
        set prompt={}
        set prompt.role="system"
        set prompt.content="あなたは釣りのスペシャリストで釣り場の潮位や季節ごとに釣れる魚情報に詳しく地元料理についても詳しいです。本日釣った魚名、体長、ユーザの状況、過去の釣果情報、釣り場の潮位情報を参考として30分程度で作れる釣り場の地元レシピを教えてください。"
        do sendjson.messages.%Push(prompt)
        set prompt={}
        set prompt.role="user"
        set prompt.content="魚名は"_body.FishName_"。"_body.FishInfo
        do sendjson.messages.%Push(prompt)
        set prompt={}
        set prompt.role="user"
        set prompt.content=body.UserInput
        do sendjson.messages.%Push(prompt)
        //request
        set req=##class(%Net.HttpRequest).%New()
        set req.ContentType="application/json"
        set req.ContentCharset="utf-8"

        /*LLM毎の準備*/
        // Ollama
        if flg=1 {
            set req.Server="176.34.0.93"
            set req.Location="/api/chat"
            //モデルの指定
            set sendjson.model="pakachan/elyza-llama3-8b"
            do sendjson.%Set("stream",0,"boolean")
        }
        // OpenAI
        if flg'=1 {
            set req.Server="api.openai.com"
            set req.Location="/v1/chat/completions"
            //モデルの指定
            set sendjson.model="gpt-4o"
            set key=..setAPIKey()
            //https通信用指定
            set req.SSLConfiguration="webapi"
            set req.Https=1
            //APIキーのセット
            do req.SetHeader("Authorization","Bearer "_key)
        }
        //body
        do sendjson.%ToJSON(req.EntityBody)
        //w req.EntityBody.Read(),!
        //w w req.EntityBody.Rewind()

        $$$ThrowOnError(req.Post())
        set response=req.HttpResponse
        if response.StatusCode'=200&(response.StatusCode'=202) {
            set errmessage=response.Data.Read()
            set status=$system.Status.Error(5001,errmessage)
            return status
        }

        set resjson={}.%FromJSON(response.Data)
        /* LLM毎回答が異なる*/
        //Ollama
        if flg=1 {
            set ans.Message=resjson.message.content
        }
        //OpenAI
        if flg'=1 {
            set ans.Message=resjson.choices."0".message.content   
        }
    }
    catch ex {
        set status=ex.AsStatus()
    }
    return status
}

/// /src/wsgi/config.pyに記載しているOpenAIのAPIキーを入手して戻す
ClassMethod setAPIKey() As %String(MAXLEN="")
{
    set sys=##class(%SYS.Python).Import("sys")
    do sys.path.append("/src/wsgi")
    set config=##class(%SYS.Python).Import("config")
    return config.key
}

ClassMethod setdata(body As %DynamicAbstractObject) As %DynamicAbstractObject
{
        set sendjson={}
        set sendjson.messages=[]
        set prompt={}
        set prompt.role="system"
        set prompt.content="あなたは釣りのスペシャリストで釣り場の地元料理をよく知っています。本日釣った魚名、体長、ユーザの状況、過去の釣果情報を参考情報として30分程度で作れる地元レシピを教えてください。"
        do sendjson.messages.%Push(prompt)
        set prompt={}
        set prompt.role="user"
        set prompt.contet="魚名は"_body.FishName_"。"_body.FishInfo
        do sendjson.messages.%Push(prompt)
        set prompt={}
        set prompt.role="user"
        set prompt.content=body.UserInput
        do sendjson.messages.%Push(prompt)
        //request
        set req=##class(%Net.HttpRequest).%New()
        set req.ContentType="application/json"
        set req.ContentCharset="utf-8"
        //body
        do sendjson.%ToJSON(req.EntityBody)
        do sendjson.%ToJSON()
        return sendjson
}

}
