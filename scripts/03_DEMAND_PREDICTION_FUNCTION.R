####0. Libraries and directories####
pacman::p_load(rstudioapi, h2o, dplyr, readr,  zoo,
               lubridate,  caret, stringr)

h2o.init() #start h2o

#setting up directory
current_path=getActiveDocumentContext()$path
setwd(dirname(current_path))
setwd("..")
rm(current_path)

#Load data (Time Series)
time_series<-read_csv("./datasets/time_series_clean.csv")
#Best model generated in DEMAND_MODEL
BEST_MODEL<-readRDS("./datasets/BEST_MODEL.rds")


#load the new feature Script
source("./scripts/01_FEATURE_CREATION_for_PricingHub.R")
#New Features
time_series<-new_features(time_series) #Need to run Script 01_Feature_Creation

YEAR<-2019
MONTH<-"Apr"
DAY<-28


####FUNCTION TO PREDICT DEMAND####
demand_prediction<- function(DAY, MONTH, YEAR){
  
  #0.AUXILIAR VARIABLES
  MONTH_aux<-match(MONTH,month.abb)
  YEAR_aux<-(YEAR-2018)*12
  start_date<-strptime(paste(DAY+1, MONTH_aux, YEAR),"%d %m %Y") #WARNING: Deppending on the system time might return one day ahead or not (change the 2 by 1 if future datafame doesn't start by day 1)
  n_future_days<-28 #how many days ahead you want to predict
  PREDICTION<-data.frame()
  
  #1.CREATING EMPTY TEST DATA (time_frame)
  #Time series column with the dates 
  time_frame<-as.data.frame(as.Date(seq(start_date, by="day", len=n_future_days))) #as.date advances the sequence one day that's why we set the starting day as the 2nd
  names(time_frame)[1]<-"ds" #rename date column
  
  #y empty column
  time_frame$y<-0
  time_frame<-new_features(time_frame)
  #We give the future data some values from the previous year
  month_indices<- ((time_series$day_month %in% time_frame$day_month) & ((time_series$year+1) %in% time_frame$year))
  time_frame[,"holidays"]<-time_series[month_indices,"holidays"] #give the predicted month the same holidays
  time_frame[,"special_days"]<-time_series[month_indices,"special_days"]
  time_frame[,"month_no"]<-MONTH_aux+YEAR_aux
  time_frame[,"diff"]<-time_series[month_indices,"diff"]
  time_frame[,"diff2"]<-time_series[month_indices,"diff2"]
  
  MONTH_aux2<-as.numeric(time_frame[nrow(time_frame),"month"])
  #2. PREDICTED AND PREDICTOR VARIABLES 
  
  #dependent variable y (visits)
  y.dep <- "y"
  #independent variables POSSIBLE VARIABLES TO INCLUDE IN THE MODEL
  #c("ds","diff","holidays","month","year","week","weekday","quarter","day","special_days", "month_no", "increment_year","diff2")
  x.indep <- c("diff","month","year","weekday","quarter","day","special_days", "month_no")
  
  if(MONTH_aux2!=MONTH_aux){
    for(MONTH in c(MONTH_aux,MONTH_aux2) ){
      
      #3. Selecting Best model (from BEST_MODEL.rds)#
      selectedRows <- BEST_MODEL[grep(MONTH, BEST_MODEL$predicted_month_number), ]
      #(if we have more than one model, we will usually use the closest year model, so the last row)
      selectedRows<- selectedRows[nrow(selectedRows),]
      selectedRows
      
      #Train & Test
      #TRAIN:  #in case the window includes more than one year (example: nov18 - feb19) we may need a condition or another
      
      if(selectedRows[,"window_end"]<selectedRows[,"window_start"]){ 
        year_aux0<-as.numeric(time_frame[1,"year"]-1)
        year_aux1<-as.numeric(time_frame[1,"year"])
        train<-time_series %>% filter(year==year_aux0 & month>=as.numeric(selectedRows[,"window_start"]) & month<=12 | year==year_aux1 & month>=1 & month<=as.numeric(selectedRows[,"window_end"]))
      } else{
        year_aux1<-as.numeric(time_frame[1,"year"])
        train<-time_series %>% filter(year==year_aux1 & month>=as.numeric(selectedRows[,"window_start"]) & month<=as.numeric(selectedRows[,"window_end"])) #windowed data
      }
      train.h2o <- as.h2o(train) #Load it with h2o
      
      test<-time_frame %>% filter(month==MONTH) #test data
      test.h2o<-as.h2o(test)
      
      #Random Forest (or any other model)
      model <- h2o.randomForest(y=y.dep, x=x.indep,training_frame = train.h2o, ntrees = 1000, mtries = -1, seed = 123,min_rows = 2, max_depth = 10)
      predict <- as.data.frame(h2o.predict(model, test.h2o))
      
      #FINAL RESULT
      PREDICTION<-rbind(PREDICTION,cbind(test$ds, predict))
    }
  }else {
    #3. Selecting Best model (from BEST_MODEL.rds)#
    selectedRows <- BEST_MODEL[grep(MONTH, BEST_MODEL$Predicted), ]
    #(if we have more than one model, we will usually use the closest year model, so the last row)
    selectedRows<- selectedRows[nrow(selectedRows),]
    #Train & Test
    if(selectedRows[,"window_end"]<selectedRows[,"window_start"]){ 
      year_aux0<-as.numeric(time_frame[1,"year"]-1)
      year_aux1<-as.numeric(time_frame[1,"year"])
      train<-time_series %>% filter(year==year_aux0 & month>=as.numeric(selectedRows[,"window_start"]) & month<=12 | year==year_aux1 & month>=1 & month<=as.numeric(selectedRows[,"window_end"]))
    } else{
      year_aux1<-as.numeric(time_frame[1,"year"])
      train<-time_series %>% filter(year==year_aux1 & month>=as.numeric(selectedRows[,"window_start"]) & month<=as.numeric(selectedRows[,"window_end"])) #windowed data
    }
    test<-time_frame
    train.h2o <- as.h2o(train) #Load it with h2o
    test.h2o<-as.h2o(test)
    #Random Forest (or any other model)
    model <- h2o.randomForest(y=y.dep, x=x.indep,training_frame = train.h2o, ntrees = 1000, mtries = -1, seed = 123,min_rows = 2, max_depth = 10)
    predict <- as.data.frame(h2o.predict(model, test.h2o))
    #FINAL RESULT
    PREDICTION<-cbind(test$ds, predict)
  }
  return(PREDICTION)
}

####Validation to check results in already known months
validation<- time_series[((time_series$day_month %in% time_frame$day_month) & ((time_series$year) %in% time_frame$year)),]
cbind(PREDICTION, validation$y)
postResample(PREDICTION[,2], validation$y)

#OTHER MODELS
#model <- h2o.randomForest(y=y.dep, x=x.indep,training_frame = train.h2o, ntrees = 1000, mtries = -1, seed = 123,min_rows = 2, max_depth = 10)
#model<-h2o.deeplearning(y=y.dep, x=x.indep, training_frame = train.h2o)
#model <- h2o.gbm(y = y.dep, x = x.indep, training_frame = train.h2o, ntrees = 5, max_depth = 4,min_rows = 1,distribution= "poisson")

