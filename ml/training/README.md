# CommuteTimely CoreML Model Training Pipeline

This directory contains scripts and documentation for training and converting the leave-time prediction model to CoreML format.

## Overview

The CommuteTimely ML model predicts optimal leave times based on:
- Route characteristics (distance, baseline duration, traffic)
- Weather conditions (precipitation, visibility, temperature)
- Temporal features (hour of day, day of week)
- Historical user behavior (optional)

## Model Architecture

### Recommended Approach: Gradient Boosting

We recommend using **LightGBM** or **XGBoost** for this task because:
- Excellent performance on tabular data
- Fast inference (critical for mobile)
- Small model size (< 10 MB)
- Good interpretability
- Handles missing values well

### Alternative: Neural Network

For more complex patterns, a small feedforward neural network (2-3 layers, 64-128 units) can work, but may be overkill for this problem.

## Feature Engineering

### Input Features (15 total)

**Route Features (5)**
1. `distance` - Route distance in meters (normalized by 1000)
2. `baseline_duration` - Normal travel time in seconds (normalized by 600)
3. `traffic_delay` - Current traffic delay in seconds (normalized by 600)
4. `incident_count` - Number of incidents (0-10)
5. `congestion_level` - Congestion level (0-4, one-hot encoded)

**Weather Features (6)**
6. `temperature` - Temperature in Celsius (normalized by 30)
7. `precipitation_prob` - Precipitation probability (0-100, normalized by 100)
8. `visibility` - Visibility in km (normalized by 20)
9. `wind_speed` - Wind speed in m/s (normalized by 20)
10. `weather_score` - Overall weather score (0-100, normalized by 100)
11. `weather_impact` - Categorical weather impact (0-4, one-hot encoded)

**Temporal Features (4)**
12. `hour_of_day` - Hour (0-23, cyclical encoding: sin/cos)
13. `day_of_week` - Day (0-6, one-hot encoded)
14. `is_weekend` - Boolean (0/1)
15. `time_until_arrival` - Hours until arrival (normalized by 12)

### Target Variable

**Regression Target**: `minutes_before_arrival` - How many minutes before arrival time the user should leave

**Classification Target** (alternative): Discretized into bins (e.g., "leave now", "15-30 min", "30-60 min", "1-2 hours")

## Training Data Schema

### CSV Format

```csv
trip_id,timestamp,user_id,origin_lat,origin_lon,dest_lat,dest_lon,arrival_time,actual_leave_time,actual_arrival_time,distance,baseline_duration,traffic_delay,incident_count,congestion_level,temperature,precipitation_prob,visibility,wind_speed,weather_score,arrived_on_time
1,2024-01-15T08:00:00Z,user_abc,37.7749,-122.4194,37.8044,-122.2712,2024-01-15T09:00:00Z,2024-01-15T08:32:00Z,2024-01-15T08:59:30Z,15000,1200,180,1,2,22.0,20.0,10.0,5.5,85.0,1
2,2024-01-15T17:30:00Z,user_xyz,37.8044,-122.2712,37.7749,-122.4194,2024-01-15T18:30:00Z,2024-01-15T17:55:00Z,2024-01-15T18:28:00Z,15000,1200,420,3,3,18.0,60.0,8.0,8.2,65.0,1
...
```

### Required Fields

- **trip_id**: Unique trip identifier
- **timestamp**: When prediction was made
- **user_id**: Anonymized user ID
- **origin_lat, origin_lon**: Start coordinates
- **dest_lat, dest_lon**: Destination coordinates
- **arrival_time**: Target arrival time
- **actual_leave_time**: When user actually left
- **actual_arrival_time**: When user actually arrived
- **distance**: Route distance (meters)
- **baseline_duration**: Normal travel time (seconds)
- **traffic_delay**: Traffic delay at prediction time (seconds)
- **incident_count**: Number of traffic incidents
- **congestion_level**: Traffic congestion (0-4)
- **temperature**: Temperature (Celsius)
- **precipitation_prob**: Rain probability (%)
- **visibility**: Visibility (km)
- **wind_speed**: Wind speed (m/s)
- **weather_score**: Weather quality (0-100)
- **arrived_on_time**: Whether user arrived on time (1/0)

## Training Pipeline

### Step 1: Data Collection

```python
# collect_data.py
import pandas as pd
import requests
from datetime import datetime

# Collect historical trip data from your backend
# This should include actual leave times and arrival times
# along with traffic/weather conditions at prediction time

def collect_trip_data(start_date, end_date):
    # Query your database for historical trips
    trips = query_database(start_date, end_date)
    
    # Enrich with actual traffic/weather at the time
    enriched_trips = []
    for trip in trips:
        traffic = get_historical_traffic(trip.route, trip.timestamp)
        weather = get_historical_weather(trip.location, trip.timestamp)
        enriched_trips.append({
            **trip,
            **traffic,
            **weather
        })
    
    return pd.DataFrame(enriched_trips)

# Save to CSV
df = collect_trip_data('2024-01-01', '2024-11-01')
df.to_csv('training_data.csv', index=False)
```

### Step 2: Feature Engineering

```python
# feature_engineering.py
import pandas as pd
import numpy as np

def engineer_features(df):
    # Calculate target: minutes user left before arrival time
    df['actual_travel_time'] = (
        pd.to_datetime(df['actual_arrival_time']) - 
        pd.to_datetime(df['actual_leave_time'])
    ).dt.total_seconds() / 60
    
    df['minutes_before_arrival'] = (
        pd.to_datetime(df['arrival_time']) - 
        pd.to_datetime(df['actual_leave_time'])
    ).dt.total_seconds() / 60
    
    # Normalize continuous features
    df['distance_norm'] = df['distance'] / 1000
    df['duration_norm'] = df['baseline_duration'] / 600
    df['traffic_norm'] = df['traffic_delay'] / 600
    df['temp_norm'] = df['temperature'] / 30
    df['precip_norm'] = df['precipitation_prob'] / 100
    df['vis_norm'] = df['visibility'] / 20
    df['wind_norm'] = df['wind_speed'] / 20
    df['weather_norm'] = df['weather_score'] / 100
    
    # Temporal features
    df['arrival_dt'] = pd.to_datetime(df['arrival_time'])
    df['hour'] = df['arrival_dt'].dt.hour
    df['day_of_week'] = df['arrival_dt'].dt.dayofweek
    df['is_weekend'] = (df['day_of_week'] >= 5).astype(int)
    
    # Cyclical encoding for hour
    df['hour_sin'] = np.sin(2 * np.pi * df['hour'] / 24)
    df['hour_cos'] = np.cos(2 * np.pi * df['hour'] / 24)
    
    # One-hot encode categorical
    df = pd.get_dummies(df, columns=['congestion_level', 'day_of_week'])
    
    return df

df = pd.read_csv('training_data.csv')
df_features = engineer_features(df)
df_features.to_csv('training_data_features.csv', index=False)
```

### Step 3: Train Model (LightGBM)

```python
# train_model.py
import lightgbm as lgb
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_absolute_error, r2_score
import joblib

# Load data
df = pd.read_csv('training_data_features.csv')

# Select features
feature_cols = [
    'distance_norm', 'duration_norm', 'traffic_norm', 'incident_count',
    'temp_norm', 'precip_norm', 'vis_norm', 'wind_norm', 'weather_norm',
    'hour_sin', 'hour_cos', 'is_weekend'
] + [col for col in df.columns if col.startswith('congestion_level_') or col.startswith('day_of_week_')]

X = df[feature_cols]
y = df['minutes_before_arrival']

# Split data
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42
)

# Train LightGBM model
params = {
    'objective': 'regression',
    'metric': 'mae',
    'boosting_type': 'gbdt',
    'num_leaves': 31,
    'learning_rate': 0.05,
    'feature_fraction': 0.9,
    'bagging_fraction': 0.8,
    'bagging_freq': 5,
    'verbose': 0
}

train_data = lgb.Dataset(X_train, label=y_train)
val_data = lgb.Dataset(X_test, label=y_test, reference=train_data)

model = lgb.train(
    params,
    train_data,
    num_boost_round=1000,
    valid_sets=[val_data],
    callbacks=[lgb.early_stopping(stopping_rounds=50)]
)

# Evaluate
y_pred = model.predict(X_test)
mae = mean_absolute_error(y_test, y_pred)
r2 = r2_score(y_test, y_pred)

print(f"Mean Absolute Error: {mae:.2f} minutes")
print(f"R² Score: {r2:.3f}")

# Save model
joblib.dump(model, 'leave_time_model.pkl')
joblib.dump(feature_cols, 'feature_columns.pkl')
print("Model saved!")
```

### Step 4: Convert to CoreML

```python
# convert_to_coreml.py
import coremltools as ct
import lightgbm as lgb
import joblib
import pandas as pd

# Load trained model
model = joblib.load('leave_time_model.pkl')
feature_cols = joblib.load('feature_columns.pkl')

# Create dummy input for conversion
dummy_input = pd.DataFrame([[0.0] * len(feature_cols)], columns=feature_cols)

# Convert to CoreML
coreml_model = ct.converters.lightgbm.convert(
    model,
    feature_names=feature_cols,
    target='minutes_before_arrival'
)

# Add metadata
coreml_model.author = 'CommuteTimely ML Team'
coreml_model.short_description = 'Predicts optimal leave time in minutes before arrival'
coreml_model.version = '1.0.0'

# Add input descriptions
for feature in feature_cols:
    coreml_model.input_description[feature] = f'Normalized {feature}'

coreml_model.output_description['minutes_before_arrival'] = 'Minutes to leave before arrival time'

# Save CoreML model
coreml_model.save('LeaveTimePredictor.mlmodel')
print("CoreML model saved!")

# Test inference
import coremltools.models as ct_models
loaded_model = ct_models.MLModel('LeaveTimePredictor.mlmodel')
test_input = {col: 0.5 for col in feature_cols}
prediction = loaded_model.predict(test_input)
print(f"Test prediction: {prediction}")
```

### Step 5: Add to Xcode Project

1. Drag `LeaveTimePredictor.mlmodel` into Xcode project
2. Xcode will auto-generate Swift classes
3. Use in `MLPredictionService.swift`:

```swift
import CoreML

func loadCoreMLModel() {
    do {
        let config = MLModelConfiguration()
        self.coreMLModel = try LeaveTimePredictor(configuration: config).model
    } catch {
        print("Failed to load CoreML model: \(error)")
    }
}

func predictWithCoreML(features: [String: Double]) throws -> Double {
    guard let model = coreMLModel else {
        throw MLError.modelNotLoaded
    }
    
    let input = LeaveTimePredictorInput(
        distance_norm: features["distance_norm"] ?? 0,
        duration_norm: features["duration_norm"] ?? 0,
        traffic_norm: features["traffic_norm"] ?? 0,
        // ... other features
    )
    
    let output = try model.prediction(from: input)
    return output.minutes_before_arrival
}
```

## Model Evaluation Metrics

Track these metrics to evaluate model performance:

1. **MAE (Mean Absolute Error)**: Average prediction error in minutes
   - Target: < 5 minutes

2. **RMSE (Root Mean Square Error)**: Penalizes large errors
   - Target: < 8 minutes

3. **On-Time Arrival Rate**: % of users who arrived on time using predictions
   - Target: > 85%

4. **Confidence Calibration**: Does predicted confidence match actual accuracy?
   - Plot calibration curve

5. **User Satisfaction**: Subjective feedback
   - Survey users regularly

## Retraining Schedule

- **Weekly**: Update with latest trip data
- **Monthly**: Full model retraining with hyperparameter tuning
- **Quarterly**: Evaluate model architecture changes

## Deployment

1. Train model locally or on cloud (AWS SageMaker, Google Cloud AI)
2. Convert to CoreML
3. Test thoroughly on device
4. Bundle with app or download on first launch
5. Implement A/B testing for model versions

## Dependencies

```bash
pip install pandas numpy scikit-learn lightgbm coremltools joblib
```

## References

- [LightGBM Documentation](https://lightgbm.readthedocs.io/)
- [CoreML Tools](https://coremltools.readme.io/)
- [Apple CoreML Documentation](https://developer.apple.com/documentation/coreml)

