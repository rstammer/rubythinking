class Rubythinking::Distributions::Binomial
  class << self
    def samples(n, size:, success:)
      dist = Croupier::Distributions::Binomial.new(size: size, success: success)
      samples = dist.to_enum.take(n)
    end

    def density(value:, size:, success:)
      # Use variable names often used in math
      # textbooks and wikipedia to have code
      # close to the formula
      k = value
      n = size
      p = success

      (factorial(n).to_f / (factorial(k) * factorial(n - k))).to_f * (p**k) * ((1-p)**(n-k))
    end

    def factorial(n)
      return 1 if n < 1
      n.to_i.downto(1).inject(:*)
    end


    def likelihood(w, l, p)
      density(value: w, size: (w+l), success: p)
    end
  end
end
