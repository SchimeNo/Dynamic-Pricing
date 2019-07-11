Forecasting & Modelling project 

by UBIQUM Data Alaytics team
Sara Marin, Sergi Chimeno, Eloi Cirera

Building a Dynamic Pricing SaaS for Retailers focused on achieving their business objectives through Price Reco. built based on accurate price elasticity measurement through Machine Learning & Experimentation based methods.

Forecast properly the Demand of both Test & Control Group towards the definition of the expected Test
Experiment new models competing with the current one, logistic regression, leveraging Test vs Control experimentation method

---------------------------------------------------------------------

DEMAND FORECASTING

BEFORE STARTING: May need to install and prepare your enviroment for the H2O package. 

for more info visit:
http://rpubs.com/Mentors_Ubiqum/H2O_wifi
---------------------------------------------------------------------
SCRIPTS DESCRIPTION

All scripts should be in a folder called scripts and all data in a folder called datasets.

01_FEATURE_CREATION.R

Contains new_feature function that will create the new features used in our project.

	- DATE Variables: The date has been splitted by YEAR, QUARTER, MONTH, WEEK, WEEKDAY and DAY

	- MONTH_NO: (numeric) feature counting the months. 

	- DIFF: (numeric) increment of y of a day respect the previous day

	- INCREMENT_YEAR: (numeric) increment of y respect the same day from the previous year

	- ROLLMEANS: (numeric) Rolling means Feature (previous 7 days)

	- SPECIAL_DAYS: (logic/binary) feature where 0=NORMAL / 1=SPECIAL DAY
  			1 if the mean of the last 7 days is bigger than 7000 or 
  			the difference between previous day is bigger than 2000

	- HOLIDAYS: (numeric from [0-8]) giving a weight from 0 to 8 according the number of visits)
---------------------------------------------------------------------
02_MODEL_COMPETITION.R

This is the heaviest script, it takes an average of 5 to 10 minutes to run, ideally you will only need to run it every year or 3-6 months to store and check the results of the new data updated. 

INPUT: Time Series of demand (ds, y)

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

OUTPUT:
	- PREDICTION: Time Series data with the predicted demand of that MONTH. (If the time series has not been updated it may give you an error)

---------------------------------------------------------------------
ERRORS THAT MAY HAPPEN:

1-Deppending on your system time the test dataset will start on day 1 or a day before, you may need to change IT on script 3 adding 1 or not to the DAY variable:

		start_date<-strptime(paste(DAY+1, MONTH_aux, YEAR),"%d %m %Y")

2-Trying to predict a very far ahead date will give an error if we haven't loaded the test data (we can predict 2 months ahead max more or less)

For any doubt send an email to: chimewallace@gmail.com

Thanks for reading, 
  