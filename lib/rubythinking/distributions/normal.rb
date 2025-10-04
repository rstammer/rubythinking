module Rubythinking
  module Distributions
    class Normal
      # Generate a single normal random variable using Box-Muller transform
      def self.random(mean = 0, std = 1)
        # Box-Muller transformation
        u1 = rand
        u2 = rand
        z0 = Math.sqrt(-2 * Math.log(u1)) * Math.cos(2 * Math::PI * u2)
        mean + std * z0
      end

      # Generate multiple normal random variables
      def self.samples(n, mean = 0, std = 1)
        Array.new(n) { random(mean, std) }
      end

      # Probability density function
      def self.density(x, mean = 0, std = 1)
        coefficient = 1.0 / (std * Math.sqrt(2 * Math::PI))
        exponent = -0.5 * ((x - mean) / std) ** 2
        coefficient * Math.exp(exponent)
      end
    end
  end
end