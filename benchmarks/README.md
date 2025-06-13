# IRT Ruby Performance Benchmarks

This directory contains comprehensive performance benchmarks for the IRT Ruby gem, helping users understand the computational characteristics and scaling behavior of the different IRT models.

## Available Benchmarks

### 1. Performance Benchmark (`performance_benchmark.rb`)

**Purpose**: Comprehensive performance analysis across different dataset sizes and model types.

**What it measures**:
- Execution time (iterations per second) for Rasch, 2PL, and 3PL models
- Memory usage analysis (allocated/retained objects and memory)
- Scaling behavior analysis (how performance changes with dataset size)
- Impact of missing data strategies on performance

**Dataset sizes tested**:
- Tiny: 10 people × 5 items (50 data points)
- Small: 50 people × 20 items (1,000 data points)
- Medium: 100 people × 50 items (5,000 data points)
- Large: 200 people × 100 items (20,000 data points)
- XLarge: 500 people × 200 items (100,000 data points)

### 2. Convergence Benchmark (`convergence_benchmark.rb`)

**Purpose**: Detailed analysis of convergence behavior and optimization characteristics.

**What it measures**:
- Impact of tolerance settings on convergence time and success rate
- Learning rate optimization analysis
- Dataset characteristics impact on convergence
- Missing data pattern effects on convergence

**Key insights provided**:
- Optimal hyperparameter settings for different scenarios
- Convergence reliability across different conditions
- Trade-offs between speed and accuracy

## Running the Benchmarks

### Prerequisites

Install benchmark dependencies:
```bash
bundle install
```

### Running Individual Benchmarks

```bash
# Full performance benchmark suite (takes 5-10 minutes)
ruby benchmarks/performance_benchmark.rb

# Convergence analysis (takes 3-5 minutes)
ruby benchmarks/convergence_benchmark.rb
```

### Running All Benchmarks

```bash
# Run both benchmark suites
ruby benchmarks/performance_benchmark.rb && ruby benchmarks/convergence_benchmark.rb
```

## Understanding the Results

### Performance Benchmark Output

1. **Iterations per Second (IPS)**: Higher is better
   - Shows relative speed between Rasch, 2PL, and 3PL models
   - Includes confidence intervals and comparison ratios

2. **Memory Usage**:
   - Total allocated: Memory used during computation
   - Total retained: Memory still held after computation
   - Object counts: Number of Ruby objects created

3. **Scaling Analysis**:
   - Shows computational complexity (O(n^x))
   - Helps predict performance for larger datasets

### Convergence Benchmark Output

1. **Convergence Rate**: Percentage of runs that converged within tolerance
2. **Average Iterations**: Typical number of iterations needed
3. **Time**: Wall-clock time to convergence

## Interpreting Results for Your Use Case

### For Educational Assessment (typical: 100-1000 students, 20-100 items)
- Focus on Medium to Large dataset results
- Rasch model typically fastest, 3PL slowest but most flexible
- Missing data strategies have < 10% performance impact

### For Psychological Testing (typical: 50-500 participants, 10-50 items)
- Focus on Small to Medium dataset results
- All models should complete in < 1 second
- Consider convergence reliability for different tolerance settings

### For Large-Scale Analysis (1000+ participants)
- Review XLarge dataset results and scaling analysis
- Consider batching or parallel processing for very large datasets
- Monitor memory usage to avoid system limits

## Customizing Benchmarks

You can modify the benchmark scripts to test your specific scenarios:

1. **Custom Dataset Sizes**: Edit `DATASET_CONFIGS` array
2. **Different Hyperparameters**: Modify tolerance, learning rate configs
3. **Specific Missing Data Patterns**: Adjust missing data generation
4. **Model-Specific Tests**: Focus on particular IRT models

## Performance Tips

Based on benchmark results:

1. **Choose the Right Model**: Rasch is fastest, use 2PL/3PL only when needed
2. **Optimize Tolerance**: `1e-5` typically good balance of speed/accuracy
3. **Adjust Learning Rate**: Start with `0.01`, increase for faster convergence
4. **Handle Missing Data**: `:ignore` strategy typically fastest
5. **Consider Iteration Limits**: 100-500 iterations usually sufficient

## Comparing with Other IRT Libraries

These benchmarks can help you compare IRT Ruby against other implementations. Key metrics to compare:

- Time per data point processed
- Memory efficiency
- Convergence reliability
- Scaling behavior with dataset size

---

*Note: Benchmark results will vary based on your hardware. Run benchmarks on your target deployment environment for most accurate performance estimates.* 