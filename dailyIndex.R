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

#######################################Calculating index values


dataday <- format(Sys.Date()-1,'20%y%m%d')

d <- dbGetQuery(conn,paste("select MDJ,F,slug,symbol from currentConstituent"))
divisor <- dbGetQuery(conn,paste("select divisor from currentDivisor"))
divisor = as.numeric(divisor[1,1])
sluglist <- d$slug

for ( i in 1:length(sluglist) ) {
  url <- paste0('https://coinmarketcap.com/zh-tw/currencies/',sluglist[i],'/historical-data/?start=',dataday,'&end=',dataday)
  url <- getURL(url,httpheader = c("User-Agent"="Mozilla/5.0 (Windows NT 6.1; WOW64)")) 
  content1 <- htmlParse(url)
  dt1 <- readHTMLTable(content1,header = T)
  dt1 <- as.data.frame(dt1[1])
  dt1[,8] <- sluglist[i]
  assign(paste("dmmh",i,sep=""),dt1)
}

dm <- rbind(dmmh1,dmmh2,dmmh3,dmmh4,dmmh5,dmmh6,dmmh7,dmmh8,dmmh9,dmmh10)
colnames(dm) <- c('date','openPrice','highPrice','lowPrice','closePrice','tradeVolume','marketCap','slug')
dm$marketCap <- as.numeric(gsub('\\$|,', '', dm$marketCap))
dm <- merge(dm,d,by='slug',all.x=T)
dm <- unique(dm)

dm1 <- dm %>%
    group_by(date) %>%
    summarise(MDJ=sum(marketCap*F)) 


dm1 <- dm %>%
  group_by(date) %>%
  summarise(MDJ=sum(marketCap*dm$F)) 

dm1$index <- as.numeric(dm1$MDJ/divisor)

dm1$date <- as.Date(gsub('年|月|日','', dm1$date),"20%y%m%d")+1
colnames(dm1)[3] <- 'indexValue'

weightsum <- dm %>%
  group_by(date,slug) %>%
  summarise(weight=log(marketCap/1000000000)) %>%
  group_by(date) %>%
  summarise(weightsum=sum(weight)) 

dm2 <- merge(dm,weightsum,by="date")
dm2$weight <- as.numeric(log(dm2$marketCap/1000000000)/dm2$weightsum)

dm2 <- dm2[,-c(2,12,10,9)]
dm2$date <- gsub('年|月|日','',dm2$date)
dm2$tradeVolume <- as.numeric(gsub('\\$|,', '', dm2$tradeVolume))


dbWriteTable(conn,"cryptoCurrencyHistory",dm2,append=T,overwrite=F)
dbWriteTable(conn_result,"accIndex",dm1,append=T,overwrite=F)

head(dm1)
