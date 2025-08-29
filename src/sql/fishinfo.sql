--- 釣り場情報用テーブル準備
CREATE TABLE FishDetector.BayInfo (
    SpotID VARCHAR(10),
    SpotName VARCHAR(60),
    DatetimeJst TIMESTAMP,
    TideHeightCmRelative NUMERIC(4,1),
    TideState VARCHAR(50),
    TideCycle VARCHAR(50)
)
go

--- インデックス追加
CREATE INDEX SpotIDIdx ON TABLE FishDetector.BayInfo(SpotID)
go
CREATE INDEX DatetimeJstIndex On TABLE FishDetector.BayInfo (DatetimeJst)
go

LOAD DATA FROM FILE '/opt/src/tides_2025-08-01_to_2025-09-09_hourly-2.csv'
 INTO FishDetector.BayInfo
 USING {"from":{"file":{"charset":"UTF-8","header":true}}}
go

--- 釣った魚情報
--- SpotID,FishID,FishingDateTime,Size,Count
CREATE TABLE FishDetector.FishingInfo(
    SpotID VARCHAR(50),
    FishID VARCHAR(50),
    ReportDate DATE,
    Size NUMERIC,
    FishCount NUMERIC,
    CONSTRAINT FishFK FOREIGN KEY (FishID) REFERENCES FishDetector.Fish(FishID)
)
go

CREATE INDEX SpotIDIdx On TABLE FishDetector.FishingInfo (SpotID)
go
CREATE INDEX FishIDIdx On TABLE FishDetector.FishingInfo (FishID)
go
CREATE INDEX ReportDateIdx On TABLE FishDetector.FishingInfo (ReportDate)
go

---釣果の登録
LOAD DATA FROM FILE '/opt/src/kisarazu-random.csv'
 INTO FishDetector.FishingInfo
 USING {"from":{"file":{"charset":"UTF-8","header":true}}}
go

LOAD DATA FROM FILE '/opt/src/honmoku_4years.csv'
 INTO FishDetector.FishingInfo
 USING {"from":{"file":{"charset":"UTF-8","header":true}}}
go

