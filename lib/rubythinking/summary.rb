require 'daru'

module Rubythinking
  class Summary
    def initialize(dataframe)
      @dataframe = dataframe
    end

    def to_s
      return "Empty dataframe" if @dataframe.nil? || @dataframe.vectors.empty?

      # Calculate statistics for each numeric column
      stats = {}
      @dataframe.vectors.each do |col_name|
        vector = @dataframe[col_name]
        next unless vector.type == :numeric || vector.to_a.all? { |v| v.is_a?(Numeric) }

        values = vector.to_a.compact.sort
        next if values.empty?

        stats[col_name] = {
          mean: mean(values),
          sd: standard_deviation(values),
          percentile_5_5: percentile(values, 5.5),
          percentile_94_5: percentile(values, 94.5)
        }
      end

      return "No numeric columns found" if stats.empty?

      # Format as table with observation count
      num_obs = @dataframe.size
      num_vars = stats.size
      header = "#{num_obs} obs. of #{num_vars} variables\n\n"
      header + format_table(stats)
    end

    private

    def mean(values)
      values.sum.to_f / values.size
    end

    def standard_deviation(values)
      m = mean(values)
      variance = values.map { |v| (v - m) ** 2 }.sum / values.size
      Math.sqrt(variance)
    end

    def percentile(sorted_values, percentile)
      k = (sorted_values.size - 1) * (percentile / 100.0)
      f = k.floor
      c = k.ceil

      if f == c
        sorted_values[k]
      else
        sorted_values[f] * (c - k) + sorted_values[c] * (k - f)
      end
    end

    def format_table(stats)
      # Calculate column widths
      col_name_width = [stats.keys.map(&:to_s).map(&:length).max, 10].max

      # Header
      output = []
      output << sprintf("%-#{col_name_width}s  %10s  %10s  %10s  %10s",
                       "", "mean", "sd", "5.5%", "94.5%")
      output << "-" * (col_name_width + 46)

      # Rows
      stats.each do |col_name, values|
        output << sprintf("%-#{col_name_width}s  %10.2f  %10.2f  %10.2f  %10.2f",
                         col_name,
                         values[:mean],
                         values[:sd],
                         values[:percentile_5_5],
                         values[:percentile_94_5])
      end

      output.join("\n")
    end
  end
end
