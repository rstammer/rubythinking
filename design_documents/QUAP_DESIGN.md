# Quap Design Specification

## Formula Specification Format

### Basic Syntax
Formulas are specified as string arrays where each string represents a statistical relationship:

```ruby
formulas = [
  'y ~ normal(mu, sigma)',     # likelihood
  'mu ~ normal(0, 10)',        # prior for mu
  'sigma ~ exponential(1)'     # prior for sigma
]
```

### Supported Distributions

#### Continuous Distributions
- `normal(mean, sd)` - Normal distribution
- `exponential(rate)` - Exponential distribution  
- `uniform(min, max)` - Uniform distribution
- `gamma(shape, rate)` - Gamma distribution
- `beta(alpha, beta)` - Beta distribution

#### Discrete Distributions  
- `binomial(n, p)` - Binomial distribution
- `poisson(lambda)` - Poisson distribution

### Linear Model Syntax
For linear relationships, use arithmetic expressions:

```ruby
formulas = [
  'weight ~ normal(mu, sigma)',
  'mu ~ a + b * height',        # linear relationship
  'a ~ normal(0, 50)',
  'b ~ normal(0, 10)', 
  'sigma ~ exponential(1)'
]
```

### Variable References
- Data variables: Reference columns in the data hash/dataframe
- Parameters: Automatically detected when used in formulas
- Transformations: Support log(), exp(), sqrt() functions

```ruby
formulas = [
  'log_y ~ normal(mu, sigma)',
  'mu ~ a + b * log(x)',
  'a ~ normal(0, 1)',
  'b ~ normal(0, 1)',
  'sigma ~ exponential(1)'
]
```

## Object-Oriented Design

### Quap Object as the Approximation

The `Quap` object represents the quadratic approximation itself. It follows a two-phase lifecycle:

1. **Initialization**: Define the model structure and validate inputs
2. **Estimation**: Perform optimization and populate results

```ruby
# Create Quap object (validates but doesn't estimate)
quap = Rubythinking::Quap.new(
  formulas: formulas,
  data: data,
  start: start_values  # optional
)

# Perform estimation (returns self for chaining)
quap.estimate

# Access results (only available after estimation)
quap.coef            # => { 'mu' => 1.5, 'sigma' => 0.8 }
quap.vcov            # => Matrix[[0.1, 0.01], [0.01, 0.05]]
quap.se              # => { 'mu' => 0.316, 'sigma' => 0.224 }
quap.summary         # => Formatted table string
quap.samples(n: 1000) # => { 'mu' => [1.4, 1.6, ...], 'sigma' => [0.7, 0.9, ...] }
quap.loglik          # => -12.34
quap.npar            # => 2
quap.aic             # => 28.68
```

### Object State Management

```ruby
# State checking
quap.estimated?      # => false initially, true after .estimate

# Error handling for premature access
quap.coef           # raises NotEstimatedError before estimation

# Method chaining support
summary = Rubythinking::Quap.new(formulas: formulas, data: data)
            .estimate
            .summary
```

### Constructor Parameters

```ruby
Rubythinking::Quap.new(
  formulas: Array,     # required - array of formula strings
  data: Hash,          # required - data hash with symbol/string keys
  start: Hash          # optional - starting values for optimization
)
```

### Estimation Method

```ruby
# Simple estimation - uses Nelder-Mead optimization internally
quap.estimate
```

## Example Use Cases

### Case 1: Simple Parameter Estimation
```ruby
# Estimate mean and variance of data
data = { y: [1.2, 1.8, 0.9, 2.1, 1.5] }

formulas = [
  'y ~ normal(mu, sigma)',
  'mu ~ normal(0, 10)',
  'sigma ~ exponential(1)'
]

quap = Rubythinking::Quap.new(formulas: formulas, data: data)
         .estimate

puts quap.summary
```

### Case 2: Linear Regression with Method Chaining
```ruby
# Height-weight relationship
data = {
  height: [150, 160, 170, 180, 190],
  weight: [50, 60, 70, 80, 90]
}

formulas = [
  'weight ~ normal(mu, sigma)',
  'mu ~ a + b * height',
  'a ~ normal(0, 50)',
  'b ~ normal(0, 10)',
  'sigma ~ exponential(1)'
]

# Fluent interface
samples = Rubythinking::Quap.new(formulas: formulas, data: data)
            .estimate
            .samples(n: 4000, seed: 42)
```

### Case 3: Logistic Regression with Inspection
```ruby
# Binary outcome model
data = {
  admit: [1, 0, 1, 0, 1],
  gre: [800, 600, 700, 500, 750]
}

formulas = [
  'admit ~ binomial(1, p)',
  'logit(p) ~ a + b * gre',
  'a ~ normal(0, 5)',
  'b ~ normal(0, 1)'
]

quap = Rubythinking::Quap.new(formulas: formulas, data: data)

# Check model before estimation
puts "Parameters: #{quap.parameter_names}"
puts "Data variables: #{quap.data_variables}"

# Estimate and inspect
quap.estimate
puts "Converged: #{quap.converged?}"
puts "AIC: #{quap.aic}"
```

### Case 4: Reusable Objects with Different Start Values
```ruby
# Create model template
base_quap = Rubythinking::Quap.new(formulas: formulas, data: data)

# Try different starting points
results = []
[{mu: 0, sigma: 1}, {mu: 2, sigma: 0.5}].each do |start_vals|
  quap = Rubythinking::Quap.new(formulas: formulas, data: data, start: start_vals)
  quap.estimate
  results << { start: start_vals, loglik: quap.loglik, aic: quap.aic }
end

best = results.max_by { |r| r[:loglik] }
puts "Best model: #{best}"
```

## Implementation Notes

### Error Handling
- `InvalidFormulaError`: Malformed formula syntax
- `MissingDataError`: Referenced data variables not found
- `NotEstimatedError`: Accessing results before calling .estimate
- `ConvergenceError`: Optimization failed to converge
- `InvalidStartError`: Start values incompatible with model

### Optimization Method
- Uses **Nelder-Mead simplex** algorithm (derivative-free)
- Robust for statistical optimization problems
- Available in Ruby's built-in optimization libraries
- Good balance of simplicity and effectiveness

### Performance Considerations  
- Use efficient matrix operations for linear algebra
- Cache parsed formulas for repeated calls
- Nelder-Mead is slower than gradient methods but more robust

### R Compatibility
- Maintain similar API to R's `quap()` function
- Support similar formula syntax where possible
- Provide comparable output format