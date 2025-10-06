require 'csv'
require 'daru'

module Rubythinking
  class Dataset
    attr_reader :data, :columns
    
    def initialize(data, columns)
      @data = data
      @columns = columns
    end
    
    def self.available
      data_dir = File.join(File.dirname(__FILE__), '../../data')
      csv_files = Dir.glob(File.join(data_dir, '*.csv'))
      csv_files.map { |file| File.basename(file, '.csv') }.sort
    end
    
    def self.load(name)
      file_path = File.join(File.dirname(__FILE__), '../../data', "#{name}.csv")
      
      unless File.exist?(file_path)
        raise ArgumentError, "Dataset '#{name}' not found at #{file_path}"
      end
      
      rows = []
      columns = nil
      
      CSV.foreach(file_path, headers: true, converters: :numeric) do |row|
        columns ||= row.headers
        rows << row.to_h
      end
      
      new(rows, columns)
    end
    
    def to_csv
      CSV.generate do |csv|
        csv << @columns
        @data.each do |row|
          csv << @columns.map { |col| row[col] }
        end
      end
    end
    
    def to_df
      Daru::DataFrame.new(@data)
    end
    
    def [](column)
      @data.map { |row| row[column] }
    end
    
    def size
      @data.size
    end
    
    def length
      size
    end
    
    def each(&block)
      @data.each(&block)
    end
    
    def map(&block)
      @data.map(&block)
    end
    
    def select(&block)
      filtered_data = @data.select(&block)
      Dataset.new(filtered_data, @columns)
    end
    
    def where(conditions = {})
      filtered_data = @data.select do |row|
        conditions.all? { |column, value| row[column.to_s] == value }
      end
      Dataset.new(filtered_data, @columns)
    end
    
    def summary
      result = {}
      @columns.each do |column|
        values = self[column].compact
        if values.first.is_a?(Numeric)
          result[column] = {
            min: values.min,
            max: values.max,
            mean: values.sum.to_f / values.length,
            count: values.length
          }
        else
          result[column] = {
            unique_values: values.uniq.length,
            count: values.length
          }
        end
      end
      result
    end
    
    def inspect
      "#<Rubythinking::Dataset rows=#{size} columns=#{@columns.inspect}>"
    end
    
    def to_s
      inspect
    end
  end
end