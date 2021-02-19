class Rubythinking::Distributions::Binomial
  class << self
    def factorial(n)
      return 1 if n < 1
      n.to_i.downto(1).inject(:*)
    end


    def likelihood(w, l, p)
      (factorial(w+l).to_f / (factorial(w) * factorial(l))).to_f * (p**w) * ((1-p)**l)
    end
  end
end
