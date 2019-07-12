####0. Libraries and directories####
pacman::p_load(rstudioapi, h2o, dplyr, readr,  zoo,
               lubridate,  caret, stringr, prophet, e1071)
h2o.init()

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

# #to check if the code runs well internally
# DAY=1
# MONTH="Apr"
# YEAR=2019
# model_type = "RF"


####FUNCTION TO PREDICT DEMAND####
demand_prediction<- function(DAY, MONTH, YEAR, model_type){
  
  #0.AUXILIAR VARIABLES
  MONTH_aux<-match(MONTH,month.abb)
  YEAR_aux<-(YEAR-2018)*12
  start_date<-strptime(paste(DAY, MONTH_aux, YEAR),"%d %m %Y") 
  PREDICTION<-data.frame()
  n_future_days<-28 #how many days ahead you want to predict
  
  #1.CREATING EMPTY TEST DATA (time_frame)
  #Time series column with the dates 
  time_frame<-as.data.frame(as.Date(seq(start_date+hours(1), by="day", len=n_future_days))) #WARNING: Deppending on the system time zone might return a start date some hours ahead or below (that's why we add +1 hour in this case)
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
    for(MONTH_Loop in c(MONTH_aux,MONTH_aux2) ){
      
      #3. Selecting Best model (from BEST_MODEL.rds)#
      selectedRows <- BEST_MODEL[grep(MONTH_Loop, BEST_MODEL$predicted_month_number), ]
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
      
      test<-time_frame %>% filter(month==(MONTH_Loop)) #test data
      test.h2o<-as.h2o(test)
      
      #APPLYING MODEL CHOOSEN
      if(model_type=="RF"){
        print("Random Forest")
        model <- h2o.randomForest(y=y.dep, x=x.indep,training_frame = train.h2o, ntrees = 100, mtries = -1, seed = 123, max_depth = 10,min_rows = 2, histogram_type="RoundRobin")
      }else if(model_type=="GBM"){
        print("GBM")
        model <- h2o.gbm(y = y.dep, x = x.indep, training_frame = train.h2o, ntrees = 5,  max_depth = 4,min_rows = 1,
                         distribution= "poisson", histogram_type = "UniformAdaptive")
      }else if(model_type=="DNN"){
        print("DNN")
        model <- h2o.deeplearning(y = y.dep, x = x.indep, training_frame = train.h2o,seed = 123)
      }else if(model_type=="SVM_linear"){
        print("SVM_linear")
        model<- svm(y~., data = train[,c("y",x.indep)],  kernel = "linear", gamma = 1e-05, cost = 10)
      }else if(model_type=="SVM_radial"){
        print("SVM_radial")
        model<- svm(y~., data = train[,c("y",x.indep)],  kernel = "radial", gamma = 1e-05, cost = 10)
      }else if (model_type=="prophet"){
        print("prophet")
        m<-prophet(time_series[,c("ds","y")])
        future <- test[,"ds"]
        forecast <- predict(m, future)
      }
      
      #Prediction (condition for if using h2o or not)
      if(model_type=="SVM_linear"|model_type=="SVM_radial"){
        predict <- predict(model, test)
      }else if(model_type=="prophet"){
        predict<-forecast[,"trend"]
        names(predict)[1]<-"y"
      }else{
        predict <- as.data.frame(h2o.predict(model, test.h2o))
      }
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
    
    
    #APPLYING MODEL CHOOSEN
    if(model_type=="RF"){
      print("Random Forest")
      model <- h2o.randomForest(y=y.dep, x=x.indep,training_frame = train.h2o, ntrees = 100, mtries = -1, seed = 123, max_depth = 10,min_rows = 2, histogram_type="RoundRobin")
    }else if(model_type=="GBM"){
      print("GBM")
      model <- h2o.gbm(y = y.dep, x = x.indep, training_frame = train.h2o, ntrees = 5,  max_depth = 4,min_rows = 1,
                       distribution= "poisson", histogram_type = "UniformAdaptive")
    }else if(model_type=="DNN"){
      print("DNN")
      model <- h2o.deeplearning(y = y.dep, x = x.indep, training_frame = train.h2o,seed = 123)
    }else if(model_type=="SVM_linear"){
      print("SVM_linear")
      model<- svm(y~., data = train[,c("y",x.indep)],  kernel = "linear", gamma = 1e-05, cost = 10)
    }else if(model_type=="SVM_radial"){
      print("SVM_radial")
      model<- svm(y~., data = train[,c("y",x.indep)],  kernel = "radial", gamma = 1e-05, cost = 10)
    }else if (model_type=="prophet"){
      print("prophet")
      m<-prophet(time_series[,c("ds","y")])
      future <- test[,"ds"]
      forecast <- predict(m, future)
    }
    
    #Prediction (condition for if using h2o or not)
    if(model_type=="SVM_linear"|model_type=="SVM_radial"){
      predict <- predict(model, test)
    }else if(model_type=="prophet"){
      predict<-forecast[,"trend"]
      names(predict)[1]<-"y"
    }else{
      predict <- as.data.frame(h2o.predict(model, test.h2o))
    }
    #FINAL RESULT
    PREDICTION<-cbind(test$ds, predict)
    
  }
  
  #validation if we want to check our MAE
  if(MONTH_aux+YEAR_aux<time_series[nrow(time_series),"month_no"]){
    validation<- time_series[((time_series$day_month %in% time_frame$day_month) & ((time_series$year) %in% time_frame$year)),]
    if(nrow(validation)==nrow(PREDICTION)){
      a<-cbind(PREDICTION, validation$y)
      b<-postResample(PREDICTION[,2], validation$y)
      OUTPUT<-list(a,b)
      return(OUTPUT)
    }else{
      print("VALIDATION NOT AVAILABLE (time_series data not available to compare with predicted)")
      return(PREDICTION)
    }
    
  }else{
    return(PREDICTION)
  }
}


# m<-prophet(train[,c("ds","y")])
# future <- time_frame[,"ds"]
# forecast <- predict(m, future)
# predict<-forecast[,"trend"]
# names(predict)[1]<-"y"
# PREDICTION<-cbind(test$ds, predict)

####Validation to check results in already known months
# validation<- time_series[((time_series$day_month %in% time_frame$day_month) & ((time_series$year) %in% time_frame$year)),]
# cbind(PREDICTION, validation$y)
# postResample(PREDICTION[,2], validation$y)

#train<-time_series %>% filter(month_no<16) 
