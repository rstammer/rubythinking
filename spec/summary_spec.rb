require 'spec_helper'

RSpec.describe Rubythinking::Summary do
  describe '#to_s' do
    context 'with Daru DataFrame' do
      it 'calculates statistics for numeric columns' do
        df = Daru::DataFrame.new({
          height: [150, 160, 170, 180, 190],
          weight: [50, 60, 70, 80, 90]
        })

        summary = Rubythinking::Summary.new(df).to_s

        expect(summary).to include('height')
        expect(summary).to include('weight')
        expect(summary).to include('mean')
        expect(summary).to include('sd')
        expect(summary).to include('5.5%')
        expect(summary).to include('94.5%')
      end

      it 'handles empty dataframe' do
        df = Daru::DataFrame.new({})
        summary = Rubythinking::Summary.new(df).to_s

        expect(summary).to eq('Empty dataframe')
      end

      it 'skips non-numeric columns' do
        df = Daru::DataFrame.new({
          name: ['Alice', 'Bob', 'Charlie'],
          age: [25, 30, 35]
        })

        summary = Rubythinking::Summary.new(df).to_s

        expect(summary).to include('age')
        expect(summary).not_to include('name')
      end
    end

    context 'with nil input' do
      it 'handles nil gracefully' do
        summary = Rubythinking::Summary.new(nil).to_s
        expect(summary).to eq('Empty dataframe')
      end
    end

    context 'statistical calculations' do
      let(:df) do
        Daru::DataFrame.new({
          values: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        })
      end

      it 'calculates mean correctly' do
        summary = Rubythinking::Summary.new(df).to_s
        expect(summary).to match(/5\.50/)  # mean of 1-10 is 5.5
      end

      it 'calculates percentiles correctly' do
        summary = Rubythinking::Summary.new(df).to_s
        # 5.5% percentile of 1-10 should be around 1.5
        # 94.5% percentile should be around 9.5
        expect(summary).to match(/1\.\d+/)
        expect(summary).to match(/9\.\d+/)
      end

      it 'formats numbers with 2 decimal places' do
        summary = Rubythinking::Summary.new(df).to_s
        lines = summary.split("\n")
        data_line = lines.last

        # Check that values have decimal points
        expect(data_line).to match(/\d+\.\d{2}/)
      end
    end
  end
end
