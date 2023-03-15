
# 指數編制步驟文件

目標：取加密貨幣市場市值前十大的貨幣編制成指數，設定2018/1/1起為基期,指數起始值為1,000，每日更新 (end of day index ) <br />
資料源：coinmarketcap （ 加密貨幣市場中，流量最大數據最受歡迎的數據查詢網站）

## 1.	挑選成分股- 爬蟲


#### 取市值前十大之加密貨幣指數作為指數成分股，之後每季調整，調整日定在每年2,5,8,11月的第三個禮拜五，取前一日收盤。 

>例如：<br />
2018/1/1  取 2017/12/31 歷史快照 找到市值前十大成分股 <br />
2018/2/16 取 2/15 歷史快照https://coinmarketcap.com/zh-tw/historical/20180215/ <br />
2018/5/18 取 5/17 https://coinmarketcap.com/zh-tw/historical/20180517/ <br />
2018/8/17 取 8/16 <br />
2018/11/16 取 11/15 <br />
以此類推 <br />
可加上條件式  <br />
IF 交易量 < 500000 <br />
IF 上市日期  <br />

## 2.	計算成分股與權重、調整係數F、調整後市值

權重 = 市值除以1,000,000,000取自然對數，取總和的佔比 <br/>
F  = 權重/市值*不固定常數(成份股總市值除以1.5) <br/>
調整後市值(MDJ) = 市值 * F  <br/>

`Create A table : 成分股名稱、市值、權重、F 值、MDJ、調整日期 (當前、歷史)  `<br/>



## 3.	算指數基期和除數
除數 = MDJ加總/指數 <br/> 
設定2018/1/1 1000為起始點 <br/> 
>2018/1/1 取12/31日成分股MDJ除以當日指數1000為除數 <br/> 
2018/2/16 取2/15 MDJ除以當日指數Ｎ為除數 <br/> 
以此類推 <br/> 


`Create B table : 調整日期、除數 (當前、歷史) `


## 4.	取現行成分股股價市值-爬蟲

取現行成分股的slug帶入網頁參數 
https://s2.coinmarketcap.com/generated/search/quick_search.json <br />

帶入成分股的slug網頁參數取歷史資料 <br />
https://coinmarketcap.com/zh-tw/currencies/bitcoin-cash/historical-data/?start=20180101&end=20190108 <br />

每日計算 <br />
權重=當日市值除以1,000,000,000取自然對數後總和的佔比 <br />
MDJ=市值*當期F (步驟2) <br />

`Create C table : 當期成分股簡稱、當日市值、當日開盤、當日最高價、當日最低價、當日權重、當日調整後市值(MDJ)  *單位：每一隻成分股 ` <br />
 
注意：調整日當天會取兩份資料一是當期成分股爬蟲（需作為新的除數計算基準）二是為新成分股資料

## 5.	計算指數
每日成分股MDJ加總 (步驟4) 除以當期除數 (步驟3) <br />

注意：F值與除數在調整日前都是固定的 <br />


>2018/1/1-2018/2/16每日成份股市值*F1 (MDJ)加總除以基期除數  <br />
2018/2/16-2018/8/15每日成份股市值*F2 (MDJ)加總除以第二期調整日除數D2 <br />
成份股市值*F3 (MDJ)加總除以第三期調整日除數D3 <br />

`Create D table : 當日指數、日期`

## 6. 排程：
每季第三個禮拜五的早上2點 執行 步驟1 更新 A table的所有欄位 新增 A’ table的所有欄位資料 <br />
每季第三個禮拜五的早上3點 執行 步驟2 更新 B table的所有欄位 新增 B’ table的所有欄位資料  <br />
每日早上4點 執行 步驟4和5 新增 C&D table的所有欄位 <br />

## 7. 執行須知

accIndexcalculateOnce.R : 補歷史資料 (執行一次)<br />
調整日取成分股 (排程:每年二、五、九、十一月第三週禮拜五執行 中午十二點執行) #0 12 14-21 2,5,8,11 * if [ date ‘+\%w’ = "5" ]; then <Rscript currentConstituent.R >;fi <br />
dailyindex.R : 每日爬前一日coinmarket收盤資料，計算當日指數 (排程:每天早上九點執行) <br />
 
## table name	description

A:currentConstituent	當前成分股資料表 <br />
A:constituentHistory	歷史成分股 <br />
B:currentDivisor	當前徐數 <br />
B:divisorHistory	歷史指數除數 <br />
C:cryptoCcurrencyHistory	成份股股價市值資料 <br />
C:cryptoCurrencyTag	網頁爬蟲代碼 <br />
D:myCryptoIndex	每日指數與調整市值 <br />

Commit status 1 of 1 passed Success
Currently watchingStop watching
