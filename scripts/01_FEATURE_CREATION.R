####0. Libraries and directories####
pacman::p_load(rstudioapi, h2o, dplyr, readr,  zoo,
               lubridate,  caret, stringr)


#setting up directory
current_path=getActiveDocumentContext()$path
setwd(dirname(current_path))
setwd("..")
rm(current_path)
list.files("datasets/")

new_features<-function(ts){
  
  #split the data by year, quarter, month...
  ts$year <- lubridate::year(ts$ds)
  ts$quarter <- lubridate::quarter(ts$ds)
  ts$month <- lubridate::month(ts$ds)
  ts$week <- lubridate::week(ts$ds)
  ts$weekday <- lubridate::wday(ts$ds)
  ts$day <- lubridate::day(ts$ds)
  
  #MONTH_NO: feature counting the months
  ts<-ts %>% group_by(year,month) %>% mutate(month_no=group_indices())
  
  #DAY_NO:
  ts$day_no<-as.numeric(rownames(ts))
  
  #DAYMONTH:
  ts$day_month<-ts$month*100+ts$day
  
  #diff:Increment between days feature
  ts$diff<-0
  ts[c(2:nrow(ts)),"diff"]<-diff(ts$y)
  
  #diff2 binary increment or decrement of diff
  ts<- ts  %>% mutate(diff2 = case_when(
    diff > 0 ~ 1, 
    diff <= 0 ~ -1))
  
  # #diff_year:Increment between same day from different years
  ts<-ts %>% group_by(month,day)  %>%mutate(increment_year=c(0,diff(y)))
  
  
  #ROLLMEANS: Rolling means Feature (previous 7 days)#
  rollmeans <- zoo::rollmean(ts$y, 7, na.pad = TRUE) #Mean model of the previous 7 days
  rollmeans[is.na(rollmeans)] <- 0 #replace NA by 0
  rollmeans<-as.data.frame(rollmeans) 
  ts$rollmeans<-rollmeans[,1]
  remove(rollmeans)
  
  #SPECIAL_DAYS: the days where 
  #the mean of the last 7 days is bigger than 7000 or 
  #the difference between previous day is bigger than 2000
  #create default feature (0=NORMAL, 1=SPECIAL)
  ts$special_days<-0
  ts$special_days <- ifelse(ts$rollmeans > 7000 | ts$diff > 2000 ,1, 0)
  
  #HOLIDAYS: (giving a weight from 0 to 8 according the number of visits)
  ts$holidays <- 0
  ts[which(ts$y > 14000),"holidays"]<-8  #weight of 8 if 14k visists or bigger
  ts[which(ts$y <= 14000 &  ts$y > 10000),"holidays"]<-7 #7 in [10k-14k] visists
  ts[which(ts$y <= 10000 &  ts$y > 8000),"holidays"]<-6 #6 in [8k-10k] visists
  ts[which(ts$y <= 8000 &  ts$y > 7000),"holidays"]<-5 #5 in [7k-8k] visists
  ts[which(ts$y <= 7000 &  ts$y > 6500),"holidays"]<-4 #4 in [6.5k-7k] visists
  ts[which(ts$y <= 6500 &  ts$y > 6000),"holidays"]<-3 #3 in [6k-6.5k] visists
  ts[which(ts$y <= 6000 &  ts$y > 5500),"holidays"]<-2 #2 in [5k-6k] visists
  
  
  return(ts)
  
}




