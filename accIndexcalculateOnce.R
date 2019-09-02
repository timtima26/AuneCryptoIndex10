
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


###################取ENV連DB(BETA&BETA_RESULT) 

env <- as.data.frame(system('cat /home/rstudio/cnyes_code/.env',intern = T))
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

#Bata_result
dbhostr = as.character(env[2,which(env[1,]=='DB_CDA_RESULT_HOST')])
dbnamer = as.character(env[2,which(env[1,]=='DB_CDA_RESULT_DATABASE')])
dbuserr = as.character(env[2,which(env[1,]=='DB_CDA_RESULT_USERNAME')])
dbpwdr = as.character(env[2,which(env[1,]=='DB_CDA_RESULT_PASSWORD')])

conn_result <- dbConnect(RMariaDB::MariaDB(),
                         dbname=dbnamer,
                         user=dbuserr,
                         password=dbpwdr,
                         host=dbhostr,
                         port=3306)




##################取得指數成分股的調整日期和抓取資料日

x <- seq(as.Date("2018-01-01"), as.Date("2018-12-31"), by = "day")
runday <- x[weekdays(x) == "Friday" & as.numeric(format(x, "%d")) <= 21 &
              as.numeric(format(x, "%d")) >= 14 & month(x) %in% c(2,5,8,11)]
runday <- c(as.Date('2018-01-01'),runday,Sys.Date()-1)
historyrankdate <- format(runday-1,'20%y%m%d')

####################取得歷史調整日成分股
i=1
for ( i in 1:5) {
  url <- paste0('https://coinmarketcap.com/zh-tw/historical/',historyrankdate[i],'/')
  url <- getURL(url,httpheader = c("User-Agent"="Mozilla/5.0 (Windows NT 6.1; WOW64)")) 
  content1 <- htmlParse(url)
  dt1 <- readHTMLTable(content1,header = T)
  dt1 <- as.data.frame(dt1[1])[1:10,3:4]
  dt1[,3] <- runday[i] #runday
  dt1[,2] <- as.numeric(gsub('\\$|,', '', dt1[,2]))
  dt1$weight <- log(dt1[,2]/1000000000)
  dt1$weight <- dt1[,4]/sum(dt1[,4])
  dt1$Fvalue <- dt1$weight/dt1[,2]*sum(dt1[,2])/1.5
  dt1$MDJ <- dt1$Fvalue*dt1[,2]
  dt1 <- dt1[,-2]
  colnames(dt1) <- c('symbol','date','weight','F','MDJ')
  dt1$weight <- round(dt1$weight,5)
  dt1$F <- round(dt1$F,5)
  assign(paste('dmm',i,sep =''),dt1)
  }


 ######取得成分股網頁參數

cctag <- fromJSON(getURL('https://s2.coinmarketcap.com/generated/search/quick_search.json'))
cctag <- cctag[,c(2,1,4)]
dbWriteTable(conn,"cryptoCurrencyTag",cctag,overwrite=T) 

dmm <- rbind(dmm1,dmm2,dmm3,dmm4,dmm5)
dmm <- merge(dmm,cctag,by='symbol',all.x=T)
dmm <- dmm[,-6]

dbWriteTable(conn,"constituentHistory",dmm,append=T,overwrite=F)

dmm5<-merge(dmm5,cctag,by='symbol',all.x=T)
dmm5<-dmm5[,-6]
dbWriteTable(conn,"currentConstituent",dmm5,append=T,overwrite=F)

#######################################Calculating index values

si <- data.frame(indexValue=1000,date='2018-01-01',MDJ=317327134000)
dbWriteTable(conn_result,"accIndex",si,append=T,overwrite=F)

for ( i in 1:5) {
  q <- dbGetQuery(conn_result,paste("select indexValue from accIndex where date='",runday[i],"'",sep=''))
  d <- dbGetQuery(conn,paste("select MDJ,F,slug,symbol from constituentHistory where date='",runday[i],"'",sep=''))
  divisor = as.numeric(sum(d$MDJ))/q
  DT <- data.frame(divisor,runday[i]) 
  colnames(DT) <- c('divisor','date')
  dbExecute(conn,"TRUNCATE TABLE currentDivisor")
  dbWriteTable(conn,"currentDivisor",DT,append=T,overwrite=F)
  dbWriteTable(conn,"divisortHistory",DT,append=T,overwrite=F)
  

  
  start <- format(runday[i],'20%y%m%d')
  end <- format(runday[i+1],'20%y%m%d')
  sluglist <- d$slug
  
  
  
  for ( j in 1:length(sluglist)) {
    url<-paste0('https://coinmarketcap.com/zh-tw/currencies/',sluglist[j],'/historical-data/?start=',start,'&end=',end)
    url<-getURL(url,httpheader = c("User-Agent"="Mozilla/5.0 (Windows NT 6.1; WOW64)")) 
    content1<-htmlParse(url)
    dt1 <- readHTMLTable(content1,header = T)
    dt1 <- as.data.frame(dt1[1])
    dt1[,8] <- sluglist[j]
    assign(paste("dmmh",j,sep=""),dt1)
  }
  
  
  dm<-rbind(dmmh1,dmmh2,dmmh3,dmmh4,dmmh5,dmmh6,dmmh7,dmmh8,dmmh9,dmmh10)
  colnames(dm)<-c('date','openPrice','highPrice','lowPrice','closePrice','tradeVolume','marketCap','slug')
  dm$marketCap <- as.numeric(gsub('\\$|,', '', dm$marketCap))
  dm<-merge(dm,d[2:4],by='slug',all.x=T)
 
  
  
  divisor<-dbGetQuery(conn,"select divisor from currentDivisor")
  divisor = as.numeric(divisor[1,1])
    
  dm1<- dm %>%
    group_by(date) %>%
    summarise(MDJ=sum(marketCap*F))
  
  dm1$index <- as.numeric(dm1$MDJ/divisor)
  
  dm1$date <- as.Date(gsub('年|月|日','', dm1$date),"20%y%m%d")+1
  colnames(dm1)[3] <-'indexValue'
 

 
  dm$weight<-log(dm$marketCap/1000000000)
  weightsum <- dm %>%
    group_by(date) %>%
    summarise(weightsum=sum(weight)) 
  
  dm2 <- merge(dm,weightsum,by="date")
  dm2$weight <- log(dm2$marketCap/1000000000)/dm2$weightsum 

 
  dm2 <- dm2[,-c(2,12,9)]
  dm2$date <- gsub('年|月|日', '', dm2$date)
  dm2$tradeVolume <- as.numeric(gsub('\\$|,', '', dm2$tradeVolume))
  
    
  dbWriteTable(conn,"cryptoCurrencyHistory",dm2,append=T,overwrite=F)
  dbWriteTable(conn_result,"accIndex",dm1,append=T,overwrite=F)
}
