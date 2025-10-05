require 'spec_helper'

RSpec.describe Rubythinking::Quap do
  describe '#initialize' do
    let(:formulas) do
      [
        'y ~ normal(mu, sigma)',
        'mu ~ normal(0, 10)', 
        'sigma ~ exponential(1)'
      ]
    end

    let(:data) { {y: [-1, 1, 0.5, -0.3, 2.1]} }

    it 'creates a Quap object without estimating' do
      quap = Rubythinking::Quap.new(formulas: formulas, data: data)
      expect(quap).to be_a(Rubythinking::Quap)
      expect(quap.estimated?).to be false
    end

    it 'accepts optional start values' do
      start_values = {mu: 2.0, sigma: 0.5}
      quap = Rubythinking::Quap.new(formulas: formulas, data: data, start: start_values)
      expect(quap.start).to eq(start_values)
    end

    it 'validates formulas on initialization' do
      invalid_formulas = ['y ~ invalid_distribution()']
      
      expect {
        Rubythinking::Quap.new(formulas: invalid_formulas, data: data)
      }.to raise_error(Rubythinking::InvalidFormulaError)
    end

    it 'validates data availability on initialization' do
      formulas = ['y ~ normal(mu, sigma)', 'mu ~ normal(0, 1)']
      data = {x: [1, 2, 3]} # y is missing
      
      expect {
        Rubythinking::Quap.new(formulas: formulas, data: data)
      }.to raise_error(Rubythinking::MissingDataError)
    end
  end

  describe '#estimate' do
    context 'simple normal model' do
      let(:data) { { y: [-1, 1, 0.5, -0.3, 2.1] } }
      
      let(:formulas) do
        [
          'y ~ normal(mu, sigma)',
          'mu ~ normal(0, 10)', 
          'sigma ~ exponential(1)'
        ]
      end

      it 'returns self after estimation' do
        quap = Rubythinking::Quap.new(formulas: formulas, data: data)
        result = quap.estimate
        expect(result).to be(quap)
        expect(quap.estimated?).to be true
      end

      it 'estimates reasonable parameter values' do
        quap = Rubythinking::Quap.new(formulas: formulas, data: data).estimate
        
        # mu should be close to sample mean
        expect(quap.coef['mu']).to be_within(0.5).of(data[:y].sum.to_f / data[:y].length)
        
        # sigma should be positive
        expect(quap.coef['sigma']).to be > 0
      end

      it 'provides variance-covariance matrix' do
        quap = Rubythinking::Quap.new(formulas: formulas, data: data).estimate
        
        expect(quap.vcov).to be_a(Matrix)
        expect(quap.vcov.row_count).to eq(2) # mu, sigma
        expect(quap.vcov.column_count).to eq(2)
      end

      it 'provides parameter standard errors' do
        quap = Rubythinking::Quap.new(formulas: formulas, data: data).estimate
        
        expect(quap.se['mu']).to be > 0
        expect(quap.se['sigma']).to be > 0
      end

      it 'raises error when accessing results before estimation' do
        quap = Rubythinking::Quap.new(formulas: formulas, data: data)
        
        expect { quap.coef }.to raise_error(Rubythinking::NotEstimatedError)
        expect { quap.vcov }.to raise_error(Rubythinking::NotEstimatedError)
        expect { quap.se }.to raise_error(Rubythinking::NotEstimatedError)
      end
    end

    context 'linear regression model' do
      let(:data) do
        {
          height: [150, 160, 170, 180, 190],
          weight: [50, 60, 70, 80, 90]
        }
      end

      let(:formulas) do
        [
          'weight ~ normal(mu, sigma)',
          'mu ~ a + b * height',
          'a ~ normal(0, 50)',
          'b ~ normal(0, 10)',
          'sigma ~ exponential(1)'
        ]
      end

      it 'estimates linear relationship parameters' do
        quap = Rubythinking::Quap.new(formulas: formulas, data: data).estimate
        
        expect(quap.coef['a']).to be_a(Numeric)
        expect(quap.coef['b']).to be > 0 # positive relationship
        expect(quap.coef['sigma']).to be > 0
      end

      it 'has correct number of parameters' do
        quap = Rubythinking::Quap.new(formulas: formulas, data: data).estimate
        
        expect(quap.coef.keys).to contain_exactly('a', 'b', 'sigma')
      end
    end

    context 'method chaining' do
      let(:data) { { y: [1, 2, 3] } }
      let(:formulas) { ['y ~ normal(mu, sigma)', 'mu ~ normal(0, 1)', 'sigma ~ exponential(1)'] }

      it 'allows fluent interface' do
        summary = Rubythinking::Quap.new(formulas: formulas, data: data)
                    .estimate
                    .summary
        
        expect(summary).to be_a(String)
        expect(summary).to include('mu')
        expect(summary).to include('sigma')
      end
    end

    context 'estimation options' do
      let(:data) { { y: [1, 2, 3] } }
      let(:formulas) { ['y ~ normal(mu, sigma)', 'mu ~ normal(0, 1)', 'sigma ~ exponential(1)'] }

      it 'uses default optimization method' do
        quap = Rubythinking::Quap.new(formulas: formulas, data: data)
        
        expect { quap.estimate }.not_to raise_error
        expect(quap.estimated?).to be true
      end
    end
  end

  describe 'result methods' do
    let(:data) { { y: [1.5, 1.8, 0.9, 2.1, 1.5] } }
    let(:formulas) { ['y ~ normal(mu, sigma)', 'mu ~ normal(0, 10)', 'sigma ~ exponential(1)'] }
    let(:quap) { Rubythinking::Quap.new(formulas: formulas, data: data).estimate }

    describe '#coef' do
      it 'returns parameter estimates' do
        expect(quap.coef).to be_a(Hash)
        expect(quap.coef.keys).to include('mu', 'sigma')
      end
    end

    describe '#vcov' do
      it 'returns variance-covariance matrix' do
        expect(quap.vcov).to be_a(Matrix)
      end
    end

    describe '#se' do
      it 'returns standard errors from diagonal of vcov' do
        expect(quap.se).to be_a(Hash)
        expect(quap.se['mu']).to be > 0
        expect(quap.se['sigma']).to be > 0
      end
    end

    describe '#summary' do
      it 'returns formatted parameter summary' do
        summary = quap.summary
        
        expect(summary).to include('mu')
        expect(summary).to include('sigma')
        expect(summary).to include(quap.coef['mu'].to_s)
        expect(summary).to include(quap.coef['sigma'].to_s)
      end
    end

    describe '#samples' do
      it 'generates samples from quadratic approximation' do
        samples = quap.samples(n: 1000)
        
        expect(samples).to be_a(Hash)
        expect(samples['mu'].length).to eq(1000)
        expect(samples['sigma'].length).to eq(1000)
        
        # Check that samples are roughly centered on estimates
        expect(samples['mu'].sum / 1000.0).to be_within(0.2).of(quap.coef['mu'])
      end

      it 'accepts seed for reproducibility' do
        samples1 = quap.samples(n: 100, seed: 42)
        samples2 = quap.samples(n: 100, seed: 42)
        
        expect(samples1['mu']).to eq(samples2['mu'])
        expect(samples1['sigma']).to eq(samples2['sigma'])
      end
    end

    describe '#loglik' do
      it 'returns log-likelihood at MAP estimate' do
        expect(quap.loglik).to be_a(Numeric)
      end
    end

    describe '#npar' do
      it 'returns number of parameters' do
        expect(quap.npar).to eq(2) # mu, sigma
      end
    end

    describe '#aic' do
      it 'calculates AIC' do
        expect(quap.aic).to eq(-2 * quap.loglik + 2 * quap.npar)
      end
    end
  end
end
