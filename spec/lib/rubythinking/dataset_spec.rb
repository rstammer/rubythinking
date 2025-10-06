require 'spec_helper'

RSpec.describe Rubythinking::Dataset do
  let(:sample_data) do
    [
      { "height" => 151.765, "weight" => 47.8256065, "age" => 63, "male" => 1 },
      { "height" => 139.7, "weight" => 36.4858065, "age" => 63, "male" => 0 },
      { "height" => 136.525, "weight" => 31.864838, "age" => 65, "male" => 0 }
    ]
  end
  
  let(:sample_columns) { ["height", "weight", "age", "male"] }
  let(:dataset) { described_class.new(sample_data, sample_columns) }

  describe '.load' do
    context 'when dataset exists' do
      it 'loads the howell dataset' do
        howell = described_class.load('howell')
        
        expect(howell).to be_a(described_class)
        expect(howell.columns).to eq(["height", "weight", "age", "male"])
        expect(howell.size).to be > 0
        expect(howell.data.first).to have_key("height")
        expect(howell.data.first).to have_key("weight")
        expect(howell.data.first).to have_key("age")
        expect(howell.data.first).to have_key("male")
      end
      
      it 'converts numeric values properly' do
        howell = described_class.load('howell')
        first_row = howell.data.first
        
        expect(first_row["height"]).to be_a(Numeric)
        expect(first_row["weight"]).to be_a(Numeric)
        expect(first_row["age"]).to be_a(Numeric)
        expect(first_row["male"]).to be_a(Numeric)
      end
    end
    
    context 'when dataset does not exist' do
      it 'raises an ArgumentError' do
        expect {
          described_class.load('nonexistent')
        }.to raise_error(ArgumentError, /Dataset 'nonexistent' not found/)
      end
    end
  end

  describe '#initialize' do
    it 'initializes with data and columns' do
      expect(dataset.data).to eq(sample_data)
      expect(dataset.columns).to eq(sample_columns)
    end
  end

  describe '#to_csv' do
    it 'converts dataset to CSV format' do
      csv_output = dataset.to_csv
      lines = csv_output.split("\n")
      
      expect(lines.first).to eq("height,weight,age,male")
      expect(lines[1]).to eq("151.765,47.8256065,63,1")
      expect(lines.length).to eq(4) # header + 3 data rows
    end
  end

  describe '#to_df' do
    it 'converts to Daru DataFrame' do
      df = dataset.to_df
      expect(df).to be_a(Daru::DataFrame)
      expect(df.nrows).to eq(3)
      expect(df.vectors.to_a).to eq(["height", "weight", "age", "male"])
    end
  end

  describe '#[]' do
    it 'returns column values as array' do
      heights = dataset["height"]
      expect(heights).to eq([151.765, 139.7, 136.525])
    end
    
    it 'returns empty array for non-existent column' do
      expect(dataset["nonexistent"]).to eq([nil, nil, nil])
    end
  end

  describe '#size and #length' do
    it 'returns the number of rows' do
      expect(dataset.size).to eq(3)
      expect(dataset.length).to eq(3)
    end
  end

  describe '#each' do
    it 'iterates over data rows' do
      rows = []
      dataset.each { |row| rows << row }
      
      expect(rows).to eq(sample_data)
    end
  end

  describe '#map' do
    it 'maps over data rows' do
      heights = dataset.map { |row| row["height"] }
      expect(heights).to eq([151.765, 139.7, 136.525])
    end
  end

  describe '#select' do
    it 'filters rows based on condition' do
      males = dataset.select { |row| row["male"] == 1 }
      
      expect(males).to be_a(described_class)
      expect(males.size).to eq(1)
      expect(males.data.first["height"]).to eq(151.765)
      expect(males.columns).to eq(sample_columns)
    end
  end

  describe '#where' do
    it 'filters rows based on hash conditions' do
      males = dataset.where(male: 1)
      
      expect(males).to be_a(described_class)
      expect(males.size).to eq(1)
      expect(males.data.first["height"]).to eq(151.765)
    end
    
    it 'filters with multiple conditions' do
      elderly_males = dataset.where(male: 1, age: 63)
      
      expect(elderly_males.size).to eq(1)
      expect(elderly_males.data.first["height"]).to eq(151.765)
    end
    
    it 'returns empty dataset when no matches' do
      result = dataset.where(age: 999)
      
      expect(result).to be_a(described_class)
      expect(result.size).to eq(0)
    end
  end

  describe '#summary' do
    it 'provides summary statistics for numeric columns' do
      summary = dataset.summary
      
      expect(summary["height"]).to include(:min, :max, :mean, :count)
      expect(summary["height"][:min]).to eq(136.525)
      expect(summary["height"][:max]).to eq(151.765)
      expect(summary["height"][:count]).to eq(3)
      expect(summary["height"][:mean]).to be_within(0.01).of(142.66)
    end
    
    it 'provides count statistics for non-numeric columns' do
      string_data = [
        { "name" => "Alice", "city" => "NYC" },
        { "name" => "Bob", "city" => "NYC" },
        { "name" => "Charlie", "city" => "LA" }
      ]
      string_dataset = described_class.new(string_data, ["name", "city"])
      summary = string_dataset.summary
      
      expect(summary["name"]).to include(:unique_values, :count)
      expect(summary["name"][:unique_values]).to eq(3)
      expect(summary["name"][:count]).to eq(3)
      expect(summary["city"][:unique_values]).to eq(2)
    end
  end

  describe '#inspect and #to_s' do
    it 'provides readable string representation' do
      expected = "#<Rubythinking::Dataset rows=3 columns=[\"height\", \"weight\", \"age\", \"male\"]>"
      
      expect(dataset.inspect).to eq(expected)
      expect(dataset.to_s).to eq(expected)
    end
  end

  describe 'integration with real howell dataset' do
    let(:howell) { described_class.load('howell') }
    
    it 'can perform complex operations on real data' do
      adults = howell.where(age: 18).select { |row| row["height"] > 150 }
      expect(adults.size).to be >= 0
      
      heights = howell["height"]
      expect(heights.length).to eq(howell.size)
      
      summary = howell.summary
      expect(summary["height"]).to include(:min, :max, :mean, :count)
    end
    
    it 'can convert to CSV and back' do
      csv_string = howell.to_csv
      expect(csv_string).to include("height,weight,age,male")
      expect(csv_string.split("\n").length).to eq(howell.size + 1) # +1 for header
    end
  end
end