library(rethinking)

globe.qa <- quap(
  alist(
    W ~ dbinom(W + L, p), # Binomial likelihood
    p ~ dunif(0, 1) # uniform prior
  ),
  data = list(W = 6, L = 3)
)

precis(globe.qa)
