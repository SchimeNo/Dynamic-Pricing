####0. Libraries and directories####
pacman::p_load(rstudioapi, h2o, dplyr, readr,  zoo,
               lubridate,  caret, stringr)

h2o.init() #start h2o


#setting up directory
current_path=getActiveDocumentContext()$path
setwd(dirname(current_path))
setwd("..")
rm(current_path)
list.files("datasets/")

#Load data (Time Series from 01-01-2018 to now)
time_series<-read_csv("./datasets/time_series_clean.csv")


#### 1.Creating new features####

#load the new feature Script
source("./scripts/01_FEATURE_CREATION_for_PricingHub.R")
time_series<-new_features(time_series) 

####2. N MONTH WINDOW MODELS ####
#dependent variable y (visits)
y.dep <- "y"
# independent variables 
x.indep <- c("ds","diff","holidays","month","year","week","weekday","quarter","day","special_days", "month_no", "increment_year") 

list1<-list()  #empty list that will store the results
aux<-1 #auxiliar variable

#For loop that tries the n-months for training (fom 1 to 12)
system.time(for (n in 0:12){
  
  #set the window limit to n 
  window<-max(time_series$month_no)-n-1
  #Initialize results matrix
  result2 <- data.frame(matrix(nrow = 5, ncol = 9))
  colnames(result2) <- c("Predicted", "Window", "RMSE", "Rsquared", "MAE", "Cumulative_Error", "predicted_month_number", "window_start", "window_end")
  
  #FOR Loop that predicts the specific month m (starting from month nº2 to last month available on the dataset) #
  for (m in 1:window){
    month1<-m
    month2<-m+n
    month3<-month2+1
    train<-time_series %>% filter(month_no>=month1 & month_no<=month2) #windowed data
    validation<- time_series %>% filter(month_no==month3) #1 month
    
    train.h2o <- as.h2o(train) #Load it with h2o
    validation.h2o <- as.h2o(validation) #Load it with h2o
    
    #APPLY THE MODEL comment and uncomment if you want to try different models (GBM, SVM...)
    
    #RANDOM FOREST (Best model)
    model <- h2o.randomForest(y=y.dep, x=x.indep, training_frame = train.h2o, stopping_rounds = 2, 
                                                  ntrees = 100, mtries = -1, seed = 123,min_rows = 10, validation_frame= validation.h2o)
    
    #GBM
    #model <- h2o.gbm(y = y.dep, x = x.indep, training_frame = train.h2o, ntrees = 5,  max_depth = 4,min_rows = 1, distribution= "poisson")
    
    #SVM (not using H2O packacge therefore the predict command will be different too)
    #svm.model<- svm(y~., data = train[,c(3,2:10)],  kernel = "linear", gamma = 1e-05, cost = 10)
    #predict.svm <- predict(svm.model, validation)
    
    #prediction
    predict <- as.data.frame(h2o.predict(model, validation.h2o))
    
    #storing the metrics
    maux0<-paste0(month.abb[as.numeric(validation[1,"month"])], validation[1,"year"])
    maux1<-paste0(month.abb[as.numeric(train[1,"month"])], train[1,"year"])
    maux2<-paste0(month.abb[as.numeric(train[nrow(train),"month"])], train[nrow(train),"year"])
    metrics2<-postResample(predict, validation$y)
    cumulative2<- sum(abs(validation$y - predict))
    result2[m, 1] <- maux0
    result2[m, 2] <- paste0(maux1,"-",maux2)
    result2[m, 3] <- metrics2[1]
    result2[m, 4] <- metrics2[2]
    result2[m, 5] <- metrics2[3]
    result2[m, 6] <- cumulative2
    result2[m, 7] <- validation[1,"month"]
    result2[m, 8] <- train[1,"month"]
    result2[m, 9] <- train[nrow(train),"month"]
    
  }
  #storing the metrics on a list 
  list1[[aux]]<-result2
  print(result2)
  aux<-aux+1
})

#SAVE the results in a list
saveRDS(list1, file = "./datasets/Results.rds") 

#LOAD the stored list
#listRF<-readRDS("./datasets/Results.rds")

#### 3.EXTRACTING THE OPTIMAL RESULT (Lowest MAE) FOR EACH MONTH####
df_aux<-bind_rows(list1)
BEST_MODEL<- df_aux %>% group_by(Predicted) %>% slice(which.min(MAE))
BEST_MODEL

#remove auxiliar variables
rm(list = c('df_aux','predict', 'train', 'validation' ))

#SAVE the BEST_MODEL list
saveRDS(BEST_MODEL, file = "./datasets/BEST_MODEL.rds") 










