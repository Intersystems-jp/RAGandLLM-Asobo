/// CLIPのモデルロードとEmbeddingを行うユーティリティクラス
/// 参考：https://jp.community.intersystems.com/node/584051
Class FishDetector.Event Extends %RegisteredObject
{

/// 1秒ごと監視
ClassMethod createEvent(timeout As %Integer = 1)
{
    kill ^iijima,^ZFishEvent,^IRISTempFish
    set ^ZFishEvent("STOP")=0
    
    //cliputil.pyインポート
    set sys=##class(%SYS.Python).Import("sys")
    do sys.path.append("/src/wsgi")
    set start=$ZH
    set cliputil=##class(%SYS.Python).Import("cliputil")
    set ^iijima("IRIS-clip-load")=$ZH-start
    // ロード終了確認用
    write "CLIP-Load完了：",^iijima("IRIS-clip-load"),!
    // イベント作成
    set status=$SYSTEM.Event.Create("FishEvent")
    set num=1
    // ^ZFishEvent("STOP")が0の時はループ、1になったら停止
    while ($GET(^ZFishEvent("STOP"))=0) {
        // timeout以内にSignalがあればEmbedding実行
        // 呼び出し側が　do $SYSTEM.Event.Signal("FishEvent",imgdir)　を送ってくるパタン
        set sigmsg=$SYSTEM.Event.WaitMsg("FishEvent",timeout)
        // IRISのリスト 1番目の値が1ならSignal送ってきている
        if $LIST(sigmsg,1)=0 {
            continue
        }
        // $LISTBUILD(メッセージ,番号) で情報が渡る
        set embedinfo=$LIST(sigmsg,2)
        set embedingtype=$LIST(embedinfo,1) //TまたはI
        set embedimg=$LIST(embedinfo,2) //Embeddingするテキスト、または画像ファイル名
        set fishnum=$LIST(embedinfo,3)  //この番号をキーにEmbedding結果をセットする
        set ^iijima("IRIS-clip-embedding-data",num)=embedimg
        set start=$ZH
        //CLIPを使ったEmbedding実行
        if embedingtype="T" {
            set embed=cliputil."get_clip_text_embeddings"(embedimg)
        }
        else {
            set embed=cliputil."get_image_embeddings"(embedimg)
        }
        //Signal送り側が使用する情報を指定された番号をキーにセット
        set ^IRISTempFish(fishnum)=embed
        set ^iijima("IRIS-clip-embedding",num)=$ZH-start
        set num=num+1
    }
    // 終了確認用グローバル
    set ^ZFishEvent="END"
}

/// CLIPモデル 画像をEmbeddingを行うときに呼ぶメソッド（またはストアドプロシージャ）
/// 引数1：Embeddingのタイプ：テキストならT、画像ならI
/// 引数2：Embeddingを行う情報（第1引数がTならテキスト、Iなら画像のフルパス）
ClassMethod GetEmbedding(type As %String, in As %String) As %Vector [ SqlName = GetEmbedding, SqlProc ]
{
    #dim %sqlcontext As %ProcedureContext
    if $get(type)="" {
        set %sqlcontext.%Message="エラー：typeが指定されていません"
        set %sqlcontext.%SQLCODE=-401
        return ""
    }
    // typeがTでもIでもないとき
    if '(($get(type)="T") || ($get(type)="I")) {
        set %sqlcontext.%Message="エラー：typeの指定が違います。type："_$get(type)
        set %sqlcontext.%SQLCODE=-401
        return ""
    } 
    // Embedding結果を受け取る時に使用する通し番号セット
    set fishnum=$INCREMENT(^IRISTempFish)
    // SignalのメッセージとしてIRISのリストで1、テキストか画像かのフラグ（T/I）、テキストなら文字列/画像ならファイルフルパス,番号 を送付
    set status=$SYSTEM.Event.Signal("FishEvent",$LISTBUILD(type,in,fishnum))
    // 失敗時
    if status=0 {
        set %sqlcontext.%Message="エラー："_in
        set %sqlcontext.%SQLCODE=-401
        return ""
    }
    //^IRISTempFish(fishnum)の中にEmbedding結果ができるので存在するまで待機
    while $get(^IRISTempFish(fishnum))="" {
        hang 0.1
    }
    set embedval=^IRISTempFish(fishnum)
    kill ^IRISTempFish(fishnum)
    return embedval
}

/// 常駐プロセス終了用メソッド（イベント終了に使用するグローバルをセット）
ClassMethod EndEvent()
{
    set ^ZFishEvent("STOP")=1
}

}
