require 'spec_helper'

RSpec.describe Rubythinking::Histogram do
  describe '#initialize' do
    it 'accepts an Array' do
      expect { Rubythinking::Histogram.new([1, 2, 3, 4, 5]) }.not_to raise_error
    end

    it 'accepts a Daru::Vector' do
      vector = Daru::Vector.new([1, 2, 3, 4, 5])
      expect { Rubythinking::Histogram.new(vector) }.not_to raise_error
    end

    it 'raises error for invalid input' do
      expect { Rubythinking::Histogram.new("invalid") }.to raise_error(ArgumentError)
    end

    it 'accepts custom number of bins' do
      expect { Rubythinking::Histogram.new([1, 2, 3], bins: 10) }.not_to raise_error
    end
  end

  describe '#to_chartkick' do
    context 'with Array input' do
      it 'returns histogram data' do
        histogram = Rubythinking::Histogram.new([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], bins: 5)

        # Mock column_chart to capture the data passed to it
        allow(histogram).to receive(:column_chart) { |data| data }

        result = histogram.to_chartkick

        expect(result).to be_a(Hash)
        expect(result.keys.size).to eq(5) # 5 bins
        expect(result.values.sum).to eq(10) # 10 data points
      end

      it 'handles negative values' do
        histogram = Rubythinking::Histogram.new([-5, -3, -1, 1, 3, 5], bins: 3)

        allow(histogram).to receive(:column_chart) { |data| data }
        result = histogram.to_chartkick

        expect(result).to be_a(Hash)
        expect(result.values.sum).to eq(6)
      end

      it 'handles decimal values' do
        histogram = Rubythinking::Histogram.new([1.5, 2.3, 3.7, 4.2], bins: 4)

        allow(histogram).to receive(:column_chart) { |data| data }
        result = histogram.to_chartkick

        expect(result).to be_a(Hash)
        expect(result.values.sum).to eq(4)
      end
    end

    context 'with Daru::Vector input' do
      it 'returns histogram data' do
        vector = Daru::Vector.new([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
        histogram = Rubythinking::Histogram.new(vector, bins: 5)

        allow(histogram).to receive(:column_chart) { |data| data }
        result = histogram.to_chartkick

        expect(result).to be_a(Hash)
        expect(result.keys.size).to eq(5)
        expect(result.values.sum).to eq(10)
      end

      it 'handles nil values in Daru::Vector' do
        vector = Daru::Vector.new([1, 2, nil, 3, 4, nil, 5])
        histogram = Rubythinking::Histogram.new(vector, bins: 5)

        allow(histogram).to receive(:column_chart) { |data| data }
        result = histogram.to_chartkick

        expect(result.values.sum).to eq(5) # Only non-nil values
      end
    end

    context 'edge cases' do
      it 'handles empty array' do
        histogram = Rubythinking::Histogram.new([])

        allow(histogram).to receive(:column_chart) { |data| data }
        result = histogram.to_chartkick

        expect(result).to eq({})
      end

      it 'handles single value' do
        histogram = Rubythinking::Histogram.new([5])

        allow(histogram).to receive(:column_chart) { |data| data }
        result = histogram.to_chartkick

        expect(result).to eq({5 => 1})
      end

      it 'handles all same values' do
        histogram = Rubythinking::Histogram.new([3, 3, 3, 3])

        allow(histogram).to receive(:column_chart) { |data| data }
        result = histogram.to_chartkick

        expect(result).to eq({3 => 4})
      end
    end

    context 'bin distribution' do
      it 'distributes values across bins correctly' do
        # Values evenly distributed from 0 to 100
        values = (0..99).to_a
        histogram = Rubythinking::Histogram.new(values, bins: 10)

        allow(histogram).to receive(:column_chart) { |data| data }
        result = histogram.to_chartkick

        expect(result.keys.size).to eq(10)
        # Each bin should have approximately 10 values
        result.values.each do |count|
          expect(count).to be_between(8, 12)
        end
      end

      it 'uses 30 bins by default' do
        values = (1..100).to_a
        histogram = Rubythinking::Histogram.new(values)

        allow(histogram).to receive(:column_chart) { |data| data }
        result = histogram.to_chartkick

        expect(result.keys.size).to eq(30)
      end
    end
  end
end

RSpec.describe Rubythinking, '.dens' do
  it 'creates histogram from array' do
    expect { Rubythinking.dens([1, 2, 3, 4, 5]) }.not_to raise_error
  end

  it 'creates histogram from Daru::Vector' do
    vector = Daru::Vector.new([1, 2, 3, 4, 5])
    expect { Rubythinking.dens(vector) }.not_to raise_error
  end

  it 'accepts custom bins parameter' do
    expect { Rubythinking.dens([1, 2, 3, 4, 5], bins: 10) }.not_to raise_error
  end
end
