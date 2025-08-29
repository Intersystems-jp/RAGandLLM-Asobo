Class FishDetector.InstallUtils
{

ClassMethod loadsql(file As %String) As %Status
{
    //ログは入力ファイルと同じディレクトリに置く
    set logfile=##class(%File).GetDirectory(file)_"sqlload-log.txt"
    set sql="LOAD SQL FROM FILE '"_file_"' DIALECT 'IRIS'"
    set sql=sql_" LOG TO FILE '"_logfile_"' IGNORE ERRORS"
    set stmt=##class(%SQL.Statement).%New()
    set tResult = ##class(%SQL.Statement).%ExecDirect(.tStatement,sql)
    if tResult.%SQLCODE<0 {
        write "Error::",tResult.%Message,!
    }
}

ClassMethod loaddata(file As %String) [ Language = python, SqlProc ]
{
    import iris
    import irisbuiltins
    import json
    import time
    start = time.time()  # 現在時刻（処理開始前）を取得
    try:
        with open(file, "r", encoding="utf-8") as f:
            fish_docs = [json.loads(line) for line in f]
        
        sql="insert into FishDetector.Fish (FishID,FishName,FishNameVec) Values(?,?,TO_VECTOR(?,DOUBLE,512))"
        stmt=iris.sql.prepare(sql)
        for item in fish_docs:
            #print(type(item["embedding"][0]))
            embeddingstr=str(item["embedding"])
            print(embeddingstr[1:-1])
            rs=stmt.execute(item["fishid"],item["fishname"],embeddingstr[1:-1])            
            #rs=stmt.execute(item["fishname"],item["text"],item["embedding"][0])
    
    except irisbuiltins.SQLError as ex:
        print(str(repr(ex)))
        print(ex.sqlcode)
        print(ex.message)
        print(ex.statement)
        raise
    
    end = time.time()  # 現在時刻（処理完了後）を取得
    time_diff = end - start  # 処理完了後の時刻から処理開始前の時刻を減算する
    print(f"処理時間：{time_diff}")  # 処理にかかった時間データを使用
}

}
