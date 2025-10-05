require 'spec_helper'

RSpec.describe Rubythinking::Distributions::Normal do
  describe '.density' do
    it 'calculates correct density for standard normal' do
      # Standard normal at x=0 should be 1/sqrt(2π) ≈ 0.3989
      density = Rubythinking::Distributions::Normal.density(0, 0, 1)
      expect(density).to be_within(0.001).of(0.3989)
    end

    it 'calculates correct density for standard normal at x=1' do
      # Standard normal at x=1 should be exp(-0.5)/sqrt(2π) ≈ 0.2420
      density = Rubythinking::Distributions::Normal.density(1, 0, 1)
      expect(density).to be_within(0.001).of(0.2420)
    end

    it 'handles different means' do
      # Normal(5, 1) at x=5 should equal Normal(0, 1) at x=0
      density1 = Rubythinking::Distributions::Normal.density(5, 5, 1)
      density2 = Rubythinking::Distributions::Normal.density(0, 0, 1)
      expect(density1).to be_within(0.001).of(density2)
    end

    it 'handles different standard deviations' do
      # Normal(0, 2) has half the peak height of Normal(0, 1)
      density1 = Rubythinking::Distributions::Normal.density(0, 0, 2)
      density2 = Rubythinking::Distributions::Normal.density(0, 0, 1)
      expect(density1).to be_within(0.001).of(density2 / 2)
    end

    it 'is symmetric around the mean' do
      mean = 3
      std = 2
      distance = 1.5
      x1 = mean - distance
      x2 = mean + distance
      
      density1 = Rubythinking::Distributions::Normal.density(x1, mean, std)
      density2 = Rubythinking::Distributions::Normal.density(x2, mean, std)
      
      expect(density1).to be_within(0.001).of(density2)
    end
  end

  describe '.random' do
    it 'generates different values on subsequent calls' do
      value1 = Rubythinking::Distributions::Normal.random
      value2 = Rubythinking::Distributions::Normal.random
      
      expect(value1).not_to eq(value2)
    end

    it 'generates values around the specified mean' do
      mean = 10
      std = 1
      samples = Array.new(1000) { Rubythinking::Distributions::Normal.random(mean, std) }
      
      sample_mean = samples.sum / samples.length
      expect(sample_mean).to be_within(0.2).of(mean)
    end

    it 'generates values with approximately correct standard deviation' do
      mean = 0
      std = 2
      samples = Array.new(1000) { Rubythinking::Distributions::Normal.random(mean, std) }
      
      sample_mean = samples.sum / samples.length
      sample_variance = samples.map { |x| (x - sample_mean) ** 2 }.sum / (samples.length - 1)
      sample_std = Math.sqrt(sample_variance)
      
      expect(sample_std).to be_within(0.3).of(std)
    end

    it 'uses default parameters when none provided' do
      # Should default to mean=0, std=1
      samples = Array.new(500) { Rubythinking::Distributions::Normal.random }
      sample_mean = samples.sum / samples.length
      
      expect(sample_mean).to be_within(0.3).of(0)
    end
  end

  describe '.samples' do
    it 'returns an array of the requested length' do
      samples = Rubythinking::Distributions::Normal.samples(100)
      expect(samples.length).to eq(100)
    end

    it 'returns empty array when n=0' do
      samples = Rubythinking::Distributions::Normal.samples(0)
      expect(samples).to eq([])
    end

    it 'generates samples with correct mean and standard deviation' do
      mean = 5
      std = 3
      samples = Rubythinking::Distributions::Normal.samples(1000, mean, std)
      
      sample_mean = samples.sum / samples.length
      sample_variance = samples.map { |x| (x - sample_mean) ** 2 }.sum / (samples.length - 1)
      sample_std = Math.sqrt(sample_variance)
      
      expect(sample_mean).to be_within(0.3).of(mean)
      expect(sample_std).to be_within(0.3).of(std)
    end

    it 'uses default parameters when none provided' do
      samples = Rubythinking::Distributions::Normal.samples(100)
      sample_mean = samples.sum / samples.length
      
      expect(sample_mean).to be_within(0.3).of(0)
    end

    it 'generates different samples each time' do
      samples1 = Rubythinking::Distributions::Normal.samples(5)
      samples2 = Rubythinking::Distributions::Normal.samples(5)
      
      expect(samples1).not_to eq(samples2)
    end
  end

  describe 'statistical properties' do
    it 'follows the 68-95-99.7 rule approximately' do
      mean = 0
      std = 1
      samples = Rubythinking::Distributions::Normal.samples(10000, mean, std)
      
      # About 68% should be within 1 standard deviation
      within_1_std = samples.count { |x| (x - mean).abs <= std }
      expect(within_1_std.to_f / samples.length).to be_within(0.05).of(0.68)
      
      # About 95% should be within 2 standard deviations
      within_2_std = samples.count { |x| (x - mean).abs <= 2 * std }
      expect(within_2_std.to_f / samples.length).to be_within(0.05).of(0.95)
    end
  end
end

RSpec.describe 'R-like API for Normal distribution' do
  include Rubythinking

  describe 'dnorm' do
    it 'calculates normal density' do
      density = dnorm(0, mean: 0, sd: 1)
      expect(density).to be_within(0.001).of(0.3989)
    end

    it 'uses default parameters' do
      density1 = dnorm(0)
      density2 = dnorm(0, mean: 0, sd: 1)
      expect(density1).to eq(density2)
    end

    it 'handles named parameters' do
      density = dnorm(1, mean: 2, sd: 0.5)
      expected = Rubythinking::Distributions::Normal.density(1, 2, 0.5)
      expect(density).to eq(expected)
    end
  end

  describe 'rnorm' do
    it 'generates normal random samples' do
      samples = rnorm(100)
      expect(samples.length).to eq(100)
      expect(samples).to be_an(Array)
      expect(samples.first).to be_a(Numeric)
    end

    it 'uses default parameters' do
      samples = rnorm(50)
      sample_mean = samples.sum / samples.length
      expect(sample_mean).to be_within(0.5).of(0)
    end

    it 'handles named parameters' do
      mean = 10
      sd = 2
      samples = rnorm(500, mean: mean, sd: sd)
      sample_mean = samples.sum / samples.length
      expect(sample_mean).to be_within(0.5).of(mean)
    end

    it 'matches direct class method call' do
      srand(42)  # Set seed for reproducibility
      samples1 = rnorm(10, mean: 5, sd: 2)
      
      srand(42)  # Reset seed
      samples2 = Rubythinking::Distributions::Normal.samples(10, 5, 2)
      
      expect(samples1).to eq(samples2)
    end
  end

  describe 'integration with existing API' do
    it 'works alongside existing distribution functions' do
      # Test that both binomial and normal APIs work together
      binom_samples = rbinom(10, size: 5, prob: 0.5)
      normal_samples = rnorm(10, mean: 0, sd: 1)
      
      expect(binom_samples.length).to eq(10)
      expect(normal_samples.length).to eq(10)
      expect(binom_samples.all? { |x| x.is_a?(Integer) }).to be true
      expect(normal_samples.all? { |x| x.is_a?(Float) }).to be true
    end
  end
end