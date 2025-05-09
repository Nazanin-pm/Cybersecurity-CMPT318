# Cybersecurity-CMPT318
# 🔍 Anomaly Detection in Electric Energy Consumption using PCA and HMM


**Instructor:** Dr. Uwe Glaesser  

**Members:**  
- Nazanin Pouria Mehr 
- Simon Yu 
- Calvin Weng   
- Tin Liang  


---

## 📌 Overview

This project applies anomaly detection techniques to electric energy consumption data using **Principal Component Analysis (PCA)** and **Hidden Markov Models (HMM)**. The goal is to detect irregular consumption patterns that may indicate system faults or cyber threats in smart grid control systems.

We leverage PCA for dimensionality reduction and feature selection, and train HMMs on time-series data to model normal patterns and detect deviations.

---

## 📂 Table of Contents

- [Problem Statement](#problem-statement)  
- [Feature Scaling](#feature-scaling)  
- [Feature Engineering](#feature-engineering)  
- [HMM Training and Testing](#hmm-training-and-testing)  
- [Log-Likelihood Analysis](#log-likelihood-analysis)  
- [Anomaly Detection](#anomaly-detection)  
- [Anomaly Injection](#anomaly-injection)  
- [Conclusion](#conclusion)  
- [References](#references)

---

## ⚠️ Problem Statement

Supervisory control systems for electric grids generate large volumes of data. Anomalies in this data can signal operational faults or malicious activity. This project aims to detect these anomalies through PCA-based feature reduction and HMM-based time-series modeling.

---

## ⚙️ Feature Scaling

To ensure balanced model training, all features were standardized (mean = 0, std = 1), which is more effective than normalization in handling outliers and aligning with the probabilistic assumptions of HMMs.

---

## 🛠️ Feature Engineering

- Applied PCA to identify high-variance contributors.
- Selected features: `Global_reactive_power` and `Global_intensity`.
- Confirmed via scree plot and explained variance ratios.

---

## 🧪 HMM Training and Testing

- Data filtered for **Wednesday 5–7 AM**, a low-variance, regular time window.
- Trained HMMs with 4–20 states using `depmixS4` in R.
- Evaluated using log-likelihood and BIC.
- **10-state model** performed best, balancing accuracy and generalization.

---

## 📈 Log-Likelihood Analysis

- Compared normalized log-likelihood across 10 test subsets.
- Defined ±8.46 as a deviation threshold from training log-likelihood.
- All subsets fell within this range, indicating consistent model performance.

---

## 🚨 Anomaly Detection

- Detected no true anomalies in clean test data.
- Subset 2 showed mild deviation; subset 7 most closely matched training data.
- Graphs confirm model reliability in distinguishing normal behavior.

---

## 🧨 Anomaly Injection

- Simulated faults:
  - Spikes in `global_active_power`
  - Missing `voltage` values
  - Increased `global_intensity`
- Resulted in significant log-likelihood deviations, proving model effectiveness.

---

## ✅ Conclusion

This project:
- Showcased the effectiveness of PCA + HMM in anomaly detection.
- Reinforced skills in time-series analysis, feature engineering, and probabilistic modeling.
- Laid a solid foundation for deploying real-time anomaly detectors in smart grid systems.

---

## 📚 References

1. Shaibu, S. (2024). *Normalization vs. Standardization*. DataCamp.  
2. Dixon et al. (2005). *Reactive Power Compensation Technologies*. IEEE.  
3. Baum et al. (1970). *Statistical Analysis of Markov Chains*. AMS.  
4. Rabiner, L. R. (1989). *Tutorial on Hidden Markov Models*. IEEE.

---

## 🙏 Acknowledgements

Special thanks to **Dr. Uwe Glaesser** for his guidance and feedback throughout this project.

