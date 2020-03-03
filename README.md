DYNAMIC PRICING PROJECT
-
by Sergi Chimeno, Eloi Cirera, Sara Marín 
  
--------------------------------------------------------------------
DESCRIPTION: 

Predicting the number of visits (demand) from a webstie or ecommerce for the next 28 days, having a dataset only of Date and Number of visits.

Part1: Demand forecast from a time series using RandomForest and other regression models instead of time series due having a not long enough data. 
   
---------------------------------------------------------------------
BEFORE STARTING

May need to install and prepare your enviroment for the H2O package.

for more info visit:

http://rpubs.com/Mentors_Ubiqum/H2O_wifi

---------------------------------------------------------------------
SCRIPTS DESCRIPTION

All scripts should be in a folder called scripts and all data in a folder called datasets.

---------------------------------------------------------------------
01_FEATURE_CREATION.R

Contains new_feature function that will create the new features used in our project (new features may be added in a future).
	
	- DATE Variables: The date has been splitted by YEAR, QUARTER, MONTH, WEEK, WEEKDAY and DAY
	- MONTH_NO: (numeric) feature counting the months. 
	- DIFF: (numeric) increment of y of a day respect the previous day
	- INCREMENT_YEAR: (numeric) increment of y respect the same day from the previous year
	- ROLLMEANS: (numeric) Rolling means Feature (previous 7 days)
	- SPECIAL_DAYS: (logic/binary) feature where 0=NORMAL / 1=SPECIAL DAY
		1 if the mean of the last 7 days is bigger than 7000 or 
		the difference between previous day is bigger than 2000
	- HOLIDAYS: (numeric from [0-8]) giving a weight from 0 to 8 according the number of visits)

NOTE: Some features cannot be used as predictors (like diff, increment_year or Rollmeans) if it's not a dynamic prediction (using the predicted to create new values), therefore have not been included in the model, but they were left here to help understand the behaviour of the data.

---------------------------------------------------------------------
02_MODEL_COMPETITION.R

This is the heaviest script, it takes an average of 5 to 10 minutes to run, ideally you will only need to run it every year or 3-6 months to store and check the results of the new data updated.

INPUT: 	

	Time Series of demand (ds, y)

OUTPUT:

	- Results.rds: List that stores the results of all the models
	- BEST_MODEL.rds: Dataframe with the optimal window model by month 

DESCRIPTION:
Contains two for loops that trains the model deppending on the MONTH WE WANT TO PREDICT and the WINDOW OF MONTHS we used to train it.
For example:  to predict February 19  it tries all combinations possible and BEST_MODEL stores the best one (with the lowest  MAE)

The script has the option of easily changing the model (Random Forest, GBM, SVM or any other models you would like to try, careful because the code may change if you are using the H2O package or not). DEFAULT MODEL USED IN THIS SCRIPT IS RANDOM FOREST.

---------------------------------------------------------------------
03_DEMAND_PREDICTION_FUNCTION.R


Function that uses our optimal model (Random forest) to predict the following 28 days with the BEST_MODEL training window. 

INPUT:  
	- Time Series of demand (ds, y) (from 01-01-2018 to current date)
	- BEST_MODEL.rds 
	- new_feature.R script 
	- DAY (numeric): The starting day you want the 28 day prediction to start.
	- MONTH (character): Manually put the specific month you want to predict.
	- YEAR (numeric): Manually put the year you want to predict.
	
First it will create an empty time series for the predicted month. 
Then it will look at the BEST_RESULT dataset to see which window of months work better, it will specify the window and then apply the model.
It should return a time series with the demand by day.

---------------------------------------------------------------------

04_DEFINITIVE_MODEL.R

This should be the main script used to predict the following 28 days.
Loads all the previous scripts and functions.

INPUT:

	- DAY (numeric): The starting day you want the 28-day prediction to start. 
	- MONTH (character): Manually put the specific month you want to predict. 
	- YEAR (numeric): Manually put the year you want to predict.
	- model_type (character): Select the model yo want to use for the prediction. 
		Models Included currently:
			"RF": Random Forest (h2o package)
			"XRT": Extreme Random Forest (h2o package)
			"GBM": Gradient Boosting Machine (h2o package) 
			"SVM_linear": Support Vector Machine linear kernel (e1071 package)
			"SVM_radial": Support Vector Machine radial kernel (e1071 package)
			"DNN": Deeplearning (h2o package)
			"prophet": Facebook's prophet forecasting (prophet package)
			

OUTPUT: 
	
	- PREDICTION: Time Series data with the predicted demand of the following 28 days. (If the time series has not been updated it may give you an error)

---------------------------------------------------------------------
ERRORS THAT MAY HAPPEN:
  
1-Deppending on the system time zone, the predicted 28-day script 3 might return a start date some hours ahead or below (that's why we add +1 hour in this case)

				time_frame<-as.data.frame(as.Date(seq(start_date+hours(1), by="day", len=n_future_days)))
				
2-Trying to predict a very far ahead date will give an error if time series hasn't been updated (we can predict 2 months ahead more or less)

3- When using SMV or models not included in the H2O package the Date format may get changed to default.

---------------------------------------------------------------------
For any doubts, email: chimewallace@gmail.com

Thanks for reading.

