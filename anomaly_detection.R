library(lubridate)
library(depmixS4)
library(ggplot2)

# load the R data file
load("RData")

# access the best performing model
bestmodel <- stats[[6]][[2]]  

#split into 10 subsets
total_rows <- nrow(testing_set)
num_groups <- 10
rows_per_group <- floor(total_rows / num_groups) 
extra_rows <- total_rows %% num_groups          

group_numbers <- rep(1:num_groups, each = rows_per_group)
group_numbers <- c(group_numbers, rep(num_groups, extra_rows))  

testing_set$Group <- group_numbers

test_subsets <- split(testing_set, testing_set$Group)


# function to calculate log likelihood
get_log_likelihood <- function(fit_model, subset_data, nstates) {
  subset_model <- depmix(response = list(Global_intensity ~ 1, Global_reactive_power ~ 1),
                         data = subset_data,
                         nstates = nstates,
                         family = list(multinomial(), multinomial()),
                         transition = ~1)
  
  # copy fitted parameters from the trained model
  subset_model <- setpars(subset_model, getpars(fit_model)[1:subset_model@npars])
  
  subset_fb <- forwardbackward(subset_model)
  
  return(subset_fb$logLik / nrow(subset_data))
}

#ITERATE OVER SUBSETS

nstates <- bestmodel@nstates

# calculate log-likelihood for each subset
log_likelihoods <- sapply(test_subsets, function(subset) {
  get_log_likelihood(bestmodel, subset, nstates)
})

print(log_likelihoods)


# DEFINE THRESHOLD FOR ANOMALOUS BEHAVIOR
nstates <- bestmodel@nstates  

# calculate log-likelihood for training set
training_logLik <- get_log_likelihood(bestmodel, training_set, nstates)



# max deviation from training loglik is threshold
deviations <- abs(log_likelihoods - training_logLik)

threshold <- max(deviations)

# plot log likelihood results
results_df <- data.frame(
  Subset = seq_along(log_likelihoods),
  LogLikelihood = log_likelihoods
)

ggplot(results_df, aes(x = Subset, y = LogLikelihood)) +
  geom_point(size = 3) +
  geom_line() +
  # lower anomaly threshold
  geom_hline(yintercept = (training_logLik - threshold), 
             linetype = "dashed", color = "red") +  
  # upper anomaly threshold
  geom_hline(yintercept = (training_logLik + threshold), 
             linetype = "dashed", color = "red") +  
  labs(title = "Log-Likelihoods of Test Subsets", x = "Subset", y = "Log-Likelihood") +
  theme_minimal()



