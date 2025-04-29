# Import Libraries --------------------------------------------------------
library(dplyr)
library(lubridate)
library(hms)
library(zoo)
library(ggplot2)
library(ggbiplot)
library(depmixS4)
library(future.apply)

# Set-up parallelization
plan(multisession)

# Import Data -------------------------------------------------------------
df = read.csv("TermProjectData.txt", header = TRUE)

# Add a date+time column
df <- df %>%
  mutate(DateTime = dmy_hms(sprintf("%s %s", Date, Time)), .before = Date)
  
# Data Pre-processing (Standardization) ------------------------------------
# Get names of data columns
data_cols <- colnames(df[, 4:ncol(df)])

# Perform Extreme Outlier Cleaning, Standardization and Linear Interpolation
df <- df %>%
  mutate(across(all_of(data_cols), ~scale(.x))) %>%
  mutate(across(all_of(data_cols), ~ifelse(abs(.x) <= 3, .x ,NA))) %>%
  mutate(across(all_of(data_cols), ~na.approx(.x, na.rm = FALSE, rule = 2)))

# Feature Engineering -----------------------------------------------------
# Compute PCA
df.pca = prcomp(df[data_cols])
summary(df.pca)

# Make scree plot of PCA (run df.pca.scree in console to show plot)
df.pca.scree <- ggscreeplot(df.pca)
ggsave("pca.scree.png", plot = df.pca.scree)

# Make PCA biplot (run df.pca.biplot in console to show plot)
df.pca.biplot <- ggbiplot(df.pca,
                          choices = c(1, 2),
                          groups = df$DateTime,
                          point.size = 1,
                          circle = TRUE,
                          varname.size = 4,
                          varname.color = "red") + 
  labs(fill = "DateTime", color = "DateTime")
ggsave("pca.biplot.png", plot = df.pca.biplot)
# From PCA, features Global_reactive_power, Global_intensity
# were selected for further training
  
# HMM Training and Testing ------------------------------------------------
# Time window selection

# Define a time window
weekday <- 3
start_time <- as_hms("05:00:00") 
end_time <- as_hms("07:00:00")

get_time_window <- function(.data) {
  .data %>% 
    filter(wday(DateTime) == weekday) %>%
    filter(between(as_hms(DateTime), start_time, end_time))
}

ggtimewindowplot <- function(.data, y) {
  .data %>%
    filter(week(DateTime) < 10 & year(DateTime) == 2007) %>%
    ggplot(mapping = aes(x = as_hms(DateTime), y = {{y}})) +
      geom_point(mapping = aes(group = week(DateTime), color = week(DateTime) * (year(DateTime) - 2006))) +
      stat_summary(aes(group = 1), fun.y=mean, colour="red", geom="line",group=1)
}

# There's nearly 3 years of data, so use 2 years for training and remaining
# for testing dataset, filtered by time window
training_set <- df %>%
  filter(between(DateTime, ymd("2006-12-16"), ymd("2008-12-16"))) %>%
  get_time_window()

testing_set <- df %>%
  filter(DateTime > ymd("2008-12-16")) %>%
  get_time_window()

# Plot a few weeks in training set to visualize trend for time window selection
global_reactive_plot <- training_set %>% ggtimewindowplot(Global_reactive_power)
global_reactive_plot

global_intensity_plot <- training_set %>% ggtimewindowplot(Global_intensity)
global_intensity_plot

# Train HMM
set.seed(3)
time_period <- as.numeric(difftime(end_time, start_time, units = "mins")) + 1
testing_set.ntimes <- rep(time_period, each = 52)
training_set.ntimes <- rep(time_period, each = 104)
coeff <- 1

# Define Model Training Function
hmm <- function(data, nstate) {
  model <- depmix(response = list(Global_intensity ~ 1, Global_reactive_power ~ 1),
                  data = data,
                  nstates = nstate,
                  family = list(multinomial(), multinomial()),
                  ntimes = training_set.ntimes)
  fit_model = fit(model, emcontrol = em.control(maxit = 600))
  print(BIC(fit_model)) # Print BIC to get rough idea of performance while training
  return(list(nstate = nstate, model = fit_model, logLik = logLik(fit_model), BIC = BIC(fit_model)))
}

# Define Plotting Function
plot_loglik_bic <- function(data, plot_name) {
  ggplot(data = data, mapping = aes(x = nstate)) +
    geom_line(mapping = aes(y = logLik, color = "Log-Liklihood")) +
    geom_point(mapping = aes(y = logLik, color = "Log-Liklihood")) +
    geom_line(mapping = aes(y = BIC / coeff, color = "BIC")) +
    geom_point(mapping = aes(y = BIC / coeff, color = "BIC")) +
    scale_y_continuous(name = "Value", breaks = scales::pretty_breaks(n = 10)) +
    labs(color = "Metrics", n.breaks = 10) 
  ggsave(filename = paste(plot_name, "train.png", sep = "_"), dpi = 600)
}

discrete <- function(data, to_nearest) {
  return(round(data / to_nearest) * to_nearest)
}

ggdensityplot <- function(data, x) {
  ggplot(data, aes(x = {{x}})) +
    geom_histogram(aes(y = after_stat(density)), color="grey", fill = "white", bins = 30) +
    geom_density(mapping = aes({{x}}, color = "Continuous")) +
    geom_density(mapping = aes(discrete({{x}}, 0.5), color = "Discrete (0.5)"), linetype = 'dashed') +
    geom_density(mapping = aes(discrete({{x}}, 0.35), color = "Discrete (0.33)"), linetype = 'dashed') +
    geom_density(mapping = aes(discrete({{x}}, 0.25), color = "Discrete (0.25)"), linetype = 'dashed') +
    geom_density(mapping = aes(discrete({{x}}, 0.10), color = "Discrete (0.10)"), linetype = 'dashed') +
    theme(legend.position = 'bottom', legend.title = element_blank())
}

# Plot the densities of the training features
ggdensityplot(training_set, Global_reactive_power)
ggdensityplot(training_set, Global_intensity)
  
# Discretize features which aren't normally distributed by rounding
training_set <- training_set %>%
  mutate(Global_reactive_power = discrete(Global_reactive_power, 0.25)) %>%
  mutate(Global_intensity = discrete(Global_intensity, 0.25))

# Define number of states to train on
results <- data.frame(nstate = c(4, 5, 6, 7, 8, 10, 12, 14, 16, 18, 20))

# Train HMM on above nstates
stats <- future_apply(results, 1, function(row) hmm(training_set, row[1]), future.seed = TRUE)
#stats <- apply(results, 1, function(row) hmm(training_set, row[1]))

# Get and plot the training log-likelihoods and BICs
results <- cbind(results, logLik = sapply(stats, `[[`, 3), BIC = sapply(stats, `[[`, 4))
plot_loglik_bic(results, "hmm")

# From training, 10 states seems to be enough, so fit on test data with params
test_model <- depmix(response = list(Global_intensity ~ 1, Global_reactive_power ~ 1),
                     data = testing_set,
                     nstate = 10,
                     family = list(multinomial(), multinomial()),
                     ntimes = testing_set.ntimes)
test_model <- setpars(test_model, getpars(stats[[6]][[2]]))
test_fit <- fit(test_model)

# Get log-likelihood and BIC on test data
test_fit.logLik <- logLik(test_fit)
test_Fit.BIC <- BIC(test_fit)
