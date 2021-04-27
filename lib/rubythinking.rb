require "rubythinking/version"
require "rubythinking/distributions"
require "rubythinking/distributions/binomial"
require "vega"
require "cmd_stan_rb"
require "croupier"

module Rubythinking
  # Mimicks R API
  def dbinom(value, size:, prob:)
    Rubythinking::Distributions::Binomial.density(value: value, success: prob, size: size)
  end

  def rbinom(n, size:, prob:)
    Rubythinking::Distributions::Binomial.samples(n, success: prob, size: size)
  end
end
