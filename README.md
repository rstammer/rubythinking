<p align="center">
  <img src="rubythinking.svg" alt="RubyThinking Logo" width="500"/>
</p>

# Rubythinking

Let's do the _Statistical Rethinking_ journey in Ruby!

## Links to compiled web versions of the notebooks

#### Chapter 2

* [2M1](https://www.robinstammer.de/rubythinking/solutions/2m1)
* [2M2](https://www.robinstammer.de/rubythinking/solutions/2m2)
* [2H1 and 2H2](https://www.robinstammer.de/rubythinking/solutions/2h1_2h2)

#### Chapter 3

* [Fun content: Sampling from a Binomial](https://www.robinstammer.de/rubythinking/binomial)

## Ruby ported code snippets from the chapters

* [Chapter 0](https://github.com/rstammer/rubythinking/blob/master/notebooks/0_chapter_code_snippets.ipynb)
* [Chapter 2](https://github.com/rstammer/rubythinking/blob/master/notebooks/2_chapter_code_snippets.ipynb)
* [Chapter 4](https://github.com/rstammer/rubythinking/blob/master/notebooks/4_chapter_howell.ipynb)

## FAQ

### Q: What is the purpose of this?

The book "Statistical Rethinking" by Richard McElreath is a famous textbook
to learn Bayesian Statistics. There is a variety of additional material on
the internet available for Python, R and probably other programming languages.

This repository offers some material of following the book and its excercises
in Ruby. On the one hand, this repository offers Ruby-based Jupyter notebooks
using [iruby](https://github.com/SciRuby/iruby), on the other hand it is
packaged as Ruby gem to easily install some dependencies like charting libraries
to run the notebooks.

### **Q**: Which version of the book are you using?

The second edition!


### Q: You are often using this in Ruby based notebooks. Can use it without them?

Sure. Just install the gem and play with it in any other Ruby environment you use!

### Q: I'm new to Ruby but want to run your Ruby based notebooks. What should I do?

First: You need to have Jupyter installed on your machine! Check [https://jupyter.org/install](https://jupyter.org/install) for
installation information!

The structure of this repository forms a Ruby gem. But before you can install
it, you need to make sure [iruby](https://github.com/SciRuby/iruby) is working on
your machine. In case of doubt, check latest `iruby` documentation!

Then you just do

```bash
gem install rubythinking && iruby register --force
```

After this, you have installed this little Ruby gem and told iruby kernel to take
it into account. Now you can start a Jupyter notebook and inspect the jupyter
notebooks in the `/notebooks` folder of this repository. To do so, download the repo,
`cd` into the directory and

```
jupyter notebook
```

By installing the gem, some other dependency gems will get installed for you that are
convenient helpers in the notebooks.

If you are creating a new Jupyter notebook with iruby, then you can load all code
used by `rubythinking` like …


## Some examples

The gem provides Ruby versions of common statistical functions used throughout the Statistical Rethinking book:

```ruby
require "rubythinking"
include Rubythinking

# Binomial distribution
dbinom(6, prob: 0.5, size: 9)  # => 0.1640625
rbinom(10, prob: 0.5, size: 5) # => [2, 2, 1, 0, 4, 1, 3, 1, 3, 1]

# Normal distribution  
dnorm(0, mean: 0, sd: 1)        # => 0.3989422804014327
rnorm(5, mean: 10, sd: 2)       # => [8.2, 12.1, 9.8, 11.5, 10.3]

# Quadratic approximation (quap)
data = {
  height: [150, 160, 170, 180, 190],
  weight: [50, 60, 70, 80, 90]
}

formulas = [
  'weight ~ normal(mu, 1)',
  'mu ~ a + b * height', 
  'a ~ normal(0, 50)',
  'b ~ normal(0, 10)'
]

model = quap(formulas: formulas, data: data)
puts model.estimate.summary
# => Quadratic approximation
#    Parameter estimates:
#      a: -99.999 (SE: 5.394)
#      b: 0.999 (SE: 0.032)

# Built-in datasets
Rubythinking::Dataset.available
# => ["cherry_blossoms", "howell", "kline", "milk", "reedfrogs", "ucb_admit", "waffle_divorce"]

milk = Rubythinking::Dataset.load("milk")
cherry = Rubythinking::Dataset.load("cherry_blossoms")

milk.to_df
```

### Chartkick Integration

The gem includes built-in charting capabilities through Chartkick, perfect for visualizing statistical results in Jupyter notebooks:

```ruby
# Line charts for trend visualization
plot_data = {50 => 150, 60 => 160, 70 => 170, 80 => 180, 90 => 190}
line_chart(plot_data, min: 0)

# Area charts for posterior distributions
posterior_samples = {0.1 => 15, 0.2 => 100, 0.3 => 701, 0.4 => 1294, 0.5 => 1994}
area_chart(posterior_samples)

# Histograms from sampling distributions
samples = rbinom(1000, prob: 0.7, size: 15)
histogram_data = samples.group_by(&:itself).transform_values(&:count)
column_chart(histogram_data)
```

### Q: Can I participate?

I'd appreciate this very much! ☀️ This project is very incomplete and there are tons of excercises and snippets of the book
that await being ported to Ruby by someone. Unfortunately, I can only do it from time to time and I'd love having people joining
this initiative.

If you are interested, feel free to pick up any part of the book you are interested in, try replicating or adopting it with Ruby and
then either support an iruby notebook to [the notebooks folder](https://github.com/rstammer/rubythinking/tree/master/notebooks) or _anything else you like_ to this repository.
Supplementary Ruby code can go somewhere in the [the lib folder](https://github.com/rstammer/rubythinking/tree/master/lib).

Even tiny contributions are rewarded with extra positive karma 😉

# Development notes

I often develop having some IRuby jupyter notebook running. Then, I'm making changes to the source code and 
restart the notebook server along reloading the gem by

```sh 
gem install rubythinking-0.4.0.gem && uv run jupyter notebook
```

As you see by this, I often use `uv` for managing the python dependencies like jupyter. Of course, with easy adjustments you can run this in any pythonic env you want, all you need is having jupyter notebooks available.
