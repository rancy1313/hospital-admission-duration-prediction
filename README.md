# hospital-admission-duration-prediction
Predicting hospital admission durations using random forest regression on critical care data to improve healthcare resource allocation. Analyzes demographic, clinical, and admission data to identify key factors influencing length of stay.

## Project Overview
This project analyzes a large critical care database to predict hospital admission duration using random forest regression models. The goal is to develop accurate predictions that could help hospitals optimize resource allocation, improve bed management, and enhance patient care through better planning.

## Business Problem
Healthcare systems constantly face pressure from high congestion and could benefit from optimized resource allocation. Accurately predicting how long patients will stay in the hospital can:
- Allow rooms to be prepared earlier for incoming patients
- Enable more efficient staff scheduling
- Provide patients with clearer estimates of their stay
- Potentially reduce the length of hospital stays
- Ease strain on emergency departments

## Data Source
The analysis uses a public critical care dataset containing de-identified patient information from a hospital in Boston, Massachusetts. The data includes:
- Demographic information
- Vital signs
- Procedures and diagnoses
- Medication information
- Admission details

Due to data quality issues, the analysis created multiple derived datasets:
- Base dataset (544,190 observations)
- Vitals subset (89,669 observations)
- Blood pressure subset (48,928 observations)
- Procedures subset (162,992 observations)

## Methodology
1. **Data Preparation**:
   - Loaded data into PostgreSQL for transformation
   - Engineered features like medication delays, procedure counts, and readmission status
   - Aggregated categorical features to reduce dimensionality
   - Applied One-Hot Encoding for categorical variables
   - Removed outliers and data entry errors using Z-scores and domain-specific thresholds
   - Split data into training and test sets

2. **Modeling**:
   - Implemented Random Forest Regression models
   - Tuned hyperparameters using GridSearchCV with 3-fold cross-validation
   - Evaluated using RMSE and R-squared metrics
   - Analyzed feature importance to identify key predictors

3. **Feature Reduction**:
   - Applied a 1% feature importance threshold
   - Reduced feature set by approximately 75%
   - Compared performance between initial and reduced feature sets

## Key Findings
- The vitals model achieved the best performance with a test RMSE of ~50 hours (2.1 days)
- This represents a 44% improvement over the baseline model
- The model explained 72% of the variance in admission duration (R-squared = 0.72)
- Key predictors of admission duration included:
  - Number of medications ordered (most important feature)
  - Diagnosis severity
  - Number of diagnoses
  - Patient age
  - Number of procedures

## Limitations
- The model was trained on data from a single hospital, limiting generalizability
- Some overfitting remained even after feature reduction
- The RMSE of 50 hours is still a substantial margin of error
- Direction of prediction errors (over vs. under-prediction) was not analyzed
- The model cannot extrapolate beyond the range of training data

## Recommendations
1. **Optimize database structure** for more efficient data preparation and better feature quality
2. **Analyze medication regimens** in greater depth to understand their relationship with length of stay
3. **Integrate multi-institution data** to build more generalizable models

## Technologies Used
- PostgreSQL and pgAdmin for data transformation
- Python for analysis and modeling
- Pandas for data manipulation
- Scikit-learn for machine learning models
- Matplotlib and Seaborn for visualization

## Future Work
Future research could focus on:
- Incorporating specific medication types and combinations
- Exploring the direction of prediction errors
- Developing separate models for different admission types
- Including hospital congestion metrics
- Validating the model across multiple healthcare institutions

## Repository Structure

This repository contains the following files:

- **Capstone_Report.pdf**: Comprehensive technical report detailing the full analysis process and results
- **Executive_Summary.pdf**: Concise summary of key findings and recommendations
- **Capstone_Presentation.pdf**: Slides used to present this project
- **Capstone_Code.ipynb**: Jupyter notebook containing all Python code for the analysis
- **Capstone_Code.html**: HTML export of the notebook for easier viewing
- **Capstone_DataPrep_SQL.sql**: SQL scripts used to extract and prepare the data from the original database

---

*Note: This analysis was conducted for educational purposes and not for clinical decision-making.*
