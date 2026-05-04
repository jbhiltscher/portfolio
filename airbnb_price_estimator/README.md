# Airbnb Price Estimator

A machine learning project that predicts Airbnb listing prices using an XGBoost regression model.

## Overview

This project builds a price prediction model for Airbnb listings. Given a set of listing attributes—such as host information, location, availability, and review scores—the model estimates the nightly price. Predictions are output as a `submission.csv` file, following a Kaggle-style competition format.

## Project Structure

```
airbnb_price_estimator/
├── data/
│   ├── train.csv       # Training data with listing features and prices
│   └── test.csv        # Test data for generating predictions
├── mini-project-1_xgboost.ipynb  # Main notebook with full pipeline
└── README.md
```

## Features Used

The model is trained on the following features selected from the raw data:

| Feature | Description |
|---|---|
| `host_is_superhost` | Whether the host is a Superhost (boolean) |
| `host_has_profile_pic` | Whether the host has a profile picture (boolean) |
| `host_identity_verified` | Whether the host's identity is verified (boolean) |
| `host_since_days` | Number of days since the host joined (derived from `host_since`) |
| `latitude` / `longitude` | Geographic coordinates, binned into 50 buckets each |
| `accommodates` | Maximum number of guests |
| `beds` | Number of beds |
| `minimum_nights` / `maximum_nights` | Stay length constraints |
| `has_availability` | Whether the listing is available (boolean) |
| `availability_30/60/90/365` | Number of available days in each window |
| `number_of_reviews` | Total review count |
| `review_scores_rating` | Average review score |
| `instant_bookable` | Whether the listing can be booked instantly (boolean) |
| `number_of_reviews_ltm` | Reviews in the last 12 months |
| `number_of_reviews_l30d` | Reviews in the last 30 days |

## Preprocessing Pipeline

1. **Date engineering** — `host_since` is converted to the number of days elapsed before 2024-01-01.
2. **Boolean encoding** — Boolean columns (`t`/`f`) are mapped to `1`/`0`.
3. **Correlation filtering** — Features with absolute correlation to `price` below 0.03 are noted (informational).
4. **Geographic binning** — Latitude and longitude are discretized into 50 equal-width bins, consistent across train and test sets.
5. **Missing value imputation** — Remaining NaN values are filled with column means.
6. **Feature scaling** — Continuous numerical features are standardized using `StandardScaler`.
7. **Log transformation** — The target variable (`price`) is log-transformed before training to reduce skewness; predictions are exponentiated back to the original scale.

## Model

An **XGBoost Regressor** is trained on the preprocessed data with the following hyperparameters:

| Parameter | Value |
|---|---|
| `colsample_bytree` | 0.5 |
| `learning_rate` | 0.05 |
| `max_depth` | 12 |
| `n_estimators` | 400 |

## Output

The notebook writes predictions to `submission.csv` with two columns:

| Column | Description |
|---|---|
| `Id` | Listing identifier from the test set |
| `price` | Predicted nightly price (in original dollar scale) |

## Dependencies

- Python 3.x
- `pandas`
- `numpy`
- `scikit-learn`
- `xgboost`
- `matplotlib`

Install dependencies with:

```bash
pip install pandas numpy scikit-learn xgboost matplotlib
```

## Usage

1. Place `train.csv` and `test.csv` in the `data/` directory.
2. Open and run `mini-project-1_xgboost.ipynb` end-to-end.
3. The predicted prices will be saved to `submission.csv` in the project root.
