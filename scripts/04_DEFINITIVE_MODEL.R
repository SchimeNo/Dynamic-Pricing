####0. Libraries and directories####
pacman::p_load(rstudioapi, h2o, dplyr, readr,  zoo,
               lubridate,  caret, stringr, e1071)

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


#load the new feature Script and demand_prediction
source("./scripts/01_FEATURE_CREATION_for_PricingHub.R")
source("./scripts/03_DEMAND_PREDICTION_FUNCTION_for_PricingHub.R")
#New Features
time_series<-new_features(time_series) #Need to run Script 01_Feature_Creation


#CHOOSE YEAR & MONTH TO PREDICT (DAY:numeric, MONTH:character, YEAR:numeric, model_type: character)
#MONTH (01:Jan 02:Feb 03:Mar 04:Apr 05:May 06:Jun 07:Jul 08:Aug 09:Sep 10:Oct 11:Nov 12:Dec)
#model_type ("RF","GBM", "SVM_linear", "SVM_radial", "DNN" (deeplearning), "prophet")



#########################################
PREDICTION<-demand_prediction(DAY=15, MONTH="Mar", YEAR=2019, model_type = "GBM")
#########################################

#PREDICTION


####MODEL COMPETITION only working for Months where we have data####
mo<-c("RF","GBM", "SVM_linear", "SVM_radial", "DNN", "prophet")
metrics2<-data.frame()
for(i in 1:length(mo)){
  
  model<-mo[i]
  PREDICTION<-demand_prediction(DAY=15, MONTH="Sep", YEAR=2019, model_type = model)
  aux<-cbind(paste0(model),as.data.frame(t(PREDICTION[[2]])))
  metrics2<-rbind(metrics2,aux)
  
}

PREDICTION


