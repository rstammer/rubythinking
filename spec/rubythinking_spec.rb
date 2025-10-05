require 'spec_helper'

RSpec.describe Rubythinking do
  it "has a version number" do
    expect(Rubythinking::VERSION).not_to be nil
  end

  describe "quap method" do
    it "is available as a module method" do
      expect(Rubythinking).to respond_to(:quap)
    end

    it "supports the full workflow" do
      data = { y: [1.0, 1.5, 2.0] }
      formulas = [
        'y ~ normal(mu, sigma)', 
        'mu ~ normal(0, 10)', 
        'sigma ~ exponential(1)'
      ]
      
      quap = Rubythinking.quap(formulas: formulas, data: data).estimate
      expect(quap.estimated?).to be true
      expect(quap.coef).to have_key('mu')
      expect(quap.coef).to have_key('sigma')
    end
  end
end
