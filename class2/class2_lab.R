# Class 2 Lab Materials

# Required packages
library(tidyverse)
library(modelr)
library(nycflights13)
library(lubridate)
library(glmnet)

#####################
## 1st Lab
#####################

# Data that comes with tidyverse
data(sim1)

# Lets look at it
View(sim1)

# Remember how to plot from last session?
ggplot(sim1, aes(x, y)) + 
  geom_point()

# Lets fit it
# R formula
# y = c + m * x
# y ~ 1 + x

mod <- lm(y~1+x, sim1)
mod <- lm(y~x, sim1) # same as above line

mod
# y = 4.221 + 2.052 x

# plot it
grid <- data.frame(x=-10:10) %>% add_predictions(mod)

#grid <- sim1 %>% 
#  data_grid(x) %>%
#  add_predictions(mod)

grid %>% ggplot(aes(x=x,y=pred)) + geom_line()

ggplot(sim1, aes(x = x)) +
  geom_point(aes(y = y)) +
  geom_line(aes(y = pred), data = grid, colour = "red", size = 1)


# BONUS: pack this as a function
plot_prediction <- function(mod, data){
  grid <- data %>% 
    data_grid(x) %>%
    add_predictions(mod)
  ggplot(data, aes(x)) +
    geom_point(aes(y = y)) +
    geom_line(aes(y = pred), data = grid, colour = "red", size = 1) 
}


###################
# 2nd Lab session
###################

# Practice a bit on transformation
# Load the data
library(readr)
my_data <- read_rds("./my_data.rds")

# Look at what's inside
my_data %>% head()
my_data %>% ggplot(aes(x,y)) + geom_point()



# Try x^2 first
mod1 <- lm(y~x+I(x^2), my_data)
plot_prediction(mod1, my_data)
plot(fitted(mod1), resid(mod1))

# Perhaps without intercept?
mod2 <- lm(y~-1+I(x^2), my_data)
plot_prediction(mod2, my_data)
plot(fitted(mod2), resid(mod2))


# Secondary school maths
# y = c + a x^b
# log(y) = log( a * x^b)
#        = log(a) + b * log(x)
# log(y) = log(a) + b * log(x)
my_log_data <- my_data %>% mutate(y=log(y))
mod3 <- lm(y~log(x), my_log_data)
coef(mod3)
plot_prediction(mod3, my_log_data)


#######################
# Categorical Variable
data(sim2)

View(sim2)

# look at what that x is
str(sim2)

ggplot(sim2) + 
  geom_point(aes(x, y))

# Multiple indicator function
mod2 <- lm(y ~ x, data = sim2)
coef(mod2)

# Review the model matrix
model.matrix(y~x, data=sim2) %>% View()

grid <- sim2 %>% 
  data_grid(x) %>% 
  add_predictions(mod2)

ggplot(sim2, aes(x)) + 
  geom_point(aes(y = y)) +
  geom_point(data = grid, aes(y = pred), colour = "red", size = 4)



###############################
# Log transformation - Diamond dataset 
###############################
# http://r4ds.had.co.nz/model-building.html#diamond-prices

# Diamon price dataset from ggplot package
data(diamonds)
diamonds %>% ggplot(aes(x=carat, y=price)) + 
  geom_hex(bins = 50)


install.packages("plotly")
library(plotly)
diamonds %>% ggplot(aes(x=carat, y=price)) + 
  geom_hex(bins = 50) -> my_plot
ggplotly(my_plot)


# Secondary school maths
# y = a x^b
# log(y) = log(a) + b * log(x)
diamonds2 <- diamonds %>% 
  mutate(lprice = log2(price), lcarat = log2(carat))

diamonds2 %>% ggplot(aes(lcarat, lprice)) + geom_hex(bins=50)

##########################
# 3rd Lab Session
##########################

# Fight overfitting

# first simulate some simple data 
n <- 80 # sample size
hk_r_user_data <- tibble(x = runif(n),
                          y = 10 *x + rnorm(n)
                          )

hk_r_user_data %>% View()
# plot it
hk_r_user_data %>% ggplot(aes(x=x, y=y)) + geom_point()

data_with_random_bits <- hk_r_user_data %>%
  mutate(z1=runif(nrow(hk_r_user_data)),
         z2=runif(nrow(hk_r_user_data)),
         z3=runif(nrow(hk_r_user_data)),
         z4=runif(nrow(hk_r_user_data)),
         z5=runif(nrow(hk_r_user_data)),
         z6=runif(nrow(hk_r_user_data)),
         z7=runif(nrow(hk_r_user_data)),
         z8=runif(nrow(hk_r_user_data)),
         z9=runif(nrow(hk_r_user_data)),
         z10=runif(nrow(hk_r_user_data))
  )
data_with_random_bits %>% View()
mod_overfit <- lm(y~. , data=data_with_random_bits)

# Cross validatation
# https://drsimonj.svbtle.com/k-fold-cross-validation-with-modelr-and-broom
std_fold <- data_with_random_bits %>% crossv_kfold(k=5) 

std_fold %>%
  mutate(model= map(train, ~lm(y~x, data=.))) %>%
  mutate(rmse_test = map2_dbl(model, test, rmse)) %>%
  mutate(rmse_train = map2_dbl(model, train, rmse)) %>%
  summarise(mean(rmse_test), mean(rmse_train)) # Lower error

std_fold %>%
  mutate(model= map(train, ~lm(y~., data=.))) %>%
  mutate(rmse_test = map2_dbl(model, test, rmse),
         rmse_train = map2_dbl(model, train, rmse)
         ) %>% 
  summarise(mean(rmse_test), mean(rmse_train)) # Lower error


# Penalized regression to the rescue

library(glmnet)
?cv.glmnet

my_glmnet_fitting <- function(in_data){
  in_data <- as.data.frame(in_data)
  x <- in_data %>% select(-y) %>% as.matrix()
  y <- as.double(in_data$y)
  cv.glmnet(x=x, 
            y=y, 
            nfolds=5)
}

my_rmse <- function(model, data){
  data <- as.data.frame(data)
  y_pred <- (predict(model, 
                     data %>% as.data.frame() %>% select(-y) %>% as.matrix(),
                     s="lambda.min"))
  print(y_pred)
  print(data$y)
  sqrt(mean((y_pred- data$y)^2))
}

# L1 (LASSO) penalization
std_fold %>%
  mutate(model= map(train, my_glmnet_fitting)) %>%
  mutate(rmse_test = map2_dbl(model, test, my_rmse)) %>%
  summarise(mean(rmse_test))


# alpha=0, L2 penalization
my_glmnet_fitting2 <- function(in_data){
  in_data <- as.data.frame(in_data)
  x <- in_data %>% select(-y) %>% as.matrix()
  y <- as.double(in_data$y)
  cv.glmnet(x=x, 
            y=y, 
            nfolds=5, alpha=0)
}

std_fold %>%
  mutate(model= map(train, my_glmnet_fitting2)) %>%
  mutate(rmse = map2_dbl(model, test, my_rmse)) %>%
  summarise(mean(rmse))


##########################
# Hands on time
##########################
# Example taken from 
# https://github.com/hadley/r4ds/blob/master/model-building.Rmd
data(flights)

daily <- flights %>% 
  mutate(date = make_date(year, month, day)) %>% 
  group_by(date) %>% 
  summarise(n = n())

daily %>% ggplot(aes(x=date, y=n)) + geom_line()


# Feature Engineering
daily <- daily %>% 
  mutate(wday = wday(date, label = TRUE))

ggplot(daily, aes(wday, n)) + 
  geom_boxplot()

mod <- lm(n ~ wday, data = daily)

grid <- daily %>% 
  data_grid(wday) %>% 
  add_predictions(mod, "n")

ggplot(daily, aes(wday, n)) + 
  geom_boxplot() +
  geom_point(data = grid, colour = "red", size = 4)


daily <- daily %>% 
  add_residuals(mod)

# What can you spot here?
daily %>% 
  ggplot(aes(date, resid)) + 
  geom_ref_line(h = 0) + 
  geom_line()


# Stronger week of day pattern

week_of_day_plot <- ggplot(daily, aes(date, resid, colour = wday)) + 
  geom_ref_line(h = 0) + 
  geom_line() 
week_of_day_plot

# BONUS: plotly
library(plotly)
ggplotly(week_of_day_plot)

# Holiday effect?
daily %>%
  filter(resid < -100)

# longer term pattern
daily %>% 
  ggplot(aes(date, resid)) + 
  geom_ref_line(h = 0) + 
  geom_line(colour = "grey50") + 
  geom_smooth(se = FALSE, span = 0.20)


term <- function(date) {
  cut(date, 
      breaks = ymd(20130101, 20130605, 20130825, 20140101),
      labels = c("spring", "summer", "fall") 
  )
}

daily <- daily %>% 
  mutate(term = term(date)) 


mod1 <- lm(n ~ wday, data = daily)
mod2 <- lm(n ~ wday * term, data = daily)

daily %>% 
  gather_residuals(without_term = mod1, with_term = mod2) %>% 
  ggplot(aes(date, resid, colour = model)) +
  geom_line(alpha = 0.75)


grid <- daily %>% 
  data_grid(wday, term) %>% 
  add_predictions(mod2, "n")

ggplot(daily, aes(wday, n)) +
  geom_boxplot() + 
  geom_point(data = grid, colour = "red") + 
  facet_wrap(~ term)

mod3 <- MASS::rlm(n ~ wday * term, data = daily)

daily %>% 
  add_residuals(mod3, "resid") %>% 
  ggplot(aes(date, resid)) + 
  geom_hline(yintercept = 0, size = 2, colour = "white") + 
  geom_line()

coef(mod3)


