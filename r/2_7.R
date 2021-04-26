f <- 6
L <- 3

curve(dbeta(x, W+1, L+1), from = 0, to = 1)
curve(dnorm(x, 0.67, 0.16), lty = 2, add = TRUE)
