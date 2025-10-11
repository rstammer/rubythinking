require 'daru'

module Rubythinking
  class Histogram
    def initialize(vector, bins: 30)
      @vector = normalize_vector(vector)
      @bins = bins
    end

    def to_chartkick
      histogram_data = calculate_histogram
      column_chart(histogram_data)
    end

    private

    def normalize_vector(vector)
      if vector.is_a?(Daru::Vector)
        vector.to_a.compact
      elsif vector.is_a?(Array)
        vector.compact
      else
        raise ArgumentError, "Expected Array or Daru::Vector, got #{vector.class}"
      end
    end

    def calculate_histogram
      return {} if @vector.empty?

      min_val = @vector.min
      max_val = @vector.max

      # Handle edge case where all values are the same
      return { min_val => @vector.size } if min_val == max_val

      bin_width = (max_val - min_val).to_f / @bins
      histogram = Hash.new(0)

      # Create bins
      @bins.times do |i|
        bin_start = min_val + (i * bin_width)
        bin_end = min_val + ((i + 1) * bin_width)
        bin_center = (bin_start + bin_end) / 2.0
        histogram[bin_center.round(2)] = 0
      end

      # Count values in each bin
      @vector.each do |value|
        # Calculate which bin this value belongs to
        bin_index = ((value - min_val) / bin_width).floor
        # Handle edge case where value equals max_val
        bin_index = @bins - 1 if bin_index >= @bins

        bin_start = min_val + (bin_index * bin_width)
        bin_end = min_val + ((bin_index + 1) * bin_width)
        bin_center = (bin_start + bin_end) / 2.0

        histogram[bin_center.round(2)] += 1
      end

      histogram.sort.to_h
    end
  end
end
