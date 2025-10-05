require "rubythinking/version"
require "rubythinking/distributions"
require "rubythinking/distributions/binomial"
require "rubythinking/distributions/normal"
require "rubythinking/quap"
require "croupier"
require "iruby/chartkick"

include IRuby::Chartkick

module Rubythinking
  def dbinom(value, size:, prob:)
    Rubythinking::Distributions::Binomial.density(value: value, success: prob, size: size)
  end

  def rbinom(n, size:, prob:)
    Rubythinking::Distributions::Binomial.samples(n, success: prob, size: size)
  end

  def dnorm(value, mean: 0, sd: 1)
    Rubythinking::Distributions::Normal.density(value, mean, sd)
  end

  def rnorm(n, mean: 0, sd: 1)
    Rubythinking::Distributions::Normal.samples(n, mean, sd)
  end

  def quap(formulas:, data:, start: nil)
    Rubythinking::Quap.new(formulas: formulas, data: data, start: start)
  end

  module_function :dbinom, :rbinom, :dnorm, :rnorm, :quap
end
