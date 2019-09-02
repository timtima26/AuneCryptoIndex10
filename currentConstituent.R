################### 套件載入
if(!require(RODBC)) install.packages("RODBC",repos = "https://mran.microsoft.com/snapshot/2019-01-10")
if(!require(gWidgets)) install.packages("gWidgets",repos = "https://mran.microsoft.com/snapshot/2019-01-10")
if(!require(RMariaDB)) install.packages("RMariaDB",repos = "https://mran.microsoft.com/snapshot/2019-01-10")
if(!require(dbConnect)) install.packages("dbConnect",repos = "https://mran.microsoft.com/snapshot/2019-01-10")
if(!require(DBI)) install.packages("DBI",repos = "https://mran.microsoft.com/snapshot/2019-01-10")
if(!require(XML)) install.packages("XML",repos = "https://mran.microsoft.com/snapshot/2019-01-10")
if(!require(bitops)) install.packages("bitops",repos = "https://mran.microsoft.com/snapshot/2019-01-10")
if(!require(RCurl)) install.packages("RCurl",repos = "https://mran.microsoft.com/snapshot/2019-01-10")
if(!require(jsonlite)) install.packages("jsonlite",repos = "https://mran.microsoft.com/snapshot/2019-01-10")
if(!require(dplyr)) install.packages("dplyr",repos = "https://mran.microsoft.com/snapshot/2019-01-10")
if(!require(lubridate)) install.packages("RODBC",repos = "https://mran.microsoft.com/snapshot/2019-01-10")
library(dplyr)
library(RODBC)
library(gWidgets)
library(RMariaDB)
library(dbConnect)
library(DBI)
library(XML)
library(bitops)
library(RCurl)
library(jsonlite)
library(lubridate)


################### 取ENV連DB(BETA mysql ) 

env <- as.data.frame(system('cat /home/rstudio/code/.env',intern = T))
env <- as.data.frame(env[-which(env[,1]==''),])
env <- as.data.frame(strsplit(as.character(env[,1]), split='='))


#Bata
dbhost = as.character(env[2,which(env[1,]=='DB_HOST')])
dbname = as.character(env[2,which(env[1,]=='DB_DATABASE')])
dbuser = as.character(env[2,which(env[1,]=='DB_USERNAME')])
dbpwd = as.character(env[2,which(env[1,]=='DB_PASSWORD')])

conn <- dbConnect(RMariaDB::MariaDB(),
                  dbname=dbname,
                  user=dbuser,
                  password=dbpwd,
                  host=dbhost,
                  port=3306)

############################################ 取當調整日前一天收盤市值最高前十加密貨幣

rerankday<-format(Sys.Date()-1,'20%y%m%d')


url <- paste0('https://coinmarketcap.com/zh-tw/historical/',rerankday,'/')
url <- getURL(url,httpheader = c("User-Agent"="Mozilla/5.0 (Windows NT 6.1; WOW64)")) 
content1<-htmlParse(url)
dt1 <- readHTMLTable(content1,header = T)
dt1 <- as.data.frame(dt1[1])[1:10,3:4]
dt1[,3] <- Sys.Date()
dt1[,2] <- as.numeric(gsub('\\$|,', '', dt1[,2]))

############################################ 前十加密貨幣計算權重與F值與調整市值
dt1$weight <- log(dt1[,2]/1000000000)
dt1$weight <- dt1[,4]/sum(dt1[,4])
dt1$Fvalue <- dt1$weight/dt1[,2]*sum(dt1[,2])/1.5
dt1$MDJ <- dt1$Fvalue*dt1[,2]
dt1 <- dt1[,-2]
colnames(dt1) <- c('symbol','date','weight','F','MDJ')
dt1$weight <- round(dt1$weight,5)
dt1$F <- round(dt1$F,5)

############################################ 加密貨幣帶入爬蟲的網頁參數
cctag <- fromJSON(getURL('https://s2.coinmarketcap.com/generated/search/quick_search.json'))
cctag <- cctag[,c(2,1,4)]
dbExecute(conn,"TRUNCATE TABLE cryptoCurrencyTag")
dbWriteTable(conn,"cryptoCurrencyTag",cctag,append=T,overwrite=F)
dt1 <- merge(dt1,cctag,by='symbol',all.x=T)
dt1 <- dt1[,c(1,3,5,4,7,2)]

########################################## 寫入當前和歷史成分股

dbWriteTable(conn,"constituentHistory",dt1,append=T,overwrite=F) 
dbExecute(conn,"TRUNCATE TABLE currentConstituent")
dbWriteTable(conn,"currentConstituent",dt1,append=T,overwrite=F)

############################################ 計算除數
q <- dbGetQuery(conn_result,"select indexValue from accIndex where date in (select max(date) from accIndex)")
index = as.numeric(q[1,])
newDivisor = as.numeric(sum(dt1$MDJ))/index
DT <- data.frame(newDivisor, Sys.Date()) 
colnames(DT) <- c('Divisor','Date')

########################################## 寫入當前和歷史除數
dbExecute(conn,"TRUNCATE TABLE currentDivisor")
dbWriteTable(conn,"currentDivisor",DT,append=T,overwrite=F)
dbWriteTable(conn,"divisortHistory",DT,append=T,overwrite=F)
